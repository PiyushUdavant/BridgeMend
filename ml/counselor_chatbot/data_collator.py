"""
Pad batches for causal LM fine-tuning; labels use -100 for ignored positions.
"""

from __future__ import annotations

from dataclasses import dataclass

import torch
from transformers import PreTrainedTokenizerBase


@dataclass
class DataCollatorForCausalAssistantSFT:
    tokenizer: PreTrainedTokenizerBase
    pad_to_multiple_of: int | None = None

    def __call__(self, features: list[dict]) -> dict[str, torch.Tensor]:
        max_len = max(len(f["input_ids"]) for f in features)
        if self.pad_to_multiple_of is not None:
            m = self.pad_to_multiple_of
            max_len = ((max_len + m - 1) // m) * m

        pad_id = self.tokenizer.pad_token_id
        if pad_id is None:
            pad_id = self.tokenizer.eos_token_id

        input_ids = []
        attention_mask = []
        labels = []

        for f in features:
            ids = list(f["input_ids"])
            am = list(f["attention_mask"])
            lab = list(f["labels"])
            pad_len = max_len - len(ids)
            if pad_len > 0:
                ids = ids + [pad_id] * pad_len
                am = am + [0] * pad_len
                lab = lab + [-100] * pad_len
            input_ids.append(ids)
            attention_mask.append(am)
            labels.append(lab)

        return {
            "input_ids": torch.tensor(input_ids, dtype=torch.long),
            "attention_mask": torch.tensor(attention_mask, dtype=torch.long),
            "labels": torch.tensor(labels, dtype=torch.long),
        }
