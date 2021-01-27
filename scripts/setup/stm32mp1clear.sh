#!/bin/bash
#
# Clear stm32mp1 setup configuration

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

COMMON_PATH="${TOP_PATH}/device/stm/${SOC_FAMILY}"
PATH_PATH="${COMMON_PATH}/scripts"

#######################################
# Variables
#######################################
clear_eula=0
clear_patches=0
clear_tee=0

nb_states=0
action_state=1

#######################################
# Functions
#######################################

#######################################
# Print state message on stdout
# Globals:
#   I nb_states
#   I/O action_state
# Arguments:
#   None
# Returns:
#   None
#######################################
state()
{
  echo -ne "  [${action_state}/${nb_states}]: $1 \033[0K\r"
  action_state=$((action_state+1))
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
empty_line()
{
  echo
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
  echo "Usage: $(basename $BASH_SOURCE) [Options] [Exclusive Options]"
  empty_line
  echo "Clear fully or partially the ${SOC_FAMILY} setup for Android"
  echo "By default, the complete stm32mp1 setup is cleared"
  empty_line
  echo "Options:"
  echo "  -h / --help: get current help"
  echo "  -v / --version: get script version"
  echo "  -e / --eula: clear EULA setup (graphics libraries)"
  echo "  -p / --patch: clear patches performed on Android distribution"
  echo "  -t / --tee: clear OP-TEE user modules"
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
warning()
{
  echo "$(tput setaf 3)WARNING: $1$(tput sgr0)"
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
# Main
#######################################

# Check that the current script is not sourced
if [[ "$0" != "$BASH_SOURCE" ]]; then
  empty_line
  error "This script must not be sourced"
  empty_line
  usage
  \popd >/dev/null 2>&1
  return 1
fi

# check the options
while getopts "hvept-:" option; do
  case "${option}" in
    -)
      # Treat long options
      case "${OPTARG}" in
        help)
          usage
          \popd >/dev/null 2>&1
          exit 0
          ;;
        version)
          echo "`basename $0` version ${SCRIPT_VERSION}"
          \popd >/dev/null 2>&1
          exit 0
          ;;
        eula)
          clear_eula=1
          nb_states=$((nb_states+1))
          ;;
        patch)
          clear_patches=1
          nb_states=$((nb_states+1))
          ;;
        tee)
          clear_tee=1
          nb_states=$((nb_states+1))
          ;;
        *)
          usage
          \popd >/dev/null 2>&1
          exit 1
          ;;
      esac;;
    # Treat short options
    h)
      usage
      \popd >/dev/null 2>&1
      exit 0
      ;;
    v)
      echo "`basename $0` version ${SCRIPT_VERSION}"
      \popd >/dev/null 2>&1
      exit 0
      ;;
    e)
      clear_eula=1
      nb_states=$((nb_states+1))
      ;;
    p)
      clear_patches=1
      nb_states=$((nb_states+1))
      ;;
    t)
      clear_tee=1
      nb_states=$((nb_states+1))
      ;;
    *)
      usage
      \popd >/dev/null 2>&1
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

if [ $# -gt 0 ]; then
  error "Unknown command : $*"
  usage
  popd >/dev/null 2>&1
  exit 1
fi

if [[ ${clear_patches} == 0 ]] && [[ ${clear_eula} == 0 ]] && [[ ${clear_tee} == 0 ]]; then
  clear_patches=1
  clear_eula=1
  clear_tee=1
  nb_states=3
fi

# Clear patches
if [[ $clear_patches == 1 ]]; then
  state "Clear patches"

  # Reset all patched directory (remove branches)
  PATCH_CONFIG_PATH=${COMMON_PATH}/patch/android/android_patch.config

  if [ -f "${PATCH_CONFIG_PATH}" ]; then
    while IFS='' read -r line || [[ -n $line ]]; do
      echo $line | grep '^PATCH_PATH' >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        local_path=($(echo $line | awk '{ print $2 }'))
        \repo sync -l ${local_path} >/dev/null 2>&1
      fi
    done < ${PATCH_CONFIG_PATH}

    # Remove patch dependent config file
    \rm -f ${COMMON_PATH}/configs/patch.config
  fi
fi

# Clear EULA setup
if [[ $clear_eula == 1 ]]; then
  state "Clear EULA dependent loaded binaries and sources"

  # Remove EULA dependent loaded source
  EULA_CONFIG_PATH=${COMMON_PATH}/scripts/eula/android_eula.config

  if [ -f "${EULA_CONFIG_PATH}" ]; then
    while IFS='' read -r line || [[ -n $line ]]; do
      echo $line | grep '^EULA_FILE_PATH' >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        local_path=($(echo $line | awk '{ print $2 }'))
        \rm -rf ${local_path}
      fi
    done < ${EULA_CONFIG_PATH}

    # Remove EULA dependent config file
    \rm -f ${COMMON_PATH}/configs/eula.config
  fi
fi

# Clear OP-TEE setup
if [[ $clear_tee == 1 ]]; then
  state "Clear TEE dependent loaded source"

  # Remove OP-TEE dependent loaded source
  OPTEE_CONFIG_PATH=${COMMON_PATH}-tee/source/patch/opteeuser/android_opteeuser.config

  if [ -f "${OPTEE_CONFIG_PATH}" ]; then
    while IFS='' read -r line || [[ -n $line ]]; do
      echo $line | grep '^TEE_FILE_PATH' >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        local_path=($(echo $line | awk '{ print $2 }'))
        \rm -rf ${local_path}
      fi
    done < ${OPTEE_CONFIG_PATH}
  fi

  OPTEE_CONFIG_PATH=${COMMON_PATH}-tee/source/patch/kmgk/android_kmgk.config

  if [ -f "${OPTEE_CONFIG_PATH}" ]; then
    while IFS='' read -r line || [[ -n $line ]]; do
      echo $line | grep '^TEE_FILE_PATH' >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        local_path=($(echo $line | awk '{ print $2 }'))
        \rm -rf ${local_path}
      fi
    done < ${OPTEE_CONFIG_PATH}
  fi

    # Remove OP-TEE dependent config file
    \rm -f ${COMMON_PATH}/configs/teeuser.config

fi

\popd >/dev/null 2>&1
