#!/bin/bash
#
# Setup partition size based on provided layout

# Copyright (C)  2016. STMicroelectronics
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
else
  # available only in ./build/envsetup.sh execution
  COMMON_PATH=$(gettop)/device/stm/${SOC_FAMILY}
fi

DEFAULT_LAYOUT_CONFIG=${COMMON_PATH}/layout/android_layout.config

PART_LAYOUT_START=34
PART_LAYOUT_START_BYTES=$(( ${PART_LAYOUT_START} * 512 ))
# Remove first and last 34 blocs (512B), revserved for GPT table, and GPT backup table
ADDITIONNAL_SIZE_BYTES=$(( ${PART_LAYOUT_START_BYTES} * 2 ))

#######################################
# Variables
#######################################
layout_config=${DEFAULT_LAYOUT_CONFIG}
reserved_memory_size=${ADDITIONNAL_SIZE_BYTES}

# used configuration from layout config file by default
disk_default=1

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
empty_line_layout()
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
usage_layout()
{
  echo "Usage: source $(basename $BASH_SOURCE) [Options]"
  empty_line_layout
  echo "  This script allows setting env variable on partition size"
  echo "  based on configuration file ${layout_config}"
  empty_line_layout
  echo "Options:"
  echo "  -h/--help: print this message"
  echo "  -v/--version: get script version"
  echo "  -c/--config <path to layout config file>: select configuration file (default: ${layout_config})"
  echo "  -d/--disk <disk type> <disk size>: used disk type (sd or emmc) and size (4GiB or 8GiB) (default: extracted from ${layout_config})"
  empty_line_layout
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
error_layout()
{
  echo "$(tput setaf 1)ERROR: $1$(tput sgr0)"  >&2
}

#######################################
# Transform input size in Bytes
# Globals:
#   O part_size_bytes
# Arguments:
#   $1: input size (xK, xM or xG)
# Returns:
#   None
#######################################
transform_part_size_in_bytes()
{
  unset part_size_bytes

  KMG=${1: -1}
  part_size=$(echo $1|tr -cd [:digit:])

  case $KMG in
    "K")
      part_size_bytes=$(( $part_size*1024 ))
      ;;
    "M")
      part_size_bytes=$(( $part_size*1024*1024 ))
      ;;
    "G")
      part_size_bytes=$(( $part_size*1024*1024*1024 ))
      ;;
    **)
      error_layout "Bad suffix value $1 for partition $part_name size, should be K, M or G"
      ;;
  esac
}

#######################################
# Since this script is sourced, be careful not to pollute
# caller's environment with temp variables.
# Globals:
#   All
# Arguments:
#   None
# Returns:
#   None
#######################################
teardown_layout() {

  # Clean global env
  unset PART_LAYOUT_START
  unset PART_LAYOUT_START_BYTES
  unset ADDITIONNAL_SIZE_BYTES

  unset layout_config
  unset reserved_memory_size
  unset disk_size
  unset disk_type
  unset disk_size_accurate

  unset part_name
  unset last_part_name
  unset part_size
  unset part_size_bytes
  unset part_mode
  unset part_nb
  unset part_prefix

  unset bootloader_part_size

  # Clean env from unwanted functions
  unset -f error_layout
  unset -f usage_layout
  unset -f empty_line_layout
  unset -f transform_part_size_in_bytes
}

#######################################
# Main
#######################################

# Check that the current script is sourced
if [[ "$0" == "$BASH_SOURCE" ]]; then
  empty_line_layout
  error_layout "This script shall be sourced"
  empty_line_layout
  usage
  exit 0
fi

# Check the current usage
if [ $# -gt 3 ]
then
  usage_layout
  exit 0
fi

while test "$1" != ""; do
  arg=$1
  case $arg in
    "-h"|"--help" )
      usage_layout
      \popd >/dev/null 2>&1
      exit 0
      ;;

    "-v"|"--version" )
      echo "$(basename $BASH_SOURCE) version ${SCRIPT_VERSION}"
      \popd >/dev/null 2>&1
      exit 0
      ;;

    "-c"|"--config" )
      layout_config=$2
      shift
      ;;

    "-d"|"--disk" )
      disk_type=$2
      disk_size=$3
      disk_default=0
      shift
      shift
      ;;

    ** )
      usage_layout
      \popd >/dev/null 2>&1
      exit 0
      ;;

  esac
  shift
done

if [ ! -f "${layout_config}" ]; then
  error_layout "${layout_config} file doesn't exist"
  teardown_layout
  return
fi

while IFS='' read -r line || [[ -n $line ]]; do

    echo $line | grep '^PART_' &> /dev/null

    if [ $? -eq 0 ]; then

    line=$(echo "${line: 5}")

    part_name=($(echo $line | awk '{ print $1 }'))
    part_size=($(echo $line | awk '{ print $2 }'))
    part_mode=($(echo $line | awk '{ print $4 }'))
    part_nb=($(echo $line | awk '{ print $3 }'))
    part_nb=${part_nb: -1}

    part_prefix=$(echo "${part_name:0:5}")

    if [ ${part_prefix} != "LAST_" ] && [[ ! ${part_name} =~ "MEMORY_MAX_SIZE" ]] \
       && [[ ${part_name} != "MEMORY_SIZE" ]] && [[ ${part_name} != "MEMORY_TYPE" ]]; then
      transform_part_size_in_bytes ${part_size}
      export ${SOC_FAMILY^^}_${part_name}_PART_SIZE=${part_size_bytes}
      reserved_memory_size=$(( reserved_memory_size + (part_nb*part_size_bytes) ))
    else
      if [ ${part_name} == "MEMORY_SIZE" ]; then
        if [ ${disk_default} == 1 ]; then
          disk_size=${part_size}
        fi
        export ${SOC_FAMILY^^}_DISK_SIZE=${disk_size}
      elif [ ${part_name} == "MEMORY_TYPE" ]; then
        if [ ${disk_default} == 1 ]; then
          disk_type=${part_size}
        fi
        export ${SOC_FAMILY^^}_DISK_TYPE=${disk_type}
      elif [ ${part_prefix} == "LAST_" ]; then
        last_part_name=$(echo ${part_name#LAST_})
      elif [[ ${part_name} =~ "MEMORY_MAX_SIZE" ]]; then
        part_prefix=$(echo "${part_prefix:0:4}")
        if [ ${part_prefix} == ${disk_size} ] && [ ${part_mode} == ${disk_type} ]; then
          transform_part_size_in_bytes ${part_size}
          disk_size_accurate=${part_size_bytes}
          if [ ! -z ${last_part_name} ];then
            part_size_bytes=$(( disk_size_accurate - reserved_memory_size ))
            export ${SOC_FAMILY^^}_${last_part_name}_PART_SIZE=${part_size_bytes}
          fi
          break
        fi
      fi
    fi
  fi
done < ${layout_config}

if [ -z "$STM32MP1_BOOTLOADER_PART_SIZE" ]; then
  bootloader_part_size=$(( ($STM32MP1_ATF_PART_SIZE*2)+$STM32MP1_BL33_PART_SIZE ))
  export ${SOC_FAMILY^^}_BOOTLOADER_PART_SIZE=${bootloader_part_size}
fi

teardown_layout
unset -f teardown_layout
