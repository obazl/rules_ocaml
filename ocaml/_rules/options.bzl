load("//ocaml:providers.bzl",
     "OcamlArchiveProvider",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlNsResolverProvider",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlSignatureProvider",

     "PpxExecutableMarker")

load("//ocaml/_transitions:transitions.bzl",
     "ocaml_module_sig_out_transition",
     "ocaml_module_deps_out_transition")

load("//ocaml/_transitions:ns_transitions.bzl",
     "ocaml_module_cc_deps_out_transition",
     "ocaml_nslib_main_out_transition",
     "ocaml_nslib_submodules_out_transition",
     # "ocaml_nslib_sublibs_out_transition",
     "ocaml_nslib_ns_out_transition",
     )

## Naming conventions:
#
#  * hidden prefix:           '_'   (e.g. _rule)
#  * ns config state prefix:  '__'  (i.e. label atts)

################
def options(ws):

    ws = "@" + ws

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
            default = Label("@ocaml//:path") # ppx also uses this
        ),
    )

#######################
def options_executable(ws):

    ws = "@" + ws

    attrs = dict(
        _linkall     = attr.label(default = ws + "//executable/linkall"),
        _threads     = attr.label(default = ws + "//executable/threads"),
        _warnings  = attr.label(default   = ws + "//executable:warnings"),
        _opts = attr.label(
            doc = "Hidden options.",
            default = "@ocaml//executable:opts"
        ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        main = attr.label(
            doc = "Label of module containing entry point of executable. This module will be placed last in the list of dependencies.",
            providers = [[OcamlModuleMarker]],
            default = None
        ),
        data = attr.label_list(
            allow_files = True,
            doc = "Runtime dependencies: list of labels of data files needed by this executable at runtime."
        ),
        strip_data_prefixes = attr.bool(
            doc = "Symlink each data file to the basename part in the runfiles root directory. E.g. test/foo.data -> foo.data.",
            default = False
        ),
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = [[OcamlArchiveProvider],
                         [OcamlImportMarker],
                         [OcamlLibraryMarker],
                         [OcamlModuleMarker],
                         [OcamlNsMarker],
                         [CcInfo]],
        ),
        _deps = attr.label(
            doc = "Dependency to be added last.",
            default = "@ocaml//executable:deps"
        ),

        ## FIXME: add cc_linkopts?
        cc_deps = attr.label_keyed_string_dict(
            doc = """Dictionary specifying C/C++ library dependencies. Key: a target label; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see [CC Dependencies: Linkmode](../ug/cc_deps.md#linkmode).
            """,
            ## FIXME: cc libs could come from LSPs that do not support CcInfo, e.g. rules_rust
            # providers = [[CcInfo]]
        ),
        _cc_deps = attr.label(
            doc = "Global C/C++ library dependencies. Apply to all instances of ocaml_executable.",
            ## FIXME: cc libs could come from LSPs that do not support CcInfo, e.g. rules_rust
            # providers = [[CcInfo]]
            default = "@ocaml//executable:cc_deps"
        ),
        cc_linkall = attr.label_list(
            ## equivalent to cc_library's "alwayslink"
            doc     = "True: use `-whole-archive` (GCC toolchain) or `-force_load` (Clang toolchain). Deps in this attribute must also be listed in cc_deps.",
            # providers = [CcInfo],
        ),
        cc_linkopts = attr.string_list(
            doc = "List of C/C++ link options. E.g. `[\"-lstd++\"]`.",

        ),
        mode = attr.label(
            default = ws + "//mode"
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    )
    return attrs


#######################
def options_library(ws):

    _providers = [
        [OcamlArchiveProvider],
        [OcamlLibraryMarker],
        [OcamlModuleMarker],
        [OcamlNsResolverProvider],
        [OcamlNsMarker],
        [OcamlSignatureProvider],
    ]

    return dict(
        modules = attr.label_list(
            doc = "List of component modules.",
            providers = _providers
        )
    )

#######################
def options_module(ws):

    _providers = [[OcamlArchiveProvider],
                  [OcamlImportMarker],
                  [OcamlLibraryMarker],
                  [OcamlModuleMarker],
                  [OcamlNsMarker],
                  [OcamlSignatureProvider],
                  [CcInfo]]

    ws = "@" + ws

    return dict(
        _opts     = attr.label(default = ws + "//module:opts"),     # string list
        _linkall  = attr.label(default = ws + "//module/linkall"),  # bool
        _threads   = attr.label(default = ws + "//module/threads"),   # bool
        _warnings = attr.label(default = ws + "//module:warnings"), # string list
        struct = attr.label(
            doc = "A single module (struct) source file label.",
            mandatory = False, # pack libs may not need a src file
            allow_single_file = True # no constraints on extension
        ),
        pack = attr.string(
            doc = "Experimental.  Name of pack lib module for which this module is to be compiled using -for-pack"
        ),
        sig = attr.label(
            doc = "Single label of a target producing OcamlSignatureProvider (i.e. rule 'ocaml_signature'). Optional.",
            allow_single_file = True, # [".cmi"],
            providers = [OcamlSignatureProvider],
            # cfg = ocaml_module_sig_out_transition
        ),
        ################
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = _providers,
            # transition undoes changes that may have been made by ns_lib
            # cfg = ocaml_module_deps_out_transition
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
        _deps = attr.label(
            doc = "Global deps, apply to all instances of rule. Added last.",
            ## NB: this is a label_flag:
            default = ws + "//module:deps"
        ),

        deps_deferred = attr.label_list(
            doc = "Deps needed at link-time (when building an executable). (I.e. for 'virtual' modules."
        ),

        deps_runtime = attr.label_list(
            doc = "Deps needed at runtime, but not build time. E.g. .cmxs plugins."
        ),
        data = attr.label_list(
            allow_files = True,
            doc = "Runtime dependencies: list of labels of data files needed by this module at runtime."
        ),
        ################
        cc_deps = attr.label_keyed_string_dict(
            doc = """Dictionary specifying C/C++ library dependencies. Key: a target label; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see [CC Dependencies: Linkmode](../ug/cc_deps.md#linkmode).
            """,
            # providers = since this is a dictionary depset, no providers
            ## but the keys must have CcInfo providers, check at build time
            # cfg = ocaml_module_cc_deps_out_transition
        ),

        _cc_deps = attr.label(
            doc = "Global cc-deps, apply to all instances of rule. Added last.",
            default = ws + "//module:deps"
        ),

        ################
        # ns = attr.label(
        #     doc = "Label of ocaml_ns target"
        # ),
        _ns_resolver = attr.label(
            doc = "Experimental",
            # allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            ## @ocaml//ns is a 'label_setting' whose value is an `ocaml_ns_resolver` rule. so this institutes a dependency on a resolver whose build params will be set dynamically using transition functions.
            default = "@ocaml//ns",
            ## rename: @ocaml//ns/resolver or @ocaml//ns:resolver

            ## TRICKY BIT: if our struct is generated (e.g. by
            ## ocaml_lex), this transition will prevent ns renaming:
            # cfg = ocaml_module_deps_out_transition
        ),
        _ns_submodules = attr.label(
            doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
            default = "@ocaml//ns:submodules",  # => string_list_setting
            # allow_files = True,
            # mandatory = True
        ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),

        # _ns_strategy = attr.label(
        #     doc = "Experimental",
        #     default = "@ocaml//ns:strategy"
        # ),
    )

#######################
# def options_pack_library(ws):

#     providers = [[OcamlArchiveProvider],
#                  [OcamlSignatureProvider],
#                  [OcamlLibraryMarker],
#                  [OcamlModuleMarker],
#                  [OcamlNsMarker]]

#     ws = "@" + ws

#     return dict(
#         _opts     = attr.label(default = ws + "//module:opts"),     # string list
#         _linkall  = attr.label(default = ws + "//module/linkall"),  # bool
#         _threads   = attr.label(default = ws + "//module/threads"),   # bool
#         _warnings = attr.label(default = ws + "//module:warnings"), # string list

#         ################
#         deps = attr.label_list(
#             doc = "List of OCaml dependencies.",
#             providers = providers,
#             # transition undoes changes that may have been made by ns_lib
#             # cfg = ocaml_module_deps_out_transition
#         ),
#         # _allowlist_function_transition = attr.label(
#         #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
#         # ),
#         _deps = attr.label(
#             doc = "Global deps, apply to all instances of rule. Added last.",
#             default = ws + "//module:deps"
#         ),
#         # data = attr.label_list(
#         #     allow_files = True,
#         #     doc = "Runtime dependencies: list of labels of data files needed by this module at runtime."
#         # ),
#         ################
#         cc_deps = attr.label_keyed_string_dict(
#             doc = """Dictionary specifying C/C++ library dependencies. Key: a target label; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see [CC Dependencies: Linkmode](../ug/cc_deps.md#linkmode).
#             """,
#             # providers = [[CcInfo]]
#             # cfg = ocaml_module_cc_deps_out_transition
#         ),
#         _cc_deps = attr.label(
#             doc = "Global cc-deps, apply to all instances of rule. Added last.",
#             default = ws + "//module:deps"
#         ),

#         ################
#         # ns = attr.label(
#         #     doc = "Label of ocaml_ns target"
#         # ),
#         # _ns_resolver = attr.label(
#         #     doc = "Experimental",
#         #     providers = [OcamlNsResolverProvider],
#         #     default = "@ocaml//ns",
#         # ),
#         # _ns_submodules = attr.label(
#         #     doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
#         #     default = "@ocaml//ns:submodules",  # => string_list_setting
#         #     # allow_files = True,
#         #     # mandatory = True
#         # ),
#         # _ns_strategy = attr.label(
#         #     doc = "Experimental",
#         #     default = "@ocaml//ns:strategy"
#         # ),
#     )

#######################
def options_ns_archive(ws):

    _submod_providers   = [
        [OcamlModuleMarker],
        [OcamlNsMarker],
        [OcamlSignatureProvider]
    ]

    ws = "@" + ws

    return dict(
        _linkall     = attr.label(default = ws +  "//archive/linkall"),
        # _threads     = attr.label(default = ws + "//ns/threads"),
        _warnings    = attr.label(default = ws + "//archive:warnings"),

        shared = attr.bool(
            doc = "True: build a shared lib (.cmxs)",
            default = False
        ),

        ns_resolver = attr.label(
            doc = "Code to use as the ns resolver module instead of generated code. The module specified must contain pseudo-recursive alias equations for all submodules.  If this attribute is specified, an ns resolver module will be generated for resolving the alias equations of the provided module.",
            # allow_single_file = [".ml"]
            providers = [OcamlModuleMarker],
        ),

        _ns_resolver = attr.label(
            doc = "Experimental",
            # allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            default = "@ocaml//ns",
            cfg = ocaml_nslib_submodules_out_transition
        ),

        submodules = attr.label_list(
            doc = "List of *_module submodules",
            allow_files = [".cmo", ".cmx", ".cmi"],
            providers   = _submod_providers,
            cfg = ocaml_nslib_submodules_out_transition
        ),

        ## so we can dump ConfigState
        _ns_prefixes   = attr.label(
            doc = "Experimental",
            default = "@ocaml//ns:prefixes"
        ),
        _ns_submodules = attr.label(
            doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
            default = "@ocaml//ns:submodules",  # => string_list_setting
            # allow_files = True,
            # mandatory = True
        ),

        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),

        _mode = attr.label(
            default = ws + "//mode"
        ),
        _projroot = attr.label(
            default = "@ocaml//:projroot"
        )
    )

