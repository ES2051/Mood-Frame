#include <stdio.h>
#include <stdint.h>
#include "driver/gpio.h"
#include "esp_log.h"
#include "driver/spi_master.h"
#include "rom/ets_sys.h"
#include "Ap_29demo.h"
#include "Img_generated.h"
#include "epd_display.h"
#include "ble_epd.h"

static const char *TAG = "EPD_TEST";

typedef uint8_t  u8;
typedef uint32_t u32;
typedef int32_t  s32;

#define EPD_PIN_BUSY    GPIO_NUM_5
#define EPD_PIN_RST     GPIO_NUM_6
#define EPD_PIN_DC      GPIO_NUM_7
#define EPD_PIN_CS      GPIO_NUM_10
#define EPD_PIN_MOSI    GPIO_NUM_11
#define EPD_PIN_CLK     GPIO_NUM_12

#define width  (1+(EPD_HEIGHT-1)/4)

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

u8 gRamBuffer[15562];

void EPD_PIN_INIT()
{
    gpio_reset_pin(EPD_PIN_DC);
    gpio_set_level(EPD_PIN_RST, 0);
  
    gpio_set_direction(EPD_PIN_DC, GPIO_MODE_OUTPUT);
    gpio_set_direction(EPD_PIN_RST, GPIO_MODE_OUTPUT);
    gpio_set_direction(EPD_PIN_BUSY, GPIO_MODE_INPUT);
}

void EPD_SPI_PIN()
{
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

    gpio_set_direction(EPD_PIN_CS, GPIO_MODE_OUTPUT);   // CS
    gpio_set_direction(EPD_PIN_DC,  GPIO_MODE_OUTPUT);   // DC
    gpio_set_direction(EPD_PIN_MOSI, GPIO_MODE_OUTPUT);   // MOSI(SDA)
    gpio_set_direction(EPD_PIN_CLK, GPIO_MODE_OUTPUT);   // SCK(SCL)

    gpio_set_level(EPD_PIN_CS, 1);   // CS High
    gpio_set_level(EPD_PIN_DC,  0);   // DC Low
}

void EPD_WaitBusy(void)
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

void spi_write_byte(uint8_t data)
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

void ssd_set_cmd(u8 data)
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

void ssd_set_data(const u8 *data, u32 size)
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

void EPD_sendCmdData(u8 cmd, const u8 *data, int size)
{
	ssd_set_cmd(cmd);
	ssd_set_data(data, size);
}

void EPD_DRIVER_310()
{
    u8 reg3C_data = 0x05;
	u8 reg11_data = 0x03;		//no flip:0x01, flip:0x03
	u8 reg18_data = 0x80;
	u8 reg22_data = 0xB1;
	u8 reg21_data[] = {0x00, 0x80};
	u8 reg01_data[3], reg44_data[2];
	u32 reg45_data = (EPD_WIDTH-1) << 16;;

    reg01_data[0] = 0x27;
    reg01_data[1] = 0x01;
    reg01_data[2] = 0x00;
    
    reg44_data[0] = 0x00;
    reg44_data[1] = 0x14;

    ssd_set_cmd(0x12); //reset

    ets_delay_us(100*1000);
    EPD_WaitBusy();

    u8 reg74_data = 0x54;
    u8 reg7E_data = 0x3B;
    EPD_sendCmdData(0x74, &reg74_data, sizeof(reg74_data));
    EPD_sendCmdData(0x7E, &reg7E_data, sizeof(reg7E_data));

    EPD_sendCmdData(0x01, reg01_data, sizeof(reg01_data));
	reg44_data[0] = 0x00;
    reg44_data[1] = 0x14;

    EPD_sendCmdData(0x11, &reg11_data, sizeof(reg11_data));
	EPD_sendCmdData(EPD_CMD_RAM_BW_X_POS, reg44_data, sizeof(reg44_data));
	EPD_sendCmdData(EPD_CMD_RAM_BW_Y_POS, (u8*)&reg45_data, sizeof(reg45_data));

    u8 reg2B_data[] = {0x04, 0x63};
	u8 reg0C_data[] = {0x8B, 0x9C, 0x96, 0x0F};
    EPD_sendCmdData(0x3C, &reg3C_data, 1);
    EPD_sendCmdData(0x2B, reg2B_data, sizeof(reg2B_data));
    EPD_sendCmdData(0x0C, reg0C_data, sizeof(reg0C_data));
    EPD_sendCmdData(0x18, &reg18_data, 1);
    EPD_sendCmdData(0x22, &reg22_data, 1);  
    ssd_set_cmd(0x20);

    ets_delay_us(100*1000);
    EPD_WaitBusy();
}

void EPD_DRIVER()
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
	/*u8 reg4E_data = 0x00;	
	u8 reg4F_data[] = {0x00, 0x00};

	EPD_sendCmdData(EPD_CMD_RAM_BW_X_CNTR, &reg4E_data, sizeof(reg4E_data));
	EPD_sendCmdData(EPD_CMD_RAM_BW_Y_CNTR, reg4F_data, sizeof(reg4F_data));
    
    ssd_set_cmd(0x10);
	if(color == 0)
	{
		ssd_set_cmd(EPD_CMD_WRITE_BW_RAM);
	}
	else
	{
		ssd_set_cmd(EPD_CMD_WRITE_RED_RAM);
	}
    */
   ssd_set_cmd(0x10);
}

