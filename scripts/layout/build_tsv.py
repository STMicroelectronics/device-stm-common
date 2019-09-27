#!/usr/bin/env python3

"""
Convert Android layout config into CubeProgrammer TSV layout file

Copyright (C)  2019. STMicroelectronics

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
     http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

import sys
import os

usage = ("Convert Android layout config into STM32CubeProgrammer TSV layout file",
         "\nusage : build_tsv [option]",
         "build TSV files in device/stm/stm32mp1/layout/programmer from",
         "android layout located in device/stm/stm32mp1/layout/",
         "[-h]                         : return this help",
         "[<android layout file path>] : build TSV files in the same folder as the one given for android layout")

# List of supported Android partition : if you add a new partition, don't forget to also update tsv_dict
android_allowed_part = ("PART_ATF", "PART_BL33", "PART_TEEH", "PART_TEED", "PART_TEEX", "PART_SPLASH", "PART_BOOT",
                        "PART_DTB", "PART_VENDOR", "PART_MODULE", "PART_SYSTEM", "PART_MISC", "PART_LAST_USERDATA")

# fsbl partitions are going to boot1 and boot2 where size are not configurable
tsv_part_type_dico = {"sd": {"name": "mmc0", "start_addr": 0x00004400},
                      "emmc": {"name": "mmc1", "start_addr": 0x00080000}}


# This header is common for all TSV mapping files and placed at the beginning of the file
tsv_header_file = ("#opt	Id		Name		Type		IP		Offset		Binary",
                   "-		0x01	fsbl-prog	Binary		none	0x00000000	fsbl-programmer.img",
                   "-		0x03	ssbl-prog	Binary		none	0x00000000	ssbl-programmer.img")

# dictionnary which contains some input to build TSV file. When Id is None, Id is incremented in the output file,
# otherwise, use provided value
# To keep all columns aligned, add a tab at the end of the type if needed
tsv_dict = {"fsbl": {"opt": "P", "type": "Binary\t", "id": 0x4},
            "ssbl": {"opt": "P", "type": "Binary\t", "id": None},
            "teeh": {"opt": "P", "type": "Binary\t", "id": 0xA},
            "teed": {"opt": "P", "type": "Binary\t", "id": None},
            "teex": {"opt": "P", "type": "Binary\t", "id": None},
            "splash": {"opt": "P", "type": "Binary\t", "id": 0x10},
            "boot": {"opt": "PE", "type": "System\t", "id": 0x21},
            "dt": {"opt": "PE", "type": "System\t", "id": None},
            "vendor": {"opt": "PE", "type": "FileSystem", "id": None},
            "system": {"opt": "PE", "type": "FileSystem", "id": None},
            "misc": {"opt": "PE", "type": "FileSystem", "id": None},
            "userdata": {"opt": "PE", "type": "FileSystem", "id": 0x30}}


def get_size(android_size: str):
    """
    Compute size in Byte
    :param android_size: size in KiB, MiB or GiB
    :return: size in Byte
    """
    if android_size.isdigit():
        return android_size

    unit = android_size[-1:]
    tsv_size = android_size[:-1]
    if unit == "K":
        return int(tsv_size) * 1024
    elif unit == "M":
        return int(tsv_size) * 1024 * 1024
    elif unit == "G":
        return int(tsv_size) * 1024 * 1024 * 1024

    print("get_size : Error with %s" % android_size, file=sys.stderr)
    return None


def build_tsv(part_list, boot_mode: str = "trusted", memory_type: str = "sd"):
    """
    Build a list of partition compatible with TSV format
    :param part_list: list of partition compatible with Android format
    :param boot_mode: build partition table for optee, or in trusted mode
    :param memory_type: sd (default) or emmc
    :return: a list of partition compatible with TSV format
    """
    tsv_part_list = []
    offset = "0x{:08x}".format(tsv_part_type_dico[memory_type]["start_addr"])
    id = "0" # safer in case of wrong android layout file

    for dict in part_list:
        # do not care about tee partitions if they are not requested
        if not boot_mode == "optee" and dict["part_name"][:-1] == "tee":
            continue

        # compute filename
        if dict["part_name"] == "fsbl":
            filename = "%s-%s.img" % (dict["part_name"], boot_mode)
        elif dict["part_name"] == "ssbl":
            filename = "%s-%s-fb%s.img" % (dict["part_name"], boot_mode, memory_type)
        else:
            filename = "%s.img" % dict["part_name"]

        # Increment partition Id, but if a specific Id is recommended in tsv_dict, use it.
        if tsv_dict[dict["part_name"]]["id"] is None:
            id = "0x{:02x}".format((int(id, 16) + 1))
        else:
            id = "0x{:02x}".format(tsv_dict[dict["part_name"]]["id"])

        # Duplicate partitions if requested (a/b mechanism)
        if dict["part_nb"] == "x2":
            part_name = dict["part_name"] + "_a"
            # To keep all columns aligned, add a tab if needed
            if len(part_name) < 8:
                part_name += "\t"
            if memory_type == "emmc" and dict["part_name"] == "fsbl":
                offset = "boot1\t"

            tsv_part_list.append("%s\t\t%s\t%s\t%s\t%s\t%s\t%s" % (
            tsv_dict[dict["part_name"]]["opt"], id, part_name, tsv_dict[dict["part_name"]]["type"],
            tsv_part_type_dico[memory_type]["name"], offset, filename))

            id = "0x{:02x}".format((int(id, 16) + 1))
            part_name = dict["part_name"] + "_b"
            if len(part_name) < 8:
                part_name += "\t"
            if memory_type == "emmc" and dict["part_name"] == "fsbl":
                offset = "boot2\t"
            else:
                offset = "0x{:08x}".format(int(offset, 0) + get_size(dict["size"]))

            tsv_part_list.append("%s\t\t%s\t%s\t%s\t%s\t%s\t%s" % (
            tsv_dict[dict["part_name"]]["opt"], id, part_name, tsv_dict[dict["part_name"]]["type"],
            tsv_part_type_dico[memory_type]["name"], offset, filename))

        elif dict["part_nb"] == "x1":
            part_name = dict["part_name"]
            if len(part_name) < 8:
                part_name += "\t"
            if memory_type == "emmc" and dict["part_name"] == "fsbl":
                offset = "boot1"
            tsv_part_list.append("%s\t\t%s\t%s\t%s\t%s\t%s\t%s" % (
            tsv_dict[dict["part_name"]]["opt"], id, part_name, tsv_dict[dict["part_name"]]["type"],
            tsv_part_type_dico[memory_type]["name"], offset, filename))

        else:
            print("Number of partition not supported", file=sys.stderr)

        # leave before computing offset of last entry : last partition takes rest of available memory
        if dict["android_name"] == "PART_LAST_USERDATA":
            break

        # increment offset value for the next round
        # fsbl offset is bootX for emmc and can't be incremented, so initialize it hereafter
        if memory_type == "emmc" and dict["part_name"] == "fsbl":
            offset = "0x{:08x}".format(tsv_part_type_dico[memory_type]["start_addr"])
        else:
            offset = "0x{:08x}".format(int(offset, 0) + get_size(dict["size"]))

    return tsv_part_list


def display_usage():
    print("\n".join(usage))
    exit(0)


if len(sys.argv) == 1:
    try:
        android_build_top = os.environ['ANDROID_BUILD_TOP']
    except KeyError:
        print("Android environment not set", file=sys.stderr)
        exit(2)  # error code : 2 : Android environment not set

    android_layout_file_path = "%s/device/stm/stm32mp1/layout/android_layout.config" % android_build_top
    tsv_dir_path = "%s/device/stm/stm32mp1/layout/programmer" % android_build_top

elif len(sys.argv) == 2:
    if sys.argv[-1] == "-h":
        display_usage()
    else:
        android_layout_file_path = sys.argv[1]
        tsv_dir_path = os.path.dirname(os.path.abspath(android_layout_file_path))
else:
    display_usage()

try:
    with open(android_layout_file_path) as android_layout:
        partition_list = []

        for partition in android_layout:

            if partition.startswith("PART"):
                part_desc = partition.split()

                if len(part_desc) == 2:
                    android_name, value = partition.split()
                    if android_name == "PART_MEMORY_TYPE":
                        part_memory_type = value
                    elif android_name == "PART_MEMORY_SIZE":
                        part_memory_size = value

                elif len(part_desc) == 4:
                    android_name, size, part_nb, part_name = partition.split()
                    if android_name in android_allowed_part:
                        partition_list.append(
                            {"android_name": android_name, "size": size, "part_nb": part_nb, "part_name": part_name,
                             "part_ab": None, "part_for_sd": None})

                elif len(part_desc) == 5:
                    android_name, size, part_nb, part_name, part_ab = partition.split()
                    if android_name in android_allowed_part:
                        partition_list.append(
                            {"android_name": android_name, "size": size, "part_nb": part_nb, "part_name": part_name,
                             "part_ab": part_ab, "part_for_sd": None})

                elif len(part_desc) == 6:
                    android_name, size, part_nb, part_name, part_ab, part_for_sd = partition.split()
                    if android_name in android_allowed_part:
                        partition_list.append(
                            {"android_name": android_name, "size": size, "part_nb": part_nb, "part_name": part_name,
                             "part_ab": part_ab, "part_for_sd": part_for_sd})

                else:
                    print("The number of parameter of the partition is not supported", file=sys.stderr)

except FileNotFoundError:
    print("%s not found" % android_layout_file_path, file=sys.stderr)
    exit(1)  # error code : 1 : file note found

with open("%s/FlashLayout_sd_trusted.tsv" % tsv_dir_path, "wt") as tsv_file:
    tsv_partition_list = build_tsv(partition_list)
    print('\n'.join(tsv_header_file), file=tsv_file)
    print('\n'.join(tsv_partition_list), file=tsv_file)

with open("%s/FlashLayout_sd_optee.tsv" % tsv_dir_path, "wt") as tsv_file:
    tsv_partition_list = build_tsv(partition_list, boot_mode="optee")
    print('\n'.join(tsv_header_file), file=tsv_file)
    print('\n'.join(tsv_partition_list), file=tsv_file)

with open("%s/FlashLayout_emmc_trusted.tsv" % tsv_dir_path, "wt") as tsv_file:
    tsv_partition_list = build_tsv(partition_list, memory_type="emmc")
    print('\n'.join(tsv_header_file), file=tsv_file)
    print('\n'.join(tsv_partition_list), file=tsv_file)

with open("%s/FlashLayout_emmc_optee.tsv" % tsv_dir_path, "wt") as tsv_file:
    tsv_partition_list = build_tsv(partition_list, boot_mode="optee", memory_type="emmc")
    print('\n'.join(tsv_header_file), file=tsv_file)
    print('\n'.join(tsv_partition_list), file=tsv_file)
