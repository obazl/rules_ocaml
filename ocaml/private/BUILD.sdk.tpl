load("@obazl//ocaml/private:ocaml_toolchains.bzl",
     "ocaml_toolchain")
load("@obazl//ocaml/private:sdk.bzl",
     "ocaml_sdkpath",
     "ocaml_register_toolchains")
# load("@obazl//ocaml/private:ocaml_toolchain.bzl",
#      "declare_toolchains")
# "ocaml_sdk")

OCAML_VERSION = "4.07.1"
OCAMLBUILD_VERSION = "0.14.0"
OCAMLFIND_VERSION = "1.8.0"
COMPILER_NAME = "ocaml-base-compiler.%s" % OCAML_VERSION

package(default_visibility = ["//visibility:public"])

ocaml_sdkpath(
    name = "path",
    path = "{sdkpath}",
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

ocaml_toolchain(
    name = "ocaml_toolchaininfo_provider",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "ocaml_toolchain_selector",
    toolchain_type = "@obazl//ocaml:toolchain",
    exec_compatible_with = [
        "@platforms//os:macos",
        "@platforms//cpu:x86_64",
    ],
    target_compatible_with = [
        "@platforms//os:macos",
        "@platforms//cpu:x86_64",
    ],
    # target_compatible_with = constraints,
    toolchain = ":ocaml_toolchaininfo_provider"
)
