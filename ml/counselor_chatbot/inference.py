"""
Generate counselor replies from a fine-tuned causal LM.
"""

from __future__ import annotations

from pathlib import Path

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

from .preprocess import build_prompt_for_generation, require_fast_tokenizer


class CounselorInference:
    def __init__(
        self,
        model_dir: str | Path,
        device: str | None = None,
    ) -> None:
        self.model_dir = Path(model_dir)
        self.tokenizer = AutoTokenizer.from_pretrained(
            self.model_dir,
            use_fast=True,
        )
        require_fast_tokenizer(self.tokenizer)
        self.model = AutoModelForCausalLM.from_pretrained(self.model_dir)
        if self.tokenizer.pad_token is None:
            self.tokenizer.pad_token = self.tokenizer.eos_token
        self.model.config.pad_token_id = self.tokenizer.pad_token_id

        if device is None:
            device = "cuda" if torch.cuda.is_available() else "cpu"
        self.device = torch.device(device)
        self.model.to(self.device)
        self.model.eval()

    @torch.inference_mode()
    def reply(
        self,
        user_message: str,
        history: list[tuple[str, str]] | None = None,
        max_new_tokens: int = 128,
        temperature: float = 0.7,
        top_p: float = 0.92,
        do_sample: bool = True,
    ) -> str:
        prompt = build_prompt_for_generation(user_message, history)
        inputs = self.tokenizer(
            prompt,
            return_tensors="pt",
            truncation=True,
            max_length=512,
        )
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        prompt_len = inputs["input_ids"].shape[1]

        gen = self.model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            pad_token_id=self.tokenizer.pad_token_id,
            eos_token_id=self.tokenizer.eos_token_id,
            do_sample=do_sample,
            temperature=max(temperature, 1e-5),
            top_p=top_p,
        )
        new_tokens = gen[0, prompt_len:]
        text = self.tokenizer.decode(new_tokens, skip_special_tokens=True).strip()
        return text
