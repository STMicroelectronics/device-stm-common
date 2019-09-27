#!/bin/bash
#
# Load ARM toolchain

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

TOOLCHAIN_PATH="${TOP_PATH}/prebuilts/gcc/linux-x86/arm/"
TOOLCHAIN_FAMILY_VERSION="8.2-2019.01"
TOOLCHAIN_VERSION=${TOOLCHAIN_FAMILY_VERSION}
TOOLCHAIN_NAME="gcc-arm-${TOOLCHAIN_VERSION}-x86_64-arm-eabi"
TOOLCHAIN_FILE_NAME="${TOOLCHAIN_NAME}.tar.xz"


#######################################
# Variables
#######################################
toolchain_mirror=0

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
  echo "Usage: `basename $0` [Options]"
  empty_line
  echo "  This script allows loading the toolchain version ${TOOLCHAIN_VERSION} used to build the BSP (bootloaders, kernel and tee os)"
  empty_line
  echo "Options:"
  echo "  -h/--help: print this message"
  echo "  -v/--version: get script version"
  echo "  -m/--mirror <directory>: load the toolchain in mirror directory"
  empty_line
}

#######################################
# Main
#######################################

# Check the current usage
if [ $# -gt 3 ]; then
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

    "-m"|"--mirror" )
      toolchain_mirror=1
      toolchain_mirror_path=$2
      shift
      ;;

    ** )
      ;;
  esac
  shift
done

if test `uname -i` != "x86_64"
then
  warning "Your computer is not 64 bits"
fi

if [[ ${toolchain_mirror} == 1 ]]; then

  if [[ ${toolchain_mirror_path} == "" ]]; then
    usage
    \popd >/dev/null 2>&1
    exit 1
  else
    \mkdir -p ${toolchain_mirror_path} >/dev/null 2>&1
    \pushd ${toolchain_mirror_path} >/dev/null 2>&1
    \wget https://developer.arm.com/-/media/Files/downloads/gnu-a/${TOOLCHAIN_FAMILY_VERSION}/${TOOLCHAIN_FILE_NAME}
    \popd >/dev/null 2>&1

    echo "The toolchain has been loaded in mirror directory ${toolchain_mirror_path}"
    empty_line
    echo "Please, add the following line in your .bashrc file:"
    blue "  export TOOLCHAIN_MIRROR=${toolchain_mirror_path}"
    empty_line
  fi
else

  if test -x ${TOOLCHAIN_PATH}/${TOOLCHAIN_NAME}/bin/arm-eabi-gcc
  then
    green "The toolchain has been already installed successfully"
  else
    \pushd ${TOOLCHAIN_PATH}
    blue "The ${TOOLCHAIN_VERSION} toochain has not been installed : Installing..."

    if [ -f ${TOOLCHAIN_MIRROR}/${TOOLCHAIN_FILE_NAME} ]; then
      \cp ${TOOLCHAIN_MIRROR}/${TOOLCHAIN_FILE_NAME} .
    else
      warning "The toolchain mirror directory is not defined, it's recommended to create it"
      \wget https://developer.arm.com/-/media/Files/downloads/gnu-a/${TOOLCHAIN_FAMILY_VERSION}/${TOOLCHAIN_FILE_NAME}
    fi

    echo "Uncompressing toochain archive.... "
    \tar xf ${TOOLCHAIN_FILE_NAME}

    echo "Deleting toochain archive.... "
    \rm ${TOOLCHAIN_FILE_NAME}

    \popd >/dev/null 2>&1
  fi
fi

\popd >/dev/null 2>&1
