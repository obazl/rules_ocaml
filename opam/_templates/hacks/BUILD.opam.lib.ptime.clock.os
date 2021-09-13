## original: /Users/gar/.opam/4.10/lib/ptime/META

load(
    "@obazl_rules_ocaml//ocaml:rules.bzl",
    "ocaml_import"
)

ocaml_import(
    name = "os",
    version = """0.8.5""",
    doc = """Ptime_clock for native OS""",
    archive = select({
        "@ocaml//mode:bytecode": [
            "//:_lib/ptime/os/ptime_clock.cma",
        ],

        "@ocaml//mode:native": [
            "//:_lib/ptime/os/ptime_clock.cmxa",
        ],

    }),
    deps = [
        "@ocaml//lib/ptime",
    ],
    visibility = ["//visibility:public"]
)

ocaml_import(
    name = "plugin",
    plugin = select({
        "@ocaml//mode:bytecode": [
            "//:_lib/ptime/os/ptime_clock.cma",
        ],

        "@ocaml//mode:native": [
            "//:_lib/ptime/os/ptime_clock.cmxs",
        ],

    }),
    deps = [
        "@ocaml//lib/ptime",
    ],
    visibility = ["//visibility:public"]
)
