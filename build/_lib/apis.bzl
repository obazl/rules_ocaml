load("@rules_ocaml//build:providers.bzl", "OCamlDepsProvider")

load("//build:providers.bzl",
     "OcamlArchiveMarker",
     "OcamlExecutableMarker",
     "OCamlImportProvider",
     "OCamlLibraryProvider",
     "OCamlNsResolverProvider",
     "OCamlModuleProvider",
     "OcamlNsMarker",
     "OcamlNsSubmoduleMarker",
     "OCamlSignatureProvider",
)
load("@rules_ocaml//build:providers.bzl", "OCamlCodepsProvider")

# load("//build/_transitions:in_transitions.bzl")

load("//build/_transitions:out_transitions.bzl",
     "cc_deps_out_transition",
     "manifest_out_transition",
     "ocaml_module_sig_out_transition",
     "ocaml_binary_deps_out_transition",
     "ocaml_module_deps_out_transition",

     "ocaml_module_cc_deps_out_transition",
     "ocaml_nslib_main_out_transition",
     "ocaml_nslib_resolver_out_transition",
     "ocaml_nslib_submodules_out_transition",
     # "ocaml_nslib_sublibs_out_transition",
     "ocaml_nslib_ns_out_transition",
     )

load("//lib:colors.bzl", "CCRED", "CCDER", "CCMAG", "CCRESET")

################
def options(ws):

    ws = "@" + ws
    # ws = "@rules_ocaml"

    return dict(
        opts             = attr.string_list(
            doc          = "List of compile options; overrides configurable default options. Supports `+-no-+` prefix for each option; for example, `-no-linkall`."
        ),
        ## use opts with select to specify compiler-specific options
        # opts_ocamlc      = attr.string_list(
        #     doc          = "Compile options for toolchains targetting the VM."
        # ),
        # opts_ocamlopt    = attr.string_list(
        #     doc          = "Compile options for toolchains targetting sys native code."
        # ),
        ## GLOBAL CONFIGURABLE DEFAULTS (all ppx_* rules)
        ## these should never be directly set.
        _debug           = attr.label(default = ws + "//cfg:debug"),
        _cmt             = attr.label(default = "@rules_ocaml//cfg:cmt"),
        _keep_locs       = attr.label(default = ws + "//cfg:keep-locs"),
        _noassert        = attr.label(default = ws + "//cfg:noassert"),
        _opaque          = attr.label(default = ws + "//cfg:opaque"),
        _xmo             = attr.label(
            doc = "Cross-module optimization. Boolean",
            default = "@rules_ocaml//cfg:xmo"
        ),
        _short_paths     = attr.label(default = ws + "//cfg:short-paths"),
        _strict_formats  = attr.label(default = ws + "//cfg:strict-formats"),
        _strict_sequence = attr.label(default = ws + "//cfg:strict-sequence"),
        _verbose         = attr.label(default = ws + "//cfg:verbose"),

#         _mode       = attr.label(
#             default = ws + "//build/mode",
#         ),
#         mode       = attr.string(
#             doc     = """
# Overrides default build mode setting, `native` or `bytecode`. The default is set by `@rules_ocaml//build/mode`, which defaults to `native`.
#             """,
#         ),

        env = attr.string_dict(
            doc = "Env variables",
            allow_empty = True
        ),

#         argsfile       = attr.label(
#             doc = """
# Name of file containing newline-terminated arg lines, to be passed with `-args`.
#             NOT YET SUPPORTED
#             """,
#             allow_single_file = True,
#         ),

#         args0file       = attr.label(
#             doc = """
# Name of file containing null-terminated arg lines, to be passed with `-args0`.
#             NOT YET SUPPORTED
#             """,
#             allow_single_file = True,
#         ),

        # _sdkpath = attr.label(
        #     default = Label("@rules_ocaml//cfg:sdkpath") # ppx also uses this
        # ),
    )

