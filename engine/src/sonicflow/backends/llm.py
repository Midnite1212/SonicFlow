import mlx.core as mx
import mlx_lm
from mlx.utils import tree_flatten
from mlx_lm.models.cache import can_trim_prompt_cache, make_prompt_cache, trim_prompt_cache
from mlx_lm.sample_utils import make_sampler

from sonicflow.backends.prompting import (
    PromptCleanup,
    accept_rewrite,
    clean_output,
    cleanup_messages,
    edit_messages,
)
from sonicflow.models import local_path

__all__ = ["LLMCleanup", "accept_rewrite"]

_PLACEHOLDER = "\x00USER_TEXT\x00"


class LLMCleanup(PromptCleanup):
    def __init__(self, name: str, repo_id: str) -> None:
        self.name = name
        self.repo_id = repo_id
        self._sampler = make_sampler(temp=0.0)

    def load(self) -> None:
        self._model, self._tokenizer = mlx_lm.load(local_path(self.repo_id))

        messages = cleanup_messages(_PLACEHOLDER)
        template = self._tokenizer.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True, enable_thinking=False
        )
        prefix, self._suffix = template.split(_PLACEHOLDER)

        # The system prompt and examples are encoded once; each request only pays for its own text.
        self._cache = make_prompt_cache(self._model)
        if not can_trim_prompt_cache(self._cache):
            raise RuntimeError(f"{self.repo_id} has a cache that cannot be reused across requests")
        self._model(mx.array(self._encode(prefix))[None], cache=self._cache)
        mx.eval([c.state for c in self._cache])
        self._prefix_len = self._cache[0].offset

        self._rewrite("Send it Friday, no wait, Thursday.")

    def arrays(self) -> list:
        return [a for _, a in tree_flatten(self._model.parameters())]

    def unload(self) -> None:
        del self._model, self._tokenizer, self._cache
        mx.clear_cache()

    def warm(self) -> None:
        logits = self._model(mx.array(self._encode(self._suffix)[:1])[None], cache=self._cache)
        mx.eval(logits)
        trim_prompt_cache(self._cache, self._cache[0].offset - self._prefix_len)

    def _encode(self, text: str) -> list[int]:
        return self._tokenizer.encode(text, add_special_tokens=False)

    def _rewrite(self, text: str) -> str:
        user_tokens = self._encode(text)
        try:
            output = mlx_lm.generate(
                self._model,
                self._tokenizer,
                user_tokens + self._encode(self._suffix),
                max_tokens=min(2 * len(user_tokens) + 16, 512),
                sampler=self._sampler,
                prompt_cache=self._cache,
            )
        finally:
            trim_prompt_cache(self._cache, self._cache[0].offset - self._prefix_len)
        return clean_output(output)

    def edit(self, selection: str, instruction: str) -> str:
        prompt = self._tokenizer.apply_chat_template(
            edit_messages(selection, instruction),
            tokenize=False,
            add_generation_prompt=True,
            enable_thinking=False,
        )
        output = mlx_lm.generate(
            self._model,
            self._tokenizer,
            self._encode(prompt),
            max_tokens=min(2 * len(self._encode(selection)) + 64, 2048),
            sampler=self._sampler,
        )
        return clean_output(output)
