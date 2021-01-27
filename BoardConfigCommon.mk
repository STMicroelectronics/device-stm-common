#
# Copyright 2015 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# ARM device
TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv7-a-neon
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := cortex-a7

TARGET_2ND_ARCH :=
TARGET_2ND_ARCH_VARIANT :=
TARGET_2ND_CPU_ABI :=
TARGET_2ND_CPU_ABI2 :=
TARGET_2ND_CPU_VARIANT :=

BOARD_SEPOLICY_DIRS += device/stm/stm32mp1/sepolicy
PRODUCT_PRIVATE_SEPOLICY_DIRS += device/stm/stm32mp1/sepolicy/product/private

# =========================================================== #
# PREBUILT configuration                                      #
# =========================================================== #

# Path for Linux kernel files
TARGET_PREBUILT_KERNEL := device/stm/stm32mp1-kernel/prebuilt
TARGET_PREBUILT_MODULE_PATH := device/stm/stm32mp1-kernel/prebuilt/modules
TARGET_PREBUILT_DTB_PATH := device/stm/stm32mp1-kernel/prebuilt/dts

# Path for primary (TF-A) and secondary (U-Boot) bootloader files
TARGET_PREBUILT_PBL := device/stm/stm32mp1-bootloader/prebuilt/fsbl/$(SOC_VERSION)-$(BOARD_FLAVOUR)
TARGET_PREBUILT_SBL := device/stm/stm32mp1-bootloader/prebuilt/ssbl/$(SOC_VERSION)-$(BOARD_FLAVOUR)

# Path for splash screen image (U-Boot)
TARGET_SPLASH_BMP := device/stm/stm32mp1/splash/stmicroelectronics.bmp

# Path for OP-TEE OS files
TARGET_PREBUILT_TEE := device/stm/stm32mp1-tee/prebuilt/$(SOC_VERSION)-$(BOARD_FLAVOUR)/optee_os

# Path to misc.img (boot control) which can be re-generated using miscgen
TARGET_PREBUILT_MISC := device/stm/stm32mp1/misc.img

# Path to teefs.img (OP-TEE encrypted file system, fixed to 128MB)
TARGET_PREBUILT_TEEFS := device/stm/stm32mp1/teefs.img

# ================= #
# TEE configuration #
# ================= #
BUILD_OPTEE_MK=device/stm/stm32mp1-tee/optee.mk

# Use dedicated partition
CFG_TEE_FS_PARENT_PATH=/mnt/vendor/teefs/optee
BOARD_ROOT_EXTRA_SYMLINKS += /mnt/vendor/teefs:/teefs
