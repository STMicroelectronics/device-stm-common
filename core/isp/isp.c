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

/* BEGIN - videodev.h was upgraded for additional controls. since this is not updated yet in sysroot, add definition here */
#ifndef V4L2_CID_ISP_CONTRAST
#define V4L2_CID_ISP_EXPOSURE			(V4L2_CID_IMAGE_PROC_CLASS_BASE + 6)
/**
 * struct v4l2_ctrl_isp_exposure - Exposure Block control within an ISP
 *
 * @enable: boolean indicating if the exposure compensation should be enabled or not
 * @shift_R: shift for RED component
 * @mult_R: multiply for RED component
 * @shift_G: shift for GREEN component
 * @mult_G: multiply for GREEN component
 * @shift_B: shift for BLUE component
 * @mult_B: multiply for BLUE component
 */
struct v4l2_ctrl_isp_exposure {
	bool enable;
	__u8 shift_R;
	__u8 mult_R;
	__u8 shift_G;
	__u8 mult_G;
	__u8 shift_B;
	__u8 mult_B;
};

#define V4L2_CID_ISP_CONTRAST			(V4L2_CID_IMAGE_PROC_CLASS_BASE + 7)
/**
 * struct v4l2_ctrl_isp_contrast - Contrast Block control within an ISP
 *
 * @enable: boolean indicating if the contrast compensation should be enabled or not
 * @lum: luminance increase value table (9 * 8 bits)
 */
struct v4l2_ctrl_isp_contrast {
	bool enable;
	__u8 lum[9];
};

#define V4L2_CID_ISP_COLOR_CONV			(V4L2_CID_IMAGE_PROC_CLASS_BASE + 8)
/**
 * struct v4l2_ctrl_isp_color_conv - Color Conversion parameters within an ISP
 *
 * @enable: boolean indicating if the color conversion should be enabled or not
 * @clamping: boolean indicating if the converted color shall be clamped or not
 * @clamping_as_rgb: boolean indicating if the clamping applies to RGB color space (YUV otherwise)
 * @coeff: color conversion coefficients of the matrix (RGB 3x3 + 1 offset column)
 */
struct v4l2_ctrl_isp_color_conv {
	bool enable;
	bool clamping;
	bool clamping_as_rgb;
	__u16 coeff[3][4];
};

#define V4L2_CID_ISP_STAT_REGION		(V4L2_CID_IMAGE_PROC_CLASS_BASE + 10)
/**
 * struct v4l2_ctrl_isp_stat_region - Region where ISP statistics are collected
 *
 * @nb_regions: number of regions
 * @top: top coordinate of a region
 * @left: left coordinate of a region
 * @width: width of a region
 * @height: height of a region
 */
struct v4l2_ctrl_isp_stat_region {
	__u8 nb_regions;
	__u32 top[25];
	__u32 left[25];
	__u32 width[25];
	__u32 height[25];
};

#define V4L2_CID_ISP_STAT_LOCATION		(V4L2_CID_IMAGE_PROC_CLASS_BASE + 11)
enum v4l2_isp_stat_location {
	V4L2_STAT_LOCATION_BEFORE_PROC	= 0,
	V4L2_STAT_LOCATION_AFTER_DEMO	= 1,
};

#define V4L2_CID_ISP_STAT_AVG_FILTER		(V4L2_CID_IMAGE_PROC_CLASS_BASE + 12)
enum v4l2_isp_stat_avg_filter {
	V4L2_STAT_AVG_FILTER_NONE	= 0,
	V4L2_STAT_AVG_FILTER_EXCL16	= 1,
	V4L2_STAT_AVG_FILTER_EXCL32	= 2,
	V4L2_STAT_AVG_FILTER_EXCL64	= 3,
};

#define V4L2_CID_ISP_STAT_BIN_COMP		(V4L2_CID_IMAGE_PROC_CLASS_BASE + 13)
enum v4l2_isp_stat_bin_comp {
	V4L2_STAT_BIN_COMP_R		= 0,
	V4L2_STAT_BIN_COMP_G		= 1,
	V4L2_STAT_BIN_COMP_B		= 2,
	V4L2_STAT_BIN_COMP_L		= 3,
};

#define V4L2_META_FMT_ST_ISP_STAT v4l2_fourcc('S', 'T', 'I', 'S') /* STM32 ISP Statistics */
#endif /* V4L2_CID_ISP_CONTRAST */

struct stm32_dcmipp_pixelstat_buf {
	/*
	 * TODO - we should have a field indicating which data is the
	 * latest, and also maybe all valid fields.  Another idea could be
	 * to avoid output of the buffer until we have perform a first loop
	 * on the capture state so that we are sure we have a valid value
	 * for all statistics
	 */
	__u32 average_RGB[3];
	__u32 bins[12];
} __packed;

/* END - videodev.h was upgraded for additional controls. since this is not updated yet in sysroot, add definition here */

#define DCMIPP_ISP_NAME				"dcmipp_main_isp"
#define DCMIPP_ISP_STAT_NAME		"dcmipp_main_isp_stat_capture"

#define DCMIPP_DRV					"dcmipp"

