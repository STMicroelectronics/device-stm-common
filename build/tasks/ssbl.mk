ifneq ($(filter stm32mp2, $(SOC_FAMILY)),)
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

SSBL_TRUSTED_BIN := $(TARGET_PREBUILT_SBL)/u-boot-nodtb-trusted-fb$(BOARD_DISK_TYPE).bin
SSBL_TRUSTED_DTB := $(TARGET_PREBUILT_SBL)/u-boot-$(SOC_VERSION)-$(BOARD_FLAVOUR)-trusted-fb$(BOARD_DISK_TYPE).dtb

SSBL_PROG := $(TARGET_PREBUILT_SBL)/u-boot-$(SOC_VERSION)-$(BOARD_FLAVOUR)-programmer.stm32

.PHONY: u-boot-nodtb.bin u-boot.dtb ssbl-programmer.img

u-boot-nodtb.bin:
	$(ACP) -fp $(SSBL_TRUSTED_BIN) $(PRODUCT_OUT)/$@

u-boot.dtb:
	$(ACP) -fp $(SSBL_TRUSTED_DTB) $(PRODUCT_OUT)/$@

ssbl-programmer.img:
	$(ACP) -fp $(SSBL_PROG) $(PRODUCT_OUT)/$@

droidcore: u-boot-nodtb.bin u-boot.dtb ssbl-programmer.img

endif
endif
