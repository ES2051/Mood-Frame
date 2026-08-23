#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#include "esp_log.h"
#include "esp_err.h"
#include "rom/ets_sys.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"

#include "epd.h"
#include "Img_generated_01.h"

_Static_assert(
    sizeof(Image_generate) == EPD_IMAGE_SIZE,
    "Image_generate must be exactly 8000 bytes"
);

//#include "driver/spi_master.h" //실제 하드웨어 SPI 초기화를 하지 않고 GPIO 비트뱅잉만 함
//불필요

static const char *TAG = "EPD";

typedef enum
{
    EPD_REQUEST_DEFAULT_IMAGE,
    EPD_REQUEST_RECEIVED_IMAGE
} epd_request_t;

static QueueHandle_t epd_queue = NULL;
static uint8_t received_image[EPD_IMAGE_SIZE];

typedef uint8_t  u8;
typedef uint32_t u32;
//typedef int32_t  s32;

static unsigned char Color_get(uint8_t color);
static void Img_display(const unsigned char *image);
static int EPD_refresh(void);

#define EPD_PIN_BUSY    GPIO_NUM_5
#define EPD_PIN_RST     GPIO_NUM_6
#define EPD_PIN_DC      GPIO_NUM_7
#define EPD_PIN_CS      GPIO_NUM_10
#define EPD_PIN_MOSI    GPIO_NUM_11
#define EPD_PIN_CLK     GPIO_NUM_12

//#define EPD_WIDTH   296
//#define EPD_HEIGHT  168

//#define width  (1+(EPD_HEIGHT-1)/4)

#define EPD_CMD_RAM_BW_X_POS	0x44
#define EPD_CMD_RAM_BW_Y_POS	0x45

#define EPD_CMD_RAM_BW_X_CNTR	0x4E
#define EPD_CMD_RAM_BW_Y_CNTR	0x4F

#define EPD_CMD_WRITE_BW_RAM	0x24
#define EPD_CMD_WRITE_RED_RAM	0x26

//2bit
#define black   0x00	/// 00
#define white   0x01	///	01
#define yellow  0x02	///	10
#define red     0x03	///	11

//#define EPD_COLOR_BLACK 0x00
//#define EPD_COLOR_WHITE 0x55
//#define EPD_COLOR_YELLOW 0xAA
//#define EPD_COLOR_RED 0xFF

//u8 gRamBuffer[15562];

static void EPD_PIN_INIT()
{
    //gpio_reset_pin(EPD_PIN_DC);
    //gpio_set_level(EPD_PIN_RST, 0);
    gpio_reset_pin(EPD_PIN_DC);
    gpio_reset_pin(EPD_PIN_RST);
    gpio_reset_pin(EPD_PIN_BUSY);
  
    gpio_set_direction(EPD_PIN_DC, GPIO_MODE_OUTPUT);
    gpio_set_direction(EPD_PIN_RST, GPIO_MODE_OUTPUT);
    gpio_set_direction(EPD_PIN_BUSY, GPIO_MODE_INPUT);

    gpio_set_level(EPD_PIN_DC, 0);
    gpio_set_level(EPD_PIN_RST, 0);
}

static void EPD_SPI_PIN()
{
/*   
    spi_bus_config_t buscfg = {
        .mosi_io_num = EPD_PIN_MOSI,
        .miso_io_num = -1,
        .sclk_io_num = EPD_PIN_CLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
    };

    spi_device_interface_config_t devcfg = {
        .clock_speed_hz = 50 * 1000 * 1000,   // 처음에는 10MHz 권장
        .mode = 0,
        .spics_io_num = EPD_PIN_CS,
        .queue_size = 1,
    };
*/ 
    gpio_reset_pin(EPD_PIN_CS);
    gpio_reset_pin(EPD_PIN_MOSI);
    gpio_reset_pin(EPD_PIN_CLK);

    gpio_set_direction(EPD_PIN_CS, GPIO_MODE_OUTPUT);   // CS
    gpio_set_direction(EPD_PIN_DC,  GPIO_MODE_OUTPUT);   // DC
    gpio_set_direction(EPD_PIN_MOSI, GPIO_MODE_OUTPUT);   // MOSI(SDA)
    gpio_set_direction(EPD_PIN_CLK, GPIO_MODE_OUTPUT);   // SCK(SCL)

    gpio_set_level(EPD_PIN_CS, 1);   // CS High
    gpio_set_level(EPD_PIN_DC,  0);   // DC Low
    gpio_set_level(EPD_PIN_MOSI, 0);
    gpio_set_level(EPD_PIN_CLK, 0);
}

