load("@rules_ocaml//build/_rules:ocaml_ns_config.bzl",
     "ocaml_ns_config")
load("@rules_ocaml//build/_rules:ocaml_ns_module.bzl",
     "ocaml_ns_module")

def _ocaml_ns_impl(name,
                   ns_name,
                   submodules,
                   visibility,
                   **kwargs):

    ocaml_ns_module(
        name      = name,
        ns_config = name + "_Config",
        visibility = visibility
        # **kwargs
    )

    if ns_name == "":
        nsname = name
    else:
        nsname = ns_name

    ocaml_ns_config(
        name       = name + "_Config",
        ns_name    = nsname,
        submodules = submodules,
        visibility = visibility,
        **kwargs
    )

#################
ocaml_ns = macro(
    implementation = _ocaml_ns_impl,
    attrs = {
        "ns_name": attr.string(configurable=False),
        "private": attr.bool(configurable=False, default=False),
        "submodules": attr.string_list(),
        "import_as":  attr.label_keyed_string_dict(),
        "ns_import_as": attr.label_keyed_string_dict(),
        "ns_merge": attr.label_list(),
    },
)

