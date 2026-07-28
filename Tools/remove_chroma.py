#!/usr/bin/env python3
"""Turn the generated green-screen pet into a cropped RGBA sprite."""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image


def smoothstep(low: float, high: float, value: float) -> float:
    value = max(0.0, min(1.0, (value - low) / (high - low)))
    return value * value * (3.0 - 2.0 * value)


def remove_green(input_path: Path, output_path: Path) -> None:
    source = Image.open(input_path).convert("RGBA")
    pixels = source.load()

    for y in range(source.height):
        for x in range(source.width):
            red, green, blue, _ = pixels[x, y]
            distance = math.sqrt(red * red + (255 - green) ** 2 + blue * blue)
            alpha = round(255 * smoothstep(38, 150, distance))

            # Suppress green spill on antialiased edge pixels.
            if alpha < 255 and green > max(red, blue):
                green = round(max(red, blue) + (green - max(red, blue)) * (alpha / 255))

            pixels[x, y] = (red, green, blue, alpha)

    alpha_channel = source.getchannel("A")
    bounds = alpha_channel.getbbox()
    if bounds is None:
        raise RuntimeError("No foreground survived chroma-key removal")

    padding = 28
    left = max(0, bounds[0] - padding)
    top = max(0, bounds[1] - padding)
    right = min(source.width, bounds[2] + padding)
    bottom = min(source.height, bounds[3] + padding)
    cropped = source.crop((left, top, right, bottom))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    cropped.save(output_path, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    remove_green(args.input, args.output)


if __name__ == "__main__":
    main()
