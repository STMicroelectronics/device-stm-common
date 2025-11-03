ifneq ($(filter stm32mp2, $(SOC_FAMILY)),)
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

ifeq ($(BOARD_FLAVOUR),dk)
FSBL_DDR_FW := $(TARGET_PREBUILT_DDR)/lpddr4_pmu_train.bin
else
FSBL_DDR_FW := $(TARGET_PREBUILT_DDR)/ddr4_pmu_train.bin
endif

FSBL_SOC_FW_CONFIG := $(TARGET_PREBUILT_PBL)/dtb/$(SOC_VERSION)-$(BOARD_FLAVOUR)-bl31.dtb
BL31_BIN:= $(TARGET_PREBUILT_PBL)/tf-a-$(SOC_VERSION)-$(BOARD_FLAVOUR)-optee-bl31.bin
FSBL_OPTEE_BIN := $(TARGET_PREBUILT_PBL)/tf-a-$(SOC_VERSION)-$(BOARD_FLAVOUR)-optee.stm32
FSBL_OPTEE_FW_CONFIG := $(TARGET_PREBUILT_PBL)/tf-a-$(SOC_VERSION)-$(BOARD_FLAVOUR)-optee-fw-config.dtb

.PHONY: fsbl.img fw-config.dtb soc-fw-config.dtb ddr-pmu.bin bl31.bin

fsbl.img:
	$(ACP) -fp $(FSBL_OPTEE_BIN) $(PRODUCT_OUT)/fsbl-optee.img

fw-config.dtb:
	$(ACP) -fp $(FSBL_OPTEE_FW_CONFIG) $(PRODUCT_OUT)/$@

soc-fw-config.dtb:
	$(ACP) -fp $(FSBL_SOC_FW_CONFIG) $(PRODUCT_OUT)/$@

ddr-pmu.bin:
	$(ACP) -fp $(FSBL_DDR_FW) $(PRODUCT_OUT)/$@

bl31.bin:
	$(ACP) -fp $(BL31_BIN) $(PRODUCT_OUT)/$@

droidcore: fsbl.img fw-config.dtb ddr-pmu.bin bl31.bin

endif
endif
