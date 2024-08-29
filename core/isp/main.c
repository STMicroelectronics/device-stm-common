/* SPDX-License-Identifier: BSD-3-Clause */
/*
 * Copyright (C) 2024 ST Microelectronics.
 */

#include <getopt.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "v4l2-controls.h"

#include "stm32-dcmipp-config.h"
#include "dcmipp-isp-ctrl.h"

static void usage(const char *argv0)
{
	printf("%s [options]\n", argv0);
	printf("DCMIPP ISP Control application\n");
	printf("-g, --gain                  Update the Sensor Gain and Exposure (AutoExposure)\n");
	printf("-c, --contrast TYPE         Set the contrast\n");
	printf("                            TYPE  0 : None\n");
	printf("                                  1 :  50%%\n");
	printf("                                  2 : 200%%\n");
	printf("                                  3 : Dynamic\n");
	printf("-i, --illuminant TYPE       Apply settings (black level, color conv, exposure) for a specific illuminant\n");
	printf("                            TYPE  0 : D50 (daylight)\n");
	printf("                                  1 : TL84 (fluo lamp)\n");
	printf("-s, --stat                  Read the stat\n");
	printf("-S, --STAT                  Read the stat continuously\n");
	printf("--help                      Display usage\n");
	printf("-v                          Verbose output\n");
}

static struct option opts[] = {
	{"gain", no_argument, 0, 'g'},
	{"contrast", required_argument, 0, 'c'},
	{"illuminant", required_argument, 0, 'i'},
	{"stat", no_argument, 0, 's'},
	{"STAT", no_argument, 0, 'S'},
	{ },
};

int main(int argc, char *argv[])
{
	static struct isp_descriptor isp_desc;
	int ret, opt;
	bool do_call_stat, do_call_stat_cont;
	struct stm32_dcmipp_stat_buf *stats;
	bool verbose = false;

	if ((argc == 1) || ((argc == 2) && !strcmp(argv[1], "--help"))) {
		usage(argv[0]);
		return 1;
	}

	/*
	 * Detect the verbose -v option
	 * Need to ensure that -v is detected first in order to be able
	 * to give it as option to other functions
	 */
	while ((opt = getopt_long(argc, argv, ":v", opts, NULL)) != -1) {
		switch (opt) {
			case 'v':
				verbose = true;
				break;
			default:
				break;
		}
	}
	optind = 1;

	ret = discover_dcmipp(&isp_desc);
	if (ret)
		return ret;
	if (verbose) {
		printf("DCMIPP ISP information:\n");
		printf(" Media device:		%s\n", isp_desc.media_dev_name);
		printf(" ISP sub-device:	%s\n", isp_desc.isp_subdev_name);
		printf(" ISP stat device:	%s\n", isp_desc.stat_dev_name);
		printf(" ISP params device:	%s\n", isp_desc.params_dev_name);
		printf(" Sensor sub-device:	%s\n", isp_desc.sensor_subdev_name);
		printf(" ISP frame:		%d x %d  -  %s\n", isp_desc.width, isp_desc.height, isp_desc.fmt_str);
		printf("--------------------------------------------------\n\n");
	}

	do_call_stat = false;
	do_call_stat_cont = false;

	while ((opt = getopt_long(argc, argv, "vgc:i:sS", opts, NULL)) != -1) {
		switch (opt) {
		case 'g':
			ret = set_sensor_gain_exposure(&isp_desc, verbose);
			if (ret)
				return ret;
			if (verbose)
				printf("Sensor gain and exposure applied\n");
			break;
		case 'c':
			ret = set_contrast(&isp_desc, atoi(optarg));
			if (ret)
				return ret;
			if (verbose)
				printf("Contrast applied\n");
			break;
		case 'i':
			ret = set_profile(&isp_desc, atoi(optarg));
			if (ret)
				return ret;
			if (verbose)
				printf("Profile applied for BlackLevel, Exposure and ColorConversion\n");
			break;
		case 's':
			do_call_stat = true;
			break;
		case 'S':
			do_call_stat_cont = true;
			break;
		case 'v':
			/* Just to have getopt_long not complain */
			break;
		default:
			printf("Invalid option -%c\n", opt);
			return 1;
		}
	}

	if (do_call_stat) {
		ret = get_stat(&isp_desc, false, &stats, V4L2_STAT_PROFILE_FULL);
		if (ret)
			return 1;
		printf("Location Pre-demosaicing\n");
		print_average(stats->pre.average_RGB);
		print_bins(stats->pre.bins);
		printf("Location Post-demosaicing\n");
		print_average(stats->post.average_RGB);
		print_bins(stats->post.bins);
	} else if (do_call_stat_cont)
		ret = get_stat(&isp_desc, true, NULL, V4L2_STAT_PROFILE_FULL);

	close_dcmipp(&isp_desc);

	return ret;
}
