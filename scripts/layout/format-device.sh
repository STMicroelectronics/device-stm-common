#!/bin/bash
#
# format SD card following layout configuration

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

if [ -n "${ANDROID_BUILD_TOP+1}" ]; then
  TOP_PATH=${ANDROID_BUILD_TOP}
elif [ -d "device/stm/${SOC_FAMILY}" ]; then
  TOP_PATH=$PWD
else
  echo "ERROR: ANDROID_BUILD_TOP env variable not defined, this script shall be executed on TOP directory"
  exit 1
fi

\pushd ${TOP_PATH} >/dev/null 2>&1

PART_LAYOUT_NAME="android_layout.config"
PART_LAYOUT_DIR="device/stm/stm32mp1/layout"
PART_LAYOUT_CONFIG=${TOP_PATH}/${PART_LAYOUT_DIR}/${PART_LAYOUT_NAME}

LOCAL_CONFIG_NAME="local.config"
LOCAL_CONFIG_FILE=${TOP_PATH}/device/stm/stm32mp1/configs/${LOCAL_CONFIG_NAME}

PART_LAYOUT_START=34
PART_LAYOUT_START_BYTES=$(( ${PART_LAYOUT_START} * 512 ))
ADDITIONNAL_SIZE_BYTES=${PART_LAYOUT_START_BYTES}

BOOT_MODE_LIST=( "optee" "trusted" )

#######################################
# Variables
#######################################
target_device=""
target_disk_type="sd"

if [ -n "${STM32MP1_DISK_SIZE+1}" ]; then
  target_disk_size=${STM32MP1_DISK_SIZE}
else
  target_disk_size="4GiB"
fi

part_suffix_1="_a"
part_suffix_2="_b"

part_value=1

part_error=0
part_error_list=""

device_full_size=0
device_full_size_bytes=0

memory_req_size=0
memory_req_size_bytes=0

total_free_space=0

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
# Print warning message in orange on stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
warning()
{
  echo "$(tput setaf 3)WARNING: $1$(tput sgr0)"
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
  echo "$(tput setaf 1)ERROR: $1$(tput sgr0)" >&2
}

#######################################
# Print message in green on stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
green()
{
  echo "$(tput setaf 2)$1$(tput sgr0)"
}

#######################################
# Print message in blue on stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
blue()
{
  echo "$(tput setaf 6)$1$(tput sgr0)"
}

#######################################
# Print script usage on stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
usage()
{
  echo "Usage: `basename $0` [Options] <device_path>"
  empty_line
  echo "  This script allows formating memory device to create required partition before provisioning"
  empty_line
  echo "Options:"
  echo "  -h/--help: print this message"
  echo "  -v/--version: get script version"
  echo "  -s/--size <disk-size>: set requested disk size [4GiB or 8GiB] (default: 4GiB)"
  echo "  -c/--config <config-file-path>: set used partition configuration file (default: ${PART_LAYOUT_CONFIG})"
  empty_line
  echo "<device_path>: /dev/sdX (sd connected through usb), /dev/mmcblkX (sd connected through reader)"
  empty_line
}

#######################################
# transform required memory in bytes
# Globals:
#   O part_size_bytes
# Arguments:
#   $1: partition size
# Returns:
#   None
#######################################
transform_part_size_in_bytes()
{
  local l_part_size
  local l_part_size_bytes

  KMG=${1: -1}
  l_part_size=$(echo $1|tr -cd [:digit:])

  case ${KMG} in
    "K")
      l_part_size_bytes=$(( $l_part_size*1024 ))
      ;;
    "M")
      l_part_size_bytes=$(( $l_part_size*1024*1024 ))
      ;;
    "G")
      l_part_size_bytes=$(( $l_part_size*1024*1024*1024 ))
      ;;
  esac
  part_size_bytes=$l_part_size_bytes
}

#######################################
# check required size vs remaining free space (and update free space)
# Globals:
#   I part_name
#   I/O total_free_space
# Arguments:
#   $1: required size in bytes
#   $2: number of required instances (1 or 2)
# Returns:
#   0 if enough space available
#   1 if not enough space available
#######################################
check_part_size()
{
  local l_nb

  transform_part_size_in_bytes $1
  l_nb=$2

  if [ $((part_size_bytes*l_nb)) -ge ${total_free_space} ] && [[ ! ${part_name} =~ "MEMORY_MAX_SIZE" ]]; then
    error "No more free space left after ${part_name}"
    return 1
  else
    total_free_space=$((total_free_space - $((part_size_bytes*l_nb)) ))
    return 0
  fi
}

