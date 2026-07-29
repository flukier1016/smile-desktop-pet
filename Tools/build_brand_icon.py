#!/usr/bin/env python3
"""Build the SmilePet macOS and web icon assets from the brand source."""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter, ImageOps


ICONSET_SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}


def remove_connected_dark_background(source: Image.Image) -> Image.Image:
    """Make only the dark canvas connected to the image edge transparent."""

    rgb = source.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def index(x: int, y: int) -> int:
        return y * width + x

    def is_background(x: int, y: int) -> bool:
        red, green, blue = pixels[x, y]
        return max(red, green, blue) <= 82 and max(red, green, blue) - min(
            red, green, blue
        ) <= 24

    def enqueue(x: int, y: int) -> None:
        position = index(x, y)
        if visited[position] or not is_background(x, y):
            return
        visited[position] = 1
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    removed = Image.new("L", (width, height), 0)
    removed.putdata([255 if value else 0 for value in visited])
    feathered = removed.filter(ImageFilter.GaussianBlur(1.15))
    alpha = ImageOps.invert(feathered)

    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def save_resized(source: Image.Image, size: int, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    resized = source.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(output, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "source",
        nargs="?",
        type=Path,
        default=Path("Assets/AppIconSource.png"),
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    args = parser.parse_args()

    project_root = args.project_root.resolve()
    source_path = (
        args.source
        if args.source.is_absolute()
        else project_root / args.source
    )
    source = Image.open(source_path)
    transparent = remove_connected_dark_background(source)
    master = transparent.resize((1024, 1024), Image.Resampling.LANCZOS)

    master_path = project_root / "Assets/AppIconMaster.png"
    master.save(master_path, optimize=True)

    save_resized(master, 512, project_root / "docs/media/app-icon.png")
    save_resized(
        master,
        512,
        project_root / "smilepet-landing/public/app-icon.png",
    )
    save_resized(
        master,
        64,
        project_root / "smilepet-landing/public/app-icon-64.png",
    )

    with tempfile.TemporaryDirectory(prefix="smilepet-icon-") as temporary:
        iconset = Path(temporary) / "AppIcon.iconset"
        iconset.mkdir()
        for filename, size in ICONSET_SIZES.items():
            save_resized(master, size, iconset / filename)
        subprocess.run(
            [
                "iconutil",
                "-c",
                "icns",
                str(iconset),
                "-o",
                str(project_root / "Assets/AppIcon.icns"),
            ],
            check=True,
        )

    print(f"Built icon master: {master_path}")
    print(f"Built macOS icon: {project_root / 'Assets/AppIcon.icns'}")
    print("Built matching documentation and landing-page icons.")


if __name__ == "__main__":
    main()
