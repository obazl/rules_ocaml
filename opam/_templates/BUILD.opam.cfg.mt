load("@bazel_skylib//rules:common_settings.bzl", "bool_flag", "string_flag")

package(default_visibility = ["//visibility:public"])

bool_flag     ( name = "mt", build_setting_default = False)
config_setting( name = "enabled", flag_values = { ":mt": "True"})

bool_flag( name = "posix", build_setting_default = False)
bool_flag( name = "vm", build_setting_default = False)

