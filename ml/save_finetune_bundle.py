"""
Copy all fine-tuned artifacts into ml/saved_finetune/ for one-folder backup.

Creates:
  saved_finetune/01_lstm_emotion_classifier/   — PyTorch LSTM + sklearn encoders
  saved_finetune/02_counselor_distilgpt2/      — full HF Trainer checkpoint (inference + resume)
  saved_finetune/manifest.json                 — dataset, base model, paths, run command

Run from repo (or anywhere):
  python ml/save_finetune_bundle.py

Optional:
  python ml/save_finetune_bundle.py --counselor-checkpoint path/to/checkpoint-XXX
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path


def _copy_tree(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def _pick_latest_checkpoint(outputs_dir: Path) -> Path | None:
    if not outputs_dir.is_dir():
        return None
    cps = sorted(
        outputs_dir.glob("checkpoint-*"),
        key=lambda p: int(p.name.split("-")[-1]) if p.name.split("-")[-1].isdigit() else -1,
    )
    return cps[-1] if cps else None


def main() -> int:
    ml = Path(__file__).resolve().parent
    root = ml.parent
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--counselor-checkpoint",
        type=Path,
        default=None,
        help="HF checkpoint folder; default: latest under counselor_chatbot/outputs/counselor-distilgpt2",
    )
    ap.add_argument(
        "--out",
        type=Path,
        default=ml / "saved_finetune",
        help="Bundle root directory",
    )
    args = ap.parse_args()

    out = args.out.resolve()
    lstm_src = ml / "artifacts"
    counselor_root = ml / "counselor_chatbot" / "outputs" / "counselor-distilgpt2"
    ckpt = args.counselor_checkpoint
    if ckpt is None:
        ckpt = _pick_latest_checkpoint(counselor_root)
    elif ckpt.is_dir() and (counselor_root in ckpt.parents or True):
        ckpt = ckpt.resolve()

    dataset_10k = ml / "dataset" / "bridgemend_dataset_10000.csv"
    dataset_1k = ml / "dataset" / "bridgemend_dataset_1000.csv"

    out.mkdir(parents=True, exist_ok=True)
    lstm_dst = out / "01_lstm_emotion_classifier"
    counselor_dst = out / "02_counselor_distilgpt2"
    dataset_dst = out / "03_dataset_bridgemend_10000.csv"

    errors: list[str] = []

    if lstm_src.is_dir() and any(lstm_src.iterdir()):
        _copy_tree(lstm_src, lstm_dst)
    else:
        errors.append(f"Missing or empty LSTM artifacts: {lstm_src}")

    if ckpt and ckpt.is_dir() and (ckpt / "model.safetensors").is_file():
        _copy_tree(ckpt, counselor_dst)
    else:
        errors.append(
            f"Missing counselor checkpoint with model.safetensors: {ckpt or counselor_root}"
        )

    if dataset_10k.is_file():
        shutil.copy2(dataset_10k, dataset_dst)
    else:
        errors.append(f"Missing dataset CSV: {dataset_10k}")

    manifest = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "repository_root": str(root),
        "dataset_primary_csv": str(dataset_10k) if dataset_10k.is_file() else None,
        "dataset_bundled_copy": str(dataset_dst) if dataset_dst.is_file() else None,
        "dataset_legacy_1k_csv": str(dataset_1k) if dataset_1k.is_file() else None,
        "lstm_classifier": {
            "source_dir": str(lstm_src),
            "bundled_dir": str(lstm_dst),
            "default_target": "emotion",
            "load_weights": str(lstm_dst / "lstm_emotion.pt"),
        },
        "counselor_causal_lm": {
            "base_model": "distilgpt2",
            "checkpoint_source": str(ckpt) if ckpt else None,
            "bundled_dir": str(counselor_dst),
            "inference_note": "CounselorInference(bundled_dir) after sys.path.insert(0, ml_dir)",
        },
        "retrain_counselor": (
            f"cd {ml} && python -m counselor_chatbot --csv dataset/bridgemend_dataset_10000.csv"
        ),
        "retrain_lstm": f"cd {ml} && python train_lstm.py",
        "bundle_errors": errors,
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    readme = out / "README.txt"
    readme.write_text(
        "\n".join(
            [
                "BridgeMend ML — saved fine-tune bundle",
                "=====================================",
                "",
                "01_lstm_emotion_classifier/",
                "  lstm_emotion.pt, tokenizer_*.joblib, label_encoder_*.joblib, context_encoders_*.joblib, metadata_*.json",
                "",
                "02_counselor_distilgpt2/",
                "  Hugging Face checkpoint: model.safetensors, tokenizer*, config*.json",
                "  (includes optimizer.pt etc. if you want to resume training)",
                "",
                "03_dataset_bridgemend_10000.csv — copy of training data used for fine-tuning",
                "",
                "manifest.json — paths, dataset references, retrain commands",
                "",
                "Inference (counselor): point CounselorInference at 02_counselor_distilgpt2",
                "Regenerate this folder: python ml/save_finetune_bundle.py",
                "",
            ]
        ),
        encoding="utf-8",
    )

    if errors:
        print("Bundle created with warnings:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
    print(f"Wrote bundle to: {out}")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
