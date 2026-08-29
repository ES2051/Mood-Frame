from pathlib import Path
from PIL import Image
import numpy as np

EPD_WIDTH = 250
EPD_HEIGHT = 122    # 실제 이미지 높이
EPD_RAM_HEIGHT = 128   # 저장용 높이

# Color_get()에 전달되는 색상 번호
COLOR_WHITE = 0x00
COLOR_YELLOW = 0x01
COLOR_RED = 0x02
COLOR_BLACK = 0x03

# RGB 기준 팔레트
PALETTE = np.array(
    [
        [255, 255, 255],  # WHITE
        [255, 255,   0],  # YELLOW
        [255,   0,   0],  # RED
        [  0,   0,   0],  # BLACK
    ],
    dtype=np.float32,
)


def nearest_palette_color(pixel: np.ndarray) -> tuple[int, np.ndarray]:
    """
    RGB 픽셀과 가장 가까운 4색 팔레트 색상을 찾는다.
    반환값:
        색상 번호, 선택된 RGB 색상
    """
    distances = np.sum((PALETTE - pixel) ** 2, axis=1)
    color_index = int(np.argmin(distances))

    return color_index, PALETTE[color_index]


def floyd_steinberg_dither(image: Image.Image) -> np.ndarray:
    """
    이미지를 WHITE/YELLOW/RED/BLACK 4색으로 디더링한다.

    반환 배열 형식:
        shape = (EPD_HEIGHT, EPD_WIDTH)
        각 값 = 0~3 색상 번호
    """
    rgb = np.array(image.convert("RGB"), dtype=np.float32)
    output = np.zeros((EPD_HEIGHT, EPD_WIDTH), dtype=np.uint8)

    for y in range(EPD_HEIGHT):
        for x in range(EPD_WIDTH):
            old_pixel = rgb[y, x].copy()

            color_index, new_pixel = nearest_palette_color(old_pixel)
            output[y, x] = color_index

            error = old_pixel - new_pixel
            rgb[y, x] = new_pixel

            # Floyd–Steinberg error diffusion
            if x + 1 < EPD_WIDTH:
                rgb[y, x + 1] += error * (7.0 / 16.0)

            if y + 1 < EPD_HEIGHT:
                if x > 0:
                    rgb[y + 1, x - 1] += error * (3.0 / 16.0)

                rgb[y + 1, x] += error * (5.0 / 16.0)

                if x + 1 < EPD_WIDTH:
                    rgb[y + 1, x + 1] += error * (1.0 / 16.0)

            # RGB 범위를 벗어나지 않도록 제한
            if x + 1 < EPD_WIDTH:
                rgb[y, x + 1] = np.clip(rgb[y, x + 1], 0, 255)

            if y + 1 < EPD_HEIGHT:
                if x > 0:
                    rgb[y + 1, x - 1] = np.clip(
                        rgb[y + 1, x - 1], 0, 255
                    )

                rgb[y + 1, x] = np.clip(rgb[y + 1, x], 0, 255)

                if x + 1 < EPD_WIDTH:
                    rgb[y + 1, x + 1] = np.clip(
                        rgb[y + 1, x + 1], 0, 255
                    )

    return output


def pack_vertical_2bpp(color_map: np.ndarray) -> bytes:
    """
    세로 방향으로 4픽셀을 1바이트에 저장한다.

    한 바이트 구성:
        bit 7~6 = 첫 번째 픽셀
        bit 5~4 = 두 번째 픽셀
        bit 3~2 = 세 번째 픽셀
        bit 1~0 = 네 번째 픽셀

    저장 순서:
        x=0의 y=0~121
        x=1의 y=0~121
        ...
        x=249의 y=0~121
    """
    bytes_per_column = (EPD_RAM_HEIGHT + 3) // 4  # 128 / 4 = 32
    packed = bytearray()

    for x in range(EPD_WIDTH - 1, -1, -1):
        for byte_y in range(bytes_per_column):
            value = 0

            for pixel_index in range(4):
                y = byte_y * 4 + pixel_index

                if y < EPD_HEIGHT:
                    color = int(color_map[y, x]) & 0x03
                else:
                    # 남는 픽셀은 흰색으로 채움
                    color = COLOR_WHITE

                shift = 6 - pixel_index * 2
                value |= color << shift

            packed.append(value)

    return bytes(packed)


def save_preview(color_map: np.ndarray, output_path: Path) -> None:
    """
    변환 결과를 확인할 수 있도록 미리보기 이미지를 저장한다.
    """
    preview = PALETTE[color_map].astype(np.uint8)
    Image.fromarray(preview, mode="RGB").save(output_path)


def save_c_header(
    packed_data: bytes,
    output_path: Path,
    array_name: str = "gImage_29demo",
) -> None:
    """
    App_29demo.h와 유사한 C header 형식으로 저장한다.
    """
    guard_name = output_path.stem.upper() + "_H"

    with output_path.open("w", encoding="utf-8") as file:
        file.write(f"#ifndef {guard_name}\n")
        file.write(f"#define {guard_name}\n\n")

        file.write("#include <stdint.h>\n\n")

        file.write(f"#define IMAGE_WIDTH     {EPD_WIDTH}\n")
        file.write(f"#define IMAGE_HEIGHT    {EPD_HEIGHT}\n")
        file.write(f"#define IMAGE_DATA_SIZE {len(packed_data)}\n\n")

        file.write(
            f"static const uint8_t {array_name}[IMAGE_DATA_SIZE] =\n"
        )
        file.write("{\n")

        values_per_line = 16

        for index, value in enumerate(packed_data):
            if index % values_per_line == 0:
                file.write("    ")

            file.write(f"0x{value:02X}")

            if index != len(packed_data) - 1:
                file.write(", ")

            if (
                index % values_per_line == values_per_line - 1
                or index == len(packed_data) - 1
            ):
                file.write("\n")

        file.write("};\n\n")
        file.write(f"#endif /* {guard_name} */\n")


def convert_image(input_file: str) -> None:
    input_path = Path(input_file)

    if not input_path.exists():
        raise FileNotFoundError(f"이미지 파일을 찾을 수 없습니다: {input_path}")

    try:
        image = Image.open(input_path)
    except Exception as error:
        raise RuntimeError(f"이미지를 열 수 없습니다: {error}") from error

    # 패널 비율에 강제로 맞춤
    image = image.resize(
        (EPD_WIDTH, EPD_HEIGHT),
        Image.Resampling.LANCZOS,
    )

    color_map = floyd_steinberg_dither(image)
    packed_data = pack_vertical_2bpp(color_map)

    output_header = Path(r"C:\ESP32\EPD_TEST\main\Img_generated.h")
    output_preview = Path(r"C:\ESP32\EPD_TEST\Img\Img_generated_preview.png")

    save_c_header(
        packed_data=packed_data,
        output_path=output_header,
        array_name="Image_generate",
    )

    save_preview(
        color_map=color_map,
        output_path=output_preview,
    )

    print(f"헤더 생성 완료: {output_header}")
    print(f"미리보기 생성 완료: {output_preview}")
    print(f"데이터 크기: {len(packed_data)} bytes")


if __name__ == "__main__":
    convert_image("input_img.jpg")