ifneq ($(filter stm32mp2, $(SOC_FAMILY)),)
ifneq ($(strip $(BOARD_TEEFSIMAGE_PARTITION_SIZE)),)

TARGET_OUT_TEEFS_IMG_PATH := $(PRODUCT_OUT)/teefs
INSTALLED_TEEFSIMAGE_TARGET := $(PRODUCT_OUT)/teefs.img

$(INSTALLED_TEEFSIMAGE_TARGET): $(MKF2FSUSERIMG) $(SELINUX_FC)
	@mkdir -p $(TARGET_OUT_TEEFS_IMG_PATH)
	$(hide) PATH=$(HOST_OUT_EXECUTABLES):$${PATH} $(MKF2FSUSERIMG) $@ $(BOARD_TEEFSIMAGE_PARTITION_SIZE) -S -f $(TARGET_OUT_TEEFS_IMG_PATH) -D $(PRODUCT_OUT)/system -s $(SELINUX_FC) -t /mnt/vendor/teefs -L teefs --prjquota --casefold
	$(hide) chmod a+r $@

.PHONY: teefsimage
teefsimage: $(INSTALLED_TEEFSIMAGE_TARGET)

droidcore: $(INSTALLED_TEEFSIMAGE_TARGET)

endif
endif
