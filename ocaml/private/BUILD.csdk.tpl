load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "csdk",
    srcs = glob([
    "ocaml/*.a", "ocaml/compiler-libs/*.a",
    "ocaml/sublibs/*.so",
    "ocaml/threads/*.a", "ocaml/vmthreads/*.a"
    ]),
    hdrs = glob(["ocaml/caml/*.h"]),
    copts = [
    "-I.",
    "-Iexternal"
    ],
    strip_include_prefix = "ocaml",
    visibility = ["//visibility:public"],
)

cc_library(
    name = "hdrs",
    hdrs = glob(["ocaml/caml/*.h"]),
    copts = ["-I."],
    # "-Iexternal",
    # # "-Iexternal/ocaml/csdk/ocaml"
    # ],
    strip_include_prefix = "ocaml",
    visibility = ["//visibility:public"],
)
