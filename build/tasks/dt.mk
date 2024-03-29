ifneq ($(filter stm32mp1, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_DTIMAGE), true)

MKDTIMG := prebuilts/misc/linux-x86/libufdt/mkdtimg

ifeq ($(BOARD_DISPLAY_PANEL), mb1230)
DTB0 := $(TARGET_PREBUILT_DTB_PATH)/$(SOC_VERSION)-$(BOARD_FLAVOUR)/$(SOC_VERSION)-$(BOARD_FLAVOUR).dtb
else
DTB0 := $(TARGET_PREBUILT_DTB_PATH)/$(SOC_VERSION)-$(BOARD_FLAVOUR)/$(SOC_VERSION)-$(BOARD_FLAVOUR)-$(BOARD_DISPLAY_PANEL).dtb
endif

BOARDID0 := 0x1263
BOARDREV0 := 0xC

.PHONY: dt.img

dt.img: $(DTB0)
	$(MKDTIMG) create $(PRODUCT_OUT)/$@ --id=/:board_id \
		$(DTB0) --id=$(BOARDID0) --rev=$(BOARDREV0)

droidcore: dt.img

endif
endif
