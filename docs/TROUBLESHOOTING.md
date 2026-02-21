# TROUBLESHOOTING

## 1) `BATCHENCODING` VS TENSOR FROM `TRANSFORMERS` CHAT TEMPLATES

### SYMPTOMS
- Console warning: `Attempting to cast a BatchEncoding to type torch.int32. This is not supported.`
- Followed by a crash like:
  - `context_pos = input_ids.size(1)` -> `AttributeError`
- Typically happens when the code does:
  - `tokenizer.apply_chat_template(..., return_tensors="pt", ...)` and then calls `.to(torch.int32)` directly on the returned object.

### ROOT CAUSE
- With some `transformers` versions, `tokenizer.apply_chat_template(..., return_tensors="pt")` may return a `BatchEncoding` (dict-like), not a `torch.Tensor`.
- The scripts assumed a Tensor, then called:
  - `.to(torch.int32)` and `.size(1)` on a `BatchEncoding`, which fails.

### FIX (CODE)
- Normalize tokenizer output to a Tensor before casting dtype:
  - Extract `input_ids` from the returned object and only then call `.to(torch.int32)`.
- Recommended helper:
  - Add a function like `_as_input_ids(tokenizer_output)` that returns a `torch.Tensor` from either a Tensor or a `BatchEncoding`/dict with `input_ids`.
  - Replace patterns like:
    - `tokenizer.apply_chat_template(...).to(torch.int32)`
    - with:
    - `tokenized = tokenizer.apply_chat_template(...)`
    - `input_ids = _as_input_ids(tokenized).to(torch.int32)`

### FIX (NO CODE CHANGE WORKAROUND)
- Run without chat templates:
  - `python chat.py --meta ./meta.yaml --no-template`

### INDENTATION PITFALL
- When patching vendor scripts, avoid introducing mixed tabs/spaces (Python will throw `TabError`).

## 2) CORE ML LOAD FAILURE: “FAILED TO BUILD THE MODEL EXECUTION PLAN … ERROR CODE: -5”

### SYMPTOMS
- Crash while loading `.mlmodelc` via `ct.models.CompiledMLModel(...)`, e.g.:
  - `Failed to build the model execution plan ... model.mil ... error code: -5`

### WHAT IT MEANS
- This is separate from the tokenizer/BatchEncoding issue.
- It indicates CORE ML couldn’t create an execution plan for that compiled model on this machine/OS/runtime (often an OS/CORE ML compatibility or model-compile mismatch).

### TRIAGE
- Try CPU-only to see if it’s a NE execution-plan issue:
  - `python chat.py --meta ./meta.yaml --cpu`
- If `--cpu` works but default doesn’t, it’s likely a CORE ML execution-plan / hardware-backend issue (not a Python logic bug).
