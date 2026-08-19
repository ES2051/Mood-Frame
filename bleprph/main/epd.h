#ifndef EPD_H
#define EPD_H

#include <stdint.h>
#include <stddef.h>

#include "esp_err.h"

#define EPD_WIDTH   250
#define EPD_HEIGHT  122

#define EPD_LINE_BYTES  32
#define EPD_IMAGE_SIZE  (EPD_WIDTH * EPD_LINE_BYTES)

//#define EPD_IMAGE_SIZE 8000

esp_err_t epd_init(void);

esp_err_t epd_display_image(const uint8_t *image, size_t length);

esp_err_t epd_display_default_image(void);

/* EPD 초기화, Queue 생성, Task 생성을 한 번에 수행 */
esp_err_t epd_task_start(void);

/* BLE에서 기본 이미지 표시를 요청할 때 호출 */
esp_err_t epd_request_default_image(void);

#endif