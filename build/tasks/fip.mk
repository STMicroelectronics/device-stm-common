ifneq ($(filter stm32mp2, $(SOC_FAMILY)),)
ifneq ($(TARGET_NO_FIPIMAGE), true)

FIP_PROG := ${HOST_OUT}/bin/fiptool

.PHONY: fip.img

fip.img: fiptool ddr-pmu.bin fw-config.dtb soc-fw-config.dtb u-boot-nodtb.bin u-boot.dtb bl31.bin tee-pageable_v2.bin tee-pager_v2.bin tee-header_v2.bin
	$(FIP_PROG) create \
		--ddr-fw $(PRODUCT_OUT)/ddr-pmu.bin \
		--fw-config $(PRODUCT_OUT)/fw-config.dtb \
		--hw-config $(PRODUCT_OUT)/u-boot.dtb \
		--nt-fw $(PRODUCT_OUT)/u-boot-nodtb.bin \
		--soc-fw $(PRODUCT_OUT)/bl31.bin \
		--soc-fw-config $(PRODUCT_OUT)/soc-fw-config.dtb \
		--tos-fw $(PRODUCT_OUT)/tee-header_v2.bin \
		--tos-fw-extra1 $(PRODUCT_OUT)/tee-pager_v2.bin \
		--tos-fw-extra2 $(PRODUCT_OUT)/tee-pageable_v2.bin \
		$(PRODUCT_OUT)/$@

droidcore: fip.img

endif
endif
