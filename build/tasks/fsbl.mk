ifneq ($(filter stm32mp1, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_FSBLIMAGE), true)

ifeq ($(TARGET_PREBUILT_PBL),)
$(error TARGET_PREBUILT_PBL not defined)
endif

ifeq ($(SOC_VERSION),)
$(error SOC_VERSION not defined)
endif

ifeq ($(BOARD_FLAVOUR),)
$(error BOARD_FLAVOUR not defined)
endif

FSBL_TRUSTED_BIN := $(TARGET_PREBUILT_PBL)/tf-a-$(SOC_VERSION)-$(BOARD_FLAVOUR)-trusted.stm32
FSBL_OPTEE_BIN := $(TARGET_PREBUILT_PBL)/tf-a-$(SOC_VERSION)-$(BOARD_FLAVOUR)-optee.stm32
FSBL_PROG := $(TARGET_PREBUILT_PBL)/tf-a-$(SOC_VERSION)-$(BOARD_FLAVOUR)-programmer.stm32

.PHONY: $(PRODUCT_OUT)/fsbl.img

$(PRODUCT_OUT)/fsbl.img:
	$(ACP) -fp $(FSBL_TRUSTED_BIN) $(PRODUCT_OUT)/fsbl-trusted.img
	$(ACP) -fp $(FSBL_OPTEE_BIN) $(PRODUCT_OUT)/fsbl-optee.img
	$(ACP) -fp $(FSBL_PROG) $(PRODUCT_OUT)/fsbl-programmer.img

droidcore: $(PRODUCT_OUT)/fsbl.img

endif
endif