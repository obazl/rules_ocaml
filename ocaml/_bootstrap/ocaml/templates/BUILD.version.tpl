load("@bazel_skylib//rules:common_settings.bzl", "int_setting", "string_setting")

package(default_visibility = ["//visibility:public"])

## VAR:MAJOR.MINOR.PATCH-OPTPRERELEASE+OPTBUILD (http://semver.org/)

string_setting( name = "version", visibility = ["//visibility:public"], build_setting_default = "{VERSION}")
string_setting( name = "major", visibility = ["//visibility:public"], build_setting_default = "{MAJOR}")
string_setting( name = "minor", visibility = ["//visibility:public"], build_setting_default = "{MINOR}")
string_setting( name = "patch", visibility = ["//visibility:public"], build_setting_default = "{PATCH}")
