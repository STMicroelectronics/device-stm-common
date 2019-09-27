/*
 * Copyright (C) 2017 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <android-base/file.h>
#include <android-base/stringprintf.h>
#include <android-base/strings.h>
#include <android-base/properties.h>
#include <android-base/logging.h>

#define STM_PROPERTIES_NB 3
std::string stm_properties[STM_PROPERTIES_NB] = {
  "config", // KEEP IT FIRST - property used to set config.disable_xxx
  "fw_config", // property persist.vendor.fw_config used to select sub-system hardware configuration
  "blkcfg" // property persist.vendor.blk_config used to resize a partition (sd or emmc) if present
};

#define OTHER_PROPERTIES_NB 1
std::string other_properties[OTHER_PROPERTIES_NB] = {
  "gralloc.trace"
};

#define ANDROID_CONFIG_NB 3
std::string android_config[ANDROID_CONFIG_NB][2] = {
  {"bt","disable_bluetooth"}, // Bluetooth available
  {"wifi","disable_wifi"}, // Wi-Fi available
  {"audio","disable_audio"} // Audio available
};

// Tries to update stm property based on kernel cmdline
// returns 'true' if successfully found and set, 'false' otherwise
bool init_stm_property(const std::string& key) {

  std::string check;
  std::string cmdline;
  std::string cmdline_key("stm." + key);

  if (android::base::ReadFileToString("/proc/cmdline", &cmdline)) {
    for (const auto& entry : android::base::Split(android::base::Trim(cmdline), " ")) {
      std::vector<std::string> pieces = android::base::Split(entry, "=");
      if (pieces.size() == 2) {
        if (pieces[0] == cmdline_key) {
          if (key == stm_properties[0]) {
            std::vector<std::string> configs = android::base::Split(pieces[1], ",");
            for (int j = 0; j<ANDROID_CONFIG_NB;j++) {
              if (configs.size()>0) {
                for (int i = 0; i<static_cast<int>(configs.size());i++) {
                  if (android_config[j][0] == configs[i]) {
                    LOG(DEBUG) << "Android property config." << android_config[j][1].c_str() << " set depending on command line with value false";
                    android::base::SetProperty("vendor." + android_config[j][1], "false");
                  }
                }
              }
              check = android::base::GetProperty("vendor." + android_config[j][1],"");
              if (check.empty()) {
                LOG(DEBUG) << "Android property config." << android_config[j][1].c_str() << " set depending on command line with value true";
                android::base::SetProperty("vendor." + android_config[j][1], "true");
              }
            }
          } else {
            LOG(DEBUG) << "STM property persist.vendor." << key.c_str() << " set depending on command line with value " << pieces[1].c_str();
            android::base::SetProperty("persist.vendor." + key, pieces[1]);
          }
          return true;
        }
      }
    }
  }
  return false;
}

bool init_other_property(const std::string& key) {
  std::string check;
  std::string cmdline;
  if (android::base::ReadFileToString("/proc/cmdline", &cmdline)) {
    for (const auto& entry : android::base::Split(android::base::Trim(cmdline), " ")) {
      std::vector<std::string> pieces = android::base::Split(entry, "=");
      if (pieces.size() == 2) {
        if (pieces[0] == key) {
          android::base::SetProperty(key, pieces[1]);
          return true;
        }
      }
    }
  }
  return false;
}

bool is_property_exist(const std::string& key, std::string* out_val) {
  *out_val = android::base::GetProperty("persist.vendor." + key, "");
  if (!out_val->empty()) {
      return true;
  }
  return false;
}

int main(int argc __unused, char** argv __unused) {

  std::string value;

  for (int i = 0;i<STM_PROPERTIES_NB;i++) {
    if (!init_stm_property(stm_properties[i])) {
      if (is_property_exist(stm_properties[i], &value)) {
        LOG(DEBUG) << "STM property persist.vendor." << stm_properties[i].c_str() << " default value kept with value " << value.c_str();
      } else {
        LOG(DEBUG) << "STM property persist.vendor." << stm_properties[i].c_str() << " not available";
      }
    }
  }
  for (int i = 0;i<OTHER_PROPERTIES_NB;i++) {
    if (init_other_property(other_properties[i])) {
        LOG(DEBUG) << "Other property " << other_properties[i].c_str() << " set";
    }
  }
}
