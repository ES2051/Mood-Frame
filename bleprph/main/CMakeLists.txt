set(srcs "main.c"
          "gatt_svr.c"
          "epd.c")

idf_component_register(SRCS "${srcs}"
                       INCLUDE_DIRS ".")
