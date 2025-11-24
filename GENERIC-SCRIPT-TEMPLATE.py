#!/usr/bin/env -S uv --quiet run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["typer"]
# ///

"""
SCRIPT_NAME goes here

Description of script goes here

"""

import typer

# Use doc string as help
app = typer.Typer(help=__doc__, add_completion=False)


@app.command()
def main(
    option: str = typer.Option(
        default="default setting", help="Describe this CLI option."
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

    typer.echo(f"Running TOOL_NAME with option={option!r}")


if __name__ == "__main__":
    app()
