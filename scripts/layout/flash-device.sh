#!/bin/bash
#
# Flash images in two steps : DFU mode, and then fastboot mode

# Copyright (C)  2019. STMicroelectronics
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

#######################################
# Constants
#######################################
SCRIPT_VERSION="1.1"

SOC_FAMILY="stm32mp1"

if [[ -n "${ANDROID_BUILD_TOP+1}" ]]; then
  COMMON_PATH=${ANDROID_BUILD_TOP}/device/stm/${SOC_FAMILY}
elif [ -d "device/stm/${SOC_FAMILY}" ]; then
  COMMON_PATH=${PWD}/device/stm/${SOC_FAMILY}
else
  echo "ERROR: ANDROID_BUILD_TOP env variable not defined, this script shall be executed on TOP directory"
  exit 1
fi

DEFAULT_LAYOUT_CONFIG=${COMMON_PATH}/layout/android_layout.config

#######################################
# Variables
#######################################
layout_config=${DEFAULT_LAYOUT_CONFIG}
flash_dfu=1
flash_fastboot=1
do_wrapped=0
memory_type=""

#######################################
# Functions
#######################################

#######################################
# Add empty line in stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
empty_line()
{
  echo
}

#######################################
# Print script usage on stdout
# Globals:
#   I layout_config
# Arguments:
#   None
# Returns:
#   None
#######################################
usage()
{
  echo "Usage: $(basename $0) [Options]"
  empty_line
  echo "  This script allows flashing images into the board through DFU and then Fastboot"
  echo "  based on configuration file ${layout_config}"
  empty_line
  echo "Options:"
  echo "  -h / --help: print this message"
  echo "  -v / --version: get script version"
  echo "  -d / --dfu: ONLY flash partition through DFU"
  echo "  -f / --fastboot: ONLY flash partition through fastboot"
  echo "  -g / --gdb: wrap fsbl image for debug purpose (required for GDB/OpenOCD)"
  echo "  -c <config file> / --config=<config file>: select configuration file (default: ${layout_config})"
  empty_line
}

#######################################
# Print error message in red on stderr
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
error()
{
  echo "$(tput setaf 1)ERROR: $1$(tput sgr0)"  >&2
}

#######################################
# Main
#######################################

# Check that the current script is not sourced
if [[ "$0" != "$BASH_SOURCE" ]]; then
  empty_line
  error "This script shall not be sourced"
  empty_line
  usage
  \popd >/dev/null 2>&1
  return
fi

# check the options
while getopts "hvdfgc:-:" option; do
  case "${option}" in
    -)
      # Treat long options
      case "${OPTARG}" in
        help)
          usage
          exit 0
          ;;
        version)
          echo "`basename $0` version ${SCRIPT_VERSION}"
          exit 0
          ;;
        dfu)
          flash_fastboot=0
          ;;
        fastboot)
          flash_dfu=0
          ;;
        gdb)
          if [ ${TARGET_BUILD_VARIANT} == "user" ]; then
            error "GDB option not compatible with user build"
            exit 1
          fi
          do_wrapped=1
          ;;
        config=*)
          layout_config="${OPTARG#*=}"
          ;;
        *)
          usage
          exit 1
          ;;
      esac;;
    # Treat short options
    h)
      usage
      exit 0
      ;;
    v)
      echo "`basename $0` version ${SCRIPT_VERSION}"
      exit 0
      ;;
    d)
      flash_fastboot=0
      ;;
    f)
      flash_dfu=0
      ;;
    g)
      if [ ${TARGET_BUILD_VARIANT} == "user" ]; then
        error "GDB option not compatible with user build"
        exit 1
      fi
      do_wrapped=1
      ;;
    c)
      layout_config="$OPTARG"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

