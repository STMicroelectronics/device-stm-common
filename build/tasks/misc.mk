ifneq ($(filter stm32mp2, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_MISCIMAGE), true)

ifeq ($(TARGET_PREBUILT_MISC),)
$(error TARGET_PREBUILT_MISC not defined)
endif

.PHONY: misc.img

misc.img:
	$(ACP) -fp $(TARGET_PREBUILT_MISC) $(PRODUCT_OUT)/$@

droidcore: misc.img

endif
endif
