#!/usr/bin/env -S uv --quiet run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["typer", "transformers", "accelerate"]
# ///

# Requires uv. Install with https://docs.astral.sh/uv/getting-started/installation/

"""
count-tokens.py

Count tokens in a text file using a HuggingFace tokenizer.
Does not support GGUFs (i.e. use --model unsloth/gpt-oss-120b not --model unsloth/gpt-oss-120b-GGUF)

"""

import typer
from transformers import AutoTokenizer
from pathlib import Path

app = typer.Typer(help=__doc__, add_completion=False)


@app.command()
def main(
    model: str = typer.Option(
        "unsloth/gemma-3-1b-it",
        help="HuggingFace model to tokenize with.",
    ),
    file: str = typer.Option(
        "count-tokens.py",
        help="File containing text to tokenize.",
    ),
    info: bool = typer.Option(
        False,
        "--info",
        help="Print the tool's docstring and exit.",
    ),
):
    if info:
        typer.echo(__doc__.strip())
        raise typer.Exit(code=0)

    # Validate file
    p = Path(file)
    if not p.exists():
        typer.echo(f"Error: file not found: {file}")
        raise typer.Exit(code=1)

    typer.echo(
        f"Counting tokens in {file} using the tokenizer from Huggingface model {model}"
    )

    try:
        tok = AutoTokenizer.from_pretrained(model)
    except Exception:
        typer.echo(f"Error: could not load model: {model}")
        raise typer.Exit(code=1)

    text = p.read_text(encoding="utf-8")
    tokens = tok(text).input_ids

    tokenizer_class = tok.__class__.__name__
    vocab_size = tok.vocab_size
    # special = tok.all_special_tokens (Not accurate for GPT-oss-120B)
    special = list(tok.special_tokens_map.keys())
    num_special = len(special)

    chars = len(text)
    utf8_bytes = len(text.encode("utf-8"))
    token_count = len(tokens)
    compression_pct = (token_count / chars * 100) if chars > 0 else 0
    bytes_per_token = (utf8_bytes / token_count) if token_count > 0 else 0

    typer.echo(f"Tokenizer class: {tokenizer_class}")
    typer.echo(f"Vocabulary size: {round(vocab_size / 1000)}k possible tokens")
    typer.echo(f"Special tokens ({num_special}): {special}")
    typer.echo()
    typer.echo(f"Input characters: {chars}")
    typer.echo(f"Compression ratio (tokens/chars): {compression_pct:.1f}%")
    typer.echo(f"UTF-8 bytes: {utf8_bytes}")
    typer.echo(f"Bytes per token: {bytes_per_token:.1f}")
    typer.echo()
    typer.echo(f"Token count: {token_count}")


if __name__ == "__main__":
    app()
