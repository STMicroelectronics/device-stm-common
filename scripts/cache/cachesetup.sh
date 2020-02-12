#!/bin/bash
#
# Create or Update cache

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

# TODO: add check of cache existence before update
# TODO: check cache creation after execution

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

CACHE_CONFIG_FILE_NAME=android_cache.config
CACHE_CONFIG_PATH=${TOP_PATH}/device/stm/${SOC_FAMILY}/scripts/cache
CACHE_CONFIG_FILE=${CACHE_CONFIG_PATH}/${CACHE_CONFIG_FILE_NAME}

#######################################
# Variables
#######################################
update_cache=0
create_cache=0

force_cache=0
setup_all=1
bypass=0

total_states=0
nb_states=0

config_req=""
config_list=""
env_item=0

#######################################
# Functions
#######################################

#######################################
# Get available configurations from config file
# Globals:
#   I/O config_list
#   I/O total_states
# Arguments:
#   None
# Returns:
#   None
#######################################
get_config_list()
{
  local config_name

  while IFS='' read -r line || [[ -n $line ]]; do

  echo $line | grep "^REPO_CACHE_NAME" &> /dev/null
  if [ $? -eq 0 ]; then
    config_list+=" $(echo $line | awk '{ print $2 }')"
    total_states=$((total_states+1))
  else
    echo $line | grep "^GIT_CACHE_NAME" &> /dev/null
    if [ $? -eq 0 ]; then
      config_list+=" $(echo $line | awk '{ print $2 }')"
      total_states=$((total_states+1))
    fi
  fi
  done < ${CACHE_CONFIG_FILE}
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
# Print script usage on stdout
# Globals:
#   I CACHE_CONFIG_FILE_NAME
#   I config_list
# Arguments:
#   None
# Returns:
#   None
#######################################
usage()
{
  local item

  echo "Usage: `basename $0` [Options] <cache option>"
  empty_line
  echo "Setup (create or update) Git cache based on configuration file ${CACHE_CONFIG_FILE_NAME}"
  empty_line
  echo "Options:"
  echo "  -h/--help: get current help"
  echo "  -v/--version: get script version"
  echo "  or"
  echo "  -u/--update: update cache (default)"
  echo "  or"
  echo "  -f/--force: create cache (force)"
  echo "  -n/--new: create cache (only create non-existing cache)"
  empty_line
  echo "<cache option>:"
  echo "    all (default)"
  echo "  or select list of required cache within the following options:"
  for item in ${config_list}
  do
    echo "    $item"
  done

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
# Print state message on stdout
# Globals:
#   I nb_states
#   I/O action_state
# Arguments:
#   None
# Returns:
#   None
#######################################
action_state=1
state()
{
  echo -ne "  [${action_state}/${nb_states}]: $1 \033[0K\r"
  action_state=$((action_state+1))
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
in_list()
{
  local list="$1"
  local checked_item="$2"

  for item in $list
  do
    if [[ "$item" == "$checked_item" ]]; then
      return 0
    fi
  done;

  return 1
}

#######################################
# Setup cache associated to remote repo manifest
# Globals:
#   I config_req
#   I create_cache
#   I setup_all
#   I/O env_msg
#   I/O env_item
# Arguments:
#   None
# Returns:
#   0 setup error
#   1 setup successfull
#######################################
setup_repo_cache()
{
  local config_name

  local repo_config_name
  local repo_config_remote
  local repo_config_dir
  local repo_config_env
  local bypass

  while IFS='' read -r line || [[ -n $line ]]; do

  echo $line | grep "^REPO_CACHE_" &> /dev/null
  if [ $? -eq 0 ]; then

    config_name="$(echo "${line: 11}" | awk '{ print $1 }')"

    case $config_name in
      "NAME" )
        repo_config_version=""
        repo_config_name="$(echo $line | awk '{ print $2 }')"
        if [[ ${setup_all} == 1 ]] || in_list "${config_req}" "${repo_config_name}"; then
          repo_config_name="$(echo "${line: 16}")"
          if [[ ${create_cache} == 1 ]]; then
            state "Setup ${repo_config_name} (be careful, it can take several hours)"
          else
            state "Update ${repo_config_name}"
          fi
          bypass=0
        else
          # setup not required
          bypass=1
        fi
        ;;
      "OPT" )
        if [[ ${bypass} == 0 ]] && [[ ${setup_all} == 1 ]]; then
          # Optional cache is not treated, except if explicitly required
          bypass=1
        fi
        ;;
      "VERSION" )
        if [[ ${bypass} == 0 ]]; then
          repo_config_version=$(echo $line | awk '{ print $2 }')
        fi
        ;;
      "REMOTE" )
        if [[ ${bypass} == 0 ]]; then
          repo_config_remote=$(echo $line | awk '{ print $2 }')
          if [[ $create_cache == 1 ]]; then
            if [[ "$repo_config_version" == "" ]]; then
              empty_line
              \repo init -u ${repo_config_remote} --mirror >/dev/null 2>&1
              \repo sync -q
            else
              empty_line
              \repo init -u ${repo_config_remote} -b ${repo_config_version} --mirror >/dev/null 2>&1
              \repo sync -q
            fi
          else
            empty_line
            \repo sync -q
          fi
          \popd >/dev/null 2>&1
        fi
        ;;
      "DIR" )
        if [[ ${bypass} == 0 ]]; then
          repo_config_dir=$(echo $line | awk '{ print $2 }')
          if [[ $create_cache == 1 ]]; then
            \rm -rf ${repo_config_dir}
            \mkdir -p ${repo_config_dir} >/dev/null 2>&1
          fi

          if [ -d "${repo_config_dir}" ]; then
            env_msg[${env_item}]="export ${repo_config_env}=\"${repo_config_dir}\""
            env_item=$((env_item+1))

              \pushd ${repo_config_dir} >/dev/null 2>&1
          else
            warning "${repo_config_dir} doesn't exist, you can create ${repo_config_name}"
            bypass=1
          fi
        fi
        ;;
      "ENV" )
        if [[ ${bypass} == 0 ]]; then
          repo_config_env=$(echo $line | awk '{ print $2 }')
          if [ -n "${!repo_config_env+1}" ] && [ ${create_cache} == 1 ]; then
            if [ ${force_cache} == 0 ]; then
              clear_line
              echo "${repo_config_env} already defined for ${repo_config_name}, bypass (use -f option if required)"
              bypass=1
            else
              empty_line
              echo "  ${repo_config_env} is already defined for ${repo_config_name}, do you want to erase existing cache ? (Y/n)"
              read answer </dev/tty
              if test "$answer" == "y" -o "$answer" == "Y"; then
                bypass=0
              else
                bypass=1
              fi
            fi
          fi
          if [ ! -n "${!repo_config_env+1}" ] && [ ${create_cache} == 0 ]; then
            warning "environment variable ${repo_config_env} doesn't exist, bypass update ${repo_config_name}"
            bypass=1
          fi
        fi
        ;;
      ** )
        error "Unknown variable REPO_CACHE_${config_name} in ${CACHE_CONFIG_FILE}"
        return 0
        ;;
    esac
  fi
  done < ${CACHE_CONFIG_FILE}

  return 1
}

