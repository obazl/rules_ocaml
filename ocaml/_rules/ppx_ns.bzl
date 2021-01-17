# load("//ocaml/_actions:ns_module.bzl", "ns_module_compile")
load("//ppx:_providers.bzl", "PpxNsModuleProvider")

load(":options_ppx.bzl", "options_ppx")

load(":impl_ns.bzl", "impl_ns")

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]

######################
# def _ppx_ns_impl(ctx):
#   return ns_module_compile(ctx)

##############
ppx_ns = rule(
    implementation = impl_ns,
    # implementation = _ppx_ns_impl,
    attrs = dict(
        options_ppx,
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        module_name = attr.string(),
        ns = attr.string(),
        ns_sep = attr.string(
            doc = "Namespace separator.  Default: '__'",
            default = "__"
        ),
        submodules = attr.label_list(
            doc = "List of all submodule source files, including .ml/.mli file(s) whose name matches the ns.",
            allow_files = OCAML_FILETYPES
        ),
        # opts = attr.string_list(),
        _linkall     = attr.label(default = "@ppx//ns:linkall"),
        _threads     = attr.label(default = "@ppx//ns:threads"),
        _warnings    = attr.label(default = "@ppx//ns:warnings"),
        _mode = attr.label(
            default = "@ppx//mode"
        ),
        msg = attr.string(),
        _rule = attr.string(default = "ppx_ns")
    ),
    provides = [DefaultInfo, PpxNsModuleProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