#######################
def options_binary():

    # ws = "@" + ws
    ws = "@rules_ocaml"

    attrs = dict(
        _linkall     = attr.label(default = ws + "//cfg/executable:linkall"),
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

        _vm_ext = attr.label(
            default = "@rules_ocaml//cfg/executable:vm_ext"
        ),
        _sys_ext = attr.label(
            default = "@rules_ocaml//cfg/executable:sys_ext"
        ),

        ## DEPENDENCIES
        ## what is a dependency of a binary?
        ## implicitly, its a dependency of the main module.
        ## it cannot be a dep of the binary itself, since that does
        ## not exist yes (unlike e.g. a structfile whose code depends
        ## on some other module).

        archive_deps = attr.bool(default = False),

        prologue = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = [[OcamlArchiveMarker],
                         [OCamlImportProvider],
                         [OCamlLibraryProvider],
                         [OCamlModuleProvider],
                         [OcamlNsMarker],
                         [CcInfo]],
            # cfg = ocaml_binary_deps_out_transition
        ),

        main = attr.label(
            doc = "Label of module containing entry point of executable. In the list of dependencies, this will be placed after 'prologue' deps and before 'epilogue' deps.",
            mandatory = True,
            # allow_single_file = True,
            # providers = [[OCamlDepsProvider,OCamlModuleProvider]],
            default = None,
            # cfg = ocaml_binary_deps_out_transition
        ),

        epilogue = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = [[OcamlArchiveMarker],
                         [OCamlImportProvider],
                         [OCamlLibraryProvider],
                         [OCamlModuleProvider],
                         [OcamlNsMarker],
                         [CcInfo]],
            # cfg = ocaml_binary_deps_out_transition
        ),

        _deps = attr.label(
            doc = "Hidden dependencies, set by CLI, to be added last.",
            default = "@rules_ocaml//cfg/executable:deps"
        ),

        data = attr.label_list(
            allow_files = True,
            doc = "Runtime dependencies: list of labels of data files needed by this executable at runtime."
        ),
        data_prefix_map = attr.string_dict(
            doc = "Map for replacing path prefixes of data files"
        ),
        # strip_data_prefixes = attr.bool(
        #     doc = "Symlink each data file to the basename part in the runfiles root directory. E.g. test/foo.data -> foo.data.",
        #     default = False
        # ),

        ## FIXME: add cc_linkopts?
        ## FIXME: no need, cc deps can be added to deps
        cc_deps = attr.label_keyed_string_dict(
            doc = """Dictionary specifying C/C++ library dependencies. Key: a target label; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see [CC Dependencies: Linkmode](../ug/cc_deps.md#linkmode).
            """,
            ## FIXME: cc libs could come from LSPs that do not support CcInfo, e.g. rules_rust
            # providers = [[CcInfo]]
        ),
        _cc_deps = attr.label(
            doc = "Global C/C++ library dependencies. Apply to all instances of ocaml_binary.",
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
            doc = "List of C/C++ link options. E.g. [\"-lstd++\"].",

        ),

        runtime = attr.label(
            doc = "runtime to use",
            default = "@rules_ocaml//rt:std"
        ),

        vm_linkage = attr.string(
            doc = "custom, dynamic or static. Custom means link with -custom flag; static with -output-complete-exe",
            values = ["custom", "static", "dynamic"],
            default = "custom"
        ),

        # mode = attr.label(
        #     default = ws + "//build/mode"
        # ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    )
    return attrs