#######################
def options_ns_library(ws):

    _submod_providers   = [
        [OcamlModuleMarker],
        [OcamlNsMarker],
    ]

    ws_prefix = "@ocaml" ## + ws

    return dict(
        _opts     = attr.label(default = ws_prefix + "//module:opts"),     # string list
        _linkall  = attr.label(default = ws_prefix + "//module/linkall"),  # bool
        _threads   = attr.label(default = ws_prefix + "//module/threads"),   # bool
        _warnings = attr.label(default = ws_prefix + "//module:warnings"), # string list

        ## we need this when we have sublibs but no direct submodules
        _ns_resolver = attr.label(
            doc = "Experimental",
            # allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            default = "@ocaml//ns",
            cfg = ocaml_nslib_submodules_out_transition
        ),

        ## Note: this is for the user; transition fn uses it to populate ns:submodules
        # submodules = attr.label_keyed_string_dict(
        submodules = attr.label_list(
            doc = "List of *_module submodules",
            allow_files = [".cmo", ".cmx", ".cmi"],
            providers   = _submod_providers,
            cfg = ocaml_nslib_submodules_out_transition
        ),

        ## so we can dump ConfigState
        _ns_prefixes   = attr.label(
            doc = "Experimental",
            default = "@ocaml//ns:prefixes"
        ),
        _ns_submodules = attr.label(
            doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
            default = "@ocaml//ns:submodules",  # => string_list_setting
            # allow_files = True,
            # mandatory = True
        ),

        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
        _projroot = attr.label(
            default = "@ocaml//:projroot" # used by ppx too
        ),

    )

