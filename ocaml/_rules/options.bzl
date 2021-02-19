load("//ocaml:providers.bzl",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlSignatureProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlNsEnvProvider",
     "OpamPkgInfo",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]

def options(ws):
    return dict(
        opts             = attr.string_list(
            doc          = "List of OCaml options. Will override configurable default options."
        ),
        ## GLOBAL CONFIGURABLE DEFAULTS (all ppx_* rules)
        _debug           = attr.label(default = ws + "//debug"),
        _cmt             = attr.label(default = ws + "//cmt"),
        _keep_locs       = attr.label(default = ws + "//keep-locs"),
        _noassert        = attr.label(default = ws + "//noassert"),
        _opaque          = attr.label(default = ws + "//opaque"),
        _short_paths     = attr.label(default = ws + "//short-paths"),
        _strict_formats  = attr.label(default = ws + "//strict-formats"),
        _strict_sequence = attr.label(default = ws + "//strict-sequence"),
        _verbose         = attr.label(default = ws + "//verbose"),

        _mode       = attr.label(
            default = ws + "//mode",
        ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
    )

################################################################
def options_module(ws):

    if ws == "@ocaml":
        providers = [[OpamPkgInfo],
                     [OcamlArchiveProvider],
                     [OcamlImportProvider],
                     [OcamlSignatureProvider],
                     [OcamlLibraryProvider],
                     [OcamlModuleProvider],
                     [OcamlNsArchiveProvider],
                     [OcamlNsLibraryProvider],
                     # [OcamlNsEnvProvider],
                     [PpxArchiveProvider],
                     [PpxModuleProvider]] # [CcInfo]],
    else:
        ## FIXME: providers for ppx_module
        providers = []

    return dict(
        _opts     = attr.label(default = ws + "//module:opts"),     # string list
        _linkall  = attr.label(default = ws + "//module/linkall"),  # bool
        _thread   = attr.label(default = ws + "//module/thread"),   # bool
        _warnings = attr.label(default = ws + "//module:warnings"), # string list
        struct = attr.label(
            mandatory = True,  # use ocaml_signature for isolated .mli files
            doc = "A single .ml source file label.",
            allow_single_file = OCAML_IMPL_FILETYPES
        ),
        module = attr.string(
            doc = "Name for output file. Use to coerce input file with different name, e.g. for a file generated from a .ml file to a different name, like foo.cppo.ml."
        ),
        sig = attr.label(
            doc = "Single label of a target providing a single .cmi file (not a .mli source file). Optional",
            allow_single_file = [".cmi"],
            providers = [OcamlSignatureProvider],
        ),
        ################
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = providers,
        ),
        _deps = attr.label(
            doc = "Global deps, apply to all instances of rule. Added last.",
            default = ws + "//module:deps"
        ),
        deps_opam = attr.string_list(
            doc = "List of OPAM package names"
        ),
        data = attr.label_list(
            allow_files = True,
            doc = "Runtime dependencies: list of labels of data files needed by this module at runtime."
        ),
        ################
        cc_deps = attr.label_keyed_string_dict(
            doc = """Dictionary specifying C/C++ library dependencies. Key: a target label; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see [CC Dependencies: Linkmode](../ug/cc_deps.md#linkmode).
            """,
            # providers = [[CcInfo]]
        ),
        _cc_deps = attr.label(
            doc = "Global cc-deps, apply to all instances of rule. Added last.",
            default = ws + "//module:deps"
        ),

    )

###################
def options_ns(ws):

    return dict(

        _ns_env = attr.label(
            doc = "Experimental",
            providers = [OcamlNsEnvProvider],
            default = ws + "//ns",
            # cfg = ocaml_module_ns_transition, # outgoing edge transition
        ),
        # _ns_pkg   = attr.label(
        #     doc = "Experimental",
        #     default = "@ocaml//ns:pkg"
        # ),
        _ns_prefix   = attr.label(
            doc = "Experimental",
            default = ws + "//ns:prefix"
        ),
        # _ns_sep = attr.string(
        #     doc = "String used to replace segment separator ('.') in prefix string.",
        #     default = "@ocaml//ns:sep"
        #     # default = "_"
        # ),
        # resolver   = attr.bool(
        #     doc = "Determines whether ns resolver module is generated. If True, then `srcs` attribute must not be empty. Must be true if submodules are inter-dependent.",
        #     default = False
        # ),
        _ns_submodules = attr.label( # _list(
            default = ws + "//ns:submodules",
            doc = "Experimental",
            # allow_files = True,
            # mandatory = True
        ),
    )

###################
options_ppx = dict(
        ppx  = attr.label(
            doc = "Label of `ppx_executable` target to be used to transform source before compilation.",
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            providers = [PpxExecutableProvider]
        ),
        ppx_args  = attr.string_list(
            doc = "Options to pass to PPX executable passed by the `ppx` attribute.",
        ),
        ppx_data  = attr.label_list(
            doc = "PPX runtime dependencies. List of labels of files needed by the PPX executable passed via the `ppx` attribute when it is executed to transform the source file. For example, a source file using [ppx_optcomp](https://github.com/janestreet/ppx_optcomp) may import a file using extension `[%%import ]`; this file should be listed in this attribute.",
            allow_files = True,
        ),
        ppx_print = attr.label(
            doc = "Format of output of PPX transform. Value must be one of '@ppx//print:binary', '@ppx//print:text'.  See [PPX Support](../ug/ppx.md#ppx_print) for more information",
            default = "@ppx//print"
        ),
        ppx_tags  = attr.string_list(
            doc = "DEPRECATED. List of tags.  Used to set e.g. -inline-test-libs, --cookies. Currently only one tag allowed."
        )
)
