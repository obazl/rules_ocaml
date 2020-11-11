load("@obazl_rules_ocaml//ocaml/_toolchains:ocaml_toolchains.bzl",
## FIXME: make a public toolchain ns
     "ocaml_toolchain")
load("@obazl_rules_ocaml//ocaml/_toolchains:sdk.bzl",
## FIXME: put these in public ocaml namespace
     "ocaml_sdkpath",
     "ocaml_register_toolchains")

OCAML_VERSION = "4.07.1"
OCAMLBUILD_VERSION = "0.14.0"
OCAMLFIND_VERSION = "1.8.0"
COMPILER_NAME = "ocaml-base-compiler.%s" % OCAML_VERSION

package(default_visibility = ["//visibility:public"])

exports_files(glob(["switch/bin/**"]))

platform(
    name = "bytecode",
    parents = ["@local_config_platform//:host"],
    constraint_values = [
        "@ocaml//mode:bytecode",
    ]
)

ocaml_sdkpath(
    name = "path",
    path = "{sdkpath}",
    visibility = ["//visibility:public"],
)

cc_library(
    name = "csdk",
    srcs = glob(["csdk/*.a"]),
    hdrs = glob(["csdk/**/*.h"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "ocamlc",
    srcs = ["switch/bin/ocamlc"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "ocamlopt",
    srcs = ["switch/bin/ocamlopt"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "ocamlfind",
    srcs = ["switch/bin/ocamlfind"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "ocamlbuild",
    srcs = ["switch/bin/ocamlbuild"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "ocamldep",
    srcs = ["switch/bin/ocamldep"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "files",
    srcs = glob([
        "switch/bin/ocaml*",
        "src/**",
        "pkg/**",
    ]),
)

################################################################
ocaml_toolchain(
    name = "ocaml_toolchaininfo_native_provider_linux",
    link = "static",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "ocaml_toolchain_native_linux",
    toolchain_type = "@obazl_rules_ocaml//ocaml:toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
        # "@ocaml//mode:native"
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
        # "@ocaml//mode:native"
    ],
    # target_compatible_with = constraints,
    toolchain = ":ocaml_toolchaininfo_native_provider_linux"
)

################################################################
ocaml_toolchain(
    name = "ocaml_toolchaininfo_bytecode_provider_linux",
    link = "static",
    mode = "bytecode",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "ocaml_toolchain_bytecode_linux",
    toolchain_type = "@obazl_rules_ocaml//ocaml:toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        # "@platforms//cpu:x86_64",
        "@ocaml//mode:bytecode"
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        # "@platforms//cpu:x86_64",
        "@ocaml//mode:bytecode"
    ],
    # target_compatible_with = constraints,
    toolchain = ":ocaml_toolchaininfo_bytecode_provider_linux"
)

################################################################
ocaml_toolchain(
    name = "ocaml_toolchaininfo_native_provider_macos",
    mode = "native",
    link = "dynamic",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "ocaml_toolchain_native_macos",
    toolchain_type = "@obazl_rules_ocaml//ocaml:toolchain",
    exec_compatible_with = [
        "@platforms//os:macos",
        # "@platforms//cpu:x86_64",
        # "@ocaml//mode:native"
    ],
    target_compatible_with = [
        "@platforms//os:macos",
        # "@platforms//cpu:x86_64",
        # "@ocaml//mode:native"
    ],
    # target_compatible_with = constraints,
    toolchain = ":ocaml_toolchaininfo_native_provider_macos"
)

################################################################
ocaml_toolchain(
    name = "ocaml_toolchaininfo_bytecode_provider_macos",
    link = "dynamic",
    mode = "bytecode",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "ocaml_toolchain_bytecode_macos",
    toolchain_type = "@obazl_rules_ocaml//ocaml:toolchain",
    exec_compatible_with = [
        "@platforms//os:macos",
        # "@platforms//cpu:x86_64",
        "@ocaml//mode:bytecode"
    ],
    target_compatible_with = [
        "@platforms//os:macos",
        # "@platforms//cpu:x86_64",
        "@ocaml//mode:bytecode"
    ],
    # target_compatible_with = constraints,
    toolchain = ":ocaml_toolchaininfo_bytecode_provider_macos"
)
