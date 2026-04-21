"""
Evaluate saved LSTM classifier: F1 (macro / weighted) and confusion matrix on the validation split.

Uses the same train/val split as training (stratified, test_size=0.2, seed=42) and the same
artifacts from the bundle (tokenizer fit on train only, etc.).

Usage:
  cd ml
  python evaluate_lstm.py
  python evaluate_lstm.py --bundle saved_finetune/01_lstm_emotion_classifier --csv dataset/bridgemend_dataset_10000.csv
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import torch
from sklearn.metrics import classification_report, confusion_matrix, f1_score
from sklearn.model_selection import train_test_split
from torch.utils.data import DataLoader

ML = Path(__file__).resolve().parent


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="LSTM eval: F1 + confusion matrix")
    p.add_argument(
        "--csv",
        type=Path,
        default=ML / "dataset" / "bridgemend_dataset_10000.csv",
    )
    p.add_argument(
        "--bundle",
        type=Path,
        default=ML / "saved_finetune" / "01_lstm_emotion_classifier",
        help="Folder with lstm_emotion.pt, tokenizer_*, label_encoder_*, metadata_emotion.json",
    )
    p.add_argument("--target", default="emotion", help="Label column (must match training)")
    p.add_argument("--test-size", type=float, default=0.2)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--batch-size", type=int, default=64)
    return p.parse_args()


def main() -> None:
    args = parse_args()
    sys.path.insert(0, str(ML))
    import train_lstm as _tl

    sys.modules["__main__"].WordTokenizer = _tl.WordTokenizer

    from train_lstm import (
        BridgeMendLSTM,
        BridgeRowsDataset,
        WordTokenizer,
        build_text_series,
        collate_fn_factory,
        pad_sequences,
    )

    bundle = args.bundle.resolve()
    meta_path = bundle / "metadata_emotion.json"
    weights = bundle / "lstm_emotion.pt"
    for p in (meta_path, weights, bundle / "tokenizer_emotion.joblib"):
        if not p.is_file():
            raise SystemExit(f"Missing: {p}")

    meta = json.loads(meta_path.read_text(encoding="utf-8"))

    df = pd.read_csv(args.csv)
    required = {"input_text", args.target, "session_type", "speaker"}
    if not required <= set(df.columns):
        raise SystemExit(f"CSV needs columns {required}")

    texts_full = build_text_series(df, meta.get("text_mode", "combined"))
    y_raw = df[args.target].astype(str)

    label_enc = joblib.load(bundle / "label_encoder_emotion.joblib")
    y_all = label_enc.transform(y_raw)
    idx = np.arange(len(df))
    _, val_idx = train_test_split(
        idx,
        test_size=args.test_size,
        random_state=args.seed,
        stratify=y_all,
    )

    tokenizer: WordTokenizer = joblib.load(bundle / "tokenizer_emotion.joblib")
    ctx_encoders = joblib.load(bundle / "context_encoders_emotion.joblib")
    context_cols = meta.get("context_cols", ["session_type", "speaker"])

    texts_val = texts_full.iloc[val_idx].tolist()
    x_val = pad_sequences(
        tokenizer.texts_to_sequences(texts_val),
        maxlen=int(meta["max_len"]),
        padding="post",
        truncating="post",
    )
    y_val = y_all[val_idx].astype(np.int64)

    context_val: list[np.ndarray] = []
    context_specs = []
    for col in context_cols:
        n_cat = len(ctx_encoders[col].classes_)
        dim = min(32, max(4, (n_cat + 1) // 2))
        context_specs.append((col, n_cat, dim))
        context_val.append(
            ctx_encoders[col].transform(df[col].astype(str).iloc[val_idx].values).astype(np.int64)
        )

    num_classes = len(meta["classes"])
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = BridgeMendLSTM(
        vocab_size=int(meta["embedding_input_dim"]),
        embed_dim=96,
        lstm_hidden=72,
        lstm_layers=int(meta.get("lstm_layers", 2)),
        num_classes=num_classes,
        context_specs=context_specs,
    )
    try:
        state = torch.load(weights, map_location=device, weights_only=True)
    except TypeError:
        state = torch.load(weights, map_location=device)
    model.load_state_dict(state)
    model.to(device)
    model.eval()

    val_ds = BridgeRowsDataset(x_val, y_val, context_val)
    collate = collate_fn_factory(context_cols)
    loader = DataLoader(
        val_ds,
        batch_size=args.batch_size,
        shuffle=False,
        collate_fn=collate,
    )

    all_pred: list[int] = []
    all_true: list[int] = []
    with torch.inference_mode():
        for texts, lengths, ctx, yb in loader:
            texts = texts.to(device)
            lengths = lengths.to(device)
            yb = yb.to(device)
            ctx_d = {k: v.to(device) for k, v in ctx.items()}
            logits = model(texts, lengths, ctx_d)
            pred = logits.argmax(dim=-1)
            all_pred.extend(pred.cpu().numpy().tolist())
            all_true.extend(yb.cpu().numpy().tolist())

    labels = list(range(num_classes))
    names = meta["classes"]

    f1_macro = f1_score(all_true, all_pred, average="macro", labels=labels, zero_division=0)
    f1_weighted = f1_score(all_true, all_pred, average="weighted", labels=labels, zero_division=0)
    f1_micro = f1_score(all_true, all_pred, average="micro", labels=labels, zero_division=0)

    cm = confusion_matrix(all_true, all_pred, labels=labels)

    print(f"Validation set: n={len(all_true)}  (test_size={args.test_size}, seed={args.seed})")
    print()
    print("F1 scores:")
    print(f"  macro:    {f1_macro:.4f}")
    print(f"  weighted: {f1_weighted:.4f}")
    print(f"  micro:    {f1_micro:.4f}")
    print()
    print("Classification report:")
    print(
        classification_report(
            all_true,
            all_pred,
            labels=labels,
            target_names=names,
            digits=4,
            zero_division=0,
        )
    )
    print("Confusion matrix (rows = true label, columns = predicted):")
    header = "".join(f"{n[:12]:>14}" for n in names)
    print(f"{'':>16}{header}")
    for i, row in enumerate(cm):
        cells = "".join(f"{v:>14}" for v in row)
        print(f"{names[i][:14]:>16}{cells}")
    print()
    print("(Copy numbers above into a spreadsheet or heatmap tool if you want a plot.)")


if __name__ == "__main__":
    main()
