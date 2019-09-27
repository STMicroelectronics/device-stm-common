ifneq ($(filter stm32mp1, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_SPLASHIMAGE), true)

ifeq ($(TARGET_SPLASH_BMP),)
$(error TARGET_SPLASH_BMP not defined)
endif

.PHONY: $(PRODUCT_OUT)/splash.img

$(PRODUCT_OUT)/splash.img:
	$(ACP) -fp $(TARGET_SPLASH_BMP) $@

droidcore: $(PRODUCT_OUT)/splash.img

endif
endif