#######################################
# Get required disk size
# Globals:
#   I PART_LAYOUT_CONFIG
#   O memory_req_size
#   O memory_req_size_bytes
# Arguments:
#   None
# Returns:
#   None
#######################################
get_required_size()
{
  local l_line
  local l_part_name
  local l_part_size
  local l_part_mode
  local l_part_prefix

  while IFS='' read -r l_line || [[ -n ${l_line} ]]; do
    echo $l_line | grep 'MEMORY_MAX_SIZE' &> /dev/null
    if [ $? -eq 0 ]; then
      l_line=$(echo "${l_line: 5}")

      l_part_name=($(echo ${l_line} | awk '{ print $1 }'))
      l_part_size=($(echo ${l_line} | awk '{ print $2 }'))
      l_part_mode=($(echo ${l_line} | awk '{ print $4 }'))

      l_part_prefix=$(echo "${l_part_name:0:5}")
      l_part_prefix=$(echo "${l_part_prefix:0:4}")

      if [ ${l_part_prefix} == ${target_disk_size} ] && [ ${l_part_mode} == ${target_disk_type} ]; then
        transform_part_size_in_bytes ${l_part_size}
        memory_req_size=${l_part_size}
        memory_req_size_bytes=${part_size_bytes}
        break
      fi
    fi
  done < ${PART_LAYOUT_CONFIG}
}

#######################################
# Get disk info
# Globals:
#   I device
#   O device_full_size
#   O device_full_size_bytes
# Arguments:
#   None
# Returns:
#   None
#######################################
get_disk_info()
{
  local l_line
  local l_device_size_sector
  local l_sector_size

  \sgdisk --print ${target_device} > /tmp/disk_info
  if [ $? -ne 0 ]; then
    error "Not possible to read device ${target_device} info"
    \popd >/dev/null 2>&1
    exit 1
  fi

  while IFS='' read -r l_line || [[ -n ${l_line} ]]; do
    echo ${l_line} | grep "^Disk ${target_device}" &> /dev/null
    if [ $? -eq 0 ]; then
      l_device_size_sector=($(echo ${l_line} | awk '{ print $3 }'))
    else
      echo ${l_line} | grep '^Logical sector size' &> /dev/null
      if [ $? -eq 0 ]; then
        l_sector_size=($(echo ${l_line} | awk '{ print $4 }'))
      else
        echo ${l_line} | grep '^Sector size (logical/physical)' &> /dev/null
        if [ $? -eq 0 ]; then
          l_sector_size=($(echo ${l_line} | awk '{ print $4 }' | awk -F"/" '{ print $1 }'))
        fi
      fi
    fi
  done < /tmp/disk_info
  \rm -rf /tmp/disk_info

  device_full_size_bytes=$[ l_device_size_sector * l_sector_size ]
  device_full_size=$[ device_full_size_bytes/1024/1024 ]M
}

#######################################
# Main
#######################################