#######################
def options_aggregators():

    _providers = [
        [OcamlArchiveMarker],
        [OCamlLibraryProvider],
        [OCamlModuleProvider],
        [OCamlNsResolverProvider],
        [OcamlNsMarker],
        [OCamlSignatureProvider],
    ]

    return dict(

        # rename = attr.string(
        ns_name = attr.string(
        ),

        manifest = attr.label_list(
            doc = "List of component modules, for libraries and archives.",
            providers = [[OcamlArchiveMarker],
                         [OCamlImportProvider],
                         [OCamlLibraryProvider],
                         [OCamlModuleProvider],
                         [OCamlNsResolverProvider],
                         ## sigs are ok in libraries, not archives
                         [OCamlSignatureProvider]
                         ],
            cfg = manifest_out_transition
        ),
        # aliases = attr.label_keyed_string_dict(),

        _ns_resolver = attr.label(
            doc = "Implicit resolver module generated by ocaml_ns_resolver",
            providers = [OCamlNsResolverProvider],
            default = "@rules_ocaml//cfg/ns:resolver",
            cfg = ocaml_nslib_resolver_out_transition
        ),

        _ns_submodules = attr.label(
            doc = "List of submodules.",
            ## to be set by out transition fn?
            default = "@rules_ocaml//cfg/ns:submodules",
        ),

        _ns_prefixes   = attr.label(
            doc = "String to be prefixed to submodule filenames.",
            ## to be set by transition fn
            default = "@rules_ocaml//cfg/ns:prefixes"
        ),

        # vm_runtime = attr.label(
        #     doc = "@rules_ocaml//cfg/runtime:dynamic (default), @rules_ocaml//cfg/runtime:static, or a custom ocaml_runtime target label",
        #     default = "@rules_ocaml//cfg/runtime:dynamic"
        # ),

        cc_deps = attr.label_list(
            doc = "Static (.a) or dynamic (.so, .dylib) libraries. Must deliver a CcInfo provider. Since ocaml rules may deliver CcInfo providers, we cannnot assume these deps are produced directly by rules_cc.",
            providers = [CcInfo],
            cfg = cc_deps_out_transition
        ),

        _cc_deps = attr.label(
            doc = "Global cc-deps, apply to all instances of rule. Added last.",
            # default = "@rules_ocaml//cfg/ns:deps",
            providers = [CcInfo],
        ),

        cc_linkage = attr.label_keyed_string_dict(
            doc = """Dictionary specifying C/C++ library dependencies. Allows finer control over linking than the 'cc_deps' attribute. Key: a target label providing CcInfo; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see link:../user-guide/dependencies-cc#_cc-linkmode[CC Dependencies: Linkmode].
            """,
            # providers = since this is a dictionary depset, no
            # providers constraints, but the keys must have CcInfo
            # providers, check at build time
            ## cfg = ocaml_module_cc_deps_out_transition
        ),

        _linklevel = attr.label(
            default = "@rules_ocaml//cfg/library/linkage:level"
        ),
        _linkage = attr.label(
            default = "@rules_ocaml//cfg/library/linkage"
        ),
        linkage = attr.string(
            doc = "Overrides hidden _linkage",
            values = ["static", "shared"]
        ),
        shared = attr.bool(
            doc = "True: build a shared lib (.cmxs)",
            default = False
        ),

        ## FIXME: why?
        standalone = attr.bool(
            doc = "True: link total depgraph. False: link only direct deps.",
            default = False
        ),

        ## CONFIGURABLE DEFAULTS
        _linkall     = attr.label(default = "@rules_ocaml//cfg/archive/linkall"),
        # _threads     = attr.label(default = "@rules_ocaml//cfg/archive/threads"),
        _warnings  = attr.label(default = "@rules_ocaml//cfg/archive:warnings"),
    )

#######################
# def options_pack_library(ws):

