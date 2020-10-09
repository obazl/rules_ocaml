load("@obazl_rules_ocaml//ocaml:rules.bzl", "ocaml_module")
# load("@obazl_rules_ocaml//ocaml/private/rules:ppx_module.bzl", "ppx_module")

package(default_visibility = ["//visibility:public"])

# ppx_executable(
#     name = "metaquot",
#     message = "Compiling //ppx:metaquot_ppxlib",
#     opts = ["-linkall",
#             "-linkpkg",
#             ## DON'T FORGET THIS:
#             "-predicates", "ppx_driver",
#             # "-verbose"
#     ],
#     deps = ["@opam//pkg:base",
#             "@opam//pkg:ppxlib",
#             "@opam//pkg:ppxlib.metaquot",
#             "@opam//pkg:ppxlib.runner",
#     ],
# )

ocaml_module(
    name = "driver_standalone_runner",
    doc  = "To be listed last in the deps attrib of a ppx_executable.",
    msg  = "Compiling //ppxlib:driver_standalone_runner",
    impl = "ppxlib_driver_standalone_runner.ml",
    opts = ["-linkall",
            "-linkpkg",
            "-predicates", "ppx_driver"],
    deps = ["@opam//pkg:base",
            "@opam//pkg:ppxlib"],
)

filegroup( name="driver_standalone_shim",
           srcs=["ppxlib_driver_standalone_runner.ml"],
           visibility = ["//visibility:public"])
