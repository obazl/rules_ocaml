load("@obazl_rules_ocaml//ocaml:build.bzl", "ocaml_import")

ocaml_import(
    name = "ctypes",
    cmxa = "api/ctypes.cmxa",
    deps = [
        # "@ocaml//csdk",
        "@ocaml//csdk/lib/integers"
    ],
    visibility = ["//visibility:public"],
)

ocaml_import(
    name = "stubs",
    cmxa = "api/cstubs.cmxa",
    deps = [":ctypes"],
    visibility = ["//visibility:public"],
)
