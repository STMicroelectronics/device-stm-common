#!/bin/bash
#
# Create disk image (can be flashed on SD card using dd tool)

# Copyright (C)  2020. STMicroelectronics
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

if [ -n "${ANDROID_BUILD_TOP+1}" ]; then
  TOP_PATH=${ANDROID_BUILD_TOP}
elif [ -d "device/stm/${SOC_FAMILY}" ]; then
  TOP_PATH=$PWD
else
  echo "ERROR: ANDROID_BUILD_TOP env variable not defined, this script shall be executed on TOP directory"
  exit 1
fi

PART_LAYOUT_NAME="android_layout.config"
PART_LAYOUT_DIR="device/stm/stm32mp1/layout"
PART_LAYOUT_CONFIG=${TOP_PATH}/${PART_LAYOUT_DIR}/${PART_LAYOUT_NAME}

BOOT_MODE_LIST=( "optee" )

DEFAULT_BOOT_MODE="optee"
DEFAULT_DISK_NAME="st-android-${DEFAULT_BOOT_MODE}-sd"

#######################################
# Variables
#######################################
layout_config=${PART_LAYOUT_CONFIG}
raw_name=${DEFAULT_DISK_NAME}.raw
zip_name=${DEFAULT_DISK_NAME}.zip
boot_mode=${DEFAULT_BOOT_MODE}

do_pv=1
do_zip=0

part_image_path=${ANDROID_PRODUCT_OUT}

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
  echo "  This script allows creating a disk image of the distribution"
  empty_line
  echo "Options:"
  echo "  -h/--help: print this message"
  echo "  -v/--version: get script version"
  echo "  -c/--config <path to layout config file>: select configuration file (default: ${layout_config})"
  echo "  -z/--zip: compress disk image (.zip)"
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
# Compress disk image
# Globals:
#   I raw_name
#   I zip_name
# Arguments:
#   None
# Returns:
#   None
#######################################
compress_disk()
{
  if ! [ -x "$(command -v zip)" ]; then
    warning "zip command not available, please install associated package"
  else
    if [[ ${do_pv} -eq 1 ]];then
      \zip -q - ${raw_name} | pv -ber > ${zip_name}
    else
      \zip ${zip_name} ${raw_name} >/dev/null 2>&1
    fi
  fi
}

#######################################
# Provision one partition
# Globals:
#   I raw_name
# Arguments:
#   $1 : image name (without suffix)
#   $2 : offset in disk
#   $3 : sparse (true or false)
# Returns:
#   None
#######################################
provision_partition()
{
  if [ ! -f "$1.img" ]; then
    error "The required partition image $1.img doesn't exists in ${part_image_path} directory"
    \popd >/dev/null 2>&1
    exit 1
  fi
  if [ $3 == "true" ];then
    \simg2img $1.img $1_raw.img
    if [[ ${do_pv} -eq 1 ]];then
      \pv -ber $1_raw.img | dd status=none of=${raw_name} conv=fdatasync,notrunc seek=1 bs=$2
    else
      dd status=none if=$1_raw.img of=${raw_name} conv=fdatasync,notrunc seek=1 bs=$2
    fi
    if [ $? -ne 0 ]; then
      error "Failed to provision the image $1_raw.img at offset $2"
      \popd >/dev/null 2>&1
      exit 1
    fi
    \rm -f $1_raw.img
  else
    if [[ ${do_pv} -eq 1 ]];then
      \pv -ber $1.img | dd status=none of=${raw_name} conv=fdatasync,notrunc seek=1 bs=$2
    else
      dd status=none if=$1.img of=${raw_name} conv=fdatasync,notrunc seek=1 bs=$2
    fi
    if [ $? -ne 0 ]; then
      error "Failed to provision the image $1.img at offset $2"
      \popd >/dev/null 2>&1
      exit 1
    fi
  fi
}

