"""
Stratified k-fold cross-validation for the BridgeMend LSTM emotion classifier.

Trains k separate models (one per fold), tokenizer fit on train only each time.
Context label encoders match train_lstm.py (fit on full-column uniques).

Reports:
  - Per-fold macro F1 (and mean ± std)
  - Out-of-fold pooled metrics: each row is predicted exactly once → one F1 + confusion matrix

Usage:
  cd ml
  python evaluate_lstm_kfold.py
  python evaluate_lstm_kfold.py --k 5 --epochs 40 --csv dataset/bridgemend_dataset_10000.csv
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from sklearn.metrics import classification_report, confusion_matrix, f1_score
from sklearn.model_selection import StratifiedKFold
from sklearn.preprocessing import LabelEncoder
from torch.utils.data import DataLoader

ML = Path(__file__).resolve().parent


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="LSTM stratified k-fold CV")
    p.add_argument(
        "--csv",
        type=Path,
        default=ML / "dataset" / "bridgemend_dataset_10000.csv",
    )
    p.add_argument("--target", default="emotion")
    p.add_argument(
        "--text-mode",
        default="combined",
        choices=("input_only", "combined"),
    )
    p.add_argument(
        "--context",
        default="default",
        choices=("default", "none"),
    )
    p.add_argument("--k", type=int, default=5, help="Number of folds")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--max-words", type=int, default=4000)
    p.add_argument("--max-len", type=int, default=96)
    p.add_argument("--embedding-dim", type=int, default=96)
    p.add_argument("--lstm-units", type=int, default=72)
    p.add_argument("--lstm-layers", type=int, default=2)
    p.add_argument("--epochs", type=int, default=80)
    p.add_argument("--batch-size", type=int, default=24)
    p.add_argument("--lr", type=float, default=1.5e-3)
    p.add_argument("--weight-decay", type=float, default=1e-4)
    p.add_argument("--no-class-weights", action="store_true")
    p.add_argument("--early-stop-patience", type=int, default=12)
    return p.parse_args()


def main() -> None:
    args = parse_args()
    sys.path.insert(0, str(ML))

    from train_lstm import (
        BridgeMendLSTM,
        BridgeRowsDataset,
        WordTokenizer,
        build_text_series,
        collate_fn_factory,
        context_columns_for_target,
        make_class_weight_tensor,
        pad_sequences,
        set_seeds,
    )

    df = pd.read_csv(args.csv)
    required = {"input_text", args.target, "session_type", "speaker"}
    if not required <= set(df.columns):
        raise SystemExit(f"CSV needs columns {required}")

    context_cols = context_columns_for_target(args.context, args.target)
    texts_full = build_text_series(df, args.text_mode)
    y_raw = df[args.target].astype(str)

    target_le = LabelEncoder()
    y_all = target_le.fit_transform(y_raw)
    num_classes = len(target_le.classes_)
    class_names = target_le.classes_.tolist()
    labels = list(range(num_classes))

    context_encoders_full: dict[str, LabelEncoder] = {}
    for col in context_cols:
        enc = LabelEncoder()
        enc.fit(df[col].astype(str).unique())
        context_encoders_full[col] = enc

    skf = StratifiedKFold(n_splits=args.k, shuffle=True, random_state=args.seed)
    idx_all = np.arange(len(df))

    oof_true = np.zeros(len(df), dtype=np.int64)
    oof_pred = np.zeros(len(df), dtype=np.int64)
    fold_f1_macro: list[float] = []

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    for fold, (train_idx, val_idx) in enumerate(skf.split(idx_all, y_all)):
        set_seeds(args.seed + fold)

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

        context_train: list[np.ndarray] = []
        context_val: list[np.ndarray] = []
        context_specs: list[tuple[str, int, int]] = []
        for col in context_cols:
            enc = context_encoders_full[col]
            n_cat = len(enc.classes_)
            dim = min(32, max(4, (n_cat + 1) // 2))
            context_specs.append((col, n_cat, dim))
            context_train.append(
                enc.transform(df[col].astype(str).iloc[train_idx].values).astype(np.int64)
            )
            context_val.append(
                enc.transform(df[col].astype(str).iloc[val_idx].values).astype(np.int64)
            )

        y_train = y_all[train_idx]
        y_val = y_all[val_idx]

        max_token_id = int(np.max(np.concatenate([x_train.ravel(), x_val.ravel()])))
        embedding_input_dim = max_token_id + 1

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

        best_state = None
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

            va_l = val_loss / max(val_n, 1)
            acc = val_correct / max(val_n, 1)
            scheduler.step(va_l)

            improved = acc > best_acc or (acc == best_acc and va_l < best_val_loss)
            if improved:
                best_acc = acc
                best_val_loss = va_l
                stale = 0
                best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            else:
                stale += 1

            if stale >= args.early_stop_patience:
                break

        if best_state is not None:
            model.load_state_dict(best_state)
        model.to(device)
        model.eval()

        preds_fold: list[int] = []
        true_fold: list[int] = []
        with torch.inference_mode():
            for texts, lengths, ctx, yb in val_loader:
                texts = texts.to(device)
                lengths = lengths.to(device)
                yb = yb.to(device)
                ctx_d = {k: v.to(device) for k, v in ctx.items()}
                logits = model(texts, lengths, ctx_d)
                pred = logits.argmax(dim=-1)
                preds_fold.extend(pred.cpu().numpy().tolist())
                true_fold.extend(yb.cpu().numpy().tolist())

        f1_m = f1_score(true_fold, preds_fold, average="macro", labels=labels, zero_division=0)
        fold_f1_macro.append(float(f1_m))
        oof_true[val_idx] = np.array(true_fold, dtype=np.int64)
        oof_pred[val_idx] = np.array(preds_fold, dtype=np.int64)

        print(
            f"Fold {fold + 1}/{args.k}  val_n={len(val_idx)}  "
            f"macro_F1={f1_m:.4f}  best_val_acc={best_acc:.4f}"
        )

    print()
    print(f"Per-fold macro F1: {fold_f1_macro}")
    mean_f1 = float(np.mean(fold_f1_macro))
    std_f1 = float(np.std(fold_f1_macro))
    print(f"Mean +/- std (macro F1): {mean_f1:.4f} +/- {std_f1:.4f}")
    print()

    oof_t = oof_true.tolist()
    oof_p = oof_pred.tolist()
    f1_macro = f1_score(oof_t, oof_p, average="macro", labels=labels, zero_division=0)
    f1_weighted = f1_score(oof_t, oof_p, average="weighted", labels=labels, zero_division=0)
    f1_micro = f1_score(oof_t, oof_p, average="micro", labels=labels, zero_division=0)
    cm = confusion_matrix(oof_t, oof_p, labels=labels)

    print(f"Out-of-fold pooled (n={len(df)}): each row predicted once by its held-out fold model.")
    print()
    print("F1 scores (pooled OOF):")
    print(f"  macro:    {f1_macro:.4f}")
    print(f"  weighted: {f1_weighted:.4f}")
    print(f"  micro:    {f1_micro:.4f}")
    print()
    print("Classification report (pooled OOF):")
    print(
        classification_report(
            oof_t,
            oof_p,
            labels=labels,
            target_names=class_names,
            digits=4,
            zero_division=0,
        )
    )
    print("Confusion matrix (rows = true, cols = pred):")
    header = "".join(f"{n[:12]:>14}" for n in class_names)
    print(f"{'':>16}{header}")
    for i, row in enumerate(cm):
        cells = "".join(f"{v:>14}" for v in row)
        print(f"{class_names[i][:14]:>16}{cells}")
    print()


if __name__ == "__main__":
    main()
