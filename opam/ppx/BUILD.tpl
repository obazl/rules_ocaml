load("@obazl//ocaml/private:rules/ppx_module.bzl", "ppx_module")

package(default_visibility = ["//visibility:public"])

ppx_module(
    name = "inline_test_lib_runtime_exit",
    doc  = "To be listed last in the deps attrib of a ppx_binary.",
    msg  = "Compiling //ppx:inline_test_lib_runtime",
    impl = "ppx_inline_test_lib_runtime_exit.ml",
    opts = [
        "-w", "-24",
        "-g",
        "-nodynlink",
        "-no-alias-deps",
        "-linkall",
        "-linkpkg",
        "-predicates", "ppx_driver",
        "-verbose",
        "-c",
    ],
    deps = ["@opam//pkg:base",
            "@opam//pkg:ppx_inline_test.runtime-lib",
            "@opam//pkg:ppx_inline_test"
    ],
)

filegroup( name="inline_test_finalizer",
           srcs=["ppx_inline_test_lib_runtime_exit.ml"],
           visibility = ["//visibility:public"])
