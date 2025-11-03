ifneq ($(filter stm32mp2, $(SOC_FAMILY)),)

ifeq ($(TARGET_PREBUILT_TOOLS),)
$(error TARGET_PREBUILT_TOOLS not defined)
endif

FIP_DDR_PROG_IMG := $(TARGET_PREBUILT_TOOLS)/programmer/$(SOC_VERSION)-$(BOARD_FLAVOUR)/fip-ddr-programmer.img
FSBLA_PROG_IMG := $(TARGET_PREBUILT_TOOLS)/programmer/$(SOC_VERSION)-$(BOARD_FLAVOUR)/fsbla-programmer.img
FIP_PROG_IMG := $(TARGET_PREBUILT_TOOLS)/programmer/$(SOC_VERSION)-$(BOARD_FLAVOUR)/fip-programmer.img

.PHONY: fsbla-programmer.img fip-programmer.img fip-ddr-programmer.img

fip-ddr-programmer.img:
	$(ACP) -fp $(FIP_DDR_PROG_IMG) $(PRODUCT_OUT)/$@

fsbla-programmer.img:
	$(ACP) -fp $(FSBLA_PROG_IMG) $(PRODUCT_OUT)/$@

fip-programmer.img:
	$(ACP) -fp $(FIP_PROG_IMG) $(PRODUCT_OUT)/$@

droidcore: fsbla-programmer.img fip-programmer.img fip-ddr-programmer.img

endif
