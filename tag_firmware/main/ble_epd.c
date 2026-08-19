#include <string.h>

#include "esp_log.h"
#include "nvs_flash.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/util/util.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

#include "epd_display.h"
#include "ble_epd.h"

static const char *TAG = "BLE_EPD";

#define BLE_EPD_DEVICE_NAME "MoodFrame-EPD"

/* Service:            7a0247e0-4b3a-4bde-9e1f-1c9b6a4f9001
 * Image char (write):  7a0247e1-4b3a-4bde-9e1f-1c9b6a4f9002
 * Status char (notify): 7a0247e2-4b3a-4bde-9e1f-1c9b6a4f9003
 * These UUIDs must match Mood_frame/ble_epd.py exactly. */
static const ble_uuid128_t s_svc_uuid =
    BLE_UUID128_INIT(0x01, 0x90, 0x4f, 0x6a, 0x9b, 0x1c, 0x1f, 0x9e,
                      0xde, 0x4b, 0x3a, 0x4b, 0xe0, 0x47, 0x02, 0x7a);

static const ble_uuid128_t s_image_chr_uuid =
    BLE_UUID128_INIT(0x02, 0x90, 0x4f, 0x6a, 0x9b, 0x1c, 0x1f, 0x9e,
                      0xde, 0x4b, 0x3a, 0x4b, 0xe1, 0x47, 0x02, 0x7a);

static const ble_uuid128_t s_status_chr_uuid =
    BLE_UUID128_INIT(0x03, 0x90, 0x4f, 0x6a, 0x9b, 0x1c, 0x1f, 0x9e,
                      0xde, 0x4b, 0x3a, 0x4b, 0xe2, 0x47, 0x02, 0x7a);

static uint8_t s_own_addr_type;
static uint16_t s_conn_handle = BLE_HS_CONN_HANDLE_NONE;
static uint16_t s_status_chr_val_handle;

static uint8_t s_img_buf[EPD_IMAGE_SIZE];
static size_t s_img_recv_len = 0;

static TaskHandle_t s_render_task_handle;

static void ble_epd_advertise(void);

static int
gatt_access_image(uint16_t conn_handle, uint16_t attr_handle,
                   struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    if (ctxt->op != BLE_GATT_ACCESS_OP_WRITE_CHR) {
        return BLE_ATT_ERR_UNLIKELY;
    }

    uint16_t om_len = OS_MBUF_PKTLEN(ctxt->om);

    /* A fresh write starting past a prior partial frame means the client
     * (re)started a transfer -- resync on it rather than corrupt the buffer. */
    if (om_len > 0 && s_img_recv_len + om_len > EPD_IMAGE_SIZE) {
        s_img_recv_len = 0;
    }

    int rc = ble_hs_mbuf_to_flat(ctxt->om, &s_img_buf[s_img_recv_len], om_len, NULL);
    if (rc != 0) {
        return BLE_ATT_ERR_UNLIKELY;
    }
    s_img_recv_len += om_len;

    if (s_img_recv_len >= EPD_IMAGE_SIZE) {
        s_img_recv_len = 0;
        xTaskNotifyGive(s_render_task_handle);
    }

    return 0;
}

static int
gatt_access_status(uint16_t conn_handle, uint16_t attr_handle,
                    struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    static const uint8_t idle = 0;
    if (ctxt->op == BLE_GATT_ACCESS_OP_READ_CHR) {
        os_mbuf_append(ctxt->om, &idle, sizeof(idle));
        return 0;
    }
    return BLE_ATT_ERR_UNLIKELY;
}

static const struct ble_gatt_svc_def s_gatt_svcs[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &s_svc_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &s_image_chr_uuid.u,
                .access_cb = gatt_access_image,
                .flags = BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_WRITE_NO_RSP,
            },
            {
                .uuid = &s_status_chr_uuid.u,
                .access_cb = gatt_access_status,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY,
                .val_handle = &s_status_chr_val_handle,
            },
            { 0 },
        },
    },
    { 0 },
};