void EPD_send(const u8 *frame_buffer, u32 bufSize, int color)
{
    /*
	if(color == 0)
	{
		ssd_set_data(frame_buffer, bufSize);
	}
	else
	{
		ssd_set_idata(frame_buffer, bufSize); //red
	}*/
    for(u32 i=0; i<bufSize; i++)
    {
            ssd_set_data(&frame_buffer[i], 1);
    }
}

int EPD_refresh_3color()
{
	u32 sleep_usec = 150ul*1000;

	u8 reg22_data = 0xC7;
	EPD_sendCmdData(0x22, &reg22_data, sizeof(reg22_data)); //EPD_CMD_UPDATE_CNTL2

	/* refresh display */
	ssd_set_cmd(0x20); //EPD_CMD_DISPLAY_REFRESH
    ets_delay_us(300*1000);

	if(gpio_get_level(EPD_PIN_BUSY) == 1)
	{
        //ets_delay_us(sleep_usec);

		ets_delay_us(10*1000);
		if(gpio_get_level(EPD_PIN_BUSY) == 1)
		{
			ets_delay_us(300*1000);
			return -1;
		}
        ESP_LOGI(TAG, "D DONE");
	}
	else
	{
		/* refresh failed */
		ets_delay_us(1000);
		return -1;
	}

	ets_delay_us(100*1000);

	{
	u8 reg10_data = 0x01;
	EPD_sendCmdData(0x10, &reg10_data, sizeof(reg10_data)); //EPD_CMD_SLEEP
	}

	ets_delay_us(100*1000);

	return 0;
}

int EPD_refresh()
{
	u32 sleep_usec = 200ul*1000*1000;

	u8 reg12_data = 0x00;
	EPD_sendCmdData(0x12, &reg12_data, sizeof(reg12_data)); //EPD_CMD_UPDATE_CNTL2

    ets_delay_us(300*1000);

    ESP_LOGI(TAG, "BUSY = %d", gpio_get_level(EPD_PIN_BUSY));
	if(gpio_get_level(EPD_PIN_BUSY) == 0)
	{
        //ets_delay_us(sleep_usec);

		ets_delay_us(1000*1000);
        ESP_LOGI(TAG, "BUSY = %d", gpio_get_level(EPD_PIN_BUSY));
		if(gpio_get_level(EPD_PIN_BUSY) == 0)
		{
			ets_delay_us(1000);

			return -1;
		}
        ESP_LOGI(TAG, "D DONE");
	}
	else
	{
		/* refresh failed */
		ets_delay_us(1000*1000);
		return -1;
	}

	ets_delay_us(100*1000);

	{
	u8 reg02_data = 0x00;
	EPD_sendCmdData(0x02, &reg02_data, sizeof(reg02_data)); //EPD_CMD_SLEEP
	}

	ets_delay_us(100*1000);

	return 0;
}

unsigned char Color_get(unsigned char color)
{
	switch(color & 0x03) //color
	{
		case 0x00:
			return white;	
         break;		
		case 0x01:
			return yellow;
		  break;
		case 0x02:
			return red;
		  break;		
		case 0x03:
			return black;
		  break;			
        default:
            return white;
          break;			
	}
}

void Img_display(const unsigned char* ImgData)
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

void app_main(void)
{
    ESP_LOGI(TAG, "EPD GPIO INIT");
    EPD_PIN_INIT();

    ESP_LOGI(TAG, "SPI GPIO INIT");
    EPD_SPI_PIN();

    gpio_set_level(EPD_PIN_RST, 0);
    ets_delay_us(30*1000);

    gpio_set_level(EPD_PIN_RST, 1);
    gpio_set_level(EPD_PIN_CS, 1);
    ets_delay_us(20*1000);

    gpio_set_level(EPD_PIN_RST, 0);
    ets_delay_us(20*1000);

    gpio_set_level(EPD_PIN_RST, 1);
    ets_delay_us(20*1000);

    ets_delay_us(100*1000);

    EPD_WaitBusy();   

    ets_delay_us(20*1000);

    EPD_DRIVER();
/* 
    EPD_sendStart(0); //Black & White


   u8 *buffer = &gRamBuffer[0];
   s32 i;
   EPD_TEST
    for(i = 0; i < EPD_WIDTH; i++)
    {
        memset(buffer, EPD_COLOR_YELLOW, width+1);
        if(i==0)
        {
            buffer[0] = 0xD5;
        }
     
        EPD_send(buffer, width+1, 0);
    }
*/
    Img_display(Image_generate);

    ESP_LOGI(TAG, "BUSY = %d", gpio_get_level(EPD_PIN_BUSY));

    if(EPD_refresh() < 0 )
        ESP_LOGI(TAG, "EPD FAIL");
    else
        ESP_LOGI(TAG, "EPD SUCCESS");

    ble_epd_init();
}
