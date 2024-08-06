ifneq ($(filter stm32mp2, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_TEEIMAGE), true)

ifeq ($(TARGET_PREBUILT_TEE),)
$(error TARGET_PREBUILT_TEE not defined)
endif

ifeq ($(SOC_VERSION),)
$(error SOC_VERSION not defined)
endif

ifeq ($(BOARD_FLAVOUR),)
$(error BOARD_FLAVOUR not defined)
endif

OPTEE_HEADER := $(TARGET_PREBUILT_TEE)/tee-header_v2-$(SOC_VERSION)-$(BOARD_FLAVOUR).bin
OPTEE_PAGEABLE := $(TARGET_PREBUILT_TEE)/tee-pageable_v2-$(SOC_VERSION)-$(BOARD_FLAVOUR).bin
OPTEE_PAGER := $(TARGET_PREBUILT_TEE)/tee-pager_v2-$(SOC_VERSION)-$(BOARD_FLAVOUR).bin

.PHONY: tee-pageable_v2.bin tee-pager_v2.bin tee-header_v2.bin

tee-pageable_v2.bin:
	$(ACP) -fp $(OPTEE_PAGEABLE) $(PRODUCT_OUT)/$@

tee-pager_v2.bin:
	$(ACP) -fp $(OPTEE_PAGER) $(PRODUCT_OUT)/$@

tee-header_v2.bin:
	$(ACP) -fp $(OPTEE_HEADER) $(PRODUCT_OUT)/$@

droidcore: tee-pageable_v2.bin tee-pager_v2.bin tee-header_v2.bin

endif
endif
