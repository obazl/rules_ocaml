load("@rules_ocaml//build/_rules:ocaml_ns_config.bzl",
     "ocaml_ns_config")
load("@rules_ocaml//build/_rules:ocaml_ns_module.bzl",
     "ocaml_ns_module")

def _ocaml_ns_impl(name,
                   ns_name,
                   submodules,
                   visibility,
                   **kwargs):

    if ns_name:
        if ns_name == "":
            nsname = name
        else:
            nsname = ns_name
    else:
        nsname = name

    ocaml_ns_module(
        name      = name,
        ns_config = name + "_Config.ml",
        visibility = visibility
        # **kwargs
    )

    ocaml_ns_config(
        name       = name + "_Config.ml",
        ns_name    = nsname,
        submodules = submodules,
        visibility = visibility,
        **kwargs
    )

#################
ocaml_ns = macro(
    implementation = _ocaml_ns_impl,
    doc = """

Macro. Expands to an link:ocaml_ns_config[ocaml_ns_config] and an
link:ocaml_ns_module[ocaml_ns_module] target that together define an OCaml build namespace.

    """,
    inherit_attrs = ocaml_ns_config,
    attrs = {
        ## all inherited
        ## inherited attrs we don’t need
        "compatible_with": None,
        "deprecation": None,
        "exec_compatible_with": None,
        "exec_properties": None,
        "features": None,
        "package_metadata": None,
        "restricted_to": None,
        "tags": None,
        "target_compatible_with": None,
        "testonly": None,
        "toolchains": None
    },
)

