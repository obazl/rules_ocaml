load("@obazl//ocaml/private:rules/ppx_binary.bzl", "ppx_binary")
load("@obazl//ocaml/private:rules/ppx_module.bzl", "ppx_module")

package(default_visibility = ["//visibility:public"])

ppx_binary(
    name = "metaquot",
    message = "Compiling //ppx:metaquot_ppxlib",
    opts = ["-linkall",
            "-linkpkg",
            ## DON'T FORGET THIS:
            "-predicates", "ppx_driver",
            "-verbose"],
    deps = ["@opam//pkg:base",
            "@opam//pkg:ppxlib",
            "@opam//pkg:ppxlib.metaquot",
            "@opam//pkg:ppxlib.runner",
    ],
)

ppx_module(
    name = "driver_standalone_runner",
    doc  = "To be listed last in the deps attrib of a ppx_binary.",
    msg  = "Compiling //ppxlib:driver_standalone_runner",
    impl = "ppxlib_driver_standalone_runner.ml",
    opts = ["-linkall",
            "-linkpkg",
            # "-verbose"
            "-predicates", "ppx_driver"],
    deps = ["@opam//pkg:base",
            "@opam//pkg:ppxlib"],
)

filegroup( name="driver_standalone_shim",
           srcs=["ppxlib_driver_standalone_runner.ml"],
           visibility = ["//visibility:public"])
