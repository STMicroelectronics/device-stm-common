ifneq ($(filter stm32mp1, $(SOC_FAMILY)),)
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

OPTEE_HEADER := $(TARGET_PREBUILT_TEE)/tee-header_v2-$(SOC_VERSION)-$(BOARD_FLAVOUR).stm32
OPTEE_PAGEABLE := $(TARGET_PREBUILT_TEE)/tee-pageable_v2-$(SOC_VERSION)-$(BOARD_FLAVOUR).stm32
OPTEE_PAGER := $(TARGET_PREBUILT_TEE)/tee-pager_v2-$(SOC_VERSION)-$(BOARD_FLAVOUR).stm32

.PHONY: $(PRODUCT_OUT)/teed.img $(PRODUCT_OUT)/teex.img $(PRODUCT_OUT)/teeh.img

$(PRODUCT_OUT)/teed.img:
	$(ACP) -fp $(OPTEE_PAGEABLE) $@

$(PRODUCT_OUT)/teex.img:
	$(ACP) -fp $(OPTEE_PAGER) $@

$(PRODUCT_OUT)/teeh.img:
	$(ACP) -fp $(OPTEE_HEADER) $@

droidcore: $(PRODUCT_OUT)/teed.img $(PRODUCT_OUT)/teex.img $(PRODUCT_OUT)/teeh.img

endif
endif