###################
def options_ns_opts(ws):

    return dict(
        _ns_prefixes   = attr.label(
            doc = "Experimental",
            default = "@ocaml//ns:prefixes"
        ),
    )

###################
def options_ns_resolver(ws):

    ws = "@ocaml" #  + ws

    return dict(

        _ns_prefixes   = attr.label(
            doc = "Experimental",
            default = ws + "//ns:prefixes"
        ),
        # _ns_strategy = attr.label(
        #     doc = "Experimental",
        #     default = "@ocaml//ns:strategy"
        # ),
        _ns_submodules = attr.label( # _list(
            default = ws + "//ns:submodules", # => string_list_setting
            doc = "List of files from which submodule names are to be derived for aliasing. The names will be formed by truncating the extension and capitalizing the initial character. Module source code generated by ocamllex and ocamlyacc can be accomodated by using the module name for the source file and generating a .ml source file of the same name, e.g. lexer.mll -> lexer.ml.",
            allow_files = True,
            # mandatory = True
        ),
        _ns_sublibs = attr.label(
            default = ws + "//ns:sublibs",  # => string_list_setting
            doc = "List of *_ns_library submodules",
            allow_files = True,
            # mandatory = True
        ),

        _mode = attr.label(
            default = ws + "//mode"
        ),
        _warnings  = attr.label(default = ws + "//ns:warnings"),
    )

###################
options_ppx = dict(
        ppx  = attr.label(
            doc = "Label of `ppx_executable` target to be used to transform source before compilation.",
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            providers = [PpxExecutableMarker]
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
