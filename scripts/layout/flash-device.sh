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
SCRIPT_VERSION="1.2"

SOC_FAMILY="stm32mp2"

if [[ -n "${ANDROID_BUILD_TOP+1}" ]]; then
  COMMON_PATH=${ANDROID_BUILD_TOP}/device/stm/${SOC_FAMILY}
elif [ -d "device/stm/${SOC_FAMILY}" ]; then
  COMMON_PATH=${PWD}/device/stm/${SOC_FAMILY}
else
  echo "ERROR: ANDROID_BUILD_TOP env variable not defined, this script shall be executed on TOP directory"
  exit 1
fi

DEFAULT_LAYOUT_CONFIG=${COMMON_PATH}/layout/android_layout.config
NUMBER_OF_TRY=2

#######################################
# Variables
#######################################
layout_config=${DEFAULT_LAYOUT_CONFIG}
flash_dfu=1
flash_fastboot=1
do_wrapped=0
do_hybrid=0
memory_type=""
chosen_device=-1
tmp_version="nodate"

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
  echo "  --hybrid: flash only emmc partitions considering hybrid configuration"
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
        hybrid)
          do_hybrid=1
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

# Use date to set unique tmp file name
tmp_version=`date +%Y-%m-%d_%H-%M`

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

  STM32_Programmer_CLI -l usb > /tmp/stm32_programmer_result-${tmp_version}

  usb_dfu_list=()
  while read -r line; do
    usb_dfu_list+=("$line")
  done < <(cat /tmp/stm32_programmer_result-${tmp_version} | grep "Device Index" | awk '{ print $5 }')

  android_serial_list=()
  while read -r line; do
    android_serial_list+=("$line")
  done < <(cat /tmp/stm32_programmer_result-${tmp_version} | grep "Serial number" | awk '{ print $5 }')
  \rm -f /tmp/stm32_programmer_result-${tmp_version}

  if [ "${#usb_dfu_list[@]}" -eq 0 ]; then
    error "No device detected, check that it's connected and configured in DFU"
    \popd >/dev/null 2>&1
    exit 1
  fi

  if [ "${#android_serial_list[@]}" -eq 0 ]; then
    error "No device detected, check that it's connected and configured in DFU"
    \popd >/dev/null 2>&1
    exit 1
  fi

  # Check how much devices are available
  num_devices=${#android_serial_list[@]}

  # Test is ANDROID_SERIAL is already defined and if it correspond to one of the existing devices plugger to PC.
  if [[ -n "${ANDROID_SERIAL+1}" ]]; then
    for ((i=0; i<num_devices; i++)); do
      if [ "$ANDROID_SERIAL" == "${android_serial_list[i]}" ]; then
        chosen_device=${i}
      fi
    done

    if [ ${chosen_device} == -1 ]; then
      error "The defined serial number from your environment (ANDROID_SERIAL) was not found among the available devices"
      \popd >/dev/null 2>&1
      exit 1
    fi
    echo "Flashing the device $ANDROID_SERIAL"
  # If there is no ANDROID_SERIAL number defined
  else
    # If there is only one device, it choose it by default
    if [ ${num_devices} -eq 1 ]; then
      chosen_device=0
      echo "Flashing the device ${android_serial_list[0]}"
    # Otherwise, it prints all the possibilities with an associated number so 
    # that the user can choose the device he wants to flash.
    else
      for j in {0..NUMBER_OF_TRY}; do
        echo "Available devices:"
        for ((i=0; i<num_devices; i++)); do
          echo "$i. ${android_serial_list[i]}"
        done

        read -p "Enter the id of the device you want to use: " chosen_device

        if ! [ ${chosen_device} -ge 0 ] || ! [ ${chosen_device} -le ${num_devices} ] || ! [[ $chosen_device =~ ^[0-9]+$ ]]; then
          if [ ${j} == NUMBER_OF_TRY ]; then
            error "Invalid selection"
            \popd >/dev/null 2>&1
            exit 1
          fi
          error "Invalid value, please choose a number between 0 and ${num_devices}"
          empty_line
        else
          echo "Flashing the device ${android_serial_list[chosen_device]}"
          break
        fi
      done
    fi
  fi

  usb_dfu=${usb_dfu_list[chosen_device]}

  if test ${do_hybrid} -eq 1; then
    #Get tsv list for the hybrid memory type configuration
    tsv_list=$(find ${COMMON_PATH}/layout/programmer -name "*.tsv" | grep -v "emmc_clear" | grep "hybrid" | awk -F"/" '{print $NF}')
  else
    #Get tsv list for the current memory type configuration
    tsv_list=$(find ${COMMON_PATH}/layout/programmer -name "*.tsv" | grep -v "emmc_clear" | grep "$memory_type" | awk -F"/" '{print $NF}')
  fi
  options=($tsv_list)

  if [[ ${#options[@]} -eq 1 ]]; then
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
  if test $(basename ${ANDROID_PRODUCT_OUT}) == "valid"; then
    fastboot_helper="(long press on User-1 button after reset)"
  else
    fastboot_helper=""
  fi

  empty_line
  echo "$(tput bold)Change boot mode from DFU to normal boot ($memory_type), and select fastboot$(tput sgr0)" ${fastboot_helper}
  if test ${do_hybrid} -eq 1; then
    provision-device -c ${layout_config} -y --hybrid -s ${android_serial_list[chosen_device]}
  else
    provision-device -c ${layout_config} -y -s ${android_serial_list[chosen_device]}
  fi
fi

\popd >/dev/null 2>&1
