#!/usr/bin/env python3
"""Create a square transparent source image for the macOS app icon."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    pet = Image.open(args.input).convert("RGBA")
    max_width, max_height = 760, 900
    scale = min(max_width / pet.width, max_height / pet.height)
    pet = pet.resize(
        (round(pet.width * scale), round(pet.height * scale)),
        Image.Resampling.LANCZOS,
    )

    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    x = (1024 - pet.width) // 2
    y = (1024 - pet.height) // 2 + 26
    canvas.alpha_composite(pet, (x, y))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output, optimize=True)


if __name__ == "__main__":
    main()