#######################################
# Setup cache associated to remote git
# Globals:
#   I config_req
#   I create_cache
#   I setup_all
#   I/O env_msg
#   I/O env_item
# Arguments:
#   None
# Returns:
#   0 setup error
#   1 setup successfull
#######################################
setup_git_cache()
{
  local config_name

  local git_config_name
  local git_config_remote
  local git_config_dir
  local git_config_env
  local bypass

  while IFS='' read -r line || [[ -n $line ]]; do

  echo $line | grep "^GIT_CACHE_" &> /dev/null
  if [ $? -eq 0 ]; then

    config_name="$(echo "${line: 10}" | awk '{ print $1 }')"

    case $config_name in
      "NAME" )
        git_config_name="$(echo $line | awk '{ print $2 }')"
        if [[ ${setup_all} == 1 ]] || in_list "${config_req}" "${git_config_name}"; then
          git_config_name="$(echo "${line: 15}")"
          if [[ ${create_cache} == 1 ]]; then
            state "Setup ${git_config_name} (be careful, it can take several minutes)"
          else
            state "Update ${git_config_name}"
          fi
          bypass=0
        else
          # setup not required
          bypass=1
        fi
        ;;
      "REMOTE" )
        if [[ ${bypass} == 0 ]]; then
          git_config_remote=$(echo $line | awk '{ print $2 }')
          if [[ $create_cache == 1 ]]; then
            \git clone -q --mirror ${git_config_remote} .
          else
            \git remote update
          fi
          \popd >/dev/null 2>&1
        fi
        ;;
      "DIR" )
        if [[ ${bypass} == 0 ]]; then
          git_config_dir=$(echo $line | awk '{ print $2 }')
          if [[ $create_cache == 1 ]]; then
            \mkdir -p ${git_config_dir} >/dev/null 2>&1
            \rm -rf ${git_config_dir}/*
          fi
          if [ -d "${git_config_dir}" ]; then
            env_msg[${env_item}]="export ${git_config_env}=\"${git_config_dir}\""
            env_item=$((env_item+1))
            \pushd ${git_config_dir} >/dev/null 2>&1
          else
            warning "${git_config_dir} doesn't exist, you can create ${git_config_name}"
            bypass=1
          fi
        fi
        ;;
      "ENV" )
        if [[ ${bypass} == 0 ]]; then
          git_config_env=$(echo $line | awk '{ print $2 }')
          if [ -n "${!git_config_env+1}" ] && [ ${create_cache} == 1 ]; then
            if [ ${force_cache} == 0 ]; then
              clear_line
              echo "${git_config_env} already defined for ${git_config_name}, bypass (use -f option if required)"
              bypass=1
            else
              echo "${git_config_env} is already defined for ${git_config_name}, do you want to erase existing cache ? (Y/n)"
              read answer </dev/tty
              if test "$answer" == "y" -o "$answer" == "Y"; then
                bypass=0
              else
                bypass=1
              fi
            fi
          fi
          if [ ! -n "${!git_config_env+1}" ] && [ ${create_cache} == 0 ]; then
            warning "environment variable ${git_config_env} doesn't exist, bypass update ${git_config_name}"
            bypass=1
          fi
        fi
        ;;
      ** )
        error "Unknown variable GIT_CACHE_${config_name} in ${CACHE_CONFIG_FILE}"
        return 0
        ;;
    esac
  fi
  done < ${CACHE_CONFIG_FILE}

  return 1
}

#######################################
# Main
#######################################

if [[ ! -f ${CACHE_CONFIG_FILE} ]]; then
  warning "${CACHE_CONFIG_FILE} not found, try local file ${CACHE_CONFIG_FILE_NAME}"
  if [[ ! -f ${CACHE_CONFIG_FILE_NAME} ]]; then
    error "${CACHE_CONFIG_FILE_NAME} not available"
    \popd >/dev/null 2>&1
    exit 1
  else
    CACHE_CONFIG_FILE=${CACHE_CONFIG_FILE_NAME}
  fi
fi

get_config_list

# Check the current usage
if [ $# -gt 3 ]; then
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

    "-u"|"--update" )
      update_cache=1
      ;;

    "-n"|"--new" )
      create_cache=1
      ;;

    "-f"|"--force" )
      force_cache=1
      ;;

    ** )
      if [[ $arg != "all" ]]; then
        if in_list "${config_list}" "${arg}"; then
          setup_all=0
          nb_states=$((nb_states+1))
          config_req+=" $arg"
        else
          error "invalid arguments = unknown request: ${arg}"
          empty_line
          usage
          \popd >/dev/null 2>&1
          exit 1
        fi
      fi
      ;;

  esac
  shift
done

if [[ ${create_cache} == 1 ]] && [[ ${update_cache} == 1 ]]; then
  error "invalid arguments = exclusive option used: -n|--new and -u|--update"
  empty_line
  usage
  \popd >/dev/null 2>&1
  exit 1
else
  if [[ ${create_cache} == 0 ]] && [[ ${update_cache} == 0 ]]; then
    # set default configuration
    update_cache=1
  fi
fi

if [[ $setup_all == 1 ]]; then
  config_req="${config_list}"
  nb_states=${total_states}
fi

# setup repo cache
if setup_repo_cache; then
  \popd >/dev/null 2>&1
  exit 1
fi

# setup git cache
if setup_git_cache; then
  \popd >/dev/null 2>&1
  exit 1
fi

clear_line

if [[ $create_cache == 1 ]]; then
  green "Required caches (${config_req} ) have been successfully created"

  if [[ ${#env_msg[@]} -gt 0 ]]; then
    echo "Please add following lines in your ~/.bashrc:"
    for msg in "${env_msg[@]}"
    do
      blue " $msg"
    done
  fi
else
  green "Required caches (${config_req} ) have been successfully updated"
fi

\popd >/dev/null 2>&1
