#ifndef BLE_EPD_H
#define BLE_EPD_H

/* Starts advertising as "MoodFrame-EPD" and exposes a GATT service that
 * accepts an EPD_IMAGE_SIZE-byte image over BLE writes, then renders it. */
void ble_epd_init(void);

#endif /* BLE_EPD_H */
