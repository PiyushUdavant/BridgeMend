"""
Run trained models and print output to the terminal.

1) Counselor (DistilGPT2): generates an empathetic reply for a user message.
2) LSTM: predicts emotion label from text + session_type + speaker (same as training).

Usage (from repo):
  cd ml
  pip install -r requirements.txt
  pip install -r counselor_chatbot/requirements.txt

  # Chat reply (point to your saved checkpoint folder)
  python run_inference.py counselor --model-dir saved_finetune/02_counselor_distilgpt2 --text "I feel like my partner ignores me"

  # Emotion classification
  python run_inference.py lstm --bundle saved_finetune/01_lstm_emotion_classifier --text "I feel unheard" --session personal --speaker husband
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ML = Path(__file__).resolve().parent


def _run_counselor(model_dir: Path, text: str) -> None:
    sys.path.insert(0, str(ML))
    from counselor_chatbot.inference import CounselorInference

    bot = CounselorInference(model_dir)
    out = bot.reply(text, history=None, do_sample=True, temperature=0.75)
    print(out)


def _run_lstm(bundle: Path, text: str, session_type: str, speaker: str) -> None:
    import joblib
    import torch

    sys.path.insert(0, str(ML))
    import train_lstm as _tl

    # Joblib pickle references WordTokenizer from the training script's __main__
    sys.modules["__main__"].WordTokenizer = _tl.WordTokenizer

    from train_lstm import BridgeMendLSTM, WordTokenizer, pad_sequences

    meta_path = bundle / "metadata_emotion.json"
    tok_p = bundle / "tokenizer_emotion.joblib"
    le_p = bundle / "label_encoder_emotion.joblib"
    ctx_p = bundle / "context_encoders_emotion.joblib"
    weights = bundle / "lstm_emotion.pt"

    for p in (meta_path, tok_p, le_p, ctx_p, weights):
        if not p.is_file():
            raise SystemExit(f"Missing file: {p}")

    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    tokenizer: WordTokenizer = joblib.load(tok_p)
    label_enc = joblib.load(le_p)
    ctx_encoders = joblib.load(ctx_p)

    text_mode = meta.get("text_mode", "combined")
    if text_mode == "combined":
        full_text = f"{session_type.strip()} {speaker.strip()} {text.strip()}"
    else:
        full_text = text.strip()

    seq = tokenizer.texts_to_sequences([full_text])
    max_len = int(meta["max_len"])
    x = pad_sequences(seq, maxlen=max_len, padding="post", truncating="post")
    row = torch.from_numpy(x).long()
    length = torch.tensor([int((row[0] != 0).sum().clamp(min=1))], dtype=torch.long)

    ctx_dict = {}
    context_cols = meta.get("context_cols", ["session_type", "speaker"])
    context_specs = []
    for col in context_cols:
        n_cat = len(ctx_encoders[col].classes_)
        dim = min(32, max(4, (n_cat + 1) // 2))
        context_specs.append((col, n_cat, dim))
        idx = int(ctx_encoders[col].transform([str(session_type if col == "session_type" else speaker)])[0])
        ctx_dict[col] = torch.tensor([idx], dtype=torch.long)

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

    with torch.inference_mode():
        logits = model(row.to(device), length.to(device), {k: v.to(device) for k, v in ctx_dict.items()})
        pred = int(logits.argmax(dim=-1).item())
    label = label_enc.inverse_transform([pred])[0]
    probs = torch.softmax(logits, dim=-1)[0].cpu().numpy()
    top = sorted(zip(meta["classes"], probs), key=lambda t: -t[1])[:3]

    print(f"predicted_emotion: {label}")
    print("top_3:")
    for name, p in top:
        print(f"  {name}: {100.0 * float(p):.1f}%")


def main() -> None:
    ap = argparse.ArgumentParser(description="Run BridgeMend ML inference")
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("counselor", help="Fine-tuned DistilGPT2 reply")
    c.add_argument(
        "--model-dir",
        type=Path,
        default=ML / "saved_finetune" / "02_counselor_distilgpt2",
        help="Folder with model.safetensors + tokenizer (HF format)",
    )
    c.add_argument("--text", required=True, help="User message")

    l = sub.add_parser("lstm", help="Emotion classifier")
    l.add_argument(
        "--bundle",
        type=Path,
        default=ML / "saved_finetune" / "01_lstm_emotion_classifier",
        help="Folder from save_finetune_bundle (tokenizer, lstm_*.pt, metadata)",
    )
    l.add_argument("--text", required=True)
    l.add_argument("--session", default="personal", help="session_type: personal | couple")
    l.add_argument("--speaker", default="husband", help="husband | wife | both")

    args = ap.parse_args()
    if args.cmd == "counselor":
        _run_counselor(args.model_dir.resolve(), args.text)
    else:
        _run_lstm(args.bundle.resolve(), args.text, args.session, args.speaker)


if __name__ == "__main__":
    main()