#define V4L2_CID_ISP_DEMOSAICING_PEAK	(V4L2_CID_USER_BASE | 0x1001)
#define V4L2_CID_ISP_DEMOSAICING_LINEH	(V4L2_CID_USER_BASE | 0x1002)
#define V4L2_CID_ISP_DEMOSAICING_LINEV	(V4L2_CID_USER_BASE | 0x1003)
#define V4L2_CID_ISP_DEMOSAICING_EDGE	(V4L2_CID_USER_BASE | 0x1004)
#define V4L2_CID_ISP_BLACKLEVEL		(V4L2_CID_USER_BASE | 0x1005)
#define V4L2_CID_ISP_BAD_PIXEL		(V4L2_CID_USER_BASE | 0x1006)
#define V4L2_CID_ISP_BAD_PIXEL_COUNT	(V4L2_CID_USER_BASE | 0x1007)

#define BAD_PIXEL_MAX_LEVEL		8

static int clamp(int val, int lo, int hi)
{
	if (val < lo)
		return lo;
	else if (val > hi)
		return hi;
	else
		return val;
}

static int find_stat_dev(struct isp_descriptor *isp_desc)
{
	struct media_entity_desc info;
	struct stat devstat;
	char dev_name[32];
	int fd, i, ret;
	__u32 id;

	fd = open(isp_desc->media_dev_name, O_RDWR);
	if (fd < 0)
		return fd;

	for (id = 0, ret = 0; ; id = info.id) {
		/* Search across all the entities */
		info.id = id | MEDIA_ENT_ID_FLAG_NEXT;
		ret = ioctl(fd, MEDIA_IOC_ENUM_ENTITIES, &info);
		if (ret < 0)
			break;

		if (!strcmp(info.name, DCMIPP_ISP_STAT_NAME)) {
			/* isp entity found. Now search for its /dev/v4l-subdevx */
			for (i = 0; i < 255; i++) {
				/* check for a sub dev that matches the major/minor */
				sprintf(dev_name, "/dev/video%d", i);
				if (stat(dev_name, &devstat) < 0)
					continue;

				if ((major(devstat.st_rdev) == info.dev.major) &&
				    (minor(devstat.st_rdev) == info.dev.minor)) {
					/* found */
					strcpy(isp_desc->stat_dev_name, dev_name);
					close(fd);
					return 0;
				}
			}
		}
	}

	close(fd);
	printf("Can't find isp subdev\n");
	return -ENXIO;
}

static int find_isp_subdev(struct isp_descriptor *isp_desc)
{
	struct media_entity_desc info;
	struct stat devstat;
	char dev_name[32];
	int fd, i, ret;
	__u32 id;

	fd = open(isp_desc->media_dev_name, O_RDWR);
	if (fd < 0)
		return fd;

	for (id = 0, ret = 0; ; id = info.id) {
		/* Search across all the entities */
		info.id = id | MEDIA_ENT_ID_FLAG_NEXT;
		ret = ioctl(fd, MEDIA_IOC_ENUM_ENTITIES, &info);
		if (ret < 0)
			break;

		if (!strcmp(info.name, DCMIPP_ISP_NAME)) {
			/* isp entity found. Now search for its /dev/v4l-subdevx */
			for (i = 0; i < 255; i++) {
				/* check for a sub dev that matches the major/minor */
				sprintf(dev_name, "/dev/v4l-subdev%d", i);
				if (stat(dev_name, &devstat) < 0)
					continue;

				if ((major(devstat.st_rdev) == info.dev.major) &&
				    (minor(devstat.st_rdev) == info.dev.minor)) {
					/* found */
					strcpy(isp_desc->isp_subdev_name, dev_name);
					close(fd);
					return 0;
				}
			}
		}
	}

	close(fd);
	printf("Can't find isp subdev\n");
	return -ENXIO;
}

static int find_media(struct isp_descriptor *isp_desc)
{
	struct media_device_info info;
	char media_dev_name[32];
	int ret, fd, i;

	for (i = 0; i < 255; i++) {
		/* Search for the dcmipp media */
		sprintf(media_dev_name, "/dev/media%d", i);
		fd = open(media_dev_name, O_RDWR);
		if (fd < 0)
			continue;

		ret = ioctl(fd, MEDIA_IOC_DEVICE_INFO, &info);
		close(fd);

		if (!ret && !strcmp(info.driver, DCMIPP_DRV)) {
			/* dcmipp found */
			strcpy(isp_desc->media_dev_name, media_dev_name);
			return 0;
		}
	}

	printf("Can't find media device\n");
	return -ENXIO;
}

static int open_isp_subdev(struct isp_descriptor *isp_desc)
{
	int ret;

	isp_desc->isp_fd = open(isp_desc->isp_subdev_name, O_RDWR);
	if (isp_desc->isp_fd == -1) {
		ret = -errno;
		printf("Failed to open isp subdev %s\n", isp_desc->isp_subdev_name);
		return ret;
	}

	return 0;
}

static void close_isp_subdev(struct isp_descriptor *isp_desc)
{
	close(isp_desc->isp_fd);
	isp_desc->isp_fd = -1;
}

static int open_stat_dev(struct isp_descriptor *isp_desc)
{
	int ret;

	isp_desc->stat_fd = open(isp_desc->stat_dev_name, O_RDWR);
	if (isp_desc->stat_fd == -1) {
		ret = -errno;
		printf("Failed to open isp subdev %s\n", isp_desc->stat_dev_name);
		return ret;
	}

	return 0;
}