#######################################
# Provision disk image
# Globals:
#   I raw_name
# Arguments:
#   None
# Returns:
#   None
#######################################
provision_disk()
{
  local l_line
  local l_sector_size
  local l_number
  local l_start
  local l_offset
  local l_name

  \sgdisk --print ${raw_name} > /tmp/disk_info
  if [ $? -ne 0 ]; then
    error "Not possible to read device ${raw_name} info"
    \popd >/dev/null 2>&1
    exit 1
  fi

  while IFS='' read -r l_line || [[ -n ${l_line} ]]; do
    echo ${l_line} | grep '^Logical sector size' &> /dev/null
    if [ $? -eq 0 ]; then
      l_sector_size=($(echo ${l_line} | awk '{ print $4 }'))
    else
      echo ${l_line} | grep '^Sector size' &> /dev/null
      if [ $? -eq 0 ]; then
        l_sector_size=($(echo ${l_line} | awk '{ print $4 }' | awk -F"/" '{ print $1 }'))
      else
        l_number=($(echo ${l_line} | awk '{ print $1 }'))
        if [[ ${l_number} =~ ^[0-9]+$ ]] ; then
          l_start=($(echo ${l_line} | awk '{ print $2 }'))
          l_offset=$[ l_start * l_sector_size ]
          l_name=($(echo ${l_line} | awk '{ print $7 }'))
          case ${l_name} in
            fsbl* )
              echo "[${l_number}] Provision fsbl-${boot_mode}.img to ${l_name} partition"
              provision_partition "fsbl-${boot_mode}" "${l_offset}" "false"
              ;;
            ssbl* )
              echo "[${l_number}] Provision ssbl-${boot_mode}-fbsd.img to ${l_name} partition"
              provision_partition "ssbl-trusted-fbsd" "${l_offset}" "false"
              ;;
            teeh )
              echo "[${l_number}] Provision teeh.img to ${l_name} partition"
              provision_partition "teeh" "${l_offset}" "false"
              ;;
            teed )
              echo "[${l_number}] Provision teed.img to ${l_name} partition"
              provision_partition "teed" "${l_offset}" "false"
              ;;
            teex )
              echo "[${l_number}] Provision teex.img to ${l_name} partition"
              provision_partition "teex" "${l_offset}" "false"
              ;;
            teefs )
              echo "[${l_number}] Provision teefs.img to ${l_name} partition"
              provision_partition "teefs" "${l_offset}" "false"
              ;;
            splash )
              echo "[${l_number}] Provision splash.img to ${l_name} partition"
              provision_partition "splash" "${l_offset}" "false"
              ;;
            boot* )
              echo "[${l_number}] Provision boot.img to ${l_name} partition"
              provision_partition "boot" "${l_offset}" "false"
              ;;
            dt* )
              echo "[${l_number}] Provision dt.img to ${l_name} partition"
              provision_partition "dt" "${l_offset}" "false"
              ;;
            super* )
              echo "[${l_number}] Provision super.img to ${l_name} partition"
              provision_partition "super" "${l_offset}" "true"
              ;;
            system* )
              echo "[${l_number}] Provision system.img to ${l_name} partition"
              provision_partition "system" "${l_offset}" "true"
              ;;
            vendor* )
              echo "[${l_number}] Provision vendor.img to ${l_name} partition"
              provision_partition "vendor" "${l_offset}" "true"
              ;;
            product* )
              echo "[${l_number}] Provision product.img to ${l_name} partition"
              provision_partition "product" "${l_offset}" "true"
              ;;
            misc )
              echo "[${l_number}] Provision misc.img to ${l_name} partition"
              provision_partition "misc" "${l_offset}" "false"
              ;;
            userdata )
              echo "[${l_number}] Provision userdata.img to ${l_name} partition"
              provision_partition "userdata" "${l_offset}" "true"
              ;;
            ** )
              error "unknown partition name ${l_name}"
              \popd >/dev/null 2>&1
              exit 1
              ;;
          esac
        fi
      fi
    fi
  done < /tmp/disk_info
  \rm -rf /tmp/disk_info
}

#######################################
# Main
#######################################

# Check the current usage
if [ $# -gt 4 ]
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

    "-c"|"--config" )
      layout_config=$2
      shift
      ;;

    "-z"|"--zip" )
      do_zip=1
      ;;

    ** )
      usage
      exit 1
      ;;

  esac
  shift
done

if [ ! -f "${layout_config}" ]; then
  error "${layout_config} file doesn't exist"
  exit 1
fi

# check tools availability
if ! [ -x "$(command -v dd)" ]; then
  empty_line
  error "dd command not available, please install associated package"
  exit 1
fi

if ! [ -x "$(command -v sgdisk)" ]; then
  empty_line
  error "sgdisk command not available, please install associated package"
  exit 1
fi

if ! [ -x "$(command -v pv)" ]; then
  empty_line
  warning "pv command not available, please install associated package"
  do_pv=0
fi

empty_line

# get back required boot mode
options=(${BOOT_MODE_LIST[*]})
if [[ ${#options[@]} -eq 1 ]];then
  boot_mode=${options[0]}
else
  PS3='Which boot option do you want to use ?'
  select opt in "${options[@]}"
  do
    boot_mode=${opt}
    break
  done
fi

# set disk image name
raw_name="st-android-${boot_mode}-sd.raw"
zip_name="st-android-${boot_mode}-sd.zip"

empty_line

# Create disk image
format-device -c ${layout_config} -r ${raw_name} ${boot_mode}
if [ $? -ne 0 ]; then
  exit 1
fi

empty_line

\pushd ${part_image_path} >/dev/null 2>&1

# Provision disk image
provision_disk

empty_line
green "The disk image ${raw_name} has been successfully provisioned"

# Compress disk image (if required)
if [[ ${do_zip} -eq 1 ]];then
  empty_line
  echo "[1] Compress ${raw_name} file"
  compress_disk
  empty_line
  green "The disk image ${raw_name} has been successfully compressed"
  green "  => ${zip_name} file available in ${part_image_path}"
else
  green "  => ${raw_name} file available in ${part_image_path}"
fi

\popd >/dev/null 2>&1

empty_line
