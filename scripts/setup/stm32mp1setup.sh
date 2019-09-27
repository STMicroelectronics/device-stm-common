#!/bin/bash
#
# Setup stm32mp1 required configuration for Android

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
setup_eula=0
setup_tee=0
setup_patches=0

nb_states=0
action_state=1

#######################################
# Functions
#######################################

#######################################
# Print state message on stdout (overwrite current line)
# Globals:
#   I nb_states
#   I/O action_state
# Arguments:
#   None
# Returns:
#   None
#######################################
state_overwrite()
{
  echo -ne "[${action_state}/${nb_states}]: $1 \033[0K\r"
  action_state=$((action_state+1))
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
  echo "[${action_state}/${nb_states}]: $1"
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
  echo "Execute the ${SOC_FAMILY} setup for Android:"
  echo "  [1] patch required modules and/or select specific version"
  echo "  [2] load graphics libraries (associated to End User License Agreement)"
  echo "  [3] load op-tee user modules"
  empty_line
  echo "Options:"
  echo "  -h/--help: get current help"
  echo "  -v/--version: get script version"
  echo "By default, the full setup is executed, it's possible to select one or several states:"
  echo "  -e/--eula: clear EULA setup (graphics libraries)"
  echo "  -p/--patch: clear patches performed on Android distribution"
  echo "  -t/--tee: clear OP-TEE user modules (client and test)"
  empty_line
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
  return
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
      echo "`basename $0` version ${SCRIPT_VERSION}"
      \popd >/dev/null 2>&1
      exit 0
      ;;

    "-e"|"--eula" )
      setup_eula=1
      nb_states=$((nb_states+1))
      ;;

    "-p"|"--patch" )
      setup_patches=1
      nb_states=$((nb_states+1))
      ;;

    "-t"|"--tee" )
      setup_tee=1
      nb_states=$((nb_states+1))
      ;;

    ** )
      usage
      \popd >/dev/null 2>&1
      exit 0
      ;;
  esac
  shift
done

if [[ ${setup_patches} == 0 ]] && [[ ${setup_eula} == 0 ]] && [[ ${setup_tee} == 0 ]]; then
  setup_patches=1
  setup_eula=1
  setup_tee=1
  nb_states=3
fi

if [[ ${setup_patches} == 1 ]]; then
  state "Apply patches"
  \applypatch
fi

if [[ ${setup_eula} == 1 ]]; then
  state "Load graphics libraries"
  \load_eula
fi

if [[ ${setup_tee} == 1 ]]; then
  state "Load op-tee user module sources"
  \load_tee -u
fi

\popd >/dev/null 2>&1
