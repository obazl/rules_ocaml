load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")

package(default_visibility = ["//visibility:public"])

bool_flag( name = "passes", build_setting_default = False)
config_setting( name = "show_verbose",
                flag_values = { ":passes": "True" })

# string_flag( name = "link", build_setting_default = "on_demand",
#              values = ["always", "on_demand"],
#              visibility = ["//visibility:public"])
