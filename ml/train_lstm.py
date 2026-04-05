"""
Train a multi-input BiLSTM classifier on bridgemend_dataset_10000.csv (PyTorch).

Combines utterance text (stacked BiLSTM + packed sequences) with categorical
context (session_type, speaker) for stronger pattern recognition than text alone.

Designed for high validation accuracy on ~1k rows:
  - Context branch + combined text mode (default)
  - Class-weighted cross-entropy for imbalanced labels
  - Tokenizer fit on training split only
  - AdamW + ReduceLROnPlateau + early stopping on val accuracy

Requires Python with PyTorch wheels (including 3.14; TensorFlow is not used).

Usage:
  cd ml
  pip install -r requirements.txt
  python train_lstm.py
  python train_lstm.py --target response_type
"""

from __future__ import annotations

import argparse
import json
import random
import re
from collections import Counter
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.utils.class_weight import compute_class_weight
from torch.nn.utils.rnn import pack_padded_sequence
from torch.utils.data import DataLoader, Dataset

TARGET_CHOICES = ("emotion", "conflict_type", "response_type", "privacy_level")
TEXT_MODE_CHOICES = ("input_only", "combined")
CONTEXT_PRESETS = ("default", "none")


def set_seeds(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def build_text_series(df: pd.DataFrame, mode: str) -> pd.Series:
    if mode == "input_only":
        return df["input_text"].astype(str)
    return (
        df["session_type"].astype(str)
        + " "
        + df["speaker"].astype(str)
        + " "
        + df["input_text"].astype(str)
    )


def context_columns_for_target(preset: str, target: str) -> list[str]:
    if preset == "none":
        return []
    base = ["session_type", "speaker"]
    return [c for c in base if c != target]


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parent
    p = argparse.ArgumentParser(description="Train multi-input BiLSTM on BridgeMend CSV")
    p.add_argument(
        "--csv",
        type=Path,
        default=root / "dataset" / "bridgemend_dataset_10000.csv",
    )
    p.add_argument("--target", default="emotion", choices=TARGET_CHOICES)
    p.add_argument(
        "--text-mode",
        default="combined",
        choices=TEXT_MODE_CHOICES,
    )
    p.add_argument(
        "--context",
        default="default",
        choices=CONTEXT_PRESETS,
    )
    p.add_argument("--max-words", type=int, default=4000)
    p.add_argument("--max-len", type=int, default=96)
    p.add_argument("--embedding-dim", type=int, default=96)
    p.add_argument("--lstm-units", type=int, default=72)
    p.add_argument("--lstm-layers", type=int, default=2)
    p.add_argument("--epochs", type=int, default=80)
    p.add_argument("--batch-size", type=int, default=24)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--lr", type=float, default=1.5e-3)
    p.add_argument("--weight-decay", type=float, default=1e-4)
    p.add_argument("--no-class-weights", action="store_true")
    p.add_argument("--out-dir", type=Path, default=root / "artifacts")
    return p.parse_args()


def make_class_weight_tensor(y_int: np.ndarray, num_classes: int, device: torch.device) -> torch.Tensor:
    classes = np.arange(num_classes)
    w = compute_class_weight(class_weight="balanced", classes=classes, y=y_int)
    return torch.tensor(w, dtype=torch.float32, device=device)


def sanitize_key(name: str) -> str:
    return name.replace(".", "_")


class WordTokenizer:
    """Keras-style word index: 0 = padding, 1 = OOV, 2+ = frequent words."""

    def __init__(self, num_words: int = 4000, oov_token: str = "<OOV>") -> None:
        self.num_words = num_words
        self.oov_token = oov_token
        self.word_index: dict[str, int] = {}

    @staticmethod
    def _tokenize(text: str) -> list[str]:
        return re.findall(r"[a-z0-9']+", str(text).lower())

    def fit_on_texts(self, texts: list[str]) -> None:
        cnt: Counter[str] = Counter()
        for raw in texts:
            for w in self._tokenize(raw):
                cnt[w] += 1
        self.word_index = {self.oov_token: 1}
        nxt = 2
        for word, _ in cnt.most_common():
            if nxt >= self.num_words:
                break
            if word in self.word_index:
                continue
            self.word_index[word] = nxt
            nxt += 1

    def texts_to_sequences(self, texts: list[str]) -> list[list[int]]:
        oov = self.word_index[self.oov_token]
        return [[self.word_index.get(w, oov) for w in self._tokenize(raw)] for raw in texts]


def pad_sequences(
    sequences: list[list[int]],
    maxlen: int,
    padding: str = "post",
    truncating: str = "post",
    dtype: type = np.int64,
) -> np.ndarray:
    arr = np.zeros((len(sequences), maxlen), dtype=dtype)
    for i, seq in enumerate(sequences):
        s = list(seq)
        if not s:
            continue
        if truncating == "post":
            s = s[:maxlen]
        else:
            s = s[-maxlen:]
        if padding == "post":
            for j, v in enumerate(s):
                if j < maxlen:
                    arr[i, j] = v
        else:
            off = maxlen - len(s)
            for j, v in enumerate(s):
                k = off + j
                if 0 <= k < maxlen:
                    arr[i, k] = v
    return arr


class BridgeRowsDataset(Dataset):
    def __init__(
        self,
        x: np.ndarray,
        y: np.ndarray,
        context_arrays: list[np.ndarray],
    ) -> None:
        self.x = x.astype(np.int64)
        self.y = y.astype(np.int64)
        self.context_arrays = [a.astype(np.int64) for a in context_arrays]

    def __len__(self) -> int:
        return len(self.y)

    def __getitem__(self, i: int):
        row = self.x[i]
        length = int(np.count_nonzero(row))
        if length == 0:
            length = 1
        ctx = [a[i] for a in self.context_arrays]
        return row, length, *ctx, self.y[i]


def collate_fn_factory(context_cols: list[str]):
    def collate(batch):
        rows = np.stack([b[0] for b in batch])
        lengths = torch.tensor([b[1] for b in batch], dtype=torch.long)
        y = torch.tensor([b[-1] for b in batch], dtype=torch.long)
        texts = torch.from_numpy(rows)
        ctx = {}
        for j, col in enumerate(context_cols):
            ctx[col] = torch.tensor([b[2 + j] for b in batch], dtype=torch.long)
        return texts, lengths, ctx, y

    return collate


class BridgeMendLSTM(nn.Module):
    def __init__(
        self,
        vocab_size: int,
        embed_dim: int,
        lstm_hidden: int,
        lstm_layers: int,
        num_classes: int,
        context_specs: list[tuple[str, int, int]],
        dropout: float = 0.35,
    ) -> None:
        super().__init__()
        self._context_specs_order = list(context_specs)
        self.word_emb = nn.Embedding(vocab_size, embed_dim, padding_idx=0)
        self.lstm = nn.LSTM(
            embed_dim,
            lstm_hidden,
            num_layers=lstm_layers,
            batch_first=True,
            bidirectional=True,
            dropout=dropout if lstm_layers > 1 else 0.0,
        )
        self.context_embeddings = nn.ModuleDict()
        ctx_out = 0
        for name, n_cat, dim in context_specs:
            key = sanitize_key(name)
            self.context_embeddings[key] = nn.Embedding(n_cat, dim)
            ctx_out += dim
        lstm_out = lstm_hidden * 2
        merge_in = lstm_out + ctx_out
        self.head = nn.Sequential(
            nn.Linear(merge_in, 96),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(96, 48),
            nn.ReLU(),
            nn.Dropout(dropout * 0.7),
            nn.Linear(48, num_classes),
        )

    def forward(self, text_ids: torch.Tensor, lengths: torch.Tensor, ctx_dict: dict[str, torch.Tensor]):
        emb = self.word_emb(text_ids)
        packed = pack_padded_sequence(
            emb,
            lengths.detach().cpu(),
            batch_first=True,
            enforce_sorted=False,
        )
        _, (h_n, _) = self.lstm(packed)
        h_forward = h_n[-2]
        h_backward = h_n[-1]
        text_vec = torch.cat([h_forward, h_backward], dim=1)
        parts = [text_vec]
        for name, _, _ in self._context_specs_order:
            key = sanitize_key(name)
            parts.append(self.context_embeddings[key](ctx_dict[name]))
        h = torch.cat(parts, dim=1)
        return self.head(h)


def top2_accuracy(logits: torch.Tensor, y: torch.Tensor) -> float:
    if logits.size(-1) < 3:
        return float((logits.argmax(dim=-1) == y).float().mean().item())
    top2 = logits.topk(2, dim=-1).indices
    ok = (top2 == y.unsqueeze(-1)).any(dim=-1)
    return float(ok.float().mean().item())


def main() -> None:
    args = parse_args()
    set_seeds(args.seed)

    df = pd.read_csv(args.csv)
    required = {"input_text", args.target, "session_type", "speaker"}
    missing = required - set(df.columns)
    if missing:
        raise SystemExit(f"Missing columns {missing} in {args.csv}")

    context_cols = context_columns_for_target(args.context, args.target)
    texts_full = build_text_series(df, args.text_mode)
    y_raw = df[args.target].astype(str)

    target_le = LabelEncoder()
    y = target_le.fit_transform(y_raw)
    num_classes = len(target_le.classes_)

    idx = np.arange(len(df))
    train_idx, val_idx = train_test_split(
        idx,
        test_size=0.2,
        random_state=args.seed,
        stratify=y,
    )

    texts_train = texts_full.iloc[train_idx].tolist()
    texts_val = texts_full.iloc[val_idx].tolist()

    tokenizer = WordTokenizer(num_words=args.max_words, oov_token="<OOV>")
    tokenizer.fit_on_texts(texts_train)

    x_train = pad_sequences(
        tokenizer.texts_to_sequences(texts_train),
        maxlen=args.max_len,
        padding="post",
        truncating="post",
    )
    x_val = pad_sequences(
        tokenizer.texts_to_sequences(texts_val),
        maxlen=args.max_len,
        padding="post",
        truncating="post",
    )

    context_encoders: dict[str, LabelEncoder] = {}
    context_train: list[np.ndarray] = []
    context_val: list[np.ndarray] = []
    context_specs: list[tuple[str, int, int]] = []

    for col in context_cols:
        enc = LabelEncoder()
        enc.fit(df[col].astype(str).unique())
        context_encoders[col] = enc
        n_cat = len(enc.classes_)
        dim = min(32, max(4, (n_cat + 1) // 2))
        context_specs.append((col, n_cat, dim))
        context_train.append(enc.transform(df[col].astype(str).iloc[train_idx].values).astype(np.int64))
        context_val.append(enc.transform(df[col].astype(str).iloc[val_idx].values).astype(np.int64))

    y_train = y[train_idx]
    y_val = y[val_idx]

    max_token_id = int(np.max(np.concatenate([x_train.ravel(), x_val.ravel()])))
    embedding_input_dim = max_token_id + 1

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = BridgeMendLSTM(
        vocab_size=embedding_input_dim,
        embed_dim=args.embedding_dim,
        lstm_hidden=args.lstm_units,
        lstm_layers=args.lstm_layers,
        num_classes=num_classes,
        context_specs=context_specs,
    ).to(device)

    ce_weight = None
    if not args.no_class_weights:
        ce_weight = make_class_weight_tensor(y_train, num_classes, device)

    criterion = nn.CrossEntropyLoss(weight=ce_weight)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=args.weight_decay)
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode="min", factor=0.45, patience=4, min_lr=1e-6
    )

    train_ds = BridgeRowsDataset(x_train, y_train, context_train)
    val_ds = BridgeRowsDataset(x_val, y_val, context_val)
    collate = collate_fn_factory(context_cols)
    train_loader = DataLoader(
        train_ds,
        batch_size=args.batch_size,
        shuffle=True,
        collate_fn=collate,
        drop_last=False,
    )
    val_loader = DataLoader(
        val_ds,
        batch_size=args.batch_size,
        shuffle=False,
        collate_fn=collate,
    )

    args.out_dir.mkdir(parents=True, exist_ok=True)
    weights_path = args.out_dir / f"lstm_{args.target}.pt"

    best_acc = -1.0
    best_val_loss = float("inf")
    stale = 0
    for epoch in range(args.epochs):
        model.train()
        train_loss = 0.0
        n_tr = 0
        for texts, lengths, ctx, yb in train_loader:
            texts = texts.to(device)
            lengths = lengths.to(device)
            yb = yb.to(device)
            ctx_d = {k: v.to(device) for k, v in ctx.items()}

            optimizer.zero_grad(set_to_none=True)
            logits = model(texts, lengths, ctx_d)
            loss = criterion(logits, yb)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()

            train_loss += loss.item() * yb.size(0)
            n_tr += yb.size(0)

        model.eval()
        val_loss = 0.0
        val_correct = 0
        val_n = 0
        val_top2 = 0.0
        with torch.no_grad():
            for texts, lengths, ctx, yb in val_loader:
                texts = texts.to(device)
                lengths = lengths.to(device)
                yb = yb.to(device)
                ctx_d = {k: v.to(device) for k, v in ctx.items()}
                logits = model(texts, lengths, ctx_d)
                loss = criterion(logits, yb)
                val_loss += loss.item() * yb.size(0)
                val_correct += (logits.argmax(dim=-1) == yb).sum().item()
                val_n += yb.size(0)
                val_top2 += top2_accuracy(logits, yb) * yb.size(0)

        tr_l = train_loss / max(n_tr, 1)
        va_l = val_loss / max(val_n, 1)
        acc = val_correct / max(val_n, 1)
        t2 = val_top2 / max(val_n, 1)
        scheduler.step(va_l)

        improved = acc > best_acc or (acc == best_acc and va_l < best_val_loss)
        if improved:
            best_acc = acc
            best_val_loss = va_l
            stale = 0
            torch.save(model.state_dict(), weights_path)
        else:
            stale += 1

        print(
            f"Epoch {epoch + 1}/{args.epochs}  "
            f"train_loss={tr_l:.4f}  val_loss={va_l:.4f}  "
            f"val_acc={acc:.4f}  val_top2={t2:.4f}  best_acc={best_acc:.4f}"
        )

        if stale >= 12:
            print("Early stopping.")
            break

    try:
        state = torch.load(weights_path, map_location=device, weights_only=True)
    except TypeError:
        state = torch.load(weights_path, map_location=device)
    model.load_state_dict(state)

    model.eval()
    final_loss = 0.0
    final_correct = 0
    final_n = 0
    final_top2 = 0.0
    with torch.no_grad():
        for texts, lengths, ctx, yb in val_loader:
            texts = texts.to(device)
            lengths = lengths.to(device)
            yb = yb.to(device)
            ctx_d = {k: v.to(device) for k, v in ctx.items()}
            logits = model(texts, lengths, ctx_d)
            final_loss += criterion(logits, yb).item() * yb.size(0)
            final_correct += (logits.argmax(dim=-1) == yb).sum().item()
            final_n += yb.size(0)
            final_top2 += top2_accuracy(logits, yb) * yb.size(0)

    joblib.dump(tokenizer, args.out_dir / f"tokenizer_{args.target}.joblib")
    joblib.dump(target_le, args.out_dir / f"label_encoder_{args.target}.joblib")
    joblib.dump(context_encoders, args.out_dir / f"context_encoders_{args.target}.joblib")

    meta = {
        "framework": "pytorch",
        "target": args.target,
        "text_mode": args.text_mode,
        "context_cols": context_cols,
        "max_len": args.max_len,
        "max_words": args.max_words,
        "classes": target_le.classes_.tolist(),
        "embedding_input_dim": embedding_input_dim,
        "context_sizes": {c: len(context_encoders[c].classes_) for c in context_cols},
        "lstm_layers": args.lstm_layers,
        "weights_file": weights_path.name,
    }
    (args.out_dir / f"metadata_{args.target}.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")

    fl = final_loss / max(final_n, 1)
    fa = final_correct / max(final_n, 1)
    ft2 = final_top2 / max(final_n, 1)
    print(f"Saved weights: {weights_path}")
    print(f"Validation: loss={fl:.4f}  accuracy={fa:.4f}  top2_accuracy={ft2:.4f}")


if __name__ == "__main__":
    main()
