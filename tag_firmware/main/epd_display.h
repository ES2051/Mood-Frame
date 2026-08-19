#ifndef EPD_DISPLAY_H
#define EPD_DISPLAY_H

#define EPD_WIDTH       250
#define EPD_HEIGHT      122
#define EPD_LINE_BYTES  32
#define EPD_IMAGE_SIZE  (EPD_WIDTH * EPD_LINE_BYTES)

void Img_display(const unsigned char *ImgData);
int EPD_refresh(void);

#endif /* EPD_DISPLAY_H */
