#
# Copyright 2013 The Android Open Source Project
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

#######################################
# Constants
#######################################
SCRIPT_VERSION="1.1"

# Check default version: grep ClangDefaultVersion build/soong/cc/config/global.go
CLANG_VERSION=r383902b

#######################################
# Functions
#######################################

#######################################
# Print warning message in orange on stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
warning_top()
{
  echo "$(tput setaf 3)WARNING: $1$(tput sgr0)"
}

#######################################
# Main
#######################################

PATH_CONFIG_FILE_NAME="path.config"
PATH_CONFIG_FILE=$(gettop)/device/stm/stm32mp1/configs/${PATH_CONFIG_FILE_NAME}

if [ ! -f ${PATH_CONFIG_FILE} ]; then
  \mkdir -p $(gettop)/device/stm/scripts
  \rm -rf $(gettop)/device/stm/scripts/*

  # add all useful scripts in PATH
  \ln -s $(gettop)/device/stm/stm32mp1-kernel/source/load_kernel.sh $(gettop)/device/stm/scripts/load_kernel
  \ln -s $(gettop)/device/stm/stm32mp1-kernel/source/build_kernel.sh $(gettop)/device/stm/scripts/build_kernel
  \ln -s $(gettop)/device/stm/stm32mp1-bootloader/source/load_bootloader.sh $(gettop)/device/stm/scripts/load_bootloader
  \ln -s $(gettop)/device/stm/stm32mp1-bootloader/source/build_bootloader.sh $(gettop)/device/stm/scripts/build_bootloader
  \ln -s $(gettop)/device/stm/stm32mp1-tee/source/load_tee.sh $(gettop)/device/stm/scripts/load_tee
  \ln -s $(gettop)/device/stm/stm32mp1-tee/source/build_tee.sh $(gettop)/device/stm/scripts/build_tee
  \ln -s $(gettop)/device/stm/stm32mp1-tee/source/build_ta.sh $(gettop)/device/stm/scripts/build_ta
  \ln -s $(gettop)/device/stm/stm32mp1-openocd/source/load_openocd.sh $(gettop)/device/stm/scripts/load_openocd
  \ln -s $(gettop)/device/stm/stm32mp1-openocd/source/build_openocd.sh $(gettop)/device/stm/scripts/build_openocd

  \ln -s $(gettop)/device/stm/stm32mp1/scripts/layout/flash-device.sh $(gettop)/device/stm/scripts/flash-device
  \ln -s $(gettop)/device/stm/stm32mp1/scripts/layout/clear-device.sh $(gettop)/device/stm/scripts/clear-device
  \ln -s $(gettop)/device/stm/stm32mp1/scripts/layout/format-device.sh $(gettop)/device/stm/scripts/format-device
  \ln -s $(gettop)/device/stm/stm32mp1/scripts/layout/provision-device.sh $(gettop)/device/stm/scripts/provision-device
  \ln -s $(gettop)/device/stm/stm32mp1/scripts/layout/create-disk.sh $(gettop)/device/stm/scripts/create-disk

  \ln -s $(gettop)/device/stm/stm32mp1/scripts/setup/stm32mp1setup.sh $(gettop)/device/stm/scripts/stm32mp1setup
  \ln -s $(gettop)/device/stm/stm32mp1/scripts/setup/stm32mp1clear.sh $(gettop)/device/stm/scripts/stm32mp1clear

  \ln -s $(gettop)/device/stm/stm32mp1/scripts/setup/bspsetup.sh $(gettop)/device/stm/scripts/bspsetup
  \ln -s $(gettop)/device/stm/stm32mp1/scripts/setup/bspclear.sh $(gettop)/device/stm/scripts/bspclear

  \ln -s $(gettop)/device/stm/stm32mp1/scripts/cache/cachesetup.sh $(gettop)/device/stm/scripts/cachesetup
  \ln -s $(gettop)/device/stm/stm32mp1/patch/applypatch.sh $(gettop)/device/stm/scripts/applypatch
  \ln -s $(gettop)/device/stm/stm32mp1/scripts/eula/load_eula.sh $(gettop)/device/stm/scripts/load_eula
  \ln -s $(gettop)/device/stm/stm32mp1/scripts/toolchain/load_toolchain.sh $(gettop)/device/stm/scripts/load_toolchain
  \ln -s $(gettop)/device/stm/stm32mp1/scripts/prebuilt/update_prebuilt.sh $(gettop)/device/stm/scripts/update_prebuilt
  \ln -s $(gettop)/device/stm/stm32mp1/scripts/starter/generate_starterpackage.sh $(gettop)/device/stm/scripts/generate_starter

  echo "PATH" > ${PATH_CONFIG_FILE}

fi

if [[ ${PATH} != *"$(gettop)/device/stm/scripts:"* ]]; then
  export PATH="$(gettop)/device/stm/scripts:$PATH"
fi

if [[ ${PATH} != *"$(gettop)/prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION}/bin:"* ]]; then
  export PATH="$(gettop)/prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION}/bin:$PATH"
fi

# initialize auto-completion (TODO: replace with smart auto-completion through function)
complete -W 'dtb gpu defaultconfig menuconfig modules modules_install mrproper vmlinux' build_kernel
complete -W 'clean' build_tee
complete -W 'clean distclean' build_openocd

echo "including device/stm/stm32mp1/scripts/layout/layoutsetup.sh"
source $(gettop)/device/stm/stm32mp1/scripts/layout/layoutsetup.sh

unset PATH_CONFIG_FILE
unset PATH_CONFIG_FILE_NAME
unset CLANG_VERSION
unset SCRIPT_VERSION
