#!/bin/bash
#
# Setup ccache

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

SOC_FAMILY="stm32mp1"

if [ -n "${ANDROID_BUILD_TOP+1}" ]; then
  TOP_PATH=${ANDROID_BUILD_TOP}
elif [ -d "device/stm/${SOC_FAMILY}" ]; then
  TOP_PATH=$PWD
else
  echo "ERROR: ANDROID_BUILD_TOP env variable not defined, this script shall be executed on TOP directory"
  return 1
fi

\pushd ${TOP_PATH} >/dev/null 2>&1

#######################################
# Variables
#######################################
machine_ccache=$(uname -s)
machine_ccache=${machine_ccache,,}

#######################################
# Functions
#######################################

#######################################
# Print message if debug is enabled
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
debug_ccache()
{
  test "$DEBUG" == "YES" && echo $*
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
error_ccache()
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
warning_ccache()
{
  echo "$(tput setaf 3)WARNING: $1$(tput sgr0)"
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
usage_ccache()
{
  echo "Usage: source $(basename $BASH_SOURCE) [ccache directory]"
  empty_line
  echo "Setup compilation cache used by Android build"
  empty_line
  echo "ccache directory: ccache directory path [default defined by CCACHE_DIR environment variable]"
  empty_line
}

#######################################
# execute command and check if successfully executed
# Globals:
#   None
# Arguments:
#   $* command which shall be executed
# Returns:
#   None
#######################################
system_ccache()
{
  debug_ccache $*
  $* 2>&1 > /dev/null
  if [ $? -ne 0 ]; then
    warning_ccache "$* : command failed !"
  fi
}

#######################################
# setup ccache
# Globals:
#   O CCACHE_DIR
#   O USE_CCACHE
# Arguments:
#   $* command which shall be executed
# Returns:
#   None
#######################################
ccache_setup()
{
  # for android build chain
  export USE_CCACHE=1

  # The default check uses size and modification time, causing false misses
  # since the mtime depends when the repo was checked out
  export CCACHE_COMPILERCHECK=content

  # strip path in object so that they will be shared between android trees
  export CCACHE_TEMPDIR=/tmp
  test -z "${CCACHE_SIZE}" && CCACHE_SIZE=16G

  if [ ! -d "${CCACHE_DIR}" ]; then
    system_ccache \mkdir -p ${CCACHE_DIR}
  fi

  ${ccache_path} -M ${CCACHE_SIZE}
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
teardown_ccache() {
  unset ccache_path
  unset machine_ccache

  unset -f empty_line
  unset -f usage_ccache
  unset -f error_ccache
  unset -f warning_ccache
  unset -f debug_ccache
  unset -f system_ccache
}

#######################################
# Main
#######################################

# Check that the current script is sourced
if [[ "$0" == "$BASH_SOURCE" ]]; then
  empty_line
  error_ccache "This script must be sourced"
  empty_line
  usage_ccache
  \popd >/dev/null 2>&1
  exit 1
fi

# Check the current usage
if [ $# -gt 2 ]; then
  usage_ccache
  \popd >/dev/null 2>&1
  teardown_ccache
  unset -f teardown_ccache
  return 1
fi

# Check the CCACHE_DIR exist
test -n "$1" && export CCACHE_DIR=$1

if  test -z "${CCACHE_DIR}"
then
  warning_ccache "ccache optimization not activated (CCACHE_DIR not defined)"
  warning_ccache "\tactivate it by setting up CCACHE_DIR before sourcing or use 'ccachesetup <path>'"
  \popd >/dev/null 2>&1
  teardown_ccache
  unset -f teardown_ccache
  return 0
fi

if [ ${machine_ccache} == "linux" ] || [ ${machine_ccache} == "darwin" ]; then
  ccache_path=${TOP_PATH}/prebuilts/misc/${machine_ccache}-x86/ccache/ccache
elif [ ${machine_ccache} == "windows" ];then
  ccache_path=${TOP_PATH}/prebuilts/misc/${machine_ccache}/ccache/ccache
else
  echo "Unrecognized machine ${machine_ccache}, ccache can't be setup"
  teardown_ccache
  unset -f teardown_ccache
  \popd >/dev/null 2>&1
  return 1
fi

ccache_setup

\popd >/dev/null 2>&1

teardown_ccache
unset -f teardown_ccache
