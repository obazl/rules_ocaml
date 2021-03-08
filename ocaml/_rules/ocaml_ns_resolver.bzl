load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "DefaultMemo")
     # "OcamlNsResolverProvider")
     # "PpxNsLibraryProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
)

load(":options.bzl",
     "ns_docstring",
     "options",
     "options_ns_resolver")

load("//ocaml/_rules:impl_ns_resolver.bzl", "impl_ns_resolver")

# OCAML_FILETYPES = [
#     ".ml", ".mli", ".cmx", ".cmo", ".cma"
# ]

# tmpdir = "_obazl_/"

################################
rule_options = options("ocaml")
rule_options.update(options_ns_resolver("ocaml"))
# rule_options.update(options_ns_opts("ocaml"))

################
ocaml_ns_resolver = rule(
  implementation = impl_ns_resolver,
    doc = ns_docstring,
    attrs = dict(
        rule_options,
        _rule = attr.string(default = "ocaml_ns_resolver")
    ),
    # provides = [DefaultInfo, OcamlNsLibraryProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
