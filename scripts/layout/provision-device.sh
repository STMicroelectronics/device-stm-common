#!/bin/bash
#
# provision the device

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

# mmc1 for emmc, mmc0 for sd for STM32MP1 boards
SD_BOOT_INSTANCE="0"
EMMC_BOOT_INSTANCE="1"

BOOT_MODE_LIST=( "optee" "trusted" )

#######################################
# Variables
#######################################
target_disk_type=""
target_device=""
target_device_access=""

req_disk_type=""

part_layout_config=${TOP_PATH}/${PART_LAYOUT_DIR}/${PART_LAYOUT_NAME}
part_image_path=${ANDROID_PRODUCT_OUT}

do_interactive=0
do_not_ask_confirmation=0
do_fastboot=0

fastboot_cmd=""
fastboot_instance_var="boot_instance"
fastboot_mode_var="boot_mode"

force_part=0
part_value_a=0
part_value_b=0

backup_image=0

provisioning_error=0
provisioning_error_msg="ERROR: partitioning not performed correctly for the following partitions: "

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
  echo "Usage:"
  echo "  Remote target through USB (using fastboot): `basename $0` [Options] [Command]"
  echo "  Local SD card: `basename $0` [Options] <device_path>"
  empty_line
  echo "  Provision selected device with latest built images"
  empty_line
  echo "Options:"
  echo "  -h/--help: print this message"
  echo "  -v/--version: get script version"
  echo "  -y/--yes: do not ask confirmation"
  echo "  -i/--interactive: set interactive mode (select provisioned partition one by one)"
  echo "  -c/--config <config-file-path>: set used partition configuration file (default: ${part_layout_config})"
  echo "  -p/--path <image path>: path to images directory which shall be provisioned (default: ${ANDROID_PRODUCT_OUT})"
  empty_line
  echo "Command:"
  echo " reboot: force board reboot after download"
  empty_line
  echo "<device_path>: /dev/sdX (SD card connected through USB dongle), /dev/mmcblkX (SD card connected through reader)"
  empty_line
}

#######################################
# If in interactive mode, ask user confirmation
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0 if not confirmed by user
#   1 if confirmed by user (or not interactive)
#######################################
doit()
{
  local b
  if [ ${do_interactive} -eq 0 ]; then
    echo "$*"
    return 1
  else
    echo -n "$*? (y/N)"
    read b </dev/tty
    if test "$b" == "y" -o "$b" == "Y"; then
      return 1
    fi
  fi
  return 0
}

#######################################
# Get back boot device (fastboot)
# Globals:
#   O boot_device
# Arguments:
#   None
# Returns:
#   None
#######################################
get_boot_device()
{
  local l_line
  local l_boot_instance="5"

  # fastboot return values on stderr (not stdout as expected)
  \fastboot getvar ${fastboot_instance_var} &> /tmp/bootinstance

  while IFS='' read -r l_line || [[ -n ${l_line} ]]; do
    echo ${l_line} | grep "${fastboot_instance_var}:" &> /dev/null
    if [ $? -eq 0 ]; then
      l_boot_instance=($(echo ${l_line} | awk '{ print $2 }'))
    fi
  done < /tmp/bootinstance
  \rm -f /tmp/bootinstance

  if [ ${l_boot_instance} == ${EMMC_BOOT_INSTANCE} ]; then
    target_disk_type="emmc"
  elif [ ${l_boot_instance} == ${SD_BOOT_INSTANCE} ]; then
    target_disk_type="sd"
  else
    error "unknown boot instance value: ${l_boot_instance}"
    \popd >/dev/null 2>&1
    exit 1
  fi
}


