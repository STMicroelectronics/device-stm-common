# stm32mp2 #

This module is used to configure the STM32MP2 Embedded Software distribution for Android:tm:.
It is part of the STMicroelectronics delivery for Android.

## Description ##

This module version is the updated version for STM32MP25 OpenSTDroid V5.0
Please see the release notes for more details.

## Documentation ##

* The [release notes][] provide information on the release.
[release notes]: https://wiki.st.com/stm32mpu/wiki/STM32_MPU_OpenSTDroid_release_note_-_v5.1.0

## Dependencies ##

This module can't be used alone. It is part of the STMicroelectronics delivery for Android.

## Containing ##

This module contains several files and directories used to compile and configure the STM32MP2 Embedded Software distribution for Android.

**Boards**
* `./eval`: STM32MP25 EVAL board configuraton (read following [README](./eval/README.md) file for more details)

**Common Makefiles**
* `BoardConfigCommon.mk`: common STM32MP2 board configuration makefile
* `./build/tasks/dt.mk`: makefile used to generate dt partition image (including device tree)
* `./build/tasks/fip.mk`: makefile used to generate fip partition image (including the secondary bootloader and tee)
* `./build/tasks/fsbl.mk`: makefile used to generate fsbl partition image (including the primary bootloader)
* `./build/tasks/ssbl.mk`: makefile used to generate ssbl partition image (including the secondary bootloader)
* `./build/tasks/metadata.mk`: makefile used to generate metadata partition image
* `./build/tasks/misc.mk`: makefile used to generate misc partition image (built using bootcontrol dedicated tool)
* `./build/tasks/splash.mk`: makefile used to generate splash partition image (including spash screen bitmap)
* `./build/tasks/tee.mk`: makefile used to generate tee partitions images (including the tee OS)
* `./build/tasks/teefs.mk`: makefile used to generate an empty F2FS partition image (tee secure storage usage)

**Scripts**
* `vendorsetup.sh`: script executed automatically when execute `source ./build/envsetup.sh`
* `./scripts/cache/cachesetup.sh`: script used to setup git cache
* `./scripts/eula/load_eula.sh`: script used to load End User License Agreement dependent library
* `./scripts/layout/layoutsetup.sh`: script to set partition configuration based on android_layout.config
* `./scripts/layout/format-device.sh`: script used to format SD card based on android_layout.config
* `./scripts/layout/provision-device.sh`: script used to provision the device based on android_layout.config
* `./scripts/layout/clear-device.sh`: script used to clear eMMC partitions (with DFU connection)
* `./scripts/layout/create-disk.sh`: script used to generate an micro SD card disk image
* `./scripts/layout/flash-device.sh`: script to provision the device (with both DFU and FASTBOOT connections)
* `./scripts/layout/build_tsv.py`: Python script to generate STM32CubeProgrammer layout files based on android_layout.config
* `./scripts/setup/stm32mp2setup.sh`: script to setup Android distribution for STM32MP2
* `./scripts/setup/stm32mp2clear.sh`: script to clear STM32MP2 setup for Android
* `./scripts/setup/bspsetup.sh`: script to setup Android distribution for STM32MP2 BSP (ex: kernel, bootloader...)
* `./scripts/setup/bspclear.sh`: script to clear STM32MP2 setup BSP (ex: kernel, bootloader...) for Android
* `./scripts/starter/generate_starterpackage.sh`: script to generate starterpackage (based on starter.config file)
* `./scripts/toolchain/load_toolchain.sh`: script to load toolchain used for the BSP (ex: kernel, bootloader...)

**Patches**
* `./patch/applypatch.sh`: script to apply patches based on android_patch.config
* `./patch/android/*` : patches

**Configuration**
* `./layout/android_layout.config`: layout configuration file (used to format and provision device)
* `./layout/programmer/*`: layout configuration file (used to provision device with STMCubeProgrammer)
* `./configs/template.config`: template file used to generate local.config

**Core**
* `./core/miscgen`: miscgen source code (used to generate misc raw partition image)
* `./splash/stmicroelectronics.bmp`: splash screen bitmap

**Hardware**
* `./hardware/allocator`: allocator HAL header files (read following [README](./hardware/allocator/README.md) file for more details)
* `./hardware/audio`: audio primary HAL source code (read following [README](./hardware/audio/README.md) file for more details)
* `./hardware/camera`: camera HAL source code (read following [README](./hardware/camera/README.md) file for more details)
* `./hardware/composer`: composer HAL source code (read following [README](./hardware/composer/README.md) file for more details)
* `./hardware/health`: health hardware service source code (read following [README](./hardware/health/README.md) file for more details)
* `./hardware/lights`: light HAL source code (read following [README](./hardware/lights/README.md) file for more details)
* `./hardware/memtrack`: memtrack HAL source code (read following [README](./hardware/memtrack/README.md) file for more details)
* `./hardware/oemlock`: oemlock HAL source code (stub) (read following [README](./hardware/oemlock/README.md) file for more details)
* `./hardware/thermal`: thermal hardware service source code (read following [README](./hardware/thermal/README.md) file for more details)
* `./hardware/usb`: usb hardware service source code (read following [README](./hardware/usb/README.md) file for more details)
* `./hardware/wifi`: wifi HAL library source code (read following [README](./hardware/wifi/README.md) file for more details)

**Sepolicy**
* `./sepolicy`: sepolicy for STM32MP2

**Tee**
* `./kmgk`: keymaster and gatekeeper source code (including OP-TEE Trust Applications)
* `./optee_client`: OP-TEE libraries source code
* `./optee_test`: OP-TEE test source code

## License ##

This module is distributed under the Apache License, Version 2.0 found in the [LICENSE](./LICENSE) file.
