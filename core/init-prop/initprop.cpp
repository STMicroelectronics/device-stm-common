/*
 * Copyright (C) 2025 The Android Open Source Project
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


int main(int argc __unused, char** argv __unused) {
  std::string cmdline;
  if (android::base::ReadFileToString("/proc/cmdline", &cmdline)) {
    for (const auto& entry : android::base::Split(android::base::Trim(cmdline), " ")) {
      std::vector<std::string> pieces = android::base::Split(entry, "=");
      if (pieces.size() == 2) {
        if (pieces[0] == "lcd_density") {
          android::base::SetProperty("qemu.sf.lcd_density", pieces[1]);
          break;
        }
      }
    }
  }
}