# Check the current usage
if [ $# -gt 6 ]; then
  usage
  \popd >/dev/null 2>&1
  exit 1
fi

while test "$1" != ""; do

  arg=$1
  case $arg in

    "-h"|"--help" )
      usage
      \popd >/dev/null 2>&1
      exit 0
    ;;

    "-v"|"--version" )
      echo "`basename $0` version ${SCRIPT_VERSION}"
      \popd >/dev/null 2>&1
      exit 0
      ;;

    "-s"|"--size" )
      target_disk_size="$2"
      shift # past argument
      ;;

    "-c"|"--config" )
      PART_LAYOUT_CONFIG="$2"
      shift # past argument
      ;;

    /dev/* )
      target_device=$1
      ;;

    ** )
      usage
      \popd >/dev/null 2>&1
      exit 1
      ;;
  esac
  shift
done


# check availability of layout config file
if [ ! -f ${PART_LAYOUT_CONFIG} ]; then
  error "Layout configuration file ${PART_LAYOUT_CONFIG} not available."
  \popd >/dev/null 2>&1
  exit 1
fi

# check availability of required device
if [ ! -n "${target_device}" ]; then
  usage
  \popd >/dev/null 2>&1
  exit 1
fi

if [ ! -e "${target_device}" ]; then
  error "Device ${target_device} not found"
  \popd >/dev/null 2>&1
  exit 1
fi

# request confirmation before formating the device
echo "Format device ${target_device}"
empty_line

echo "Current information of the block device ${target_device}"
empty_line

\lsblk ${target_device}
empty_line

# Ask for confirmation to avoid formating bad block device
echo "The device ${target_device} will be formatted using ${PART_LAYOUT_CONFIG}"
empty_line
echo -n "Are you sure to proceed? (y/N): "
read a
if test "$a" == "y" -o "$A" == "Y"; then
  empty_line
  echo "Format started (${target_disk_size})"
  empty_line
else
  \popd >/dev/null 2>&1
  exit 0
fi

# get back required boot mode
PS3='Which boot option do you want to use ?'
options=(${BOOT_MODE_LIST[*]})
select opt in "${options[@]}"
do
  target_boot_mode=${opt}
  break
done

# get back required configuration
get_required_size

# check availability of requested configuration
if [ ${memory_req_size_bytes} == 0 ]; then
  error "No compatible configuration available for ${target_disk_type} and {target_size} in ${PART_LAYOUT_CONFIG}"
  \popd >/dev/null 2>&1
  exit 1
fi

# get back disk information
get_disk_info

# check request vs device capability
if [ ${memory_req_size_bytes} -gt  ${device_full_size_bytes} ]; then
  error "Device ${target_device} is too small for requested size ${memory_req_size}: ${device_full_size} available."
  error "Please look at README in ${PART_LAYOUT_DIR}"
  \popd >/dev/null 2>&1
  exit 1
fi

# remove the 34 first and last sector (GPT table)
total_free_space=$(( memory_req_size_bytes - (2*ADDITIONNAL_SIZE_BYTES) ))

# start formating the device
echo "[0] Reset disk partitions of device ${target_device}"
\sgdisk --clear ${target_device} &> /dev/null
\sgdisk --move-second-header --mbrtogpt ${target_device} &> /dev/null

while IFS='' read -r line || [[ -n $line ]]; do

  sgdisk_option=""

  echo $line | grep '^PART_' &> /dev/null

    if [ $? -eq 0 ]; then

    line=$(echo "${line: 5}")

    part_name=($(echo $line | awk '{ print $1 }'))
    part_prefix=$(echo "${part_name:0:5}")
    part_size=($(echo $line | awk '{ print $2 }'))
    part_nb=($(echo $line | awk '{ print $3 }'))
    part_label=($(echo $line | awk '{ print $4 }'))

    if [[ ${part_name} != "MEMORY_SIZE" ]] && [[ ${part_name} != "MEMORY_TYPE" ]]; then

      part_nb=${part_nb: -1}
      if [ ${part_nb} -eq 2 ]; then
        tmp_suffix=($(echo $line | awk '{ print $5 }'))
        if [ -n "${tmp_suffix}" ]; then
          part_suffix_1=${tmp_suffix: 0: 2}
          part_suffix_2=${tmp_suffix: -2}
        fi
      else
        part_suffix_1=""
        part_suffix_2=""
      fi

      if [[ ${part_prefix} != "LAST_" ]] && [[ ! ${part_name} =~ "MEMORY_MAX_SIZE" ]]; then

        if [[ ${part_name} =~ "TEE" ]] && [[ ${target_boot_mode} == "optee" ]] || [[ ! ${part_name} =~ "TEE" ]]; then
          check_part_size ${part_size} ${part_nb}
          if [ $? -ne 0 ]; then
            empty_line
            error "Not enough space on disk (${total_free_space} bytes) to create partition ${part_label} (${part_nb} x ${part_size_bytes} Bytes)"
            \popd >/dev/null 2>&1
            exit 1
          fi

          if [ ${part_nb} -eq 2 ]; then
            if [ ${part_value} -eq 1 ]; then
              echo "[${part_value}] Create one partition ${part_label}${part_suffix_1} of size ${part_size}"
              \sgdisk --set-alignment=1 --new=${part_value}::+${part_size} --change-name=${part_value}:${part_label}${part_suffix_1} --typecode=${part_value}:8300 ${target_device}  &> /dev/null
              if [ $? -ne 0 ]; then
                part_error=1
                part_error_list+=" ${part_label}${part_suffix_1}"
              fi
              part_value=$((part_value+1))
              echo "[${part_value}] Create one partition ${part_label}${part_suffix_2} of size ${part_size}"
              \sgdisk --set-alignment=1 --new=${part_value}:+:+${part_size} --change-name=${part_value}:${part_label}${part_suffix_2} --typecode=${part_value}:8300 ${target_device}  &> /dev/null
              if [ $? -ne 0 ]; then
                part_error=1
                part_error_list+=" ${part_label}${part_suffix_2}"
              fi
            else
              # Set BOOT Partition as "legacy BIOS bootable"
              if [ ${part_name} == "BOOT" ]; then
                echo "[${part_value}] Create one bootable partition ${part_label}${part_suffix_1} of size ${part_size}"
                sgdisk_option="--attributes=${part_value}:set:2"
              else
                echo "[${part_value}] Create one partition ${part_label}${part_suffix_1} of size ${part_size}"
              fi
              \sgdisk --set-alignment=1 --new=${part_value}:+:+${part_size} --change-name=${part_value}:${part_label}${part_suffix_1} ${sgdisk_option} --typecode=${part_value}:8300 ${target_device}  &> /dev/null
              if [ $? -ne 0 ]; then
                part_error=1
                part_error_list+=" ${part_label}${part_suffix_1}"
              fi
              part_value=$((part_value+1))
              if [ ${part_name} == "BOOT" ]; then
                echo "[${part_value}] Create one bootable partition ${part_label}${part_suffix_2} of size ${part_size}"
                sgdisk_option="--attributes=${part_value}:set:2"
              else
                echo "[${part_value}] Create one partition ${part_label}${part_suffix_2} of size ${part_size}"
              fi
              \sgdisk --set-alignment=1 --new=${part_value}:+:+${part_size} --change-name=${part_value}:${part_label}${part_suffix_2} ${sgdisk_option} --typecode=${part_value}:8300 ${target_device}  &> /dev/null
              if [ $? -ne 0 ]; then
                part_error=1
                part_error_list+=" ${part_label}${part_suffix_2}"
              fi
            fi
          else
            echo "[${part_value}] Create one partition ${part_label} of size ${part_size}"
            if [ ${part_value} -eq 1 ]; then
              \sgdisk --set-alignment=1 --new=${part_value}::+${part_size} --change-name=${part_value}:${part_label} --typecode=${part_value}:8300 ${target_device}  &> /dev/null
              if [ $? -ne 0 ]; then
                part_error=1
                part_error_list+=" ${part_label}"
              fi
            else
              \sgdisk --set-alignment=1 --new=${part_value}:+:+${part_size} --change-name=${part_value}:${part_label} --typecode=${part_value}:8300 ${target_device}  &> /dev/null
              if [ $? -ne 0 ]; then
                part_error=1
                part_error_list+=" ${part_label}"
              fi
            fi
          fi
          part_value=$((part_value+1))
        fi
      else
        if [ ${part_prefix} == "LAST_" ]; then

          if [ ${part_nb} -eq 2 ]; then
            empty_line
            error "${part_label} partition can't be duplicated"
            empty_line
            \popd >/dev/null 2>&1
            exit 1
          else
            last_part_nb=1
          fi

          last_part_label=${part_label}
          last_part_size=${part_size}

        elif [[ ${part_name} =~ "MEMORY_MAX_SIZE" ]]; then

          part_prefix=$(echo "${part_prefix:0:4}")

          if [ ${part_prefix} == ${target_disk_size} ]; then
            last_part_size=${total_free_space}
            # Convert to xxM
            last_part_size=$(( (last_part_size/1024)/1024 ))M

            check_part_size ${last_part_size} ${last_part_nb}

            echo "[${part_value}] Create one partition ${last_part_label} on remaining area"
            \sgdisk --set-alignment=1 --new=${part_value}:+: --change-name=${part_value}:${last_part_label} --typecode=${part_value}:8300 ${target_device} &> /dev/null
            if [ $? -ne 0 ]; then
              part_error=1
              part_error_list+=" ${last_part_label}"
            fi
            break
          fi
        fi
      fi
    fi
  fi

done < ${PART_LAYOUT_CONFIG}

\popd >/dev/null 2>&1

empty_line

if [ ${part_error} -eq 1 ]; then
  error "Format of the device ${target_device} not finalized correctly: ${part_error_list}."
  exit 1
else
  green "Format of the device ${target_device} successfully finalized."
  empty_line
  warning "Please unplug and replug your device before provisioning."
  exit 0
fi
