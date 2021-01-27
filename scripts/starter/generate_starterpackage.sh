#!/bin/bash
#
# Generate starter package (images)

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
SCRIPT_VERSION="1.3"

SOC_FAMILY="stm32mp1"

BOARD_NAME_LIST=( "eval" "disco" )
BOARD_FLAVOUR_LIST=( "ev1" "dk2" )
BOARD_OPTION_LIST=( "default" "normal" "demo" "empty" )

if [ -n "${ANDROID_BUILD_TOP+1}" ]; then
  TOP_PATH=${ANDROID_BUILD_TOP}
elif [ -d "device/stm/${SOC_FAMILY}" ]; then
  TOP_PATH=$PWD
else
  echo "ERROR: ANDROID_BUILD_TOP env variable not defined, this script shall be executed on TOP directory"
  return 1
fi

\pushd ${TOP_PATH} >/dev/null 2>&1

DEVICE_PATH_STARTER="${TOP_PATH}/device/stm/${SOC_FAMILY}"
RELATIVE_DEVICE_PATH_STARTER="device/stm/${SOC_FAMILY}"

OUTPUT_PATH_STARTER="${TOP_PATH}/out/target/product"

STARTER_CONFIG_FILE_NAME="starter.config"
STARTER_CONFIG_FILE_DEFAULT_RELATIVE="${RELATIVE_DEVICE_PATH_STARTER}/scripts/starter/${STARTER_CONFIG_FILE_NAME}"
STARTER_CONFIG_FILE_DEFAULT="${TOP_PATH}/${STARTER_CONFIG_FILE_DEFAULT_RELATIVE}"

STARTER_NAME="st-android-11.0.0"
STARTER_BUILD="userdebug"
STARTER_OUT="out-starter"

DEFAULT_BOARD_OPTION="normal"

STARTER_TARGET_SD_SIZE_DEFAULT="4GiB"
STARTER_TARGET_EMMC_SIZE_DEFAULT="4GiB"

#######################################
# Variables
#######################################
nb_states_starter=0

starter_target_emmc=0
starter_target_sd=0

starter_board_option="normal"
starter_soc_version="stm32mp157f"

starter_build_mode="optee"
starter_no_teeimage="false"

starter_targets=
starter_version=

starter_board_flavour=

#######################################
# Functions
#######################################