#     providers = [[OcamlArchiveMarker],
#                  [OCamlSignatureProvider],
#                  [OCamlLibraryProvider],
#                  [OCamlModuleProvider],
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
#         #     providers = [OCamlNsResolverProvider],
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
def options_ns_aggregators():

    ws_prefix = "@rules_ocaml" ## + ws

    return dict(
        _opts     = attr.label(default = ws_prefix + "//cfg/module:opts"),     # string list
        _linkall  = attr.label(default = ws_prefix + "//cfg/module/linkall"),  # bool
        # _threads   = attr.label(default = ws_prefix + "//module/threads"),   # bool
        _warnings = attr.label(default = ws_prefix + "//cfg/module:warnings"), # string list

        ## Note: this is for the user; transition fn uses it to populate ns:submodules

        archive_name = attr.string(
            doc = "Name of generated archive file, without extension. If not provided, name will be derived from target 'name' attribute.  Ignored if archived == False."
        ),

        ns_name = attr.string(
            doc = "Namespace name is derived from 'name' attribute by default; use this to override."
        ),

        # _ns_name = attr.label(
        #     doc = "Implicit namespace name",
        #     # providers = [OCamlNsResolverProvider],
        #     # string
        #     default = "@rules_ocaml//cfg/ns:name",
        #     # cfg = ocaml_nslib_resolver_out_transition
        # ),

        _ns_resolver = attr.label(
            doc = "Implicit resolver module generated by ocaml_ns_resolver",
            providers = [OCamlNsResolverProvider],
            default = "@rules_ocaml//cfg/ns:resolver",
            cfg = ocaml_nslib_resolver_out_transition
        ),

        ## not yet:
        # resolver = attr.label(
        #     doc = """User-provided resolver module.""",
        #     allow_single_file = True,
        #     providers = [OCamlModuleProvider],
        #     cfg = ocaml_nslib_resolver_out_transition
        #     ## user-provided resolver is not itself namespaced,
        #     ## do not use transition
        # ),

        manifest = attr.label_list(
            doc = "List of namespaced submodules; will be renamed by prefixing the namespace,",
            allow_files = [".cmo", ".cmx", ".cmi", ".cmxa", ".cma"],
            providers   = [[OCamlModuleProvider], [OcamlNsMarker]],
            cfg = ocaml_nslib_submodules_out_transition
        ),
        # aliases = attr.label_keyed_string_dict(),

        _ns_submodules = attr.label(
            doc = "List of submodules.",
            ## to be set by out transition fn?
            default = "@rules_ocaml//cfg/ns:submodules",
        ),

        _ns_prefixes   = attr.label(
            doc = "String to be prefixed to submodule filenames.",
            ## to be set by transition fn
            default = "@rules_ocaml//cfg/ns:prefixes"
        ),

        cc_deps = attr.label_list(
            doc = "Static (.a) or dynamic (.so, .dylib) libraries. Must by built or imported using Bazel's rules_cc ruleset (thus providing CcInfo output).",
            providers = [CcInfo],
        ),

        cc_linkage = attr.label_keyed_string_dict(
            doc = """Dictionary specifying C/C++ library dependencies. Allows finer control over linking than the 'cc_deps' attribute. Key: a target label providing CcInfo; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see link:../user-guide/dependencies-cc#_cc-linkmode[CC Dependencies: Linkmode].
            """,
            # providers = since this is a dictionary depset, no
            # providers constraints, but the keys must have CcInfo
            # providers, check at build time
            ## cfg = ocaml_module_cc_deps_out_transition
        ),

        _cc_deps = attr.label(
            doc = "Global cc-deps, apply to all instances of rule. Added last.",
            # default = "@rules_ocaml//cfg/ns:deps",
            providers = [CcInfo],
        ),

        _linklevel = attr.label(
            default = "@rules_ocaml//cfg/library/linkage:level"
        ),
        _linkage = attr.label(
            default = "@rules_ocaml//cfg/library/linkage"
        ),
        linkage = attr.string(
            doc = "Overrides hidden _linkage",
            values = ["static", "shared"]
        ),
        # shared = attr.bool(
        #     doc = "True: build a shared lib (.cmxs)",
        #     default = False
        # ),

        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
        # _projroot = attr.label(
        #     default = "@rules_ocaml//cfg:projroot" # used by ppx too
        # ),

    )

#######################
## DEPRECATED - use options_ns_aggregators
# def options_ns_archive():

#     # _submod_providers   = [
#     #     [OCamlModuleProvider],
#     #     [OcamlNsMarker],
#     #     [OCamlSignatureProvider]
#     # ]

#     # ws = "@" + ws
#     ws = "@rules_ocaml" + ws

#     return dict(
#         _linkall     = attr.label(default = ws + "//cfg/archive/linkall"),
#         # _threads     = attr.label(default = ws + "//cfg/cfg/ns/threads"),
#         _warnings    = attr.label(default = ws + "//cfg/archive:warnings"),

#         shared = attr.bool(
#             doc = "True: build a shared lib (.cmxs)",
#             default = False
#         ),

#         ns = attr.string(
#             doc = "Namespace name is derived from 'name' attribute by default; use this to override."
#         ),

#         ns_resolver = attr.label(
#             doc = """User-provided resolver module.""",
#             allow_single_file = True,
#             providers = [OCamlModuleProvider],
#             ## user-provided resolver is not itself namespaced,
#             ## do not use transition
#             # cfg = ocaml_nslib_submodules_out_transition
#         ),

#         submodules = attr.label_list(
#             doc = "List of *_module submodules",
#             allow_files = [".cmo", ".cmx", ".cmi"],
#             providers   = [[OCamlModuleProvider], [OcamlNsMarker]],
#             # providers   = _submod_providers,
#             cfg = ocaml_nslib_submodules_out_transition
#         ),

#         _ns_submodules = attr.label( # Not needed?
#             doc = "A configuration setting set by transition function on submodules attribute, passed to submodules and ns resolver.",
#             default = "@rules_ocaml//cfg/ns:submodules",
#         ),

#         _ns_resolver = attr.label(
#             doc = "Resolver module generated by ocaml_ns_resolver",
#             providers = [OCamlNsResolverProvider],
#             default = "@rules_ocaml//cfg/ns:resolver",
#             cfg = ocaml_nslib_submodules_out_transition
#         ),

#         _ns_prefixes   = attr.label(
#             doc = "String to be prefixed to submodule filenames. Set by transition function.",
#             default = "@rules_ocaml//cfg/ns:prefixes"
#         ),

