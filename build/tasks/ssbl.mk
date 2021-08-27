ifneq ($(filter stm32mp1, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_SSBLIMAGE), true)

ifeq ($(TARGET_PREBUILT_SBL),)
$(error TARGET_PREBUILT_SBL not defined)
endif

ifeq ($(SOC_VERSION),)
$(error SOC_VERSION not defined)
endif

ifeq ($(BOARD_FLAVOUR),)
$(error BOARD_FLAVOUR not defined)
endif

ifeq ($(BOARD_DISK_TYPE),)
$(error BOARD_DISK_TYPE not defined)
endif

ifeq ($(BOARD_DISPLAY_PANEL), mb1230)
SSBL_TRUSTED_BIN := $(TARGET_PREBUILT_SBL)/u-boot-$(SOC_VERSION)-$(BOARD_FLAVOUR)-trusted-fb$(BOARD_DISK_TYPE).stm32
else
SSBL_TRUSTED_BIN := $(TARGET_PREBUILT_SBL)/u-boot-$(SOC_VERSION)-$(BOARD_FLAVOUR)-$(BOARD_DISPLAY_PANEL)-trusted-fb$(BOARD_DISK_TYPE).stm32
endif

SSBL_PROG := $(TARGET_PREBUILT_SBL)/u-boot-$(SOC_VERSION)-$(BOARD_FLAVOUR)-programmer.stm32

.PHONY: ssbl.img

ssbl.img:
	$(ACP) -fp $(SSBL_TRUSTED_BIN) $(PRODUCT_OUT)/ssbl-trusted-fb$(BOARD_DISK_TYPE).img
	$(ACP) -fp $(SSBL_PROG) $(PRODUCT_OUT)/ssbl-programmer.img

droidcore: ssbl.img

endif
endif
