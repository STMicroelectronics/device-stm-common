ifneq ($(filter stm32mp1, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_MISCIMAGE), true)

ifeq ($(TARGET_PREBUILT_MISC),)
$(error TARGET_PREBUILT_MISC not defined)
endif

$(PRODUCT_OUT)/misc.img:
	$(ACP) -fp $(TARGET_PREBUILT_MISC) $@

droidcore: $(PRODUCT_OUT)/misc.img

endif
endif