static void close_stat_dev(struct isp_descriptor *isp_desc)
{
	close(isp_desc->stat_fd);
	isp_desc->stat_fd = -1;
}

static void to_fmt_str(char *fmt_str, int fmt)
{
	if (fmt >= MEDIA_BUS_FMT_SBGGR8_1X8 && fmt <= MEDIA_BUS_FMT_SRGGB16_1X16)
		strcpy(fmt_str, "Raw Bayer");
	else if (fmt == MEDIA_BUS_FMT_RGB565_2X8_LE)
		strcpy(fmt_str, "RGB565");
	else if (fmt == MEDIA_BUS_FMT_RGB888_1X24)
		strcpy(fmt_str, "RGB888");
	else if (fmt == MEDIA_BUS_FMT_YUV8_1X24)
		strcpy(fmt_str, "YUV 420");
	else if (fmt >= MEDIA_BUS_FMT_UYVY8_2X8 && fmt <= MEDIA_BUS_FMT_YVYU8_2X8)
		strcpy(fmt_str, "YUV 422");
	else
		sprintf(fmt_str, "Format = 0x%x", fmt);
}

int discover_dcmipp(struct isp_descriptor *isp_desc)
{
	struct v4l2_subdev_selection sel;
	struct v4l2_subdev_format fmt;
	int ret;

	/* find dcmipp media dev */
	ret = find_media(isp_desc);
	if (ret)
		return ret;

	/* find isp sub dev */
	ret = find_isp_subdev(isp_desc);
	if (ret)
		return ret;

	/* find stat video dev */
	ret = find_stat_dev(isp_desc);
	if (ret)
		return ret;

	/* Get input frame params */
	ret = open_isp_subdev(isp_desc);
	if (ret)
		return ret;

	fmt.which = V4L2_SUBDEV_FORMAT_ACTIVE;
	fmt.pad = 0;
	ret = ioctl(isp_desc->isp_fd, VIDIOC_SUBDEV_G_FMT, &fmt);
	if (ret) {
		printf("Failed to get format\n");
		return ret;
	}
	isp_desc->fmt = fmt.format.code;
	to_fmt_str(isp_desc->fmt_str, isp_desc->fmt);

	sel.which = V4L2_SUBDEV_FORMAT_ACTIVE;
	sel.pad = 0;
	sel.target = V4L2_SEL_TGT_COMPOSE;
	ret = ioctl(isp_desc->isp_fd, VIDIOC_SUBDEV_G_SELECTION, &sel);
	if (ret) {
		printf("Failed to get selection\n");
		return ret;
	}
	isp_desc->width = sel.r.width;
	isp_desc->height = sel.r.height;

	printf("DCMIPP ISP information:\n");
	printf(" Media device:		%s\n", isp_desc->media_dev_name);
	printf(" ISP sub-device:	%s\n", isp_desc->isp_subdev_name);
	printf(" ISP stat device:	%s\n", isp_desc->stat_dev_name);
	printf(" ISP frame:		%d x %d  -  %s\n", isp_desc->width, isp_desc->height, isp_desc->fmt_str);
	printf("--------------------------------------------------\n\n");

	ret = open_stat_dev(isp_desc);
	if (ret)
		return ret;

	return 0;
}

void close_dcmipp(struct isp_descriptor *isp_desc)
{
	close_stat_dev(isp_desc);
	close_isp_subdev(isp_desc);
}

static int set_ext_ctrl(int fd, struct v4l2_ext_controls *extCtrls)
{
	int ret;

	ret = ioctl(fd, VIDIOC_S_EXT_CTRLS, extCtrls);
	if (ret)
		printf("VIDIOC_S_EXT_CTRLS setting failed (CID %x)\n", extCtrls->controls->id);

	return ret;
}

static int set_ext_ctrl_user_int(int fd, int v4l2_cid, int value)
{
	struct v4l2_ext_controls extCtrls;
	struct v4l2_ext_control extCtrl;

	memset(&extCtrl, 0, sizeof(struct v4l2_ext_control));
	extCtrl.id = v4l2_cid;
	extCtrl.value = value;

	extCtrls.controls = &extCtrl;
	extCtrls.count = 1;
	extCtrls.ctrl_class = V4L2_CTRL_CLASS_USER;

	return set_ext_ctrl(fd, &extCtrls);
}

static int set_ext_ctrl_imgproc_int(int fd, int v4l2_cid, int value)
{
	struct v4l2_ext_controls extCtrls;
	struct v4l2_ext_control extCtrl;

	memset(&extCtrl, 0, sizeof(struct v4l2_ext_control));
	extCtrl.id = v4l2_cid;
	extCtrl.value = value;

	extCtrls.controls = &extCtrl;
	extCtrls.count = 1;
	extCtrls.ctrl_class = V4L2_CTRL_CLASS_IMAGE_PROC;

	return set_ext_ctrl(fd, &extCtrls);
}

static int set_ext_ctrl_imgproc_ptr(int fd, int v4l2_cid, void *ptr, int ptr_size)
{
	struct v4l2_ext_controls extCtrls;
	struct v4l2_ext_control extCtrl;

	memset(&extCtrl, 0, sizeof(struct v4l2_ext_control));
	extCtrl.id = v4l2_cid;
	extCtrl.size = ptr_size;
	extCtrl.ptr = ptr;

	extCtrls.controls = &extCtrl;
	extCtrls.count = 1;
	extCtrls.ctrl_class = V4L2_CTRL_CLASS_IMAGE_PROC;

	return set_ext_ctrl(fd, &extCtrls);
}

