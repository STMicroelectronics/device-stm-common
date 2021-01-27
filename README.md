# stm32mp1 #

This module is used to configure the STM32MP1 distribution for Android.
It is part of the STMicroelectronics delivery for Android (see the [delivery][] for more information).

[delivery]: https://wiki.st.com/stm32mpu/wiki/STM32MP15_distribution_for_Android_release_note_-_v2.0.0

## Description ##

This module version is the updated version for STM32MP15 distribution for Android V2.0
Please see the release notes for more details.

## Documentation ##

* The [release notes][] provide information on the release.
* The [distribution package][] provides detailed information on how to use this delivery.

[release notes]: https://wiki.st.com/stm32mpu/wiki/STM32MP15_distribution_for_Android_release_note_-_v2.0.0
[distribution package]: https://wiki.st.com/stm32mpu/wiki/STM32MP1_Distribution_Package_for_Android

## Dependencies ##

This module can't be used alone. It is part of the STMicroelectronics delivery for Android.

## Containing ##

This module contains several files and directories used to compile and configure the STM32MPU distribution for Android.

**Boards**
* `./eval`: STM32MP15 Evaluation boards configuraton (read following [README](./eval/README.md) file for more details)

**Common Makefiles**
* `BoardConfigCommon.mk`: common STM32MP1 board configuration makefile
* `./build/dt.mk`: makefile used to generate dt partition image (including device tree)
* `./build/fsbl.mk`: makefile used to generate fsbl partition image (including the primary bootloader)
* `./build/ssbl.mk`: makefile used to generate ssbl partition image (including the secondary bootloader)
* `./build/misc.mk`: makefile used to generate misc partition image (built using bootcontrol dedicated tool)
* `./build/splash.mk`: makefile used to generate splash partition image (including spash screen bitmap)
* `./build/tee.mk`: makefile used to generate tee partitions images (including the tee OS)
* `./build/teefs.mk`: makefile used to generate an empty F2FS partition image (tee secure storage usage)
* `./kernel.mk`: makefile used to includes kernel modules in vendor partition image

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
* `./scripts/prebuilt/update_prebuilt.sh`: script to update prebuilt images for kernel, bootloader and tee
* `./scripts/setup/stm32mp1setup.sh`: script to setup Android distribution for STM32MP1
* `./scripts/setup/stm32mp1clear.sh`: script to clear STM32MP1 setup for Android
* `./scripts/setup/bspsetup.sh`: script to setup Android distribution for STM32MP1 BSP (ex: kernel, bootloader...)
* `./scripts/setup/bspclear.sh`: script to clear STM32MP1 setup BSP (ex: kernel, bootloader...) for Android
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
* `./core/initprop`: initprop source code (used to initialize proprietary properties)
* `./core/miscgen`: miscgen source code (used to generate misc raw partition image)
* `./core/devmem`: devmem source code (used for debug purpose)
* `./splash/stmicroelectronics.bmp`: splash screen bitmap

**Periherals**
* `./peripheral/allocator`: allocator HAL header files (read following [README](./peripheral/allocator/README.md) file for more details)
* `./peripheral/audio`: audio primary HAL source code (read following [README](./peripheral/audio/README.md) file for more details)
* `./peripheral/camera`: camera HAL source code (read following [README](./peripheral/camera/README.md) file for more details)
* `./peripheral/composer`: composer HAL source code (read following [README](./peripheral/composer/README.md) file for more details)
* `./peripheral/copro`: proprietary copro hardware service source code (read following [README](./peripheral/copro/README.md) file for more details)
* `./peripheral/health`: health hardware service source code (read following [README](./peripheral/health/README.md) file for more details)
* `./peripheral/lights`: light HAL source code (read following [README](./peripheral/lights/README.md) file for more details)
* `./peripheral/memtrack`: memtrack HAL source code (read following [README](./peripheral/memtrack/README.md) file for more details)
* `./peripheral/oemlock`: oemlock HAL source code (stub) (read following [README](./peripheral/oemlock/README.md) file for more details)
* `./peripheral/thermal`: thermal hardware service source code (read following [README](./peripheral/thermal/README.md) file for more details)
* `./peripheral/usb`: usb hardware service source code (read following [README](./peripheral/usb/README.md) file for more details)
* `./peripheral/wifi`: wifi HAL library source code (read following [README](./peripheral/wifi/README.md) file for more details)

**Sepolicy**
* `./sepolicy`: sepolicy for STM32MP1

**Tee**
* `./kmgk`: keymaster and gatekeeper source code (including OP-TEE Trust Applications)
* `./optee_client`: OP-TEE libraries source code
* `./optee_test`: OP-TEE test source code

## License ##

This module is distributed under the Apache License, Version 2.0 found in the [LICENSE](./LICENSE) file.
