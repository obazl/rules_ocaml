load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "include",
    # srcs = glob([
    # "csdk/ocaml/*.a", "csdk/ocaml/compiler-libs/*.a",
    # "csdk/ocaml/sublibs/*.so",
    # "csdk/ocaml/threads/*.a", "csdk/ocaml/vmthreads/*.a"
    # ]),
    hdrs = glob(["**/*.h"]),
    copts = [
    "-I.",
    "-Iexternal"
    ],
    # strip_include_prefix = "csdk/ocaml",
    visibility = ["//visibility:public"],
)