static int get_ext_ctrl(int fd, struct v4l2_ext_controls *extCtrls)
{
	int ret;

	ret = ioctl(fd, VIDIOC_G_EXT_CTRLS, extCtrls);
	if (ret)
		printf("VIDIOC_G_EXT_CTRLS setting failed (CID %x)\n", extCtrls->controls->id);

	return ret;
}

static int get_ext_ctrl_user_int(int fd, int v4l2_cid, int *value)
{
	struct v4l2_ext_controls extCtrls;
	struct v4l2_ext_control extCtrl;
	int ret;

	memset(&extCtrl, 0, sizeof(struct v4l2_ext_control));
	extCtrl.id = v4l2_cid;

	extCtrls.controls = &extCtrl;
	extCtrls.count = 1;
	extCtrls.ctrl_class = V4L2_CTRL_CLASS_USER;

	ret = get_ext_ctrl(fd, &extCtrls);
	*value = extCtrl.value;

	return ret;
}

static int get_ext_ctrl_imgproc_ptr(int fd, int v4l2_cid, void *ptr, int ptr_size)
{
	struct v4l2_ext_controls extCtrls;
	struct v4l2_ext_control extCtrl;

	memset(&extCtrl, 0, sizeof(struct v4l2_ext_control));
	extCtrl.id = v4l2_cid;
	extCtrl.ptr = ptr;
	extCtrl.size = ptr_size;

	extCtrls.controls = &extCtrl;
	extCtrls.count = 1;
	extCtrls.ctrl_class = V4L2_CTRL_CLASS_IMAGE_PROC;

	return get_ext_ctrl(fd, &extCtrls);
}

int set_black_level(struct isp_descriptor *isp_desc, int level)
{
	int ret;

	ret = set_ext_ctrl_user_int(isp_desc->isp_fd, V4L2_CID_ISP_BLACKLEVEL, level);
	if (ret)
		printf("Failed to apply Black Level\n");
	else
		printf("Black Level applied\n");

	return ret;
}

int get_black_level(struct isp_descriptor *isp_desc)
{
	int ret, level;

	ret = get_ext_ctrl_user_int(isp_desc->isp_fd, V4L2_CID_ISP_BLACKLEVEL, &level);
	if (!ret)
		printf("Read Black Level : %d\n", level);
	else
		printf("Failed to read Black Level\n");

	return ret;
}

int set_demosaicing_control(struct isp_descriptor *isp_desc, char *optarg)
{
	char controls[4][20] = { "peak", "hline", "vline", "edge" };
	char *control;
	int ret, strength, cid = 0;

	if (!strncmp(optarg, "p=", 2))
		cid = V4L2_CID_ISP_DEMOSAICING_PEAK;
	else if (!strncmp(optarg, "h=", 2))
		cid = V4L2_CID_ISP_DEMOSAICING_LINEH;
	else if (!strncmp(optarg, "v=", 2))
		cid = V4L2_CID_ISP_DEMOSAICING_LINEV;
	else if (!strncmp(optarg, "e=", 2))
		cid = V4L2_CID_ISP_DEMOSAICING_EDGE;

	if (!cid) {
		printf("Unknown demosaicing control : %s\n", optarg);
		return -EINVAL;
	}

	control = controls[cid - V4L2_CID_ISP_DEMOSAICING_PEAK];
	strength = atoi(&optarg[2]);

	ret = set_ext_ctrl_user_int(isp_desc->isp_fd, cid, strength);
	if (ret)
		printf("Failed to apply %s demosaicing control\n", control);
	else
		printf("%s demosaicing control applied\n", control);

	return ret;
}

int get_bad_pixel_count(struct isp_descriptor *isp_desc)
{
	int ret, count;

	ret = get_ext_ctrl_user_int(isp_desc->isp_fd, V4L2_CID_ISP_BAD_PIXEL_COUNT, &count);
	if (!ret)
		printf("Bad pixels : %d\n", count);
	else
		printf("Failed to get bad pixels count\n");

	return ret;
}

int set_bad_pixel_config(struct isp_descriptor *isp_desc, int level)
{
	int ret;

	ret = set_ext_ctrl_user_int(isp_desc->isp_fd, V4L2_CID_ISP_BAD_PIXEL, level);
	if (ret)
		printf("Failed to apply Bad Pixel Configuration\n");
	else
		printf("Bad Pixel Configuration applied\n");

	return ret;
}

