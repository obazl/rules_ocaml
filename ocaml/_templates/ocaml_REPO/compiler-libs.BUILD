package(default_visibility = ["//visibility:public"])

load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")

load("@obazl_rules_ocaml//ocaml:rules.bzl", "ocaml_import")

alias(
    name = "compiler-libs",
    actual = "@ocaml.compiler-libs//:compiler-libs"
)

alias(
    name = "common",
    actual = "@ocaml.compiler-libs//:common"
)

alias(
    name = "bytecomp",
    actual = "@ocaml.compiler-libs//:bytecomp"
)

alias(
    name = "optcomp",
    actual = "@ocaml.compiler-libs//:optcomp"
)

alias(
    name = "toplevel",
    actual = "@ocaml.compiler-libs//:toplevel"
)

alias(
    name = "native-toplevel",
    actual = "@ocaml.compiler-libs//:native-toplevel"
)

bool_flag( name = "create_toploop", build_setting_default = False )
config_setting( name = "create_toploop_enabled", flag_values = {":create_toploop": "True"} )
config_setting( name = "create_toploop_disabled", flag_values = {":create_toploop": "False"} )

bool_flag( name = "plugin", build_setting_default = False )
config_setting( name = "plugin_enabled", flag_values = {":plugin": "True"} )
config_setting( name = "plugin_disabled", flag_values = {":plugin": "False"} )

bool_flag( name = "toploop", build_setting_default = False )
config_setting( name = "toploop_enabled", flag_values = {":toploop": "True"} )
config_setting( name = "toploop_disabled", flag_values = {":toploop": "False"} )

config_setting(
    name = "byte_plugin",
    flag_values = {
        "@ocaml//mode": "bytecode",
        ":plugin": "True",
    },
    visibility = ["//visibility:public"]
)

config_setting(
    name = "byte_toploop",
    flag_values = {
        "@ocaml//mode": "bytecode",
        ":toploop": "True",
    },
    visibility = ["//visibility:public"]
)

config_setting(
    name = "native_plugin",
    flag_values = {
        "@ocaml//mode": "native",
        ":plugin": "True",
    },
    visibility = ["//visibility:public"]
)

## options -mt etc. are findlib-specific, not used by compilers
## vm threads have been removed, so we do not support (META is outdated)
## no need to qualify threads lib as "posix"


