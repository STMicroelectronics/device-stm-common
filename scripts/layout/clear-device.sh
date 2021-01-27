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
SCRIPT_VERSION="1.0"

SOC_FAMILY="stm32mp1"

if [[ -n "${ANDROID_BUILD_TOP+1}" ]]; then
  COMMON_PATH=${ANDROID_BUILD_TOP}/device/stm/${SOC_FAMILY}
elif [ -d "device/stm/${SOC_FAMILY}" ]; then
  COMMON_PATH=${PWD}/device/stm/${SOC_FAMILY}
else
  echo "ERROR: ANDROID_BUILD_TOP env variable not defined, this script shall be executed on TOP directory"
  exit 1
fi

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
  echo "  This script allows clearing memory with default partition structure"
  empty_line
  echo "Options:"
  echo "  -h/--help: print this message"
  echo "  -v/--version: get script version"
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

# Check the current usage
if [ $# -gt 2 ]
then
  usage
  exit 1
fi

while test "$1" != ""; do
  arg=$1
  case $arg in
    "-h"|"--help" )
      usage
      exit 0
      ;;

    "-v"|"--version" )
      echo "$(basename $0) version ${SCRIPT_VERSION}"
      exit 0
      ;;

    ** )
      usage
      exit 1
      ;;

  esac
  shift
done

# Be in the folder where images are located
\pushd ${ANDROID_PRODUCT_OUT} >/dev/null 2>&1


# Check if STM32CubeProgrammer is available in the $PATH
cube_path=`which STM32CubeProgrammer`
if [ ! -x "${cube_path}" ]; then
  error "STM32CubeProgrammer not found in the PATH"
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
tsv_list=$(find ${COMMON_PATH}/layout/programmer -name "*.tsv" | grep "_clear" | awk -F"/" '{print $NF}')
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

STM32_Programmer_CLI -c port=${usb_dfu} -w ${COMMON_PATH}/layout/programmer/${selected_tsv}

\popd >/dev/null 2>&1