static void
epd_render_task(void *arg)
{
    for (;;) {
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);

        ESP_LOGI(TAG, "image received, rendering");
        Img_display(s_img_buf);
        int rc = EPD_refresh();
        ESP_LOGI(TAG, rc == 0 ? "render done" : "render failed");

        if (s_conn_handle != BLE_HS_CONN_HANDLE_NONE) {
            uint8_t status = (rc == 0) ? 1 : 2;
            struct os_mbuf *om = ble_hs_mbuf_from_flat(&status, sizeof(status));
            if (om != NULL) {
                ble_gatts_notify_custom(s_conn_handle, s_status_chr_val_handle, om);
            }
        }
    }
}

static int
ble_gap_event(struct ble_gap_event *event, void *arg)
{
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        if (event->connect.status == 0) {
            s_conn_handle = event->connect.conn_handle;
            ESP_LOGI(TAG, "client connected");
        } else {
            ble_epd_advertise();
        }
        return 0;

    case BLE_GAP_EVENT_DISCONNECT:
        ESP_LOGI(TAG, "client disconnected, resuming advertising");
        s_conn_handle = BLE_HS_CONN_HANDLE_NONE;
        s_img_recv_len = 0;
        ble_epd_advertise();
        return 0;

    case BLE_GAP_EVENT_ADV_COMPLETE:
        ble_epd_advertise();
        return 0;

    default:
        return 0;
    }
}

static void
ble_epd_advertise(void)
{
    struct ble_hs_adv_fields fields;
    struct ble_gap_adv_params adv_params;
    const char *name = ble_svc_gap_device_name();
    int rc;

    memset(&fields, 0, sizeof(fields));
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.name = (uint8_t *)name;
    fields.name_len = strlen(name);
    fields.name_is_complete = 1;
    fields.uuids128 = (ble_uuid128_t *)&s_svc_uuid;
    fields.num_uuids128 = 1;
    fields.uuids128_is_complete = 1;

    rc = ble_gap_adv_set_fields(&fields);
    if (rc != 0) {
        ESP_LOGE(TAG, "adv_set_fields failed: %d", rc);
        return;
    }

    memset(&adv_params, 0, sizeof(adv_params));
    adv_params.conn_mode = BLE_GAP_CONN_MODE_UND;
    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN;

    rc = ble_gap_adv_start(s_own_addr_type, NULL, BLE_HS_FOREVER, &adv_params,
                            ble_gap_event, NULL);
    if (rc != 0) {
        ESP_LOGE(TAG, "adv_start failed: %d", rc);
    }
}

static void
ble_on_sync(void)
{
    int rc = ble_hs_id_infer_auto(0, &s_own_addr_type);
    if (rc != 0) {
        ESP_LOGE(TAG, "id_infer_auto failed: %d", rc);
        return;
    }
    ble_epd_advertise();
}

static void
ble_on_reset(int reason)
{
    ESP_LOGW(TAG, "nimble host reset, reason=%d", reason);
}

static void
ble_host_task(void *param)
{
    nimble_port_run();
    nimble_port_freertos_deinit();
}

void
ble_epd_init(void)
{
    esp_err_t esp_rc = nvs_flash_init();
    if (esp_rc == ESP_ERR_NVS_NO_FREE_PAGES || esp_rc == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        esp_rc = nvs_flash_init();
    }
    ESP_ERROR_CHECK(esp_rc);

    xTaskCreate(epd_render_task, "epd_render", 4096, NULL, 5, &s_render_task_handle);

    ESP_ERROR_CHECK(nimble_port_init());

    ble_hs_cfg.reset_cb = ble_on_reset;
    ble_hs_cfg.sync_cb = ble_on_sync;

    ble_svc_gap_init();
    ble_svc_gatt_init();

    int rc = ble_gatts_count_cfg(s_gatt_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "gatts_count_cfg failed: %d", rc);
        return;
    }
    rc = ble_gatts_add_svcs(s_gatt_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "gatts_add_svcs failed: %d", rc);
        return;
    }

    rc = ble_svc_gap_device_name_set(BLE_EPD_DEVICE_NAME);
    if (rc != 0) {
        ESP_LOGE(TAG, "device_name_set failed: %d", rc);
        return;
    }

    nimble_port_freertos_init(ble_host_task);

    ESP_LOGI(TAG, "advertising as \"%s\"", BLE_EPD_DEVICE_NAME);
}
