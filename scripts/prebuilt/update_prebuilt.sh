#!/bin/bash
#
# Update prebuilt images

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
SCRIPT_VERSION="2.0"

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

#######################################
# Variables
#######################################
kernel_update=0
bootloader_update=0
opteeos_update=0

nb_states=0
action_state=1

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
  echo "Update prebuilt images"
  empty_line
  echo "Options:"
  echo "  -h/--help: get current help"
  echo "  -v/--version: get script version"
  echo "  -k/--kernel: update kernel prebuilts (default all)"
  echo "  -b/--bootloader: update bootloader prebuilts (default all)"
  echo "  -o/--optee: update optee os prebuilts (default all)"
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
# Clear current line in stdout
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
clear_line()
{
  echo -ne "\033[2K"
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
      echo "$(basename $BASH_SOURCE) version ${SCRIPT_VERSION}"
      \popd >/dev/null 2>&1
      exit 0
      ;;

    "-k"|"--kernel" )
      kernel_update=1
      ;;

    "-b"|"--bootloader" )
      bootloader_update=1
      ;;

    "-o"|"--optee" )
      opteeos_update=1
      ;;

    ** )
      usage
      \popd >/dev/null 2>&1
      exit 1
      ;;

  esac
  shift
done

if [[ ${kernel_update} == 0 ]] && [[ ${bootloader_update} == 0 ]] && [[ ${opteeos_update} == 0 ]]; then
  kernel_update=1
  bootloader_update=1
  opteeos_update=1
fi

# build kernel (incl. dtb and modules)
if [[ ${kernel_update} == 1 ]]; then
  empty_line
  green "Build and update images for Linux kernel"
  empty_line
  \build_kernel -i
  empty_line
fi

# build bootloader (TF-A and U-Boot)
if [[ ${bootloader_update} == 1 ]]; then
  # build bootloader
  green "Build and update images for primary and secondary bootloaders"
  empty_line
  \build_bootloader -i
  empty_line

  # build bootloader (programmer images)
  green "Build and update images for primary and secondary bootloaders (programmer images)"
  empty_line
  \build_bootloader -p -i
  empty_line
fi

# build op-tee os and ta
if [[ ${opteeos_update} == 1 ]]; then
  green "Build and update images for TEE OS"
  empty_line
  \build_tee -i
  empty_line
  green "Build TAs"
  \build_ta -i
  empty_line
fi

\popd >/dev/null 2>&1

clear_line
green "The prebuilt images have been updated"
