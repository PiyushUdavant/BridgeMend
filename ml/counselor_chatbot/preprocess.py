"""
Load BridgeMend CSV and build supervised (user -> assistant) examples.

Multi-turn: this dataset has one row per session_id. Training uses single-turn
pairs; at inference, pass `history` as prior (user, assistant) tuples so the
model sees full context in one prompt (same format as training).
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pandas as pd
from datasets import Dataset, DatasetDict


USER_MARK = "### User:"
ASSIST_MARK = "### Assistant:"


def require_fast_tokenizer(tokenizer) -> None:
    """Label masking uses `return_offsets_mapping`, which only fast tokenizers support."""
    if not getattr(tokenizer, "is_fast", False):
        raise ValueError(
            "A fast tokenizer (Rust-based) is required for training: label masking uses "
            "character offsets. Pick a model that ships tokenizer.json (e.g. distilgpt2, "
            f"gpt2). Got slow tokenizer for: {getattr(tokenizer, 'name_or_path', type(tokenizer))!r}."
        )


def format_single_turn(user_message: str, assistant_message: str) -> str:
    return (
        f"{USER_MARK}\n{user_message.strip()}\n"
        f"{ASSIST_MARK}\n{assistant_message.strip()}"
    )


def build_prompt_for_generation(
    user_message: str,
    history: list[tuple[str, str]] | None = None,
) -> str:
    """
    Build the prompt up to and including '### Assistant:\n' so the model continues
    with the reply. `history` is oldest-first list of (user, assistant) turns.
    """
    history = history or []
    blocks: list[str] = []
    for u, a in history:
        blocks.append(format_single_turn(u, a))
    blocks.append(f"{USER_MARK}\n{user_message.strip()}\n{ASSIST_MARK}\n")
    return "\n".join(blocks)


def assistant_prefix_for_masking(user_message: str) -> str:
    """Character offset helper: loss is applied only after this prefix."""
    return f"{USER_MARK}\n{user_message.strip()}\n{ASSIST_MARK}\n"


def load_counseling_csv(
    csv_path: str | Path,
    user_col: str = "input_text",
    assistant_col: str = "ai_response",
) -> pd.DataFrame:
    path = Path(csv_path)
    if not path.is_file():
        raise FileNotFoundError(path)
    df = pd.read_csv(path)
    for c in (user_col, assistant_col):
        if c not in df.columns:
            raise ValueError(f"Missing column {c!r}; available: {list(df.columns)}")
    df = df[[user_col, assistant_col]].dropna()
    df[user_col] = df[user_col].astype(str).str.strip()
    df[assistant_col] = df[assistant_col].astype(str).str.strip()
    df = df[(df[user_col] != "") & (df[assistant_col] != "")]
    return df.reset_index(drop=True)


def dataframe_to_dataset(df: pd.DataFrame, user_col: str, assistant_col: str) -> Dataset:
    return Dataset.from_dict(
        {
            "user": df[user_col].tolist(),
            "assistant": df[assistant_col].tolist(),
        }
    )


def train_test_split_dataset(
    ds: Dataset,
    test_size: float = 0.1,
    seed: int = 42,
) -> DatasetDict:
    split = ds.train_test_split(test_size=test_size, seed=seed)
    return DatasetDict(train=split["train"], test=split["test"])


def tokenize_supervised_batch(
    examples: dict[str, list[Any]],
    tokenizer,
    max_length: int,
) -> dict[str, list[list[int]]]:
    """
    Tokenize user/assistant pairs; mask labels (-100) on user + markers so
    loss is only on assistant tokens (supervised fine-tuning).
    """
    input_ids_list: list[list[int]] = []
    attention_mask_list: list[list[int]] = []
    labels_list: list[list[int]] = []

    for user, assistant in zip(examples["user"], examples["assistant"]):
        full_text = format_single_turn(user, assistant)
        prefix = assistant_prefix_for_masking(user)

        enc = tokenizer(
            full_text,
            truncation=True,
            max_length=max_length,
            padding=False,
            return_offsets_mapping=True,
            add_special_tokens=False,
        )
        ids = enc["input_ids"]
        mask = enc["attention_mask"]
        offsets = enc["offset_mapping"]
        assistant_start = len(prefix)

        labels: list[int] = []
        for tid, (start, _end) in zip(ids, offsets):
            if start < assistant_start:
                labels.append(-100)
            else:
                labels.append(tid)

        input_ids_list.append(ids)
        attention_mask_list.append(mask)
        labels_list.append(labels)

    return {
        "input_ids": input_ids_list,
        "attention_mask": attention_mask_list,
        "labels": labels_list,
    }


def prepare_dataset_from_csv(
    csv_path: str | Path,
    tokenizer,
    max_length: int,
    test_size: float = 0.1,
    seed: int = 42,
    user_col: str = "input_text",
    assistant_col: str = "ai_response",
) -> DatasetDict:
    require_fast_tokenizer(tokenizer)
    df = load_counseling_csv(csv_path, user_col, assistant_col)
    raw = dataframe_to_dataset(df, user_col, assistant_col)
    splits = train_test_split_dataset(raw, test_size=test_size, seed=seed)

    def _tok(batch):
        return tokenize_supervised_batch(batch, tokenizer, max_length)

    tokenized = splits.map(
        _tok,
        batched=True,
        remove_columns=["user", "assistant"],
        desc="Tokenizing",
    )
    return tokenized
