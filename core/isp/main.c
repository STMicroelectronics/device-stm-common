#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <linux/media.h>
#include <linux/v4l2-subdev.h>
#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include "isp.h"

static void usage(const char *argv0)
{
	printf("%s [options]\n", argv0);
	printf("DCMIPP ISP test application\n");
	printf("-b, --black-level LEVEL     Set the Black Level control\n");
	printf("-B, --BLACK-LEVEL           Read the Black Level control\n");
	printf("-e, --exposure TYPE         Set the exposure\n");
	printf("                            TYPE  0 : None\n");
	printf("                                  1 : Red   x 1.25\n");
	printf("                                  2 : Green x 1.25\n");
	printf("                                  3 : Blue  x 1.25\n");
	printf("                                  4 : R/G/B x 2\n");
	printf("                                  5 : R/G/B x 0.75\n");
	printf("-c, --contrast TYPE         Set the contrast\n");
	printf("                            TYPE  0 : None\n");
	printf("                                  1 :  50%%\n");
	printf("                                  2 : 200%%\n");
	printf("                                  3 : Dynamic\n");
	printf("-x, --color-conv TYPE       Set the color conversion settings\n");
	printf("                            TYPE  0 : Disabled\n");
	printf("                                  1 : Grayscale\n");
	printf("                                  2 : Sepia\n");
	printf("-X, --COLOR-CONV            Read the color conversion settings\n");
	printf("-w, --white-balance         Set the white balance (gray world model)\n");
	printf("-P, --BAD-PIXEL             Read the number of bad pixel\n");
	printf("-p, --bad-pixel LEVEL or *MAX\n");
	printf("                            Set the Bad Pixel level detection\n");
	printf("                            LEVEL 0    Disable detection\n");
	printf("                                  1..8 Detection level\n");
	printf("                            *MAX (eg *200) Find a level which has MAX bad pixels\n");
	printf("-d, --demosaicing-control [p=PEAK] [h=HLINE] [v=VLINE] [e=EDGE]\n");
	printf("                            PEAK  0..7 : Strength of peak detection\n");
	printf("                            HLINE 0..7 : Strength of horizontal line detection\n");
	printf("                            VLINE 0..7 : Strength of vertical line detection\n");
	printf("                            EDGE  0..7 : Strength of edge detection\n");
	printf("-s, --stat                  Read the stat\n");
	printf("-S, --STAT                  Read the stat continuously\n");
	printf("-r, --region TYPE           Set the stat region\n");
	printf("                            TYPE  0 : None\n");
	printf("                                  1 : 320 x 240 @ (160, 120)\n");
	printf("                                  2 :  64 x  64 @ (  0,   0)\n");
	printf("-h, --histogram COMPONENT   Set the component of stat histogram/bin\n");
	printf("                            COMPONENT  R : Red\n");
	printf("                                       G : Green\n");
	printf("                                       B : Blue\n");
	printf("                                       L : Luminance\n");
	printf("-a, --average TYPE          Set the component filter of for stat average\n");
	printf("                            TYPE  0 : None\n");
	printf("                                  1 : Exclude if 16 ≤ component < 240\n");
	printf("                                  2 : Exclude if 32 ≤ component < 224\n");
	printf("                                  3 : Exclude if 64 ≤ component < 192\n");
	printf("-l, --location TYPE         Set the stat capture location\n");
	printf("                            TYPE  0 : Before pixel processing\n");
	printf("                                  1 : After demosaicing\n");
}

static struct option opts[] = {
	{"black-level", required_argument, 0, 'b'},
	{"BLACK-LEVEL", no_argument, 0, 'B'},
	{"exposure", required_argument, 0, 'e'},
	{"contrast", required_argument, 0, 'c'},
	{"color-conv", required_argument, 0, 'x'},
	{"COLOR-CONV", no_argument, 0, 'X'},
	{"white-balance", no_argument, 0, 'w'},
	{"BAD-PIXEL", no_argument, 0, 'P'},
	{"bad-pixel", required_argument, 0, 'p'},
	{"demosaicing-control", required_argument, 0, 'd'},
	{"stat", no_argument, 0, 's'},
	{"STAT", no_argument, 0, 'S'},
	{"region", required_argument, 0, 'r'},
	{"histogram", required_argument, 0, 'h'},
	{"average", required_argument, 0, 'a'},
	{"location", required_argument, 0, 'l'},
	{ },
};

int main(int argc, char *argv[])
{
	static struct isp_descriptor isp_desc = {
		.isp_fd = -1,
		.stat_fd = -1,
	};
	int ret, opt;
	bool do_call_stat, do_call_stat_cont;

	if (argc == 1) {
		usage(argv[0]);
		return 1;
	}

	ret = discover_dcmipp(&isp_desc);
	if (ret)
		return ret;

	do_call_stat = false;
	do_call_stat_cont = false;

	while ((opt = getopt_long(argc, argv, "b:Be:c:x:Xwp:Pd:sSr:h:a:l:", opts, NULL)) != -1) {
		switch (opt) {
		case 'b':
			ret = set_black_level(&isp_desc, atoi(optarg));
			if (ret)
				return ret;
			break;
		case 'B':
			ret = get_black_level(&isp_desc);
			if (ret)
				return ret;
			break;
		case 'e':
			ret = set_exposure(&isp_desc, atoi(optarg), NULL);
			if (ret)
				return ret;
			break;
		case 'c':
			ret = set_contrast(&isp_desc, atoi(optarg));
			if (ret)
				return ret;
			break;
		case 'x':
			ret = set_color_conv(&isp_desc, atoi(optarg));
			if (ret)
				return ret;
			break;
		case 'X':
			ret = get_color_conv(&isp_desc);
			if (ret)
				return ret;
			break;
		case 'w':
			ret = set_white_balance(&isp_desc);
			if (ret)
				return ret;
			break;
		case 'P':
			ret = get_bad_pixel_count(&isp_desc);
			if (ret)
				return ret;
			break;
		case 'p':
			if (optarg[0] == '*')
				ret = set_bad_pixel_target(&isp_desc, atoi(&optarg[1]));
			else
				ret = set_bad_pixel_config(&isp_desc, atoi(optarg));
			if (ret)
				return ret;
			break;
		case 'd':
			ret = set_demosaicing_control(&isp_desc, optarg);
			if (ret)
				return ret;
			break;
		case 's':
			do_call_stat = true;
			break;
		case 'S':
			do_call_stat_cont = true;
			break;
		case 'r':
			ret = set_region(&isp_desc, atoi(optarg));
			if (ret)
				return ret;
			break;
		case 'h':
			ret = set_histo_comp_src(&isp_desc, optarg);
			if (ret)
				return ret;
			break;
		case 'a':
			ret = set_average_filter(&isp_desc, atoi(optarg));
			if (ret)
				return ret;
			break;
		case 'l':
			ret = set_stat_location(&isp_desc, atoi(optarg));
			if (ret)
				return ret;
			break;
		default:
			printf("Invalid option -%c\n", opt);
			return 1;
		}
	}

	if (do_call_stat)
		ret = get_stat(&isp_desc, false, NULL);
	else if (do_call_stat_cont)
		ret = get_stat(&isp_desc, true, NULL);

	close_dcmipp(&isp_desc);

	return ret;
}
