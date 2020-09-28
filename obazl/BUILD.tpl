load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")

package(default_visibility = ["//visibility:public"])

exports_files(["opam"])

bool_flag( name = "verbose", build_setting_default = False)
config_setting( name = "enable_verbose",
                flag_values = { "//:verbose": "True" })
config_setting( name = "disable_verbose",
                flag_values = { "//:verbose": "False" })

# bzl_library(
#     name = "obazl",
#     visibility = ["//visibility:public"],
#     srcs = [
#         "obazl.bzl",
#     ],
# )