#######################################
# Print error message in red on stderr
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
error_starter()
{
  echo "$(tput setaf 1)ERROR: $1$(tput sgr0)" >&2
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
warning_starter()
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
green_starter()
{
  echo "$(tput setaf 2)$1$(tput sgr0)"
}

#######################################
# Add empty line in stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
empty_line_starter()
{
  echo
}

#######################################
# Clear current line in stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
clear_line_starter()
{
  echo -ne "\033[2K"
}

#######################################
# Print state message on stdout
# Globals:
#   I nb_states_starter
#   I/O action_state_starter
# Arguments:
#   None
# Returns:
#   None
#######################################
action_state_starter=1
state_starter()
{
  echo -ne "  [${action_state_starter}/${nb_states_starter}]: $1 \033[0K\r"
  action_state_starter=$((action_state_starter+1))
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
usage_starter()
{
  echo "Usage: source $(basename $BASH_SOURCE) [Options]"
  empty_line_starter
  echo "Generate starter kits based on configuration file"
  empty_line_starter
  echo "Options:"
  echo "  -h/--help: get current help"
  echo "  -v/--version: get script version"
  echo "  -s/--soc <soc version> = stm32mp157c or stm32mp157f options (default = stm32mp157f)"
  echo "  -o/--opt <board option> = normal, empty or demo options (default = normal)"
  echo "  -c/--config  <starter_config>  = starter config file (default = ${STARTER_CONFIG_FILE_DEFAULT_RELATIVE})"
  echo "  -k/--kit  <starter_version>  = starterpackage version (default = current date)"
  empty_line_starter
}

#######################################
# Check if item is available in list
# Globals:
#   None
# Arguments:
#   $1 = list of possible items
#   $2 = item which shall be tested
# Returns:
#   0 if item found in list
#   1 if item not found in list
#######################################
in_list_starter()
{
  local list="$1"
  local checked_item="$2"

  for item in ${list}
  do
    if [[ "$item" == "$checked_item" ]]; then
      return 0
    fi
  done

  return 1
}

#######################################
# Get back starter configuration from file
# Globals:
#   I starter_config_file
#   I BOARD_NAME_LIST
#   I BOARD_FLAVOUR_LIST
#   O starter_board_name
#   O starter_board_config
#   O starter_targets[]
#   O starter_target_sd
#   O starter_target_emmc
#   O starter_target_sd_size
#   O starter_target_emmc_size
# Arguments:
#   None
# Returns:
#   0 if error
#   1 if starter configuration has been retrieved successfully
#######################################
get_starter_config()
{
  local nb_flavours=0
  local nb_targets=0

  local config_name
  local config_value1
  local config_value2

  while IFS='' read -r line || [[ -n $line ]]; do

    echo $line | grep "^STARTER_" &> /dev/null
    if [ $? -eq 0 ]; then

      config_name=($(echo $line | awk '{ print $1 }'))
      config_value1=($(echo $line | awk '{ print $2 }'))
      config_value2=($(echo $line | awk '{ print $3 }'))

      case $config_name in
        "STARTER_BOARD_NAME" )
          if in_list_starter "${BOARD_NAME_LIST[*]}" "$config_value1"; then
            starter_board_name=${config_value1}
          else
            error_starter "Unknown STARTER_BOARD_NAME $config_value1"
            return 0
          fi
          ;;
        "STARTER_BOARD_CONFIG" )
          starter_board_config=$config_value1
          ;;
        "STARTER_BOARD_FLAVOUR" )
          if in_list_starter "${BOARD_FLAVOUR_LIST[*]}" "$config_value1"; then
            starter_board_flavour+=" $config_value1"
            nb_flavours=$((nb_flavours+1))
          else
            error_starter "Unknown STARTER_BOARD_FLAVOUR $config_value1"
            return 0
          fi
          if [[ "$config_value2" != "" ]]; then
            if in_list_starter "${BOARD_FLAVOUR_LIST[*]}" "$config_value2"; then
              starter_board_flavour+=" $config_value2"
              nb_flavours=$((nb_flavours+1))
            else
              error_starter "Unknown STARTER_BOARD_FLAVOUR $config_value2"
              return 0
            fi
          fi
          ;;
        "STARTER_BUILD_MODE" )
          starter_build_mode=$config_value1
          if [ "$starter_build_mode" == "trusted" ]; then
            starter_no_teeimage="true"
          else
            starter_no_teeimage="false"
          fi
          ;;
        "STARTER_TARGETS" )
          if [ "$config_value1" == "emmc" ]; then
            starter_target_emmc=1
            starter_targets+=" emmc"
            nb_targets=$((nb_targets+1))
          else
            if [ "$config_value1" == "sd" ]; then
              starter_target_sd=1
              starter_targets+=" sd"
              nb_targets=$((nb_targets+1))
            fi
          fi
          if [ "$config_value2" == "emmc" ]; then
            starter_target_emmc=1
            starter_targets+=" emmc"
            nb_targets=$((nb_targets+1))
          else
            if [ "$config_value2" == "sd" ]; then
              starter_target_sd=1
              starter_targets+=" sd"
              nb_targets=$((nb_targets+1))
            fi
          fi
          ;;
        "STARTER_TARGET_SD_SIZE" )
          starter_target_sd_size=$config_value1
          ;;
        "STARTER_TARGET_EMMC_SIZE" )
          starter_target_emmc_size=$config_value1
          ;;
        ** )
          warning_starter "${config_name} is unknown"
          ;;
      esac
    fi
  done < ${starter_config_file}

  # calculate number of states executed (nb_targets * (1 + 3 * nb_flavours))
  nb_states_starter=$((nb_flavours*3))
  nb_states_starter=$((nb_states_starter*${nb_targets}))
  nb_states_starter=$((nb_states_starter+${nb_targets}))

  return 1
}