if [ $# -gt 0 ]; then
  error "Unknown command : $*"
  usage
  exit 1
fi

if test ${flash_fastboot} -eq 1; then
  if [ ! -f "${layout_config}" ]; then
    error "${layout_config} file doesn't exist"
    exit 1
  fi
fi

#Get the memory type from layout config
memory_type=($(grep "PART_MEMORY_TYPE" ${layout_config} | awk '{ print $2 }'))

# Be in the folder where images are located
\pushd ${ANDROID_PRODUCT_OUT} >/dev/null 2>&1

if test ${flash_dfu} -eq 1; then
  # Check if STM32_Programmer_CLI is available in the $PATH
  cube_path=`which STM32_Programmer_CLI`
  if [ ! -x "${cube_path}" ]; then
    error "STM32_Programmer_CLI not found in the PATH"
    echo "Please install STM32CubeProgrammer : "
    echo "https://wiki.st.com/stm32mpu/wiki/STM32CubeProgrammer#Installing_the_STM32CubeProgrammer_tool"
    \popd >/dev/null 2>&1
    exit 1
  fi

  STM32_Programmer_CLI -l usb > /tmp/stm32_programmer_result
  usb_dfu=$(cat /tmp/stm32_programmer_result | grep "Device Index" | awk '{ print $5 }')
  \rm -f /tmp/stm32_programmer_result
  if [ ! ${usb_dfu} ]; then
    error "USB DFU device not found"
    echo "Check that USB cable is plugged and board is well configured in DFU"
    \popd >/dev/null 2>&1
    exit 1
  fi

  #Get tsv list for the current memory type configuration
  tsv_list=$(find ${COMMON_PATH}/layout/programmer -name "*.tsv" | grep -v "emmc_clear" | grep "$memory_type" | awk -F"/" '{print $NF}')
  options=($tsv_list)

  if [[ ${#options[@]} -eq 1 ]];then
    echo "Layout config ${options[0]} selected"
    selected_tsv=${options[0]}
  else
    PS3='Which layout do you want to flash ?'
    select opt in "${options[@]}"
    do
      selected_tsv=$opt
      break
    done
  fi

  if test ${do_wrapped} -eq 1; then
    wrapped_tsv="${selected_tsv%.tsv}"
    wrapped_tsv+="-wrapped.tsv"
    if [[ ${selected_tsv} =~ "optee" ]]; then
      \rm -f fsbl-optee-wrapped.img
      \stm32wrapper4dbg -s fsbl-optee.img -d fsbl-optee-wrapped.img
      \sed 's/fsbl-optee.img/fsbl-optee-wrapped.img/g' ${COMMON_PATH}/layout/programmer/${selected_tsv} > ${COMMON_PATH}/layout/programmer/${wrapped_tsv}
    elif [[ ${selected_tsv} =~ "trusted" ]]; then
      \rm -f fsbl-trusted-wrapped.img
      \stm32wrapper4dbg -s fsbl-trusted.img -d fsbl-trusted-wrapped.img
      \sed 's/fsbl-trusted.img/fsbl-trusted-wrapped.img/g' ${COMMON_PATH}/layout/programmer/${selected_tsv} > ${COMMON_PATH}/layout/programmer/${wrapped_tsv}
    else
      error "Unknown boot mode for ${selected_tsv}"
      \popd >/dev/null 2>&1
      exit 1
    fi
    \STM32_Programmer_CLI -c port=${usb_dfu} -w ${COMMON_PATH}/layout/programmer/${wrapped_tsv}
    \rm -f ${COMMON_PATH}/layout/programmer/${wrapped_tsv}
  else
    \STM32_Programmer_CLI -c port=${usb_dfu} -w ${COMMON_PATH}/layout/programmer/${selected_tsv}
  fi
fi

if test ${flash_fastboot} -eq 1; then
  if test $(basename ${ANDROID_PRODUCT_OUT}) == "disco"; then
    fastboot_helper="(long press on USER2 button after reset)"
  elif test $(basename ${ANDROID_PRODUCT_OUT}) == "eval"; then
    fastboot_helper="(long press on PA13 button after reset)"
  else
    fastboot_helper=""
  fi

  empty_line
  echo "$(tput bold)Change boot mode from DFU to normal boot ($memory_type), and select fastboot$(tput sgr0)" ${fastboot_helper}
  provision-device -c ${layout_config} -y
fi

\popd >/dev/null 2>&1