static void EPD_WaitBusy(void)
{
    if(gpio_get_level(EPD_PIN_BUSY) == 0)
    {
        ets_delay_us(1000);      // 1ms 대기
    }
   /*
   while(1)
   {
        if(gpio_get_level(EPD_PIN_BUSY) == 1)
            break; 
        ets_delay_us(5000);
   }
   ets_delay_us(100*1000);*/
}

static void spi_write_byte(uint8_t data)
{
    for (uint8_t i = 0x80; i > 0; i >>= 1)
    {
        if (data & i)
            gpio_set_level(EPD_PIN_MOSI, 1);
        else
            gpio_set_level(EPD_PIN_MOSI, 0);

        gpio_set_level(EPD_PIN_CLK, 1);
        ets_delay_us(3);
        gpio_set_level(EPD_PIN_CLK, 0);
        ets_delay_us(3);
    }
}

static void ssd_set_cmd(u8 data)
{
    gpio_set_level(EPD_PIN_CS, 0);
    gpio_set_level(EPD_PIN_DC, 0);
    gpio_set_level(EPD_PIN_MOSI, 0);
    gpio_set_level(EPD_PIN_CLK, 0);

	spi_write_byte(data);

    gpio_set_level(EPD_PIN_DC, 0);
    gpio_set_level(EPD_PIN_MOSI, 0);
    gpio_set_level(EPD_PIN_CLK, 0);
    gpio_set_level(EPD_PIN_CS, 1);
}

static void ssd_set_data(const u8 *data, u32 size)
{
    gpio_set_level(EPD_PIN_CS, 0);
    gpio_set_level(EPD_PIN_DC, 1);
    gpio_set_level(EPD_PIN_MOSI, 0);
    gpio_set_level(EPD_PIN_CLK, 0);

	for(u32 i=0; i<size; i++)
		{
		    spi_write_byte(data[i]);
		}

    gpio_set_level(EPD_PIN_DC, 0);
    gpio_set_level(EPD_PIN_MOSI, 0);
    gpio_set_level(EPD_PIN_CLK, 0);
    gpio_set_level(EPD_PIN_CS, 1);
}

void ssd_set_idata(const u8 *data, u32 size)
{
    gpio_set_level(EPD_PIN_CS, 0);
    gpio_set_level(EPD_PIN_DC, 1);
    gpio_set_level(EPD_PIN_MOSI, 0);
    gpio_set_level(EPD_PIN_CLK, 0);

	for(u32 i=0; i<size; i++)
		{
		    spi_write_byte(~data[i]);
		}

    gpio_set_level(EPD_PIN_DC, 0);
    gpio_set_level(EPD_PIN_MOSI, 0);
    gpio_set_level(EPD_PIN_CLK, 0);
    gpio_set_level(EPD_PIN_CS, 1);

}

static void EPD_sendCmdData(u8 cmd, const u8 *data, int size)
{
	ssd_set_cmd(cmd);
	ssd_set_data(data, size);
}

static void EPD_DRIVER()
{
	u8 reg00_data[] = {0x0F, 0x29};
    u8 reg01_data[] = {0x07, 0x00, 0x26, 0x21, 0x78, 0x26};
    u8 reg06_data[] = {0x0F, 0x8B, 0x9C, 0x96};
    u8 reg50_data = 0x37;
    u8 reg61_data[] = {0x00, 0x80, 0x00, 0xFA};
    u8 reg62_data[] = {0x50, 0x43};
    u8 regE3_data = 0x22;
    u8 reg30_data = 0x08;
    u8 regE9_data = 0x01;
    u8 reg04_data = 0x00;

    EPD_sendCmdData(0x00, reg00_data, sizeof(reg00_data));

    EPD_sendCmdData(0x01, reg01_data, sizeof(reg01_data));

    EPD_sendCmdData(0x06, reg06_data, sizeof(reg06_data));

    EPD_sendCmdData(0x50, &reg50_data, sizeof(reg50_data));

	EPD_sendCmdData(0x61, reg61_data, sizeof(reg61_data));

    EPD_sendCmdData(0x62, reg62_data, sizeof(reg62_data));

    EPD_sendCmdData(0xE3, &regE3_data, sizeof(regE3_data));

    EPD_sendCmdData(0x30, &reg30_data, sizeof(reg30_data));

    EPD_sendCmdData(0xE9, &regE9_data, sizeof(regE9_data));

    EPD_sendCmdData(0x04, &reg04_data, sizeof(reg04_data));

    ets_delay_us(300*1000);
    EPD_WaitBusy(); 
}

