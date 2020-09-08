load("@obazl_rules_ocaml//ocaml:build.bzl", "ocaml_import")

ocaml_import(
    name = "integers",
    cmxa = "integers.cmxa",
    visibility = ["//visibility:public"],
)
# ocaml_import(
#     name = "integers",
#     cmxa = "api/integers.cmxa",
#     visibility = ["//visibility:public"],
# )