#######################################
# Check back starter configuration previously extracted from file
# Globals:
#   I starter_board_name
#   I starter_board_config
#   I starter_targets[]
#   I starter_target_sd
#   I starter_target_emmc
#   I/O starter_target_sd_size
#   I/O starter_target_emmc_size
# Arguments:
#   None
# Returns:
#   0 if error
#   1 if starter configuration has been checked successfully
#######################################
check_starter_config()
{
  # check that the starter board config is correctly set
  if [ ! -n "${starter_board_name}" ] || [ ! -n "${starter_board_config}" ] || [ ! -n "${starter_targets}" ] || [ ! -n "${starter_board_flavour}" ]; then
    error_starter "Missing configuration within ${starter_config_file}"
    return 0
  fi

  # use default size for SD card if not defined in configuration file
  if [ ! -z ${starter_target_sd} ] && [ ! -n ${starter_target_sd_size} ]; then
    green_starter "No size defined for SD card within ${starter_config_file}, use default value ${STARTER_TARGET_SD_SIZE_DEFAULT} instead"
    starter_target_sd_size = ${STARTER_TARGET_SD_SIZE_DEFAULT}
  fi

  # use default size for eMMC if not defined in configuration file
  if [ ! -z ${starter_target_emmc} ] && [ ! -n ${starter_target_emmc_size} ]; then
    green_starter "No size defined for SD card within ${starter_config_file}, use default value ${STARTER_TARGET_EMMC_SIZE_DEFAULT} instead"
    starter_target_emmc_size = ${STARTER_TARGET_EMMC_SIZE_DEFAULT}
  fi

  return 1
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
teardown_starter() {

  # Clean global env
  unset TOP_PATH
  unset DEVICE_PATH_STARTER
  unset RELATIVE_DEVICE_PATH_STARTER
  unset OUTPUT_PATH_STARTER
  unset STARTER_CONFIG_FILE_NAME
  unset STARTER_CONFIG_FILE_DEFAULT_RELATIVE
  unset STARTER_CONFIG_FILE_DEFAULT
  unset STARTER_NAME
  unset STARTER_BUILD
  unset STARTER_OUT
  unset STARTER_TARGET_SD_SIZE_DEFAULT
  unset STARTER_TARGET_EMMC_SIZE_DEFAULT

  unset BOARD_FLAVOUR

  unset nb_states_starter
  unset starter_target_emmc
  unset starter_target_sd
  unset starter_version

  unset starter_board_name
  unset starter_board_flavour
  unset starter_targets
  unset starter_target_sd_size
  unset starter_target_emmc_size
  unset starter_config_file
  unset starter_build_mode
  unset starter_no_teeimage

  unset emmc_starter_dir
  unset emmc_starter_name
  unset emmc_starter_path
  unset sd_starter_dir
  unset sd_starter_name
  unset sd_starter_path

  unset git_path
  unset git_sha1
  unset file_name
  unset file_format

  # Clean env from unwanted functions
  unset -f usage_starter
  unset -f error_starter
  unset -f warning_starter
  unset -f green_starter
  unset -f empty_line_starter
  unset -f clear_line_starter
  unset -f state_starter
  unset -f in_list_starter
  unset -f get_starter_config
  unset -f check_starter_config

  \popd >/dev/null 2>&1
}

#######################################
# Main
#######################################

if [[ "$0" == "$BASH_SOURCE" ]]; then
  empty_line_starter
  error_starter "This script must be sourced"
  empty_line_starter
  usage_starter
  \popd >/dev/null 2>&1
  exit 1
fi

# Check the current usage
if [ $# -gt 4 ]; then
  usage_starter
  teardown_starter
  return 1
fi

while test "$1" != ""; do
  arg=$1
  case $arg in

    "-h"|"--help" )
      usage_starter
      teardown_starter
      return 0
      ;;

    "-v"|"--version" )
      echo "$(basename $BASH_SOURCE) version ${SCRIPT_VERSION}"
      teardown_starter
      return 0
      ;;

    "-c"|"--config" )
      starter_config_file=$2
      shift
      ;;

    "-k"|"--kit" )
      starter_version=$2
      shift
      ;;

    "-s"|"--soc" )
      starter_soc_version=$2
      shift
      ;;

    "-o"|"--opt" )
      starter_board_option=$2
      if [ "${starter_board_option}" = "default" ]; then
        starter_board_option=${DEFAULT_BOARD_OPTION}
      fi
      shift
      ;;

    ** )
      starter_config_file=$1
      ;;

  esac
  shift
done

if [ ! -n "${starter_config_file}" ]; then
  starter_config_file=${STARTER_CONFIG_FILE_DEFAULT}
fi

if [ ! -f "${starter_config_file}" ]; then
  error_starter "${starter_config_file} file doesn't exist, please create it"
  teardown_starter
  return 1
fi

