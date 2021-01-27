#!/bin/bash
#
# Load End User License Agreement (EULA) dependent modules

# Copyright (C)  2019. STMicroelectronics
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
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

COMMON_PATH=${TOP_PATH}/device/stm/${SOC_FAMILY}

EULA_CONFIG_PATH=${COMMON_PATH}/scripts/eula/android_eula.config
EULA_AGREEMENT_PATH=${COMMON_PATH}/scripts/eula/agreements/
EULA_PATCH_PATH=${COMMON_PATH}/scripts/eula/patch/
EULA_CONFIG_STATUS_PATH=${COMMON_PATH}/configs/eula.config

TMP_PATH=device/stm/${SOC_FAMILY}/tmp/

READTIMEOUT=60

GENERIC_MSG=" are covered by an End User License Agreement (EULA). \
To have the right to use these packages in your images, you need to read and accept the following..."

#######################################
# Variables
#######################################

eula_error=0
agreement_file=
agreement_status=0
agreement_accepted=0
output_path=

do_force=0
do_create_git=0

# agreement request is disabled
agreement_requested=0

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
#   I EULA_CONFIG_PATH
# Arguments:
#   None
# Returns:
#   None
#######################################
usage()
{
  echo "Usage: $(basename $BASH_SOURCE) [Options]"
  empty_line
  echo "  This script allows loading files which requires specific End User License Agreement"
  echo "  listed in the following file: $EULA_CONFIG_PATH"
  empty_line
  echo "Options:"
  echo "  -h / --help: print this message"
  echo "  -v / --version: get script version"
  echo "  -f / --force: force EULA dependent libraries load"
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
# Check EULA acceptance status within the status file
# Globals:
#   I EULA_CONFIG_STATUS_PATH
# Arguments:
#   $1: agreement name
# Returns:
#   1 if found agreement acceptance in status file
#   0 if not found
#######################################
check_eula_status()
{
  local loc_eula_status

  \ls ${EULA_CONFIG_STATUS_PATH} >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    loc_eula_status=`grep "$*" $EULA_CONFIG_STATUS_PATH`
    if [[ ${loc_eula_status} =~ "ACCEPTED" ]]; then
      return 1
    fi
  fi
  return 0
}

#######################################
# Ask EULA acceptance for the required agreement
# Globals:
#   I EULA_AGREEMENT_PATH
#   I EULA_CONFIG_STATUS_PATH
#   I READTIMEOUT
# Arguments:
#   $1: message which shall be displayed
# Returns:
#   1 if EULA has been accepted by the user
#   0 if EULA has not been accepted by the user
#######################################
ask_eula_agreement()
{
  local loc_answer
  local loc_agreement_path

  loc_agreement_path=$EULA_AGREEMENT_PATH
  loc_agreement_path+=$agreement_file

  if [[ ${agreement_requested} == "1" ]]; then
    empty_line
    blue "$*"
    empty_line
    echo "To load it you have to accept the following agreement: $loc_agreement_path"
    echo -n "  Do you want to read the agreement ? (y/N)"

    \read -t $READTIMEOUT loc_answer </dev/tty
    if [ "$?" -gt "128" ]; then
      empty_line
      warning "Timeout reached"
      empty_line
    elif (echo -n $loc_answer | grep -q -e "^[yY][a-zA-Z]*$"); then
      empty_line
      \tput setaf 2
      \cat $loc_agreement_path
      \tput sgr 0
      empty_line
    fi

    echo -n "  Do you accept the agreement ? (y/N)"
    \read -t $READTIMEOUT loc_answer </dev/tty
    if [ "$?" -gt "128" ]; then
      empty_line
      warning "Timeout reached, default answer is 'No'"
    elif (echo -n $loc_answer | grep -q -e "^[yY][a-zA-Z]*$"); then
      echo "$agreement_file ACCEPTED" >> $EULA_CONFIG_STATUS_PATH
      return 1
    fi
  else
    # agreement considered automatically accepted
    echo "$agreement_file ACCEPTED" >> $EULA_CONFIG_STATUS_PATH
    return 1
  fi

  eula_error=1
  return 0
}

#######################################
# Extract compressed file within the required directory
# Globals:
#   I TMP_PATH
# Arguments:
#   $1: target directory
#   $2: compressed file name
#   $3: compressed file format (raw, tar-xz or tar-gz)
# Returns:
#   None
#######################################
extract_file()
{
  local loc_file_path
  local loc_tar_file

  loc_file_path=${TMP_PATH}
  loc_file_path+=$2

  case $3 in
    "raw" )
      \cp -rf ${loc_file_path} $1
      ;;
    "tar-xz" )
      loc_tar_file=${loc_file_path}
      loc_tar_file+=".tar.xz"
      \tar -Jxvf ${loc_tar_file} -C ${TMP_PATH} >/dev/null 2>&1
      \cp -rf ${loc_file_path}/* $1
      ;;
    "tar-gz" )
      loc_tar_file=${loc_file_path}
      loc_tar_file+=".tar.gz"
      \tar -zxvf ${loc_tar_file} -C ${TMP_PATH} >/dev/null 2>&1
      \cp -rf ${loc_file_path}/* $1
      ;;
    ** )
      error "Unsupported format"
      ;;
  esac
}

#######################################
# Apply selected patch in current target directory
# Globals:
#   I EULA_PATCH_PATH
# Arguments:
#   $1: patch (file name)
# Returns:
#   None
#######################################
apply_patch()
{
  local loc_patch_path

  loc_patch_path=${EULA_PATCH_PATH}
  loc_patch_path+=$1
  if [ "${1##*.}" != "patch" ];then
    loc_patch_path+=".patch"
  fi

  \pushd ${output_path} >/dev/null 2>&1
  if [[ ${do_create_git} == 1 ]]; then
    \git am ${loc_patch_path} &> /dev/null
    if [ $? -ne 0 ]; then
      error "Not possible to apply patch ${loc_patch_path}, please review android_eula.config"
      \popd >/dev/null 2>&1
      rm -rf ${TMP_PATH}
      exit 1
    fi
  else
    \patch -p1 --merge < ${loc_patch_path} >/dev/null 2>&1
  fi
  \popd >/dev/null 2>&1
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
  return
fi

# check the options
while getopts "hvf-:" option; do
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
          do_force=1
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
      do_force=1
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
  exit 1
fi

# Check availability of the EULA configuration file
if [[ ! -f ${EULA_CONFIG_PATH} ]]; then
  echo "No files required which depends on EULA acceptation"
  \popd >/dev/null 2>&1
  exit 0
fi

# Start EULA config file parsing
while IFS='' read -r line || [[ -n $line ]]; do

  echo $line | grep '^EULA_' >/dev/null 2>&1

  if [ $? -eq 0 ]; then

    line=$(echo "${line: 5}")
    eula_value=($(echo $line | awk '{ print $1 }'))

    if [ ${eula_value} == "AGREEMENT" ]; then
      parsing_step=0
      agreement_status=0
      agreement_file=($(echo $line | awk '{ print $2 }'))
      check_eula_status ${agreement_file} || agreement_status=1

      if [ ${agreement_status} == 1 ] && [ ${do_force} == 0 ]; then
        green "The graphics libraries have been already loaded successfully"
        \popd >/dev/null 2>&1
        exit 0
      fi
    else
      if [ ${agreement_status} == 0 ]; then
        if [ -n "${agreement_file+1}" ]; then
          if [ ${eula_value} == "FILE_MSG" ]; then
            agreement_accepted=0
            \rm -rf ${TMP_PATH}
            eula_message=$(echo "${line: 9}")
            full_message=${eula_message}
            full_message+=${GENERIC_MSG}
            if [ -n "${ANDROID_FORCE_EULA_AGREEMENT+1}" ]; then
              agreement_accepted=1
              echo "${agreement_file} ACCEPTED" >> ${EULA_CONFIG_STATUS_PATH}
              empty_line
              blue "${full_message}"
              empty_line
              green "${agreement_file} is forced accepted"
            else
              ask_eula_agreement "${full_message}" || agreement_accepted=1
            fi
          fi
        fi
      elif [ ${do_force} == 1 ]; then
        # agreement already accepted, force reload
        agreement_accepted=1
      else
        agreement_accepted=0
      fi
          if [ ${agreement_accepted} == 1 ]; then
            case ${eula_value} in
              "GIT_PATH" )
                parsing_step=$((parsing_step+1))
                rm -rf ${TMP_PATH}
                \mkdir -p ${TMP_PATH}
                git_path=($(echo $line | awk '{ print $2 }'))
                echo "  => Loading ${eula_message}"
                \git clone ${git_path} ${TMP_PATH} >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                  error "Not possible to clone module from ${git_path}"
                  sed -n '/${agreement_file}/!p' ${EULA_CONFIG_STATUS_PATH} >/dev/null 2>&1
                fi
                ;;
              "GIT_SHA1" )
                parsing_step=$((parsing_step+1))
                git_sha1=($(echo $line | awk '{ print $2 }'))
                \pushd ${TMP_PATH} >/dev/null 2>&1
                \git checkout ${git_sha1} >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                  error "Not possible to checkout ${git_sha1} for ${git_path}"
                  sed -n '/${agreement_file}/!p' ${EULA_CONFIG_STATUS_PATH}
                fi
                \popd >/dev/null 2>&1
                ;;
              "LOCAL_PATH" )
                parsing_step=$((parsing_step+2))
                local_path=($(echo $line | awk '{ print $2 }'))
                \mkdir -p ${TMP_PATH}
                if [ -d ${local_path} ]; then
                  \cp ${local_path}/* ${TMP_PATH}/
                else
                  error "${local_path} doesn't exist"
                fi
                ;;
              "FILE_PATH" )
                parsing_step=$((parsing_step+1))
                output_path=($(echo $line | awk '{ print $2 }'))
                msg_patch=0
                do_create_git=0
                \rm -rf ${output_path}
                ;;
              "FILE_NAME" )
                parsing_step=$((parsing_step+1))
                file_name=($(echo $line | awk '{ print $2 }'))
                ;;
              "FILE_FORMAT" )
                parsing_step=$((parsing_step+1))
                file_format=($(echo $line | awk '{ print $2 }'))
                ;;
              "PATCH"* )
                patch_path=($(echo $line | awk '{ print $2 }'))
                if [[ ${msg_patch} == 0 ]]; then
                  echo "  => Applying required patches to $output_path"
                  msg_patch=1
                fi
                apply_patch "${patch_path}"
                ;;
              "CREATE_GIT" )
                do_create_git=1
                msg_git="$(echo "${line: 10}")"
                ;;
            esac
            if [[ ${parsing_step} == 5 ]]; then
              parsing_step=2
              mkdir -p ${output_path}
              echo "  => Extracting data to $output_path"
              extract_file ${output_path} ${file_name} ${file_format}
              if [[ ${do_create_git} == 1 ]]; then
                \pushd ${output_path} >/dev/null 2>&1
                \git init >/dev/null 2>&1
                \git commit --allow-empty -m "Initial commit" >/dev/null 2>&1
                \git add . >/dev/null 2>&1
                \git commit -m "${msg_git}" >/dev/null 2>&1
                \popd >/dev/null 2>&1
              fi
            fi
        else
            empty_line
            warning "You have to read and accept agreements to allow loading required modules"
            empty_line
            \popd >/dev/null 2>&1
            exit 1
        fi
      fi
    fi
done < ${EULA_CONFIG_PATH}

\rm -rf ${TMP_PATH}
\popd >/dev/null 2>&1