int set_bad_pixel_target(struct isp_descriptor *isp_desc, int target)
{
	int i, ret, level, count, average, target_level;

	printf(" Looking for level with %d bad pixel max\n", target);

	target_level = BAD_PIXEL_MAX_LEVEL;

	for (level = 1; level <= BAD_PIXEL_MAX_LEVEL; level++) {
		/* Set bad pixel level */
		ret = set_ext_ctrl_user_int(isp_desc->isp_fd, V4L2_CID_ISP_BAD_PIXEL, level);
		if (ret) {
			printf("Failed to apply Bad Pixel Configuration\n");
			goto out;
		}

		/* Average measruement */
		average = 0;
		for (i = 0; i < 10; i++) {
			/* Wait for next frame and check number of bad pixels for that level */
			usleep(100 * 1000);
			ret = get_ext_ctrl_user_int(isp_desc->isp_fd, V4L2_CID_ISP_BAD_PIXEL_COUNT, &count);
			if (ret) {
				printf("Failed to get bad pixels count\n");
				goto out;
			}
			average += count;
		}
		average /= 10;
		printf("\tLevel %d has %d bad pixels\n", level, average);

		/* Exit if target reached */
		if (average > target) {
			target_level = level ? level - 1 : 0;
			break;
		}
	}

	/* Apply the found level */
	ret = set_ext_ctrl_user_int(isp_desc->isp_fd, V4L2_CID_ISP_BAD_PIXEL, target_level);
	if (ret) {
		printf("Failed to apply Bad Pixel Configuration\n");
		goto out;
	}
	printf(" Applying level %d\n", target_level);
out:
	return ret;
}

int set_exposure(struct isp_descriptor *isp_desc, int type, struct v4l2_ctrl_isp_exposure *exposure_wb)
{
	struct v4l2_ctrl_isp_exposure exposure;
	int ret;

	switch (type) {
	case 0:
		exposure.enable = false;
		/* Disabled */
		break;
	case 1:
		/* Red = x1.25 */
		exposure.enable = true;
		exposure.shift_R = 0;
		exposure.shift_G = 0;
		exposure.shift_B = 0;
		exposure.mult_R = 160;
		exposure.mult_G = 128;
		exposure.mult_B = 128;
		break;
	case 2:
		/* Green = x1.25  */
		exposure.enable = true;
		exposure.shift_R = 0;
		exposure.shift_G = 0;
		exposure.shift_B = 0;
		exposure.mult_R = 128;
		exposure.mult_G = 160;
		exposure.mult_B = 128;
		break;
	case 3:
		/* Blue = x1.25 */
		exposure.enable = true;
		exposure.shift_R = 0;
		exposure.shift_G = 0;
		exposure.shift_B = 0;
		exposure.mult_R = 128;
		exposure.mult_G = 128;
		exposure.mult_B = 160;
		break;
	case 4:
		/* R/G/B = x2 */
		exposure.enable = true;
		exposure.shift_R = 1;
		exposure.shift_G = 1;
		exposure.shift_B = 1;
		exposure.mult_R = 128;
		exposure.mult_G = 128;
		exposure.mult_B = 128;
		break;
	case 5:
		/* R/G/B = x0.75 */
		exposure.enable = true;
		exposure.shift_R = 0;
		exposure.shift_G = 0;
		exposure.shift_B = 0;
		exposure.mult_R = 96;
		exposure.mult_G = 96;
		exposure.mult_B = 96;
		break;
	case -1:
		/* Customized (eg white balance) */
		exposure = *exposure_wb;
		break;
	default:
		printf("Unknwon exposure type (%d)\n", type);
		return -EINVAL;
	}

	ret = set_ext_ctrl_imgproc_ptr(isp_desc->isp_fd, V4L2_CID_ISP_EXPOSURE, &exposure, sizeof(exposure));
	if (ret)
		printf("Failed to apply exposure\n");
	else
		printf("Exposure applied\n");

	return ret;
}

int set_contrast(struct isp_descriptor *isp_desc, int type)
{
	struct v4l2_ctrl_isp_contrast contrast;
	__u8 dynamic[9] = { 32, 32, 32, 27, 23, 20, 18, 17, 16 };

	int i, ret;

	switch (type) {
	case 0:
		contrast.enable = false;
		/* Disabled */
		break;
	case 1:
		/* 50% */
		contrast.enable = true;
		for (i = 0; i < 9; i++)
			contrast.lum[i] = 8;
		break;
	case 2:
		/* 200% */
		contrast.enable = true;
		for (i = 0; i < 9; i++)
			contrast.lum[i] = 32;
		break;
	case 3:
		/* Dynamic */
		contrast.enable = true;
		memcpy(contrast.lum, dynamic, sizeof(dynamic));
		break;
	default:
		printf("Unknwon contrast type (%d)\n", type);
		return -EINVAL;
	}

	ret = set_ext_ctrl_imgproc_ptr(isp_desc->isp_fd, V4L2_CID_ISP_CONTRAST, &contrast, sizeof(contrast));
	if (ret)
		printf("Failed to apply contrast\n");
	else
		printf("Contrast applied\n");

	return ret;
}

