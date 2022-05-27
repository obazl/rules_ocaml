load("//ocaml:providers.bzl",
     "OcamlArchiveMarker",
     "OcamlExecutableMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlNsResolverProvider",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsSubmoduleMarker",
     "OcamlProvider",
     "OcamlSignatureProvider",
)
load("//ppx:providers.bzl",
     "PpxExecutableMarker",
)

load("//ocaml/_transitions:transitions.bzl",
     "ocaml_module_sig_out_transition",
     "ocaml_executable_deps_out_transition",
     "ocaml_module_deps_out_transition")

load("//ocaml/_transitions:ns_transitions.bzl",
     "ocaml_module_cc_deps_out_transition",
     "ocaml_nslib_main_out_transition",
     "ocaml_nslib_submodules_out_transition",
     # "ocaml_nslib_sublibs_out_transition",
     "ocaml_nslib_ns_out_transition",
     )

################
def options(ws):

    # ws = "@" + ws
    ws = "@rules_ocaml"

    return dict(
        opts             = attr.string_list(
            doc          = "List of compile options; overrides configurable default options. Supports `+-no-+` prefix for each option; for example, `-no-linkall`."
        ),
        ## GLOBAL CONFIGURABLE DEFAULTS (all ppx_* rules)
        ## these should never be directly set.
        _debug           = attr.label(default = ws + "//cfg/debug"),
        _cmt             = attr.label(default = ws + "//cfg/cmt"),
        _keep_locs       = attr.label(default = ws + "//cfg/keep-locs"),
        _noassert        = attr.label(default = ws + "//cfg/noassert"),
        _opaque          = attr.label(default = ws + "//cfg/opaque"),
        _short_paths     = attr.label(default = ws + "//cfg/short-paths"),
        _strict_formats  = attr.label(default = ws + "//cfg/strict-formats"),
        _strict_sequence = attr.label(default = ws + "//cfg/strict-sequence"),
        _verbose         = attr.label(default = ws + "//cfg/verbose"),

        _mode       = attr.label(
            default = ws + "//build/mode",
        ),
        mode       = attr.string(
            doc     = "Overrides default build mode setting, 'native' or 'bytecode'.",
            # default = ""
        ),

        argsfile       = attr.label(
            doc = "Name of file containing newline-terminated arg lines, to be passed with -args",
            allow_single_file = True,
        ),

        args0file       = attr.label(
            doc = "Name of file containing null-terminated arg lines, to be passed with -args0",
            allow_single_file = True,
        ),

        # _sdkpath = attr.label(
        #     default = Label("@rules_ocaml//cfg:sdkpath") # ppx also uses this
        # ),
    )

