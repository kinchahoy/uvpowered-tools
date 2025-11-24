# uvpowered-tools

Minimal command-line tools implemented as executable uv-powered Python scripts.
Each script is a standalone Python file that uses the ```#!/usr/bin/env -S uv …``` shebang to spin up a cached environment with the correct package versions. No building, compiling, or installing packages into your system.

- Zero overhead to run (no virtualenv setup, no pip installs)

- Fully standalone and directly executable

- Easy to modify as small, readable Python scripts

All tooling is powered by uv, which resolves and caches Python dependencies automatically at runtime.

## List of tools (may not be complete)

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
```
### Notes

- Most scripts run quickly unless they require uv to do a bunch of dependency checking (e.g. if they use import 'transformers'). 
- If you want them available system-wide, you can copy the script into /usr/local/bin and make it executable.