int set_color_conv(struct isp_descriptor *isp_desc, int type)
{
	/* Grayscale:
	 *  R = G = B = 0.299R + 0.587G + 0.114B */
	__u16 gray_coeff[3][4] =
		{ {  76, 150,  29,   0 },
		  {  76, 150,  29,   0 },
		  {  76, 150,  29,   0 } };
	/* Sepia:
	 *  R = 0.393R + 0.769G + 0.189B
	 *  G = 0.349R + 0.686G + 0.168B
	 *  B = 0.272R + 0.534G + 0.131B
	 * And clamp values
	 */
	__u16 sepia_coeff[3][4] =
		{ { 101, 197,  48,   0 },
		  {  89, 176,  43,   0 },
		  {  70, 137,  33,   0 } };
	struct v4l2_ctrl_isp_color_conv cconv;
	int ret;

	switch (type) {
	case 0:
		/* Disabled */
		cconv.enable = false;
		break;
	case 1:
		/* Grayscale */
		cconv.enable = true;
		cconv.clamping = false;
		memcpy(cconv.coeff, gray_coeff, sizeof(cconv.coeff));
		break;
	case 2:
		/* Sepia */
		cconv.enable = true;
		cconv.clamping = true;
		cconv.clamping_as_rgb = true;
		memcpy(cconv.coeff, sepia_coeff, sizeof(cconv.coeff));
		break;
	default:
		printf("Unknwon color conv type (%d)\n", type);
		return -EINVAL;
	}

	ret = set_ext_ctrl_imgproc_ptr(isp_desc->isp_fd, V4L2_CID_ISP_COLOR_CONV, &cconv, sizeof(cconv));
	if (ret)
		printf("Failed to apply color conversion\n");
	else
		printf("Color conversion applied\n");

	return ret;
}

int get_color_conv(struct isp_descriptor *isp_desc)
{
	struct v4l2_ctrl_isp_color_conv cconv;
	int i, j, ret;

	ret = get_ext_ctrl_imgproc_ptr(isp_desc->isp_fd, V4L2_CID_ISP_COLOR_CONV, &cconv, sizeof(cconv));
	if (!ret) {
		printf(" Color Conversion %s\n", cconv.enable ? "enabled" : "disabled");
		if (cconv.enable) {
			for (i = 0; i < 3; i++) {
				printf(" [ ");
				for (j = 0; j < 4; j++)
					printf("%4d ", cconv.coeff[i][j]);
				printf("]\n");
			}
			printf(" Clamping %s", cconv.clamping ? "enabled" : "disabled");
			if (cconv.clamping)
				printf(" (%s)", cconv.clamping_as_rgb ? "RGB" : "YUV");
			printf("\n");
		}
	} else {
		printf("Failed to get color conversion setting\n");
	}

	return ret;
}

static void print_range(int min, int max, int val, int nb_pix, char histo[20][32])
{
	printf("    [%3d:%3d]   %7d\t%2d%%   %s\n", min, max, val, 100 * val / nb_pix, histo[clamp(20 * val / nb_pix, 0, 19)]);
}