#######################
def options_executable(ws):

    # ws = "@" + ws
    ws = "@rules_ocaml"

    attrs = dict(
        _linkall     = attr.label(default = ws + "//cfg/executable/linkall"),
        # _threads     = attr.label(default = ws + "//cfg/executable/threads"),
        _warnings  = attr.label(default   = ws + "//cfg/executable:warnings"),
        _opts = attr.label(
            doc = "Hidden options.",
            default = "@rules_ocaml//cfg/executable:opts"
        ),
        # _sdkpath = attr.label(
        #     default = Label("@rules_ocaml//cfg:sdkpath")
        # ),
        exe  = attr.string(
            doc = "By default, executable name is derived from 'name' attribute; use this to override."
        ),
        main = attr.label(
            doc = "Label of module containing entry point of executable. This module will be placed last in the list of dependencies.",
            allow_single_file = True,
            providers = [[OcamlModuleMarker]],
            default = None,
            # cfg = ocaml_executable_deps_out_transition
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
            providers = [[OcamlArchiveMarker],
                         [OcamlImportMarker],
                         [OcamlLibraryMarker],
                         [OcamlModuleMarker],
                         [OcamlNsMarker],
                         [CcInfo]],
            # cfg = ocaml_executable_deps_out_transition
        ),
        _deps = attr.label(
            doc = "Dependency to be added last.",
            default = "@rules_ocaml//cfg/executable:deps"
        ),


        _stublibs = attr.label_list(
            default = ["@stublibs//:stublibs"]
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
            default = "@rules_ocaml//cfg/executable:cc_deps"
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
            default = ws + "//build/mode"
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    )
    return attrs


#######################
def options_library(ws):

    _providers = [
        [OcamlArchiveMarker],
        [OcamlLibraryMarker],
        [OcamlModuleMarker],
        [OcamlNsResolverProvider],
        [OcamlNsMarker],
        [OcamlSignatureProvider],
    ]

    return dict(
        manifest = attr.label_list(
            doc = "List of component modules.",
            providers = _providers
        )
    )

#######################
def options_module(ws):

    _providers = [[OcamlArchiveMarker],
                  [OcamlImportMarker],
                  [OcamlLibraryMarker],
                  [OcamlModuleMarker],
                  # [OcamlNsMarker],
                  [OcamlNsResolverProvider],
                  [OcamlSignatureProvider],
                  [CcInfo]]

    # ws = "@" + ws
    ws = "@rules_ocaml"

    return dict(
        _opts     = attr.label(default = ws + "//cfg/module:opts"),     # string list
        _linkall  = attr.label(default = ws + "//cfg/module/linkall"),  # bool
        # _threads   = attr.label(default = ws + "//cfg/module/threads"),   # bool

        struct = attr.label(
            doc = "A single module (struct) source file label.",
            mandatory = True,
            allow_single_file = True # no constraints on extension
        ),
        # pack = attr.string(
        #     doc = "Experimental.  Name of pack lib module for which this module is to be compiled using -for-pack"
        # ),
        sig = attr.label(
            doc = "Single label of a target producing `OcamlSignatureProvider` (i.e. rule `ocaml_signature`) OR a sig source file. Optional.",
            allow_single_file = True,
            ## FIXME: how to specify OcamlSignatureProvider OR FileProvider?
            #providers = [[OcamlSignatureProvider]],
            # cfg = ocaml_module_sig_out_transition
        ),
        ################
        deps = attr.label_list(
            doc = "List of dependencies.",
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
            default = ws + "//cfg/module:deps"
        ),

        open = attr.label_list(
            doc = "List of OCaml dependencies to be passed with `-open`.",
            providers = [
                [OcamlProvider],
                [OcamlArchiveMarker],
                [OcamlImportMarker],
                [OcamlLibraryMarker],
                [OcamlModuleMarker],
                [OcamlNsMarker],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),

        ## OBSOLETE: we don't need deps_deferred?
        # deps_deferred = attr.label_list(
        #     doc = "Deps needed at link-time (when building an executable). (I.e. for 'virtual' modules."
        # ),

        deps_runtime = attr.label_list(
            doc = "Runtime module dependencies, e.g. .cmxs plugins."
        ),
        data = attr.label_list(
            allow_files = True,
            doc = "Runtime data dependencies: list of labels of data files needed by this module at runtime."
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
            default = ws + "//cfg/module:deps"
        ),

        ################
        ns_resolver = attr.label(
            doc = "Resolver for bottom-up namespacing",
            allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            mandatory = False
        ),

        # ns = attr.label(
        #     doc = "Label of ocaml_ns target"
        # ),
        _ns_submodules = attr.label(
            doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
            default = "@rules_ocaml//cfg/ns:submodules",  # => string_list_setting
            # allow_files = True,
            # mandatory = True
        ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),

        # _ns_strategy = attr.label(
        #     doc = "Experimental",
        #     default = "@rules_ocaml//cfg/ns:strategy"
        # ),
    )

#######################
# def options_pack_library(ws):

#     providers = [[OcamlArchiveMarker],
#                  [OcamlSignatureProvider],
#                  [OcamlLibraryMarker],
#                  [OcamlModuleMarker],
#                  [OcamlNsMarker]]

#     ws = "@" + ws

#     return dict(
#         _opts     = attr.label(default = ws + "//cfg/module:opts"),     # string list
#         _linkall  = attr.label(default = ws + "//cfg/module/linkall"),  # bool
#         _threads   = attr.label(default = ws + "//cfg/module/threads"),   # bool
#         _warnings = attr.label(default = ws + "//cfg/module:warnings"), # string list

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
#             default = ws + "//cfg/module:deps"
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
#             default = ws + "//cfg/module:deps"
#         ),

#         ################
#         # ns = attr.label(
#         #     doc = "Label of ocaml_ns target"
#         # ),
#         # _ns_resolver = attr.label(
#         #     doc = "Experimental",
#         #     providers = [OcamlNsResolverProvider],
#         #     default = "@rules_ocaml//cfg/ns",
#         # ),
#         # _ns_submodules = attr.label(
#         #     doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
#         #     default = "@rules_ocaml//cfg/ns:submodules",  # => string_list_setting
#         #     # allow_files = True,
#         #     # mandatory = True
#         # ),
#         # _ns_strategy = attr.label(
#         #     doc = "Experimental",
#         #     default = "@rules_ocaml//cfg/ns:strategy"
#         # ),
#     )

#######################
def options_ns_archive(ws):

    _submod_providers   = [
        [OcamlModuleMarker],
        [OcamlNsMarker],
        [OcamlSignatureProvider]
    ]

    # ws = "@" + ws
    ws = "@rules_ocaml" + ws

    return dict(
        _linkall     = attr.label(default = ws + "//cfg/archive/linkall"),
        # _threads     = attr.label(default = ws + "//cfg/cfg/ns/threads"),
        _warnings    = attr.label(default = ws + "//cfg/archive:warnings"),

        shared = attr.bool(
            doc = "True: build a shared lib (.cmxs)",
            default = False
        ),

        ns = attr.string(
            doc = "Namespace name is derived from 'name' attribute by default; use this to override."
        ),

        ## if submodules list includes a module with same name as ns,
        ## it will automatically be treated as the resolver.

        # ns_resolver = attr.label(
        #     doc = "Code to use as the ns resolver module instead of generated code. The module specified must contain pseudo-recursive alias equations for all submodules.  If this attribute is specified, an ns resolver module will be generated for resolving the alias equations of the provided module.",
        #     # allow_single_file = [".ml"]
        #     providers = [OcamlModuleMarker],
        # ),

        submodules = attr.label_list(
            doc = "List of *_module submodules",
            allow_files = [".cmo", ".cmx", ".cmi"],
            providers   = _submod_providers,
            cfg = ocaml_nslib_submodules_out_transition
        ),

        ## so we can dump ConfigState
        _ns_prefixes   = attr.label(
            doc = "Experimental",
            default = "@rules_ocaml//cfg/ns:prefixes"
        ),
        _ns_submodules = attr.label(
            doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
            default = "@rules_ocaml//cfg/ns:submodules",  # => string_list_setting
            # allow_files = True,
            # mandatory = True
        ),

        _ns_resolver = attr.label(
            doc = "Experimental",
            # allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            default = "@rules_ocaml//cfg/ns",
            cfg = ocaml_nslib_submodules_out_transition
        ),

        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),

        _mode = attr.label(
            default = ws + "//build/mode"
        ),
        # _projroot = attr.label(
        #     default = "@rules_ocaml//cfg:projroot"
        # )
    )

#######################
def options_ns_library(ws):

    ws_prefix = "@rules_ocaml" ## + ws

    return dict(
        _opts     = attr.label(default = ws_prefix + "//cfg/module:opts"),     # string list
        _linkall  = attr.label(default = ws_prefix + "//cfg/module/linkall"),  # bool
        # _threads   = attr.label(default = ws_prefix + "//module/threads"),   # bool
        _warnings = attr.label(default = ws_prefix + "//cfg/module:warnings"), # string list

        ns = attr.string(
            doc = "Namespace name is derived from 'name' attribute by default; use this to override."
        ),

        ## Note: this is for the user; transition fn uses it to populate ns:submodules
        submodules = attr.label_list(
            doc = "List of namespaced submodules; will be renamed by prefixing the namespace,",
            allow_files = [".cmo", ".cmx", ".cmi"],
            providers   = [[OcamlModuleMarker], [OcamlNsMarker]],
            cfg = ocaml_nslib_submodules_out_transition
        ),

        deps = attr.label_list(
            doc = "Non-namespaced deps of ns. Will not be renamed.",
            allow_files = [".cmo", ".cmx", ".cmi"],
            providers   = [OcamlModuleMarker],
            # cfg = ocaml_nslib_submodules_out_transition
        ),

        ## so we can dump ConfigState
        _ns_prefixes   = attr.label(
            doc = "Experimental",
            default = "@rules_ocaml//cfg/ns:prefixes"
        ),
        _ns_submodules = attr.label(
            doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
            default = "@rules_ocaml//cfg/ns:submodules",  # => string_list_setting
            # allow_files = True,
            # mandatory = True
        ),

        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
        # _projroot = attr.label(
        #     default = "@rules_ocaml//cfg:projroot" # used by ppx too
        # ),

    )

###################
def options_ns_opts(ws):

    return dict(

        # ns = attr.string(
        #     doc = "Namespace name is derived from 'name' attribute by default; use this to override."
        # ),

        _ns_prefixes   = attr.label(
            doc = "Experimental",
            default = "@rules_ocaml//cfg/ns:prefixes"
        ),
    )

###################
def options_ns_resolver(ws):

    ws = "@rules_ocaml" #  + ws

    return dict(

        ns = attr.string(),

        submodules = attr.string_list(
            # default = "@rules_ocaml//cfg/ns:submodules", # => string_list_setting
            doc = """
List of strings from which submodule names are to be derived for aliasing. Bazel labels may be used; the submodule name will be derived from the target part. For example, '//a/b:c' normalizes to C. But they are just strings, and will not be checked against any files.

The normalized submodule names must match the names of the modules electing membership via the 'ns_resolver' attribute.

 Module source code generated by ocamllex and ocamlyacc can be accomodated by using the module name for the source file and generating a .ml source file of the same name, e.g. lexer.mll -> lexer.ml.
            """,
            # allow_files = True,
            # mandatory = True
        ),

        # fusions = attr.label_keyed_string_dict(
        include = attr.label_keyed_string_dict(
            doc = """
Exogenous (sub)modules, namespaced or non-namespaced.  Aliased names will not be prefixed with ns name of this ns_resolver.

Keys: labels of modules;
Values: alias name to be used in this resolver.

e.g. '//mwe/rgb:R': 'Red' will generate

module R = Red
            """,
            providers = [
                [OcamlModuleMarker],     ## exogenous non-namespaced
                [OcamlNsSubmoduleMarker] ## exogenous namespaced
            ]
        ),

        embed = attr.label_keyed_string_dict(
            doc = """
Exogenous namespaces (resolver modules).
            """,
            providers = [
                [OcamlNsResolverProvider], ## subnamespace resolver
            ]
        ),

        merge = attr.label_list(
            doc = """
Includes all submodules of an exogenous namespace.
            """,
            providers = [
                [OcamlNsResolverProvider], ## subnamespace resolver
            ]
        ),

        # exclusions = attr.label_list(
        #     # enhancement: allow user to fuse entire ns except
        #     # submodules listed here for exclusion.
        # )

        _ns_prefixes   = attr.label(
            doc = "Experimental",
            default = ws + "//cfg/ns:prefixes"
        ),
        # _ns_strategy = attr.label(
        #     doc = "Experimental",
        #     default = "@rules_ocaml//cfg/ns:strategy"
        # ),

        ## OBSOLETE???
        _ns_submodules = attr.label( # _list(
            default = ws + "//cfg/ns:submodules", # => string_list_setting
            doc = "List of files from which submodule names are to be derived for aliasing. The names will be formed by truncating the extension and capitalizing the initial character. Module source code generated by ocamllex and ocamlyacc can be accomodated by using the module name for the source file and generating a .ml source file of the same name, e.g. lexer.mll -> lexer.ml.",
            allow_files = True,
            # mandatory = True
        ),
        ## OBSOLETE???
        _ns_sublibs = attr.label(
            default = ws + "//cfg/ns:sublibs",  # => string_list_setting
            doc = "List of *_ns_library submodules",
            allow_files = True,
            # mandatory = True
        ),

        # _mode = attr.label(
        #     default = ws + "//build/mode"
        # ),
        # _warnings  = attr.label(default = ws + "//cfg/ns:warnings"),
    )

###################
options_ppx = dict(
        ppx  = attr.label(
            doc = """
Label of `ppx_executable` target to be used to transform source before compilation.
            """,
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            providers = [PpxExecutableMarker]
        ),
        ppx_args  = attr.string_list(
            doc = "Options to pass to PPX executable passed by the `ppx` attribute.",
        ),
        ppx_data  = attr.label_list(
            doc = "PPX runtime data dependencies. List of labels of files needed by the PPX executable passed via the `ppx` attribute when it is executed to transform the source file. For example, a source file using link:https://github.com/janestreet/ppx_optcomp[ppx_optcomp] may import a file using extension `[%%import ]`; this file should be listed in this attribute.",
            allow_files = True,
        ),
        ppx_verbose = attr.bool(default = False),
        ppx_print = attr.label(
            doc = "Format of output of PPX transform. Value must be one of `@rules_ocaml//ppx/print:binary`, `@rules_ocaml//ppx/print:text`.  See link:../ug/ppx.md#ppx_print[PPX Support] for more information",
            default = "@rules_ocaml//ppx/print"
        ),
        # ppx_tags  = attr.string_list(
        #     doc = "DEPRECATED. List of tags.  Used to set e.g. -inline-test-libs, --cookies. Currently only one tag allowed."
        # )
)

################################################################
options_signature = dict(

        src = attr.label(
            doc = "A single .mli source file label",
            allow_single_file = [".mli", ".ml"] #, ".cmi"]
        ),

        ns = attr.label(
            doc = "Bottom-up namespacing",
            allow_single_file = True,
            mandatory = False
        ),

        as_cmi = attr.string(
            doc = "For use with ns_module only. Creates a symlink from the extracted cmi file."
        ),

        pack = attr.string(
            doc = "Experimental",
        ),

        deps = attr.label_list(
            doc = "List of OCaml dependencies. Use this for compiling a .mli source file with deps. See [Dependencies](#deps) for details.",
            providers = [
                [OcamlProvider],
                [OcamlArchiveMarker],
                [OcamlImportMarker],
                [OcamlLibraryMarker],
                [OcamlModuleMarker],
                [OcamlNsMarker],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),

        open = attr.label_list(
            doc = "List of OCaml dependencies to be passed with -open.",
            providers = [
                [OcamlProvider],
                [OcamlArchiveMarker],
                [OcamlImportMarker],
                [OcamlLibraryMarker],
                [OcamlModuleMarker],
                [OcamlNsMarker],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),

        data = attr.label_list(
            allow_files = True
        ),

        ################################################################
        _ns_resolver = attr.label(
            doc = "Experimental",
            providers = [OcamlNsResolverProvider],
            default = "@rules_ocaml//cfg/ns",
            # default = "@rules_ocaml//cfg/ns:bootstrap",
            # default = "@rules_ocaml//cfg/bootstrap/ns:resolver",
        ),

        _ns_submodules = attr.label( # _list(
            doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
            default = "@rules_ocaml//cfg/ns:submodules", ## NB: ppx modules use ocaml_signature
        ),
    )
