#!/usr/bin/env bash -e
###############################################################################
# Copyright 2020
# ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
# P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

##############################################################################
# Author: P. Donker
# Purpose:
#   Initialisation script to setup the environment variables for this branch
#

# 
# Make sure it is sourced and no one accidentally gave the script execution rights and just executes it.
if [[ "$_" == "${0}" ]]; then
    echo "ERROR: Use this command with '. ' or 'source '"
    sleep 1
    return
fi

# 
if [ -z "${ALTERA_DIR}" ]; then
    echo "== environ variable 'ALTERA_DIR' not set. =="
    echo "should be in your .bashrc file."
    echo "if it is your .bashrc file but not active run bash in your terminal"
    return
fi

# Figure out where this script is located and set environment variables accordingly
export RADIOHDL_WORK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "HDL environment will be setup for" $RADIOHDL_WORK

# setup paths to build and config dir if not already defined by the user.
export RADIOHDL_BUILD_DIR=${RADIOHDL_WORK}/build
if [[ ! -d "${RADIOHDL_BUILD_DIR}" ]]; then
    echo "make buil dir"
    echo "${RADIOHDL_BUILD_DIR}"
    mkdir "${RADIOHDL_BUILD_DIR}"
fi
# modelsim uses this sim dir for testing
export HDL_IOFILE_SIM_DIR=${RADIOHDL_BUILD_DIR}/sim
if [[ ! -d "${HDL_IOFILE_SIM_DIR}" ]]; then
    echo "make sim dir"
    echo "${HDL_IOFILE_SIM_DIR}"
    mkdir "${HDL_IOFILE_SIM_DIR}"
fi
# if sim dir not empty, remove all files and dirs
if [ ! -z "$(ls -A ${HDL_IOFILE_SIM_DIR})" ]; then
    echo "clear sim dir"
    rm -r ${HDL_IOFILE_SIM_DIR}/*
fi

# copy git user_components.ipx into Altera dir's
for altera_dir in ${ALTERA_DIR}/*; do
    if [[ -d "${altera_dir}" ]] &&  [[ ! -h "${altera_dir}" ]]; then
        echo "copy git hdl_user_components.ipx to ${altera_dir}/ip/altera/user_components.ipx"
        cp ${RADIOHDL_WORK}/quartus/hdl_user_components.ipx $altera_dir/ip/altera/user_components.ipx
    fi
done

# source also radiohdl tool
. ../../git/radiohdl/init_radiohdl.sh
