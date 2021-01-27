ifneq ($(filter stm32mp1, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_TEEFSIMAGE), true)

TARGET_OUT_TEEFS_IMG_PATH := $(PRODUCT_OUT)/teefs

.PHONY: teefs.img

teefs.img: $(MKF2FSUSERIMG)
	@mkdir -p $(TARGET_OUT_TEEFS_IMG_PATH)
	$(hide) PATH=$(HOST_OUT_EXECUTABLES):$${PATH} $(MKF2FSUSERIMG) $(PRODUCT_OUT)/$@ $(BOARD_TEEFSIMAGE_PARTITION_SIZE) -S -f $(TARGET_OUT_TEEFS_IMG_PATH) -D $(PRODUCT_OUT)/system -s $(SELINUX_FC) -t /mnt/vendor/teefs -L teefs --prjquota --casefold

droidcore: teefs.img

endif
endif