void EPD_sendStart(int color)
{
   ssd_set_cmd(0x10);
}

void EPD_send(const u8 *frame_buffer, u32 bufSize, int color)
{
    for(u32 i=0; i<bufSize; i++)
    {
            ssd_set_data(&frame_buffer[i], 1);
    }
}

static int EPD_refresh(void)
{
    const uint32_t timeout_ms = 40000; //max 40s
    uint32_t elapsed_ms = 0;

    ssd_set_cmd(0x12);

    ESP_LOGI(TAG,
             "EPD refresh command sent, BUSY=%d",
             gpio_get_level(EPD_PIN_BUSY));

    /* BUSY LOW = 갱신 중, HIGH = 갱신 완료 */
    while (gpio_get_level(EPD_PIN_BUSY) == 0)
    {
        if (elapsed_ms >= timeout_ms)
        {
            ESP_LOGE(TAG,
                     "EPD refresh timeout, BUSY=%d",
                     gpio_get_level(EPD_PIN_BUSY));
            return -1;
        }

        vTaskDelay(pdMS_TO_TICKS(10));
        elapsed_ms += 10;
    }

    ESP_LOGI(TAG,
             "EPD refresh completed, BUSY=%d, elapsed=%lu ms",
             gpio_get_level(EPD_PIN_BUSY),
             (unsigned long)elapsed_ms);

    vTaskDelay(pdMS_TO_TICKS(100));

    ssd_set_cmd(0x02);
    vTaskDelay(pdMS_TO_TICKS(100));

    return 0;
}

unsigned char Color_get(unsigned char color)
{
	switch(color & 0x03) //color
	{
		case 0x00:
			return white;			
		case 0x01:
			return yellow;
		case 0x02:
			return red;		
		case 0x03:
			return black;			
        default:
            return white;			
	}
}

static void Img_display(const unsigned char* ImgData)
{
    unsigned int i;
	unsigned char temp1;
	unsigned char data_H1,data_H2,data_L1,data_L2,data;
	
    if (ImgData == NULL)
    {
        ESP_LOGE(TAG, "Image data is NULL");
        return;
    }

	ssd_set_cmd(0x10);	       
    for(i=0;i<EPD_IMAGE_SIZE;i++)  
	{
        temp1=ImgData[i]; 
        data_H1=Color_get(temp1>>6&0x03)<<6;			
        data_H2=Color_get(temp1>>4&0x03)<<4;
        data_L1=Color_get(temp1>>2&0x03)<<2;
        data_L2=Color_get(temp1&0x03);
			
        data=data_H1|data_H2|data_L1|data_L2;
        ssd_set_data(&data, 1);
    }	
}

esp_err_t epd_init(void)
{
    ESP_LOGI(TAG, "EPD GPIO INIT");
    EPD_PIN_INIT();

    ESP_LOGI(TAG, "SPI GPIO INIT");
    EPD_SPI_PIN();

    gpio_set_level(EPD_PIN_RST, 0);
    ets_delay_us(30000);

    gpio_set_level(EPD_PIN_RST, 1);
    gpio_set_level(EPD_PIN_CS, 1);
    ets_delay_us(20000);

    gpio_set_level(EPD_PIN_RST, 0);
    ets_delay_us(20000);

    gpio_set_level(EPD_PIN_RST, 1);
    ets_delay_us(20000);

    //ets_delay_us(100*1000);

    EPD_WaitBusy();   

    //ets_delay_us(20*1000);

    EPD_DRIVER();

    return ESP_OK;
}

esp_err_t epd_display_image(const uint8_t *image, size_t length)
{
    if (image == NULL)
    {
        ESP_LOGE(TAG, "Image pointer is NULL");
        return ESP_ERR_INVALID_ARG;
    }

    if (length != EPD_IMAGE_SIZE)
    {
        ESP_LOGE(TAG,
                 "Invalid image size: %u, expected: %u",
                 (unsigned)length,
                 (unsigned)EPD_IMAGE_SIZE);

        return ESP_ERR_INVALID_SIZE;
    }

    Img_display(image);

    if (EPD_refresh() < 0)
    {
        ESP_LOGE(TAG, "EPD refresh failed");
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "EPD update success");
    return ESP_OK;
}

esp_err_t epd_display_default_image(void)
{
    return epd_display_image(Image_generate,
                             sizeof(Image_generate));
}

