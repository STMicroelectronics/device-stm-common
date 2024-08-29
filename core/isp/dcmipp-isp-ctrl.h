/* SPDX-License-Identifier: BSD-3-Clause */
/*
 * Copyright (C) 2024 ST Microelectronics.
 */

#ifndef DCMIPP_ISP_CTRL_H
#define DCMIPP_ISP_CTRL_H

#ifdef __cplusplus
extern "C" {
#endif

#define STR_MAX_LEN	32
struct isp_descriptor {
	char media_dev_name[STR_MAX_LEN];
	char isp_subdev_name[STR_MAX_LEN];
	char params_dev_name[STR_MAX_LEN];
	char stat_dev_name[STR_MAX_LEN];
	char sensor_subdev_name[STR_MAX_LEN];
	int isp_fd;
	int params_fd;
	int stat_fd;
	int width;
	int height;
	int fmt;
	char fmt_str[STR_MAX_LEN];
	struct stm32_dcmipp_stat_buf *stats[4];
	int stats_buf_nb;
	size_t stats_buf_len;
	struct stm32_dcmipp_params_cfg *params[4];
	int params_buf_nb;
	size_t params_buf_len;
};

#ifdef __cplusplus
enum v4l2_isp_stat_profile : int;
#endif

int discover_dcmipp(struct isp_descriptor *isp_desc);
int set_sensor_gain_exposure(struct isp_descriptor *isp_desc, bool verbose);
int set_contrast(struct isp_descriptor *isp_desc, int type);
int set_profile(struct isp_descriptor *isp_desc, int type);
int get_stat(struct isp_descriptor *isp_desc, bool loop, struct stm32_dcmipp_stat_buf **stats, enum v4l2_isp_stat_profile profile);
void print_average(__u32 average_RGB[3]);
void print_bins(__u32 bins[12]);
void close_dcmipp(struct isp_descriptor *isp_desc);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // DCMIPP_ISP_CTRL_H
