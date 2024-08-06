# Use this file to generate dtb.img and dtbo.img instead of using
# BOARD_PREBUILT_DTBIMAGE_DIR. We need to keep dtb and dtbo files at the fixed
# positions in images, so that bootloader can rely on their indexes in the
# image. As dtbo.img must be signed with AVB tool, we generate intermediate
# dtbo.img, and the resulting $(PRODUCT_OUT)/dtbo.img will be created with
# Android build system, by exploiting BOARD_PREBUILT_DTBOIMAGE variable.

ifneq ($(filter stm32mp2, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_DTIMAGE), true)

ifeq ($(BOARD_ID),)
$(error BOARD_ID not defined)
endif

ifeq ($(BOARD_REV),)
$(error BOARD_REV not defined)
endif

MKDTIMG := prebuilts/misc/linux-x86/libufdt/mkdtimg
DTBOIMAGE := $(PRODUCT_OUT)/$(DTBO_UNSIGNED)

DTBO0 := $(TARGET_PREBUILT_DTBO_PATH)/$(SOC_VERSION)-$(BOARD_FLAVOUR)/$(SOC_VERSION)-$(BOARD_FLAVOUR)-overlay.dtbo

ifeq ($(BOARD_REV_2),)
$(DTBOIMAGE): $(DTBO0)
	$(MKDTIMG) create $@ --id=/:board_id \
		$(DTBO0) --id=$(BOARD_ID) --rev=$(BOARD_REV)
else
$(DTBOIMAGE): $(DTBO0)
	$(MKDTIMG) create $@ --id=/:board_id \
		$(DTBO0) --id=$(BOARD_ID) --rev=$(BOARD_REV) \
		$(DTBO0) --id=$(BOARD_ID) --rev=$(BOARD_REV_2)
endif

include $(CLEAR_VARS)
LOCAL_MODULE := dtboimage
LOCAL_ADDITIONAL_DEPENDENCIES := $(DTBOIMAGE)
include $(BUILD_PHONY_PACKAGE)

droidcore: dtboimage

endif
endif
