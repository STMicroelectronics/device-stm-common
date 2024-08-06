#!/bin/bash

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
SCRIPT_VERSION="1.2"

SOC_FAMILY="stm32mp2"

if [ -n "${ANDROID_BUILD_TOP+1}" ]; then
  TOP_PATH=${ANDROID_BUILD_TOP}
elif [ -d "device/stm/${SOC_FAMILY}" ]; then
  TOP_PATH=$PWD
else
  echo "ERROR: ANDROID_BUILD_TOP env variable not defined, this script shall be executed on TOP directory"
  exit 0
fi

\pushd ${TOP_PATH} >/dev/null 2>&1

COMMON_PATH="${TOP_PATH}/device/stm/${SOC_FAMILY}"

PATCH_CONFIG_FILE="android_patch.config"
DEFAULT_PATCH_CONFIG_PATH="${COMMON_PATH}/patch/android/${PATCH_CONFIG_FILE}"

PATCH_STATUS_FILE="${COMMON_PATH}/configs/patch.config"

#######################################
# Variables
#######################################
force_apply=0
apply_error=0
apply_state=0
patch_count=0

patch_config_path=${DEFAULT_PATCH_CONFIG_PATH}

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
#   I patch_config_path
# Arguments:
#   None
# Returns:
#   None
#######################################
usage()
{
  echo "Usage: $(basename $BASH_SOURCE) [Options]"
  empty_line
  echo "Apply patches based on patch configuration file"
  empty_line
  echo "Options:"
  echo "  -h / --help: get current help"
  echo "  -v / --version: get script version"
  echo "  -f / --force: force applying patches"
  echo "  -c <patch config file> / --config=<patch config file>: patch configuration file absolute path [default = ${patch_config_path}]"
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
# Apply selected patch in current target directory
# Globals:
#   I patch_files_path
# Arguments:
#   $1: patch
# Returns:
#   1 if the patch can't be applied (error)
#   0 if the patch has been applied successfully
#######################################
apply_patch()
{
  local loc_patch_path

  loc_patch_path=${patch_files_path}/
  loc_patch_path+=$1
  if [ "${1##*.}" != "patch" ];then
    loc_patch_path+=".patch"
  fi

  \git am ${loc_patch_path} >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    patch -p1 ${loc_patch_path} >/dev/null 2>&1
    if [ $? -ne 0 ]; then
       return 1
    fi
  fi
  return 0
}

#######################################
# Check patch status within the status file
# Globals:
#   I PATCH_STATUS_FILE
# Arguments:
#   $1 version
# Returns:
#   3 if patches has been already applied
#   2 if patches has been already applied with newer version
#   1 if patches has been already applied with older version
#   0 if patches has not been already applied
#######################################
check_patch_status()
{
  local l_patch_status
  local l_patch_version

  \ls ${PATCH_STATUS_FILE}  >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    l_patch_status=$(grep "PATCH ${patch_subdir//-/_}" ${PATCH_STATUS_FILE})
    if [ $? -eq 0 ]; then
    l_patch_version=($(echo ${l_patch_status} | awk '{ print $3 }'))
      if [[ $((l_patch_version)) -eq $((1)) ]]; then
      return 3
      elif [ $((l_patch_version)) -gt $((1)) ]; then
      return 2
      else
        return 1
      fi
    fi
  fi
  return 0
}

#######################################
# Main
#######################################

# Check that the current script is not sourced
if [[ "$0" != "$BASH_SOURCE" ]]; then
  empty_line
  error "This script shall not be sourced"
  empty_line
  usage
  \popd >/dev/null 2>&1
  return
fi

# check the options
while getopts "hvfc:-:" option; do
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
                force)
                    force_apply=1
                    ;;
                config=*)
                    patch_config_path=${OPTARG#*=}
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
        f)
            force_apply=1
            ;;
        c)
            patch_config_path=${OPTARG}
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

if [[ ! -f ${patch_config_path} ]]; then
  error "patch configuration file ${patch_config_path} not found"
  \popd >/dev/null 2>&1
  exit 0
fi

patch_files_path="$(dirname "${patch_config_path}")"
patch_subdir=$(basename "${patch_files_path}")

while IFS='' read -r line || [[ -n $line ]]; do

  echo $line | grep '^PATCH_' &> /dev/null

  if [ $? -eq 0 ]; then

    line=$(echo "${line: 6}")
    patch_value=($(echo $line | awk '{ print $1 }'))

    case ${patch_value} in
      "CONFIG_VERSION" )
        patch_version=($(echo $line | awk '{ print $2 }'))
        if [ ${force_apply} -eq 0 ]; then
          check_patch_status "${patch_version}"
          patch_status=$?
          if [ ${patch_status} -eq 3 ]; then
            green "The required patches have been already applied successfully"
            exit 1
          elif [ ${patch_status} -eq 2 ]; then
            blue "The required patches have been already applied successfully with more recent configuration"
            exit 1
          elif [ ${patch_status} -eq 1 ]; then
            blue "update patches based on new configuration"
          else
            blue "Apply patches based on required configuration"
          fi
        else
          blue "Apply patches based on required configuration (forced mode)"
        fi
      ;;
      "PATH" )

        if [[ ${apply_state} == 1 ]]; then
          \popd >/dev/null 2>&1
        fi
        apply_state=1

        patch_path=($(echo ${line} | awk '{ print $2 }'))
        \repo sync -l ${patch_path} >/dev/null 2>&1

        \pushd ${patch_path} >/dev/null 2>&1

        if [ $? -ne 0 ]; then
          error "$patch_path not found, please review android_patch.config"
          \popd >/dev/null 2>&1
          \popd >/dev/null 2>&1
          exit 0
        fi

        \git reset --hard >/dev/null 2>&1
        \git clean -f -x -d >/dev/null 2>&1

        patch_count=0
      ;;

      "COMMIT" )

        patch_commit=($(echo $line | awk '{ print $2 }'))

        \git checkout ${patch_commit} >/dev/null 2>&1
        if [ $? -ne 0 ]; then
          error "not possible set required commit on $patch_path, please review android_patch.config"
          \popd >/dev/null 2>&1
          \popd >/dev/null 2>&1
          exit 0
        fi
      ;;

      ** )
        ((patch_count++))
        if [ ${patch_value} -eq ${patch_count} ]; then
          patch_file=($(echo $line | awk '{ print $2 }'))
          apply_patch "${patch_file}"
          if [ $? -ne 0 ]; then
            error "not possible to apply ${patch_file} on ${patch_path}"
            \popd >/dev/null 2>&1
            \popd >/dev/null 2>&1
            exit 0
          fi
        else
          error "patch ordering issue ${patch_value} vs ${patch_count} expected"
          \popd >/dev/null 2>&1
          \popd >/dev/null 2>&1
          exit 0
        fi
      ;;
    esac

  fi

done < ${patch_config_path}

if [ ${apply_state} -eq 1 ]; then
  \popd >/dev/null 2>&1
fi

echo "PATCH ${patch_subdir//-/_} ${patch_version}" >> ${PATCH_STATUS_FILE}