#         _allowlist_function_transition = attr.label(
#             default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
#         ),

#         # _mode = attr.label(
#         #     default = ws + "//build/mode"
#         # ),
#         # _projroot = attr.label(
#         #     default = "@rules_ocaml//cfg:projroot"
#         # )
#     )

# #######################
# ## DEPRECATED - use options_ns_aggregators
# def options_ns_library():

#     ws_prefix = "@rules_ocaml" ## + ws

#     return dict(
#         _opts     = attr.label(default = ws_prefix + "//cfg/module:opts"),     # string list
#         _linkall  = attr.label(default = ws_prefix + "//cfg/module/linkall"),  # bool
#         # _threads   = attr.label(default = ws_prefix + "//module/threads"),   # bool
#         _warnings = attr.label(default = ws_prefix + "//cfg/module:warnings"), # string list

#         ## Note: this is for the user; transition fn uses it to populate ns:submodules

#         ns = attr.string(
#             doc = "Namespace name is derived from 'name' attribute by default; use this to override."
#         ),

#         ns_resolver = attr.label(
#             doc = """User-provided resolver module.""",
#             allow_single_file = True,
#             providers = [OCamlModuleProvider],
#             ## user-provided resolver is not itself namespaced,
#             ## do not use transition
#             # cfg = ocaml_nslib_submodules_out_transition
#         ),

#         submodules = attr.label_list(
#             doc = "List of namespaced submodules; will be renamed by prefixing the namespace,",
#             allow_files = [".cmo", ".cmx", ".cmi"],
#             providers   = [[OCamlModuleProvider], [OcamlNsMarker]],
#             cfg = ocaml_nslib_submodules_out_transition
#         ),

#         _ns_submodules = attr.label(
#             doc = "List of submodules.",
#             default = "@rules_ocaml//cfg/ns:submodules",
#         ),

#         _ns_resolver = attr.label(
#             doc = "Resolver module generated by ocaml_ns_resolver",
#             providers = [OCamlNsResolverProvider],
#             default = "@rules_ocaml//cfg/ns:resolver",
#             cfg = ocaml_nslib_resolver_out_transition
#         ),

#         _ns_prefixes   = attr.label(
#             doc = "String to be prefixed to submodule filenames.",
#             default = "@rules_ocaml//cfg/ns:prefixes"
#         ),

#         _allowlist_function_transition = attr.label(
#             default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
#         ),
#         # _projroot = attr.label(
#         #     default = "@rules_ocaml//cfg:projroot" # used by ppx too
#         # ),

#     )

###################
def options_ns_opts(ws):

    return dict(

        # ns = attr.string(
        #     doc = "Namespace name is derived from 'name' attribute by default; use this to override."
        # ),

        _ns_prefixes   = attr.label(
            default = "@rules_ocaml//cfg/ns:prefixes"
        ),
    )

###################
# def options_ns_resolver(ws):

#     ws = "@rules_ocaml" #  + ws

#     return dict(

#     )

###################
options_ppx = dict(
    # _ppx_only = attr.label(
    #     doc = "Stop processing after ppx xform action. Tools can use this to inspect the ppx xform output, e.g. @obazl//inspect:ppx",
    #     default = "@rules_ocaml//ppx:stop" # default False
    #     ),

    ppx  = attr.label(
        doc = """
        Label of `ppx_executable` target to be used to transform source before compilation.
        """,
        executable = True,
        cfg = "exec",
        # cfg = _ppx_transition,
        allow_single_file = True,
        providers = [OcamlExecutableMarker]
    ),
    # _allowlist_function_transition = attr.label(
    #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
    # ),

    ppx_args  = attr.string_list(
        doc = "Options to pass to PPX executable passed by the `ppx` attribute.",
    ),
    ppx_data  = attr.label_list(
        doc = "PPX runtime data dependencies. List of labels of files needed by the PPX executable passed via the `ppx` attribute when it is executed to transform the source file. For example, a source file using link:https://github.com/janestreet/ppx_optcomp[ppx_optcomp] may import a file using extension `[%%import ]`; this file should be listed in this attribute.",
        allow_files = True,
    ),
    ppx_verbose = attr.bool(default = False),
    ppx_print = attr.label(  ##FIXME: make this a string attr.
        doc = "Format of output of PPX transform: binary (default) or text. Value must be one of `@rules_ocaml//ppx/print:binary!` or `@rules_ocaml//ppx/print:text!`.",
        default = None #"@rules_ocaml//ppx/print"
    ),
    _ppx_print = attr.label(
        doc = "Format of output of PPX transform. Value must be one of `@rules_ocaml//ppx/print:binary!` or `@rules_ocaml//ppx/print:text!`.  See link:../ug/ppx.md#ppx_print[PPX Support] for more information",
        default = None # "@rules_ocaml//ppx/print"
    ),
    # ppx_tags  = attr.string_list(
    #     doc = "DEPRECATED. List of tags.  Used to set e.g. -inline-test-libs, --cookies. Currently only one tag allowed."
    # )
)