#######################################
# Get back boot mode (fastboot)
# Globals:
#   O boot_mode
# Arguments:
#   None
# Returns:
#   None
#######################################
get_boot_mode()
{
  local l_line
  local l_boot_mode="5"

  # fastboot return values on stderr (not stdout as expected)
  \fastboot getvar ${fastboot_mode_var} &> /tmp/bootmode

  while IFS='' read -r l_line || [[ -n ${l_line} ]]; do
    echo ${l_line} | grep "${fastboot_mode_var}:" &> /dev/null
    if [ $? -eq 0 ]; then
      l_boot_mode=($(echo ${l_line} | awk '{ print $2 }'))
    fi
  done < /tmp/bootmode
  \rm -f /tmp/bootmode

  if [ ${l_boot_mode} == trusted ]; then
    target_boot_mode="trusted"
  elif [ ${l_boot_mode} == optee ]; then
    target_boot_mode="optee"
  else
    error "unknown boot mode value: ${l_boot_mode}"
    \popd >/dev/null 2>&1
    exit 1
  fi
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

    "-i"|"--interactive" )
      do_interactive=1
      ;;

    "-y"|"--yes" )
      do_not_ask_confirmation=1
      ;;

    /dev/sd*)
      target_device_access="usb"
      target_device=$1
      ;;

    /dev/mmcblk* )
      target_device_access="sd"
      target_device=$1
      ;;

    reboot )
      fastboot_cmd=$1
      ;;

    "-c"|"--config" )
      part_layout_config="$2"
      shift # past argument
      ;;

    "-p"|"--path" )
      part_image_path="$2"
      shift # past argument
      ;;

    ** )
      usage
      \popd >/dev/null 2>&1
      exit 1
      ;;

  esac
  shift
done

# check provisioning method
if [ -n "${target_device}" ]; then
  if [ ! -e "${target_device}" ]; then
    error "Device ${target_device} not found"
    \popd >/dev/null 2>&1
    exit 1
  fi
  echo "Provisioning of SD card device ${target_device} using ${part_layout_config} partition config file"
  if [ ${do_not_ask_confirmation} -eq 0 ]; then
    empty_line
    echo -n "Are you sure to proceed? (y/N): "
    read a
    if [ "$a" == "y" -o "$A" == "Y" ]; then
      empty_line
      echo "[0] Start SD card device provisioning"
    else
      \popd >/dev/null 2>&1
      exit 0
    fi
  else
    empty_line
    echo "[0] Start SD card device provisioning"
  fi

  target_disk_type="sd"

  PS3='Which boot option do you want to flash ?'
  options=(${BOOT_MODE_LIST[*]})
  select opt in "${options[@]}"
  do
    target_boot_mode=${opt}
    break
  done

else
  echo "Provisionning remote target through USB fastboot using ${part_layout_config} partition config file"
  if [ ${do_not_ask_confirmation} -eq 0 ]; then
    empty_line
    echo -n "Are you sure to proceed? (y/N): "
    read a
    if [ "$a" == "y" -o "$A" == "Y" ]; then
      empty_line
      echo "[0] Start device provisioning"
    else
      \popd >/dev/null 2>&1
      exit 0
    fi
  else
    empty_line
    echo "[0] Start device provisioning"
  fi
  do_fastboot=1

  # get back boot device (emmc or sd)
  get_boot_device
  echo "   => detected boot device = ${target_disk_type}"
  get_boot_mode
  echo "   => detected boot mode = ${target_boot_mode}"
fi

if [ -n "${STM32MP1_DISK_TYPE+1}" ]; then
  if [ "${target_disk_type}" != "${STM32MP1_DISK_TYPE}" ]; then
    error "Error, current disk configuration (${STM32MP1_DISK_TYPE}) not compatible with target (${target_disk_type})"
    exit 1
  fi
fi

# check availability of layout config file
if [ ! -f ${part_layout_config} ]; then
  error "Layout configuration file ${part_layout_config} not available."
  \popd >/dev/null 2>&1
  exit 1
fi