//freeRTOS
static void epd_task(void *arg)
{
    epd_request_t request;

    while (true)
    {
        if (xQueueReceive(
                epd_queue,
                &request,
                portMAX_DELAY) == pdTRUE)
        {
            switch (request)
            {
                case EPD_REQUEST_DEFAULT_IMAGE:
                {
                    ESP_LOGI(TAG, "Default image update started");

                    esp_err_t ret =
                        epd_display_default_image();

                    if (ret == ESP_OK)
                    {
                        ESP_LOGI(
                            TAG,
                            "Default image displayed"
                        );
                    }
                    else
                    {
                        ESP_LOGE(
                            TAG,
                            "Display failed: %s",
                            esp_err_to_name(ret)
                        );
                    }

                    break;
                }

                case EPD_REQUEST_RECEIVED_IMAGE:
                {
                    ESP_LOGI(TAG, "Received image update started");

                    esp_err_t ret =
                        epd_display_image(received_image,
                                          sizeof(received_image));

                    if (ret == ESP_OK)
                    {
                        ESP_LOGI(
                            TAG,
                            "Received image displayed"
                        );
                    }
                    else
                    {
                        ESP_LOGE(
                            TAG,
                            "Received image display failed: %s",
                            esp_err_to_name(ret)
                        );
                    }

                    break;
                }

                default:
                    ESP_LOGW(
                        TAG,
                        "Unknown EPD request: %d",
                        request
                    );
                    break;
            }
        }
    }
}

esp_err_t epd_task_start(void)
{
    if (epd_queue != NULL)
    {
        ESP_LOGW(TAG, "EPD task already started");
        return ESP_OK;
    }

    esp_err_t ret = epd_init();

    if (ret != ESP_OK)
    {
        ESP_LOGE(
            TAG,
            "EPD init failed: %s",
            esp_err_to_name(ret)
        );

        return ret;
    }

    epd_queue = xQueueCreate(
        2,
        sizeof(epd_request_t)
    );

    if (epd_queue == NULL)
    {
        ESP_LOGE(TAG, "Failed to create EPD queue");
        return ESP_ERR_NO_MEM;
    }

    BaseType_t task_result = xTaskCreate(
        epd_task,       /* 실행할 함수 */
        "epd_task",     /* Task 이름 */
        4096,           /* Stack 크기 */
        NULL,           /* 전달할 인자 */
        5,              /* 우선순위 */
        NULL            /* Task handle */
    );

    if (task_result != pdPASS)
    {
        ESP_LOGE(TAG, "Failed to create EPD task");

        vQueueDelete(epd_queue);
        epd_queue = NULL;

        return ESP_ERR_NO_MEM;
    }

    ESP_LOGI(TAG, "EPD task started");

    return ESP_OK;
}

esp_err_t epd_request_default_image(void)
{
    if (epd_queue == NULL)
    {
        ESP_LOGE(TAG, "EPD queue is not initialized");
        return ESP_ERR_INVALID_STATE;
    }

    epd_request_t request =
        EPD_REQUEST_DEFAULT_IMAGE;

    if (xQueueSend(
            epd_queue,
            &request,
            0) != pdTRUE)
    {
        ESP_LOGW(TAG, "EPD queue is full");
        return ESP_ERR_TIMEOUT;
    }

    ESP_LOGI(TAG, "Default image request queued");

    return ESP_OK;
}

esp_err_t epd_request_image(const uint8_t *image, size_t length)
{
    if (epd_queue == NULL)
    {
        ESP_LOGE(TAG, "EPD queue is not initialized");
        return ESP_ERR_INVALID_STATE;
    }

    if (image == NULL)
    {
        ESP_LOGE(TAG, "Image pointer is NULL");
        return ESP_ERR_INVALID_ARG;
    }

    if (length != EPD_IMAGE_SIZE)
    {
        ESP_LOGE(TAG,
                 "Invalid received image size: %u, expected: %u",
                 (unsigned)length,
                 (unsigned)EPD_IMAGE_SIZE);
        return ESP_ERR_INVALID_SIZE;
    }

    memcpy(received_image, image, sizeof(received_image));

    epd_request_t request =
        EPD_REQUEST_RECEIVED_IMAGE;

    if (xQueueSend(
            epd_queue,
            &request,
            0) != pdTRUE)
    {
        ESP_LOGW(TAG, "EPD queue is full");
        return ESP_ERR_TIMEOUT;
    }

    ESP_LOGI(TAG, "Received image request queued");

    return ESP_OK;
}
