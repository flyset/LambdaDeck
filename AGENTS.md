### Project LambdaDeck

LambdaDeck is the local, on-device LLM runtime/server effort in this repo.

Legacy context: ANEMLL (pronounced like "animal") is a practical codebase/framework for running **ANE-optimized Core ML LLMs** locally on Apple Silicon.

**Primary goal:** make it easy to **download, organize, and run** these models for on-device inference (low power, offline, privacy-preserving).

**What this repo provides**
- Model distributions under `anemll-*` (each typically includes `meta.yaml`, `*.mlmodelc`, tokenizer assets, and `chat.py` / `chat_full.py`).
- Python dependencies for inference (`requirements.txt` / `requirements.lock.txt`).
- Convenience script `start.sh` to activate `.venv`.

---

### What LambdaDeck Is Building

LambdaDeck aims to make the ANEMLL Core ML model bundles usable from mainstream developer tools by exposing an OpenAI-compatible HTTP API.

- Target clients: OpenCode, VSCode extensions, and any OpenAI-compatible SDK/tooling
- Core endpoints (v1):
  - `GET /v1/models`
  - `POST /v1/chat/completions` (non-streaming and SSE streaming via `stream=true`)
- Runtime direction: Swift-native server on macOS Apple Silicon; existing Python `chat.py` scripts remain a reference runner
- Non-goals (v1): full OpenAI API surface, tool/function calling, multi-tenant auth, iOS embedding

Current focus: `.backlog/DRAFT/2026/TRACK_1_DRAFT_coreml_openai_server.md`

---

### Agent Workflow

- Read-only actions are allowed without approval (e.g., `ls`, `rg`, `cat`, `git status`).
- Before any write/state change:
  - Present a short plan.
  - Ask exactly one explicit yes/no approval question (e.g., “Proceed? (yes/no)”).
  - Only proceed after an explicit “yes”. If the answer is “no”, stop and do not make changes.
- State-changing includes file edits, creating/deleting files, installs, running tests, or Git history changes.

---

### Tracks Backlog Governance (`.backlog/`)

For non-trivial work, use the Tracks backlog as the planning and execution source of truth for LambdaDeck.

- Canonical rules: `.backlog/README.md`
- Scoped backlog guidance: `.backlog/AGENTS.md`
- PORE reference for problem statements: `.backlog/PORE.md`
- Track placement: `.backlog/<STATUS>/<YYYY>/TRACK_<n>_<STATUS>_<title>.md`
- Allowed statuses: `DRAFT`, `ACTIVE`, `BLOCKED`, `COMPLETED`, `DEPRECATED`

Implementation gates (must follow):
- No implementation starts for a Track until it is moved to `ACTIVE` and the "Move Track <n> to ACTIVE" plan step is checked.
- Begin each implementation session by reading the Track and executing the next unchecked plan step(s).
- After each meaningful chunk, update the Track immediately (plan checks, **Current inventory**, and tests/validations run).
- Do not create extra files under `.backlog/` beyond `.backlog/README.md`, `.backlog/PORE.md`, `.backlog/AGENTS.md`, and Track files in status/year folders.

---

### Quickstart (run a model in this repo)

```bash
# (Optional) create a venv once
python3 -m venv .venv

# Activate environment
source .venv/bin/activate
# or:
source start.sh

# Install dependencies
pip install -r requirements.lock.txt
# (or)
pip install -r requirements.txt

# Run a model (pick one folder under anemll-*)
cd anemll-*/   # choose the model you want
python chat.py --meta ./meta.yaml
# or:
python chat_full.py --meta ./meta.yaml
```

**Controls:**
- Ctrl-D to exit
- Ctrl-C to interrupt generation

---

### Download additional models (optional)

Most ANEMLL models are hosted on Hugging Face and use Git LFS for large files.

```bash
brew install git-lfs
git lfs install

# Clone a model repo (example naming)
git clone https://huggingface.co/anemll/<model-repo>
cd <model-repo>
git lfs pull

# If the distribution contains zipped .mlmodelc files:
find . -type f -name "*.zip" -exec unzip {} \;
```

Tip: if a model repo includes an `ios/` folder, prefer that for unzipped `.mlmodelc` distributions ready for app bundling.

---

### Known Issues & Fixes

#### 1) `BatchEncoding` vs Tensor from `transformers` chat templates

**Symptoms**
- Console warning: `Attempting to cast a BatchEncoding to type torch.int32. This is not supported.`
- Followed by a crash like:
  - `context_pos = input_ids.size(1)` → `AttributeError`
- Typically happens when the code does:
  - `tokenizer.apply_chat_template(..., return_tensors="pt", ...)` and then calls `.to(torch.int32)` directly on the returned object.

**Root cause**
- With some `transformers` versions, `tokenizer.apply_chat_template(..., return_tensors="pt")` may return a `BatchEncoding` (dict-like), not a `torch.Tensor`.
- The scripts assumed a Tensor, then called:
  - `.to(torch.int32)` and `.size(1)` on a `BatchEncoding`, which fails.

**Fix (code)**
- Normalize tokenizer output to a Tensor before casting dtype:
  - Extract `input_ids` from the returned object and only then call `.to(torch.int32)`.
- Recommended helper:
  - Add a function like `_as_input_ids(tokenizer_output)` that returns a `torch.Tensor` from either a Tensor or a BatchEncoding/dict with `input_ids`.
  - Replace patterns like:
    - `tokenizer.apply_chat_template(...).to(torch.int32)`
    - with:
    - `tokenized = tokenizer.apply_chat_template(...)`
    - `input_ids = _as_input_ids(tokenized).to(torch.int32)`

**Fix (no code change workaround)**
- Run without chat templates:
  - `python chat.py --meta ./meta.yaml --no-template`

**Indentation pitfall**
- When patching vendor scripts, avoid introducing mixed tabs/spaces (Python will throw `TabError`).

#### 2) Core ML load failure: “Failed to build the model execution plan … error code: -5”

**Symptoms**
- Crash while loading `.mlmodelc` via `ct.models.CompiledMLModel(...)`, e.g.:
  - `Failed to build the model execution plan ... model.mil ... error code: -5`

**What it means**
- This is separate from the tokenizer/BatchEncoding issue.
- It indicates Core ML couldn’t create an execution plan for that compiled model on this machine/OS/runtime (often an OS/CoreML compatibility or model-compile mismatch).

**Triage**
- Try CPU-only to see if it’s a NE execution-plan issue:
  - `python chat.py --meta ./meta.yaml --cpu`
- If `--cpu` works but default doesn’t, it’s likely a Core ML execution-plan / hardware-backend issue (not a Python logic bug).
