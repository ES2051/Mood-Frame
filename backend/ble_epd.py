"""
ble_epd.py
Pack a comfort image into the EPD tag's native 4-color format and push it
over BLE to the ble_epd.c GATT service running on the tag (EPD_TEST_01
firmware). Packing must exactly match Img_convert.py's pack_vertical_2bpp
so the tag renders the same pixels this produces.
"""

import asyncio
import os

import numpy as np
from PIL import Image
from bleak import BleakClient, BleakScanner

import config

EPD_WIDTH = 250
EPD_HEIGHT = 122
EPD_RAM_HEIGHT = 128

COLOR_WHITE, COLOR_YELLOW, COLOR_RED, COLOR_BLACK = 0, 1, 2, 3
PALETTE = np.array(
    [[255, 255, 255], [255, 255, 0], [255, 0, 0], [0, 0, 0]], dtype=np.float32
)

CHUNK_SIZE = 180
SCAN_TIMEOUT = 10.0
RENDER_TIMEOUT = 20.0


def _dither(image: Image.Image) -> np.ndarray:
    rgb = np.array(
        image.convert("RGB").resize((EPD_WIDTH, EPD_HEIGHT), Image.LANCZOS),
        dtype=np.float32,
    )
    out = np.zeros((EPD_HEIGHT, EPD_WIDTH), dtype=np.uint8)

    for y in range(EPD_HEIGHT):
        for x in range(EPD_WIDTH):
            old = rgb[y, x].copy()
            idx = int(np.argmin(np.sum((PALETTE - old) ** 2, axis=1)))
            out[y, x] = idx
            err = old - PALETTE[idx]

            if x + 1 < EPD_WIDTH:
                rgb[y, x + 1] = np.clip(rgb[y, x + 1] + err * 7 / 16, 0, 255)
            if y + 1 < EPD_HEIGHT:
                if x > 0:
                    rgb[y + 1, x - 1] = np.clip(rgb[y + 1, x - 1] + err * 3 / 16, 0, 255)
                rgb[y + 1, x] = np.clip(rgb[y + 1, x] + err * 5 / 16, 0, 255)
                if x + 1 < EPD_WIDTH:
                    rgb[y + 1, x + 1] = np.clip(rgb[y + 1, x + 1] + err * 1 / 16, 0, 255)

    return out


def _pack(color_map: np.ndarray) -> bytes:
    bytes_per_column = EPD_RAM_HEIGHT // 4
    packed = bytearray()

    for x in range(EPD_WIDTH - 1, -1, -1):
        for byte_y in range(bytes_per_column):
            value = 0
            for i in range(4):
                y = byte_y * 4 + i
                color = int(color_map[y, x]) & 0x03 if y < EPD_HEIGHT else COLOR_WHITE
                value |= color << (6 - i * 2)
            packed.append(value)

    return bytes(packed)


def _save_debug_artifacts(image_path: str, color_map: np.ndarray, packed: bytes) -> None:
    """Writes the exact bytes sent over BLE (<name>_tag.bin) and a preview of
    what the dithered image looks like (<name>_tag_preview.png), so the
    dithering can be checked without needing the physical tag."""
    base, _ = os.path.splitext(image_path)

    with open(f"{base}_tag.bin", "wb") as f:
        f.write(packed)

    preview = PALETTE[color_map].astype(np.uint8)
    Image.fromarray(preview, mode="RGB").save(f"{base}_tag_preview.png")


def pack_image_for_tag(image_path: str, save_debug: bool = True) -> bytes:
    """Convert any image into the tag's exact EPD_IMAGE_SIZE-byte wire format."""
    image = Image.open(image_path)
    color_map = _dither(image)
    packed = _pack(color_map)

    if save_debug:
        _save_debug_artifacts(image_path, color_map, packed)

    return packed


async def _send(image_bytes: bytes, device_name: str, timeout: float) -> bool:
    device = await BleakScanner.find_device_by_name(device_name, timeout=SCAN_TIMEOUT)
    if device is None:
        raise RuntimeError(
            f"BLE tag '{device_name}' not found -- is it powered on and in range?"
        )

    render_done = asyncio.Event()

    def on_status(_, data: bytearray):
        render_done.set()

    async with BleakClient(device) as client:
        await client.start_notify(config.BLE_TAG_STATUS_CHAR_UUID, on_status)

        for offset in range(0, len(image_bytes), CHUNK_SIZE):
            chunk = image_bytes[offset : offset + CHUNK_SIZE]
            await client.write_gatt_char(
                config.BLE_TAG_IMAGE_CHAR_UUID, chunk, response=False
            )
            await asyncio.sleep(0.01)

        try:
            await asyncio.wait_for(render_done.wait(), timeout=timeout)
            rendered = True
        except asyncio.TimeoutError:
            rendered = False

        await client.stop_notify(config.BLE_TAG_STATUS_CHAR_UUID)

    return rendered


def send_image_to_tag(
    image_path: str,
    device_name: str = config.BLE_TAG_DEVICE_NAME,
    timeout: float = RENDER_TIMEOUT,
) -> bool:
    """Pack `image_path` and push it to the tag over BLE. Returns True if the
    tag confirmed a render, False if it timed out waiting for confirmation."""
    packed = pack_image_for_tag(image_path)
    return asyncio.run(_send(packed, device_name, timeout))


if __name__ == "__main__":
    import sys

    path = sys.argv[1] if len(sys.argv) > 1 else "generated/sadness.png"
    ok = send_image_to_tag(path)
    print("render confirmed" if ok else "sent, but no render confirmation received")