while IFS='' read -r line || [[ -n $line ]]; do
  # Set req_disk_type to current selected mode by default. It will be updated if needed when reading configuration file
  req_disk_type=${target_disk_type}

  echo $line | grep '^PART_' &> /dev/null

  if [ $? -eq 0 ]; then

    line=$(echo "${line: 5}")

    part_name=($(echo $line | awk '{ print $1 }'))
    part_size=($(echo $line | awk '{ print $2 }'))
    part_nb=($(echo $line | awk '{ print $3 }'))
    part_label=($(echo $line | awk '{ print $4 }'))

    # For fsbl and ssbl, use prebuilt image dependeing on boot mode and disk type
    if [ "${part_label}" = "fsbl" ]; then
      part_filename=${part_label}-${target_boot_mode}.img
    elif [ "${part_label}" = "ssbl" ]; then
      part_filename=${part_label}-${target_boot_mode}-fb${target_disk_type}.img
    else
      part_filename=${part_label}.img
    fi

    # bypass both MEMORY_SIZE and MEMORY_TYPE (not useful here)
    if [[ ${part_name} != "MEMORY_SIZE" ]] && [[ ${part_name} != "MEMORY_TYPE" ]]; then

      # bypass TEE partition if not required (boot mode)
      if [[ ${part_name} =~ "TEE" ]] && [[ ${target_boot_mode} == "optee" ]] || [[ ! ${part_name} =~ "TEE" ]]; then

        part_enable=($(echo $line | awk '{ print $6 }'))
        if [ ! -z  ${part_enable} ]; then
          req_disk_type=${part_enable}
        fi

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

        if [[ ${req_disk_type} == ${target_disk_type} ]]; then
          part_value_a=$((part_value_b+1))
          if [ ${part_nb} -eq 2 ]; then
            part_value_b=$((part_value_a+1))
          else
            part_value_b=$((part_value_a))
          fi
        else
          part_value_a=$((part_value_b+1))
          part_value_b=$((part_value_a))
          echo "[${part_value_a}] The partition ${part_label} must be loaded using STM32CubeProgrammer tool"
        fi

        # Fastboot mode with remote target connected via USB
        if [ ${do_fastboot} -eq 1 ] && [[ ! ${part_name} =~ "MEMORY_MAX_SIZE" ]] && [[ ${req_disk_type} == ${target_disk_type} ]]; then
          if [ -f ${part_image_path}/${part_filename} ]; then
            if [ ${part_nb} -eq 2 ]; then
              empty_line
              doit "[${part_value_a}] Loading ${part_label}${part_suffix_1} with the image ${part_image_path}/${part_filename}" || force_part=1

              if [ ${force_part} -eq 1 ]; then
                \fastboot flash ${part_label}${part_suffix_1} ${part_image_path}/${part_filename}
                if [ $? -ne 0 ]; then
                  provisioning_error=1
                  provisioning_error_msg+="${part_label}${part_suffix_1} "
                fi
                force_part=0
              fi

              empty_line
              doit "[${part_value_b}] Loading ${part_label}${part_suffix_2} with the image ${part_image_path}/${part_filename}" || force_part=1

              if [ ${force_part} -eq 1 ]; then
                \fastboot flash ${part_label}${part_suffix_2} ${part_image_path}/${part_filename}
                if [ $? -ne 0 ]; then
                  provisioning_error=1
                  provisioning_error_msg+="${part_label}${part_suffix_2} "
                fi
                force_part=0
              fi
            else
              empty_line
              doit "[${part_value_a}] Loading ${part_label} with the image ${part_image_path}/${part_filename}" || {
                \fastboot flash ${part_label} ${part_image_path}/${part_filename}
              }
            fi
          else
            echo "[${part_value_a}] WARNING ${part_image_path}/${part_filename} to provision partition ${part_label}"
            if [ ${part_nb} -eq 2 ]; then
              echo "[${part_value_b}] WARNING ${part_image_path}/${part_filename} not available to provision the second partition ${part_label}"
            fi
            provisioning_error=1
            provisioning_error_msg+="${part_label} "
          fi
        # Local device
        else
          if [[ ! ${part_name} =~ "MEMORY_MAX_SIZE" ]] && [[ ${req_disk_type} == ${target_disk_type} ]]; then
            tmp_device_a="${target_device}"
            tmp_device_b="${target_device}"

            #Check for partition name in order to avoid writing wrong device
            device_part_name=$(sfdisk --part-label ${tmp_device_a} ${part_value_a})

            if [ ${part_nb} -eq 2 ]; then
              expected_part_name=${part_label}${part_suffix_1}
            else
              expected_part_name=${part_label}
            fi
            if [[ ${device_part_name} != ${expected_part_name} ]];then
              error "Current partition name is \"${device_part_name}\" when \"${expected_part_name}\" is expected!"
              \popd >/dev/null 2>&1
              exit 1
            fi

            if [ "${target_device_access}" == "sd" ]; then
              tmp_device_a+="p"
              tmp_device_b+="p"
            fi

            tmp_device_a+="${part_value_a}"
            tmp_device_b+="${part_value_b}"

            \umount ${tmp_device_a} &> /dev/null
            if [ ${part_nb} -eq 2 ]; then
              \umount ${tmp_device_b} &> /dev/null
            fi

            if [ -f ${part_image_path}/${part_filename} ]; then
              empty_line
              doit "[${part_value_a}] start provisioning of partition ${part_label} with the image ${part_image_path}/${part_filename}" || force_part=1

              if [ ${force_part} -eq 1 ]; then
                # In case of partition different from Boot and Misc, need to manage sparse image conversion and resize
                tmp_image=${part_image_path}/${part_filename}
                if [[ ! ${part_name} == "BOOT" ]] && [[ ! ${part_name} == "MISC" ]] && [[ ! ${part_name} == "ATF" ]] && [[ ! ${part_name} == "BL33" ]]; then
                  tmp_image=${part_image_path}/${part_label}_raw.img
                  # Convert Sparse image to Raw image
                  \simg2img ${part_image_path}/${part_filename} ${tmp_image} &> /dev/null
                  # Check if command succeed otherwise keep current image file which is not in sparse format
                  if [ $? -eq 0 ]; then
                    echo "${part_filename} sparse image converted to raw image"
                    # Resize in case of Userdata image
                    if [[ ${part_name} =~ "USERDATA" ]];then
                      echo "Shrink ${part_filename} before writing"
                      \resize2fs -M ${tmp_image} &> /dev/null
                    fi
                    backup_image=1
                  else
                    # Remove temporarily raw image
                    \rm -f ${tmp_image}
                    tmp_image=${part_image_path}/${part_filename}
                    backup_image=0
                  fi
                fi
                \pv -ber ${tmp_image} | dd status=none of=${tmp_device_a}
                if [ $? -ne 0 ]; then
                  provisioning_error=1
                  provisioning_error_msg+="${part_label} "
                else
                  if [[ ! ${part_name} == "BOOT" ]] && [[ ! ${part_name} == "MISC" ]]; then
                    if [[ ${part_name} =~ "USERDATA" ]];then
                      echo "Resize the filesystem to use the whole ${tmp_device_a}"
                      \resize2fs -f ${tmp_device_a} &> /dev/null
                    fi
                  fi
                fi
                if [ ${backup_image} -eq 1 ]; then
                  # Remove temporarily raw image
                  \rm -f ${tmp_image}
                  backup_image=0
                fi
                force_part=0
              fi

              if [ ${part_nb} -eq 2 ]; then
                empty_line
                doit "[${part_value_b}] start provisioning of the second partition ${part_label} with the image ${part_image_path}/${part_filename}" || force_part=1
                if [ ${force_part} -eq 1 ]; then
                  # Convert to raw in case of System and Vendor image
                  tmp_image=${part_image_path}/${part_filename}
                  if [[ ${part_name} =~ "SYSTEM" ]] || [[ ${part_name} =~ "MODULE" ]];then
                    tmp_image=${part_image_path}/${part_label}_raw.img
                    \simg2img ${part_image_path}/${part_filename} ${tmp_image} &> /dev/null
                    # check if command succeed otherwise keep current image file which is not in sparse format
                    if [ $? -eq 0 ]; then
                      echo "${part_filename} sparse image converted to raw image"
                      backup_image=1
                    else
                      # Remove temporarily raw image
                      \rm -f ${tmp_image}
                      tmp_image=${part_image_path}/${part_filename}
                      backup_image=0
                    fi
                  fi
                  \pv -ber ${tmp_image} | dd status=none of=${tmp_device_b}
                  if [ $? -ne 0 ]; then
                    provisioning_error=1
                    provisioning_error_msg+="${part_label} "
                  fi
                  if [ ${backup_image} -eq 1 ];then
                    # Remove temporarily raw image
                    \rm -f ${tmp_image}
                    backup_image=0
                  fi
                  force_part=0
                fi
              fi
            else
              echo "[${part_value_a}] WARNING ${part_image_path}/${part_filename} not available to provision partition ${part_label}"
              \mkfs.ext4 -L ${part_label} ${tmp_device_a} &> /dev/null
              if [ ${part_nb} -eq 2 ]; then
                echo "[${part_value_b}] WARNING ${part_image_path}/${part_filename} not available to provision the second partition ${part_label}"
                \mkfs.ext4 -L ${part_label} ${tmp_device_b} &> /dev/null
              fi
              provisioning_error=1
              provisioning_error_msg+="${part_label} "
            fi
          fi
        fi
      fi
    fi
  fi

done < ${part_layout_config}

empty_line

if [ ${provisioning_error} -eq 1 ]; then
  error "${provisioning_error_msg}"
else
  green "Provisioning finalized successfully for the ${target_disk_type} device ${target_device}."
fi

if [ -n "${fastboot_cmd}" ]; then
  if [ ${fastboot_cmd} == "reboot" ]; then
    echo "Reboot target..."
    \fastboot reboot
  fi
fi
