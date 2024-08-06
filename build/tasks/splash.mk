ifneq ($(filter stm32mp2, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_SPLASHIMAGE), true)

ifeq ($(TARGET_SPLASH_BMP),)
$(error TARGET_SPLASH_BMP not defined)
endif

.PHONY: splash.img

splash.img:
	$(ACP) -fp $(TARGET_SPLASH_BMP) $(PRODUCT_OUT)/$@

droidcore: splash.img

endif
endif
