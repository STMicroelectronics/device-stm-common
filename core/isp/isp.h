#ifndef ISP_H
#define ISP_H

#ifdef __cplusplus
extern "C" {
#endif

struct isp_descriptor {
	char media_dev_name[32];
	char isp_subdev_name[32];
	char stat_dev_name[32];
	int isp_fd;
	int stat_fd;
	int width;
	int height;
	int fmt;
	char fmt_str[32];
};

int discover_dcmipp(struct isp_descriptor *isp_desc);
void close_dcmipp(struct isp_descriptor *isp_desc);
int set_black_level(struct isp_descriptor *isp_desc, int level);
int get_black_level(struct isp_descriptor *isp_desc);
int set_demosaicing_control(struct isp_descriptor *isp_desc, char *optarg);
int get_bad_pixel_count(struct isp_descriptor *isp_desc);
int set_bad_pixel_config(struct isp_descriptor *isp_desc, int level);
int set_bad_pixel_target(struct isp_descriptor *isp_desc, int target);
int set_exposure(struct isp_descriptor *isp_desc, int type, struct v4l2_ctrl_isp_exposure *exposure_wb);
int set_contrast(struct isp_descriptor *isp_desc, int type);
int set_color_conv(struct isp_descriptor *isp_desc, int type);
int get_color_conv(struct isp_descriptor *isp_desc);
int get_stat(struct isp_descriptor *isp_desc, bool loop, __u32 average[3]);
int set_region(struct isp_descriptor *isp_desc, int type);
int set_histo_comp_src(struct isp_descriptor *isp_desc, char *comp);
int set_average_filter(struct isp_descriptor *isp_desc, int type);
int set_stat_location(struct isp_descriptor *isp_desc, int type);
int set_white_balance(struct isp_descriptor *isp_desc);
#ifdef __cplusplus
} // extern "C"
#endif

#endif // ISP_H