#######################
def options_module(ws):

    _providers = [[OcamlArchiveMarker],
                  [OCamlDepsProvider],
                  [OCamlCodepsProvider],
                  [OCamlImportProvider],
                  [OCamlLibraryProvider],
                  [OCamlModuleProvider],
                  # [OcamlNsMarker],
                  [OCamlNsResolverProvider],
                  # [OCamlSignatureProvider],
                  [CcInfo],
                  [CcSharedLibraryInfo]]

    # ws = "@" + ws
    ws = "@rules_ocaml"

    return dict(
        _opts     = attr.label(default = ws + "//cfg/module:opts"),
        _linkall  = attr.label(default = ws + "//cfg/module/linkall"),
        _warnings = attr.label(
            default = "@rules_ocaml//cfg/module:warnings"
        ),

        _normalize_modname = attr.label(
            default = "@rules_ocaml//cfg/module:normalize"
        ),

        _rule = attr.string( default = "ocaml_module" ),

        module_name = attr.string(
            doc = "Use this string as module name, instead of deriving it from sig or struct"
        ),

        sig = attr.label(
            doc = "Single label of a target producing `OCamlSignatureProvider` (i.e. rule `ocaml_signature`) OR a sig source file. Optional.",
            allow_single_file = True,
            # providers = [OCamlSignatureProvider],
            #              [OCamlImportProvider]]
            ## FIXME: how to specify OCamlSignatureProvider OR FileProvider?
            # allow_files = True
            #              ["File"]],
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

        pack = attr.label_list(
            doc = "Experimental.  List of pack submodules. They will be compiled with -for-pack, and this module will be compile with -pack."
        ),

        open = attr.label_list(
            doc = "List of OCaml dependencies to be passed with `-open`.",
            providers = [
                [OCamlDepsProvider],
                [OcamlArchiveMarker],
                [OCamlImportProvider],
                [OCamlLibraryProvider],
                [OCamlModuleProvider],
                [OcamlNsMarker],
            ],
            # cfg = ocaml_signature_deps_out_transition
        ),

        deps_runtime = attr.label_list(
            doc = """
Runtime module dependencies, e.g. .cmxs plugins. Use the `data` attribute for runtime data dependencies.
            """
        ),

        data = attr.label_list(
            allow_files = True,
            doc = """
Runtime data dependencies: list of labels of data files needed by this module at runtime. This is a standard Bazel attribute; see link:https://bazel.build/reference/be/common-definitions#typical-attributes[Typical attributes,window="_blank"].
            """
        ),

        ################
        cc_deps = attr.label_list(
            doc = "Static (.a) or dynamic (.so, .dylib) libraries. Must by built or imported using Bazel's rules_cc ruleset (thus providing CcInfo output).",
            providers = [CcInfo],
            # out transition sets compilation mode to opt
            cfg = ocaml_module_cc_deps_out_transition
        ),

        cc_linkage = attr.label_keyed_string_dict(
            ## FIXME: the val string should allow user to
            ## specify linker flags and options?
            doc = """Dictionary specifying C/C++ library dependencies. Allows finer control over linking than the 'cc_deps' attribute. Key: a target label providing CcInfo; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see link:../user-guide/dependencies-cc#_cc-linkmode[CC Dependencies: Linkmode].
            """,
            # providers = since this is a dictionary depset, no
            # providers constraints, but the keys must have CcInfo
            # providers, check at build time
            ## cfg = ocaml_module_cc_deps_out_transition
        ),

        _cc_deps = attr.label(
            doc = "Global cc-deps, apply to all instances of rule. Added last.",
            default = ws + "//cfg/module:deps"
        ),

        _xmo = attr.label(
            doc = "Cross-module optimization. Boolean",
            default = "@rules_ocaml//cfg:xmo"
        )
    )

