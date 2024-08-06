#!/bin/bash
#
# Clear stm32mp2 bsp setup configuration

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

SOC_FAMILY="stm32mp2"

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

TOOLCHAIN_PATH="${TOP_PATH}/prebuilts/gcc/linux-x86/arm64"
TOOLCHAIN_VERSION="10.3-2021.07"
TOOLCHAIN_NAME="gcc-arm-${TOOLCHAIN_VERSION}-x86_64-aarch64-none-linux-gnu"

#######################################
# Variables
#######################################
clear_toolchain=1

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
  echo "Usage: $(basename $BASH_SOURCE) [Options]"
  empty_line
  echo "Clear fully or partially the ${SOC_FAMILY} BSP setup:"
  echo "  [1] required toolchain for the BSP is removed"
  empty_line
  echo "Options:"
  echo "  -h/--help: get current help"
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

# Check the current usage
if [ $# -gt 2 ]; then
  usage
  \popd >/dev/null 2>&1
  exit 0
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
      echo "$(basename $BASH_SOURCE) version ${SCRIPT_VERSION}"
      \popd >/dev/null 2>&1
      exit 0
      ;;

    ** )
      usage
      \popd >/dev/null 2>&1
      exit 0
      ;;
  esac
  shift
done

# Clear toolchain
if [[ ${clear_toolchain} == 1 ]]; then
  \rm -r ${TOOLCHAIN_PATH}/${TOOLCHAIN_NAME} >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    error "Cannot remove toolchain ${TOOLCHAIN_PATH}/${TOOLCHAIN_NAME}"
  fi
fi

\popd >/dev/null 2>&1