int get_stat(struct isp_descriptor *isp_desc, bool loop, __u32 average[3])
{
	struct stm32_dcmipp_pixelstat_buf *buffers[4];
	struct v4l2_requestbuffers req;
	struct v4l2_capability cap;
	enum v4l2_buf_type type;
	struct v4l2_format fmt;
	struct v4l2_buffer buf;
	struct timeval tv;
	size_t buflen = 0;
	fd_set fds;
	int range0, range4, range8, range16, range32, range64;
	int range128, range192, range224, range240, range248, range252;
	char histo[20][32];
	int i, ret, nb_pix;

	for (i = 0; i < 20; i++) {
		strcpy(histo[i], "--------------------");
		histo[i][i + 1] = '\0';
	}

	ret = ioctl(isp_desc->stat_fd, VIDIOC_QUERYCAP, &cap);
	if (ret) {
		printf("Failed to query cap\n");
		return ret;
	}

	if ((!(cap.capabilities & V4L2_CAP_META_CAPTURE)) || (!(cap.capabilities & V4L2_CAP_STREAMING))) {
		printf("Incorrect capabilities (%x)\n", cap.capabilities);
		return -ENXIO;
	}

	fmt.type = V4L2_BUF_TYPE_META_CAPTURE;
	ret = ioctl(isp_desc->stat_fd, VIDIOC_G_FMT, &fmt);
	if (ret) {
		printf("Failed to get format\n");
		return ret;
	}

	if (fmt.fmt.meta.dataformat != V4L2_META_FMT_ST_ISP_STAT) {
		printf("Invalid format (%x)\n", fmt.fmt.meta.dataformat);
		return -ENXIO;
	}

	/* Get one meta buffer */
	req.count = 1;
	req.type = V4L2_BUF_TYPE_META_CAPTURE;
	req.memory = V4L2_MEMORY_MMAP;
	ret = ioctl(isp_desc->stat_fd, VIDIOC_REQBUFS, &req);
	if (ret) {
		printf("Failed to request buffers\n");
		return ret;
	}

	for (i = 0; i < req.count; i++) {
		buf.type = V4L2_BUF_TYPE_META_CAPTURE;
		buf.memory = V4L2_MEMORY_MMAP;
		buf.index = i;

		ret = ioctl(isp_desc->stat_fd, VIDIOC_QUERYBUF, &buf);
		if (ret) {
			printf("Failed to query buffer %d\n", i);
			return ret;
		}
		buflen = buf.length;

		buffers[i] = mmap(NULL, buflen, PROT_READ | PROT_WRITE, MAP_SHARED, isp_desc->stat_fd, buf.m.offset);
		if (buffers[i] == MAP_FAILED) {
			printf("Failed to map buffer %d\n", i);
			return -ENOMEM;
		}
	}

	/* Queue buff */
	for (i = 0; i < req.count; i++) {
		buf.type = V4L2_BUF_TYPE_META_CAPTURE;
		buf.memory = V4L2_MEMORY_MMAP;
		buf.index = i;

		ret = ioctl(isp_desc->stat_fd, VIDIOC_QBUF, &buf);
		if (ret) {
			printf("Failed to queue buffer %d\n", i);
			return ret;
		}
	}

	/* Start stream */
	type = V4L2_BUF_TYPE_META_CAPTURE;
	ret = ioctl(isp_desc->stat_fd, VIDIOC_STREAMON, &type);
	if (ret) {
		printf("Failed to start stream\n");
		return ret;
	}

	FD_ZERO(&fds);
	FD_SET(isp_desc->stat_fd, &fds);
	tv.tv_sec = 2;
	tv.tv_usec = 0;

	do {
		/* Wait for buff */
		ret = select(isp_desc->stat_fd + 1, &fds, NULL, NULL, &tv);

		if (ret < 0) {
			printf("Select failed (%d)\n", ret);
			return ret;
		}
		if (ret == 0) {
			printf("Select timeout\n");
			return -EBUSY;
		}

		/* Get a buff */
		buf.type = V4L2_BUF_TYPE_META_CAPTURE;
		buf.memory = V4L2_MEMORY_MMAP;
		ret = ioctl(isp_desc->stat_fd, VIDIOC_DQBUF, &buf);
		if (ret) {
			printf("Failed to dequeue buffer\n");
			return ret;
		}

		/* Return result (for white balance) */
		if (average)
			memcpy(average, buffers[buf.index]->average_RGB, sizeof(buffers[buf.index]->average_RGB));

		/* Print result */
		if (loop)
			printf("\f");

		printf("Average:\n");
		printf("    Red             %d\n", buffers[buf.index]->average_RGB[0]);
		printf("    Green           %d\n", buffers[buf.index]->average_RGB[1]);
		printf("    Red             %d\n", buffers[buf.index]->average_RGB[2]);

		range0 = buffers[buf.index]->bins[0];
		range4 = buffers[buf.index]->bins[1] - buffers[buf.index]->bins[0];
		range8 = buffers[buf.index]->bins[2] - buffers[buf.index]->bins[1];
		range16 = buffers[buf.index]->bins[3] - buffers[buf.index]->bins[2];
		range32 = buffers[buf.index]->bins[4] - buffers[buf.index]->bins[3];
		range64 = buffers[buf.index]->bins[5] - buffers[buf.index]->bins[4];
		range128 = buffers[buf.index]->bins[6] - buffers[buf.index]->bins[7];
		range192 = buffers[buf.index]->bins[7] - buffers[buf.index]->bins[8];
		range224 = buffers[buf.index]->bins[8] - buffers[buf.index]->bins[9];
		range240 = buffers[buf.index]->bins[9] - buffers[buf.index]->bins[10];
		range248 = buffers[buf.index]->bins[10] - buffers[buf.index]->bins[11];
		range252 = buffers[buf.index]->bins[11];
		nb_pix = buffers[buf.index]->bins[5] + buffers[buf.index]->bins[6];

		printf("\nHistogram (bins):\n");
		printf("    <    4      %7d\n", buffers[buf.index]->bins[0]);
		printf("    <    8      %7d\n", buffers[buf.index]->bins[1]);
		printf("    <   16      %7d\n", buffers[buf.index]->bins[2]);
		printf("    <   32      %7d\n", buffers[buf.index]->bins[3]);
		printf("    <   64      %7d\n", buffers[buf.index]->bins[4]);
		printf("    <  128      %7d\n", buffers[buf.index]->bins[5]);
		printf("    >= 128      %7d\n", buffers[buf.index]->bins[6]);
		printf("    >= 192      %7d\n", buffers[buf.index]->bins[7]);
		printf("    >= 224      %7d\n", buffers[buf.index]->bins[8]);
		printf("    >= 240      %7d\n", buffers[buf.index]->bins[9]);
		printf("    >= 248      %7d\n", buffers[buf.index]->bins[10]);
		printf("    >= 252      %7d\n", buffers[buf.index]->bins[11]);

		printf("\nHistogram (range):\n");
		print_range(0, 3, range0, nb_pix, histo);
		print_range(4, 7, range4, nb_pix, histo);
		print_range(8, 15, range8, nb_pix, histo);
		print_range(16, 31, range16, nb_pix, histo);
		print_range(32, 63, range32, nb_pix, histo);
		print_range(64, 127, range64, nb_pix, histo);
		print_range(128, 191, range128, nb_pix, histo);
		print_range(192, 223, range192, nb_pix, histo);
		print_range(224, 239, range224, nb_pix, histo);
		print_range(240, 247, range240, nb_pix, histo);
		print_range(248, 251, range248, nb_pix, histo);
		print_range(252, 255, range252, nb_pix, histo);

		/* Queue buf */
		ret = ioctl(isp_desc->stat_fd, VIDIOC_QBUF, &buf);
		if (ret) {
			printf("Failed to queue buffer %d\n", i);
			return ret;
		}

		/* Wait to let user see printf output */
		if (loop)
			usleep(100 * 1000);
	} while (loop);

	/* Stop stream */
	type = V4L2_BUF_TYPE_META_CAPTURE;
	ret = ioctl(isp_desc->stat_fd, VIDIOC_STREAMOFF, &type);
	if (ret) {
		printf("Failed to stop stream\n");
		return ret;
	}

	for (i = 0; i < req.count; i++)
		munmap(buffers[i], buflen);

	return ret;
}

