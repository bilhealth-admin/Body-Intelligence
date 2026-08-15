from __future__ import annotations

import argparse
import gzip
import shutil
from pathlib import Path


def compress(source: Path, output: Path) -> None:
    if not source.is_file():
        raise FileNotFoundError(source)
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    with source.open("rb") as source_stream, temporary.open("wb") as raw_output:
        with gzip.GzipFile(
            filename="", fileobj=raw_output, mode="wb", compresslevel=9, mtime=0
        ) as output_stream:
            shutil.copyfileobj(source_stream, output_stream, length=1024 * 1024)
    temporary.replace(output)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create a reproducible, streamed gzip catalog artifact."
    )
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    compress(args.source, args.output)
    print(f"Compressed catalog ready: {args.output}")


if __name__ == "__main__":
    main()
