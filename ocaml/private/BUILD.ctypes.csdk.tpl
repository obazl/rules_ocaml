load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "ctypes",
    srcs = glob(["api/*.a"]),
    hdrs = glob(["api/*.h"]),
    # copts = ["-I.", "-Iexternal"], # "-Iexternal/csdk/ocaml"],
    strip_include_prefix = "api",
    deps = [
        "//csdk:hdrs",
    ],
    visibility = ["//visibility:public"],
)
