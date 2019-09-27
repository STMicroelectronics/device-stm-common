ifneq ($(filter stm32mp1, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_DTIMAGE), true)

MKDTIMG := prebuilts/misc/linux-x86/libufdt/mkdtimg

DTB0 := $(TARGET_PREBUILT_KERNEL)/dts/stm32mp157c-ev1.dtb
BOARDID0 := 0x1263
BOARDREV0 := 0xC

.PHONY: $(PRODUCT_OUT)/dt.img

$(PRODUCT_OUT)/dt.img: $(DTB0)
	$(MKDTIMG) create $@ --id=/:board_id \
		$(DTB0) --id=$(BOARDID0) --rev=$(BOARDREV0)

droidcore: $(PRODUCT_OUT)/dt.img

endif
endif
