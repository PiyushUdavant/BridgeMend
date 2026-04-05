"""
Fine-tune DistilGPT2 (or similar) with Hugging Face Trainer on CSV pairs.

Defaults use eval/save once per epoch to avoid many slow full validation passes on CPU
(each pass walks the entire held-out set). Use --eval_strategy steps for fixed-step eval.
"""

from __future__ import annotations

import argparse
import inspect
from pathlib import Path

import numpy as np
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    Trainer,
    TrainingArguments,
)

from .data_collator import DataCollatorForCausalAssistantSFT
from .inference import CounselorInference
from .preprocess import prepare_dataset_from_csv, require_fast_tokenizer


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parent.parent
    p = argparse.ArgumentParser(description="Fine-tune counseling chatbot (causal LM)")
    p.add_argument(
        "--csv",
        type=Path,
        default=root / "dataset" / "bridgemend_dataset_10000.csv",
    )
    p.add_argument(
        "--model_name",
        default="distilgpt2",
        help="e.g. distilgpt2, gpt2, gpt2-medium; small LLaMA-class: TinyLlama/TinyLlama-1.1B-Chat-v1.0",
    )
    p.add_argument("--output_dir", type=Path, default=root / "counselor_chatbot" / "outputs" / "counselor-distilgpt2")
    p.add_argument("--max_length", type=int, default=256)
    p.add_argument("--test_size", type=float, default=0.1)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--epochs", type=float, default=3.0)
    p.add_argument("--batch_size", type=int, default=4)
    p.add_argument("--grad_accum", type=int, default=4)
    p.add_argument("--lr", type=float, default=5e-5)
    p.add_argument("--warmup_ratio", type=float, default=0.05)
    p.add_argument("--logging_steps", type=int, default=20)
    p.add_argument(
        "--eval_strategy",
        default="epoch",
        choices=["epoch", "steps"],
        help="epoch: one validation per epoch (default; best on slow CPU). steps: use --eval_steps.",
    )
    p.add_argument(
        "--eval_steps",
        type=int,
        default=800,
        help="Used only when --eval_strategy steps (larger = fewer evals).",
    )
    p.add_argument(
        "--save_strategy",
        default="epoch",
        choices=["epoch", "steps"],
        help="epoch: checkpoint each epoch (default). steps: use --save_steps.",
    )
    p.add_argument(
        "--save_steps",
        type=int,
        default=800,
        help="Used only when --save_strategy steps.",
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()

    tokenizer = AutoTokenizer.from_pretrained(
        args.model_name,
        use_fast=True,
    )
    require_fast_tokenizer(tokenizer)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    model = AutoModelForCausalLM.from_pretrained(args.model_name)
    model.resize_token_embeddings(len(tokenizer))
    model.config.pad_token_id = tokenizer.pad_token_id

    dataset = prepare_dataset_from_csv(
        args.csv,
        tokenizer,
        max_length=args.max_length,
        test_size=args.test_size,
        seed=args.seed,
    )

    collator = DataCollatorForCausalAssistantSFT(tokenizer=tokenizer)

    ta_sig = set(inspect.signature(TrainingArguments.__init__).parameters)
    eval_kw = "eval_strategy" if "eval_strategy" in ta_sig else "evaluation_strategy"
    trainer_kw = "tokenizer" if "tokenizer" in set(inspect.signature(Trainer.__init__).parameters) else "processing_class"

    sched: dict = {eval_kw: args.eval_strategy}
    if args.eval_strategy == "steps":
        sched["eval_steps"] = args.eval_steps
    if "save_strategy" in ta_sig:
        sched["save_strategy"] = args.save_strategy
        if args.save_strategy == "steps":
            sched["save_steps"] = args.save_steps
    else:
        sched["save_steps"] = args.save_steps

    training_args = TrainingArguments(
        output_dir=str(args.output_dir),
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.batch_size,
        per_device_eval_batch_size=args.batch_size,
        gradient_accumulation_steps=args.grad_accum,
        learning_rate=args.lr,
        warmup_ratio=args.warmup_ratio,
        logging_steps=args.logging_steps,
        **sched,
        save_total_limit=2,
        load_best_model_at_end=True,
        metric_for_best_model="eval_loss",
        greater_is_better=False,
        seed=args.seed,
        report_to="none",
        prediction_loss_only=False,
    )

    def _compute_metrics(eval_pred):
        logits = eval_pred.predictions
        labels = eval_pred.label_ids
        shift_logits = np.asarray(logits)[..., :-1, :]
        shift_labels = np.asarray(labels)[..., 1:]
        preds = np.argmax(shift_logits, axis=-1)

        flat_preds = preds.reshape(-1)
        flat_labels = shift_labels.reshape(-1)
        mask = flat_labels != -100
        if not np.any(mask):
            return {"assistant_token_accuracy": 0.0}
        acc = float((flat_preds[mask] == flat_labels[mask]).mean())
        return {"assistant_token_accuracy": acc}

    trainer_init = dict(
        model=model,
        args=training_args,
        train_dataset=dataset["train"],
        eval_dataset=dataset["test"],
        data_collator=collator,
        compute_metrics=_compute_metrics,
    )
    trainer_init[trainer_kw] = tokenizer
    trainer = Trainer(**trainer_init)

    trainer.train()
    trainer.save_model(str(args.output_dir))
    tokenizer.save_pretrained(str(args.output_dir))

    print("\n--- Evaluation (test set) ---")
    metrics = trainer.evaluate()
    for k, v in metrics.items():
        print(f"  {k}: {v}")

    print("\n--- Sample inference ---")
    infer = CounselorInference(args.output_dir)
    sample_in = "I feel like my partner ignores me"
    sample_out = infer.reply(sample_in, history=None, do_sample=True, temperature=0.8)
    print(f"Input: {sample_in!r}")
    print(f"Output: {sample_out}")

    demo_history = [
        ("We argued about chores again.", "It helps to name one concrete request instead of criticizing character."),
    ]
    follow_up = infer.reply(
        "I tried that but they still shut down.",
        history=demo_history,
        do_sample=True,
        temperature=0.8,
    )
    print("\n--- Multi-turn sample (synthetic history) ---")
    print(f"Input: 'I tried that but they still shut down.'")
    print(f"Output: {follow_up}")


if __name__ == "__main__":
    main()
