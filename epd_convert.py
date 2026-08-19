"""
epd_convert.py
Convert a generated comfort image into a 4-color (black / white / red /
yellow) image ready for your EPD tag display.
"""

import os
from PIL import Image, ImageEnhance, ImageFilter

# The 4 colors your tag EPD supports.
PALETTE_4C = [
    (0, 0, 0),        # black
    (255, 255, 255),  # white
    (255, 0, 0),      # red
    (255, 255, 0),    # yellow
]

# Your tag EPD's native resolution: 128 x 250 (width x height).
# PIL's resize() takes (width, height), so this is set as (128, 250).
EPD_SIZE = (128, 250)


def _make_palette_image(colors):
    """Build a Pillow 'P' mode image containing exactly these colors."""
    pal_img = Image.new("P", (1, 1))
    flat = []
    for c in colors:
        flat.extend(c)
    # Pillow palettes need 256 entries (768 values) -- pad with the last color.
    while len(flat) < 768:
        flat.extend(colors[-1])
    pal_img.putpalette(flat)
    return pal_img


def convert_for_epd(image_path: str, size: tuple = EPD_SIZE) -> str:
    """
    Quantize `image_path` down to the 4-color EPD palette with
    Floyd-Steinberg dithering (this is what lets a photo still read as a
    photo instead of flat color blobs at only 4 colors).

    Returns the path to the converted PNG: "<name>_epd4c.png".
    """
    base, _ = os.path.splitext(image_path)
    img = Image.open(image_path).convert("RGB").resize(size, Image.LANCZOS)

    # Muted, low-saturation tones (typical of AI-generated photos) almost
    # always map to black/white in nearest-color quantization -- red/yellow
    # only get picked when a pixel is already strongly that color. Boosting
    # saturation first is what lets red/yellow actually show up at all.
    img = ImageEnhance.Color(img).enhance(2.4)
    img = ImageEnhance.Contrast(img).enhance(1.25)

    # Fine photographic detail/texture turns to speckled static once
    # Floyd-Steinberg dithers it down to 4 colors at this resolution.
    # Smoothing first keeps regions large enough to read as shapes.
    img = img.filter(ImageFilter.GaussianBlur(radius=1.3))

    pal_img = _make_palette_image(PALETTE_4C)
    quantized = img.quantize(palette=pal_img, dither=Image.FLOYDSTEINBERG)

    out_path = f"{base}_epd4c.png"
    quantized.convert("RGB").save(out_path)
    return out_path


if __name__ == "__main__":
    import sys
    path = sys.argv[1] if len(sys.argv) > 1 else "generated/sadness.png"
    print(convert_for_epd(path))