if [ ! -n "$starter_version" ]; then
  starter_version=`date +%Y-%m-%d`
fi


# get back starter configuration from file
if get_starter_config; then
  teardown_starter
  return 1
fi

# check starter configuration
if check_starter_config; then
  teardown_starter
  return 1
fi

DEVICE_PATH_STARTER+=/${starter_board_name}
RELATIVE_DEVICE_PATH_STARTER+=/${starter_board_name}

\mkdir -p ${STARTER_OUT}
\mkdir -p ${STARTER_OUT}/${starter_board_name}

if [ ! -d ${DEVICE_PATH_STARTER} ];then
  error_starter "device ${starter_board_name} doesn't exist!"
  teardown_starter
  return 1
fi

OUTPUT_PATH_STARTER+=/${starter_board_name}

if [ ${starter_target_emmc} -eq 1 ]; then

  state_starter "set environment configuration for eMMC"

  source ./build/envsetup.sh &> /dev/null
  source ./device/stm/${SOC_FAMILY}/scripts/layout/layoutsetup.sh -d emmc 4GiB
  lunch ${starter_board_config}_${starter_board_name}-${STARTER_BUILD} >/dev/null 2>&1

  for board_flavour in ${starter_board_flavour}
  do
    state_starter "build images in $board_flavour configuration for eMMC"

    # clean existing build
    if [ -d ${OUTPUT_PATH_STARTER} ]; then
      make installclean >/dev/null 2>&1
    fi

    # build distribution
    BOARD_OPTION=${starter_board_option} BOARD_FLAVOUR=${board_flavour} BOARD_DISK_TYPE=emmc TARGET_USERIMAGES_SPARSE_EXT_DISABLED=true TARGET_NO_TEEIMAGE=${starter_no_teeimage} make -j4 >/dev/null 2>&1

    # create starter (copy images and associated layout)
    emmc_starter_dir=${STARTER_NAME}-${starter_version}-${starter_soc_version}-${board_flavour}-emmc-starter
    state_starter "create starter in ${STARTER_OUT}/${starter_board_name}/${emmc_starter_dir}"

    emmc_starter_path=${STARTER_OUT}/${starter_board_name}/${emmc_starter_dir}
    \mkdir -p ${emmc_starter_path}

    \cp ${OUTPUT_PATH_STARTER}/fsbl-${starter_build_mode}.img ${emmc_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/fsbl-programmer.img ${emmc_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/ssbl-trusted-fbemmc.img ${emmc_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/ssbl-programmer.img ${emmc_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/splash.img ${emmc_starter_path}/
    if [ "${starter_build_mode}" == "optee" ]; then
      \cp ${OUTPUT_PATH_STARTER}/teed.img ${emmc_starter_path}/
      \cp ${OUTPUT_PATH_STARTER}/teeh.img ${emmc_starter_path}/
      \cp ${OUTPUT_PATH_STARTER}/teex.img ${emmc_starter_path}/
      \cp ${OUTPUT_PATH_STARTER}/teefs.img ${emmc_starter_path}/
    fi
    \cp ${OUTPUT_PATH_STARTER}/boot.img ${emmc_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/dt.img ${emmc_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/super.img ${emmc_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/misc.img ${emmc_starter_path}/

    # F2FS format no more resizeable and sparsed by default (not possible to deactivate)
    \simg2img ${OUTPUT_PATH_STARTER}/userdata.img ${OUTPUT_PATH_STARTER}/userdata2.img
    \mv ${OUTPUT_PATH_STARTER}/userdata2.img ${emmc_starter_path}/userdata.img
    # \resize2fs ${emmc_starter_path}/userdata.img 256M &> /dev/null

    \mkdir -p ${emmc_starter_path}/flashlayout
    \cp ${DEVICE_PATH_STARTER}/../layout/programmer/FlashLayout_emmc_${starter_build_mode}.tsv ${emmc_starter_path}/flashlayout/
    \sed -i -e 's/^PE/P/g' ${emmc_starter_path}/flashlayout/FlashLayout_emmc_${starter_build_mode}.tsv
    \cp ${DEVICE_PATH_STARTER}/../layout/programmer/FlashLayout_emmc_clear.tsv ${emmc_starter_path}/flashlayout/

    \pushd ${STARTER_OUT}/${starter_board_name} >/dev/null 2>&1

    emmc_starter_name=${emmc_starter_dir}
    state_starter "generate starter kit ${emmc_starter_name}.tar.gz"
    \tar zcf ${emmc_starter_name}.tar.gz  ${emmc_starter_dir}/* &> /dev/null

    \popd >/dev/null 2>&1
  done
fi


if [ ${starter_target_sd} -eq 1 ]; then

  state_starter "set environment configuration for SD card"

  source ./build/envsetup.sh &> /dev/null
  source ./device/stm/${SOC_FAMILY}/scripts/layout/layoutsetup.sh -d emmc ${starter_target_sd_size}
  lunch ${starter_board_config}_${starter_board_name}-${STARTER_BUILD} >/dev/null 2>&1

  for board_flavour in ${starter_board_flavour}
  do
    state_starter "build images in ${board_flavour} configuration for SD card"

    # clean existing build
    if [ -d ${OUTPUT_PATH_STARTER} ]; then
      make installclean >/dev/null 2>&1
    fi

    # build distribution
    BOARD_OPTION=${starter_board_option} BOARD_FLAVOUR=${board_flavour} BOARD_DISK_TYPE=sd TARGET_USERIMAGES_SPARSE_EXT_DISABLED=true TARGET_NO_TEEIMAGE=${starter_no_teeimage} make -j4 >/dev/null 2>&1

    # create starter (copy images and associated layout)
    sd_starter_dir=${STARTER_NAME}-${starter_version}-${starter_soc_version}-${board_flavour}-sd-starter
    state_starter "create starter in ${STARTER_OUT}/${starter_board_name}/${sd_starter_dir}"

    sd_starter_path=${STARTER_OUT}/${starter_board_name}/${sd_starter_dir}
    \mkdir -p ${sd_starter_path}

    \cp ${OUTPUT_PATH_STARTER}/fsbl-${starter_build_mode}.img ${sd_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/fsbl-programmer.img ${sd_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/ssbl-trusted-fbsd.img ${sd_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/ssbl-programmer.img ${sd_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/splash.img ${sd_starter_path}/
    if [ "${starter_build_mode}" == "optee" ]; then
      \cp ${OUTPUT_PATH_STARTER}/teed.img ${sd_starter_path}/
      \cp ${OUTPUT_PATH_STARTER}/teeh.img ${sd_starter_path}/
      \cp ${OUTPUT_PATH_STARTER}/teex.img ${sd_starter_path}/
      \cp ${OUTPUT_PATH_STARTER}/teefs.img ${sd_starter_path}/
    fi
    \cp ${OUTPUT_PATH_STARTER}/boot.img ${sd_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/dt.img ${sd_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/super.img ${sd_starter_path}/
    \cp ${OUTPUT_PATH_STARTER}/misc.img ${sd_starter_path}/

    # F2FS format no more resizeable and sparsed by default (not possible to deactivate)
    \simg2img ${OUTPUT_PATH_STARTER}/userdata.img ${OUTPUT_PATH_STARTER}/userdata2.img
    \mv ${OUTPUT_PATH_STARTER}/userdata2.img ${sd_starter_path}/userdata.img
    # \resize2fs ${sd_starter_path}/userdata.img 256M &> /dev/null

    \mkdir -p ${sd_starter_path}/flashlayout
    \cp ${DEVICE_PATH_STARTER}/../layout/programmer/FlashLayout_sd_${starter_build_mode}.tsv ${sd_starter_path}/flashlayout/
    \sed -i -e 's/^PE/P/g' ${sd_starter_path}/flashlayout/FlashLayout_sd_${starter_build_mode}.tsv

    \pushd ${STARTER_OUT}/${starter_board_name} >/dev/null 2>&1

    sd_starter_name=${sd_starter_dir}
    state_starter "generate starter kit ${sd_starter_name}.tar.gz"
    \tar zcf ${sd_starter_name}.tar.gz  ${sd_starter_dir}/* &> /dev/null

    \popd >/dev/null 2>&1
  done
fi

clear_line_starter
green_starter "starter kit has been generated:"
if [ ${starter_target_emmc} -eq 1 ]; then
  green_starter "starter for emmc memory available in ${emmc_starter_path} directory"
fi

if [ ${starter_target_sd} -eq 1 ]; then
  green_starter "starter for sd memory available in ${sd_starter_path} directory"
fi

teardown_starter
unset teardown_starter
