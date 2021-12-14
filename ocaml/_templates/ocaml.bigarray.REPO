load("@rules_ocaml//build:rules.bzl", "ocaml_import")

ocaml_import(
    name = "bigarray",
    version = "[distributed with OCaml]",
    archive = select({
        "@ocaml//mode:bytecode": ["//:bigarray.cma"],
        "@ocaml//mode:native"  : [
            "//:bigarray.cmxa",
            "//:bigarray.a"
        ],
     }),
    all = glob(["bigarray.*"]),
    deps = ["@ocaml//unix"],
    visibility = ["//visibility:public"],
)

ocaml_import(
    name = "plugin",
    version = "[distributed with OCaml]",
    archive = select({
        "@ocaml//mode:bytecode": ["//:bigarray.cma"],
        "@ocaml//mode:native"  : ["//:bigarray.cmxs"],
     }),
    all = glob(["bigarray.*"]),
    deps = ["@ocaml//unix"],
    visibility = ["//visibility:public"],
)
