
----

## 2026-03-24: SHORT TERM HELPER FOR LITELLM ISSUE (sh script not python)
`inventory_litellm.sh` is a temporary quick script for a first-pass local check related to the LiteLLM package vulerability discussed at [Hacker News](https://news.ycombinator.com/item?id=47501729).
It is intended only to help you quickly gauge whether that issue might not be impacting you.
Its LiteLLM version inventory is a quick first pass and should not be considered definitive, authoritative, or trusted for security decisions. v1.82.7, v1.82.8 are known bad.

----

# uvpowered-tools

Minimal command-line tools implemented as executable uv-powered Python scripts.
Each script is a standalone Python file that uses the ```#!/usr/bin/env -S uv …``` shebang to spin up a cached environment with the correct package versions. No building, compiling, or installing packages into your system.

- Zero overhead to run (no virtualenv setup, no pip installs)

- Fully standalone and directly executable

- Easy to modify as small, readable Python scripts

## List of uv powered tools (may not be complete)

#### Temporary first-pass LiteLLM inventory: inventory_litellm.sh

Scans likely local Python environment locations and reports any LiteLLM versions it can identify by reading environment files from an isolated `uv`-managed Python 3.12 process.

This script exists as a temporary first-pass helper for the LiteLLM package incident discussed at [Hacker News](https://news.ycombinator.com/item?id=47501729).
It does not execute discovered Python interpreters while inspecting them, because the risk being investigated may involve Python startup behavior.

Do not treat its output as a definitive or trusted compromise assessment.
If it reports nothing, that does not prove you are safe.
If it reports a version, that does not by itself prove the environment is clean or compromised.

#### LLM token counter: count-tokens.py

Loads a HuggingFace tokenizer for an LLM model and tokenizes a given file.
Outputs a compact summary: token count, compression ratio, bytes per token, vocabulary size, and special-token information.

<details>

```
❯ ./count-tokens.py --file count-tokens.py --model unsloth/Qwen3-VL-30B-A3B-Instruct
Counting tokens in count-tokens.py using the tokenizer from Huggingface model unsloth/Qwen3-VL-30B-A3B-Instruct
Tokenizer class: Qwen2TokenizerFast
Vocabulary size: 152k possible tokens
Special tokens (3): ['eos_token', 'pad_token', 'additional_special_tokens']

Input characters: 2546
Compression ratio (tokens/chars): 27.4%
UTF-8 bytes: 2546
Bytes per token: 3.6

Token count: 698
```

```
❯ ./count-tokens.py --file count-tokens.py --model unsloth/gpt-oss-120b
Counting tokens in count-tokens.py using the tokenizer from Huggingface model unsloth/gpt-oss-120b
Tokenizer class: PreTrainedTokenizerFast
Vocabulary size: 200k possible tokens
Special tokens (3): ['bos_token', 'eos_token', 'pad_token']

Input characters: 2546
Compression ratio (tokens/chars): 26.4%
UTF-8 bytes: 2546
Bytes per token: 3.8

Token count: 671
```

<summary>Example output for gpt-oss-120b, Qwen3-VL-30B-A3B-Instruct </summary>
</details>

#### Extensible minimal example: GENERIC-SCRIPT-TEMPLATE.py

A minimal script template showing how to build new uv-powered tools.
Useful as a starting point for extending or adding your own utilities.

## Installation

### Clone this repo
```
git clone https://github.com/kinchahoy/uvpowered-tools
cd uvpowered-tools
```
### Make sure you have uv installed

```
echo "Examine the uv install script"
curl -LsSf https://astral.sh/uv/install.sh | less
echo "Run the uv install script Reference at https://docs.astral.sh/uv/getting-started/installation/
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Run the script (chmod +x if they are not executable)
```
./count-tokens.py

or

./GENERIC-SCRIPT-TEMPLATE.py

or

./inventory_litellm.sh
```
### Notes

- Most scripts run quickly unless they require uv to do a bunch of dependency checking (e.g. if they use import 'transformers'). 
- If you want them available system-wide, you can copy the script into /usr/local/bin and make it executable.
