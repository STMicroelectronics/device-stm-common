#
# Copyright 2015 The Android Open Source Project
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
#

# Set the output for the kernel module build products
ifneq ($(TARGET_KERNEL_MODULE),)
KERNEL_MODULE_OUT_TOP := $(PRODUCT_OUT)/$(TARGET_KERNEL_MODULE)
else
KERNEL_MODULE_OUT_TOP := $(PRODUCT_OUT)/vendor
endif

KERNEL_MODULE_OUT := $(KERNEL_MODULE_OUT_TOP)/lib/modules

# Set the vendor image path
VENDOR_IMAGE := $(PRODUCT_OUT)/vendor.img

# Install modules
KERNEL_MODULES := $(foreach file,$(wildcard $(TARGET_PREBUILT_MODULE_PATH)/*.ko),\
                  $(file):$(KERNEL_MODULE_OUT)/$(notdir $(file)))

INSTALLED_KERNEL_MODULES := $(call copy-many-files,$(KERNEL_MODULES))

# Add dependencies for vendor image building
$(VENDOR_IMAGE): $(INSTALLED_KERNEL_MODULES)