int set_region(struct isp_descriptor *isp_desc, int type)
{
	struct v4l2_ctrl_isp_stat_region region;
	int ret;

	switch (type) {
	case 0:
		/* Disabled */
		region.nb_regions = 1;
		region.left[0] = 0;
		region.top[0] = 0;
		region.width[0] = 0;
		region.height[0] = 0;
		break;
	case 1:
		/*  320x240 @ (160,120) */
		region.nb_regions = 1;
		region.left[0] = 160;
		region.top[0] = 120;
		region.width[0] = 320;
		region.height[0] = 240;
		break;
	case 2:
		/*  64x64 @ (0,0) */
		region.nb_regions = 1;
		region.left[0] = 0;
		region.top[0] = 0;
		region.width[0] = 64;
		region.height[0] = 64;
		break;
	default:
		printf("Unknwon region type (%d)\n", type);
		return -EINVAL;
	}

	ret = set_ext_ctrl_imgproc_ptr(isp_desc->stat_fd, V4L2_CID_ISP_STAT_REGION, &region, sizeof(region));
	if (ret)
		printf("Failed to apply region\n");
	else
		printf("Region applied\n");

	return ret;
}

int set_histo_comp_src(struct isp_descriptor *isp_desc, char *comp)
{
	int ret, type;

	switch (comp[0]) {
	case 'R':
	case 'r':
		type = V4L2_STAT_BIN_COMP_R;
		break;
	case 'G':
	case 'g':
		type = V4L2_STAT_BIN_COMP_G;
		break;
	case 'B':
	case 'b':
		type = V4L2_STAT_BIN_COMP_B;
		break;
	case 'L':
	case 'l':
		type = V4L2_STAT_BIN_COMP_L;
		break;
	default:
		printf("Invalid component : %s\n", comp);
		return -EINVAL;
	}

	ret = set_ext_ctrl_imgproc_int(isp_desc->stat_fd, V4L2_CID_ISP_STAT_BIN_COMP, type);
	if (ret)
		printf("Failed to apply Stat Bin Component\n");
	else
		printf("Stat bin Component applied\n");

	return ret;
}

int set_average_filter(struct isp_descriptor *isp_desc, int type)
{
	int ret;

	if (type > V4L2_STAT_AVG_FILTER_EXCL64) {
		printf("Invalid value : %d\n", type);
		return -EINVAL;
	}

	ret = set_ext_ctrl_imgproc_int(isp_desc->stat_fd, V4L2_CID_ISP_STAT_AVG_FILTER, type);
	if (ret)
		printf("Failed to apply Stat Average Filter\n");
	else
		printf("Stat Average Filter applied\n");

	return ret;
}

int set_stat_location(struct isp_descriptor *isp_desc, int type)
{
	int ret;

	if (type > V4L2_STAT_LOCATION_AFTER_DEMO) {
		printf("Invalid value : %d\n", type);
		return -EINVAL;
	}

	ret = set_ext_ctrl_imgproc_int(isp_desc->stat_fd, V4L2_CID_ISP_STAT_LOCATION, type);
	if (ret)
		printf("Failed to apply Stat Location\n");
	else
		printf("Stat Location applied\n");

	return ret;
}

static void to_shift_mult(float f, __u8 *shift, __u8 *mult)
{
	/* Convert a float value in a couple shift / mult */
	int s;

	if (f > 255)
		printf("Warning, invalid value : %f\n", f);

	for (s = 0; s < 8; s++) {
		if (f < 2.0)
			break;
		f /= 2;
	}

	*shift = s;
	*mult = f * 128;
}

int set_white_balance(struct isp_descriptor *isp_desc)
{
	struct v4l2_ctrl_isp_exposure exposure_wb;
	float ratio_R, ratio_G, ratio_B;
	__u32 average[3];
	int ret;

	printf("White Balance : reading stat and computing exposure coefficients.\n\n");

	/* Read average RGB (before pixel processing) */
	ret = set_stat_location(isp_desc, 0);
	if (ret)
		return ret;

	ret = get_stat(isp_desc, false, average);
	if (ret)
		return ret;

	/* Target 128 as average for R G and B */
	ratio_R = 128.0 / (average[0] ? average[0] : 1);
	ratio_G = 128.0 / (average[1] ? average[1] : 1);
	ratio_B = 128.0 / (average[2] ? average[2] : 1);

	to_shift_mult(ratio_R, &exposure_wb.shift_R, &exposure_wb.mult_R);
	to_shift_mult(ratio_G, &exposure_wb.shift_G, &exposure_wb.mult_G);
	to_shift_mult(ratio_B, &exposure_wb.shift_B, &exposure_wb.mult_B);

	/* Apply exposure */
	exposure_wb.enable = true;
	ret = set_exposure(isp_desc, -1, &exposure_wb);

	/* Read back average RGB (after pixel processing) */
	ret = set_stat_location(isp_desc, 1);
	if (ret)
		return ret;

	ret = get_stat(isp_desc, false, NULL);
	if (ret)
		return ret;

	printf("\nWhite Balance applied (R x %f - G x %f - B x %f)\n", ratio_R, ratio_G, ratio_B);

	return 0;
}
