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
     "ocaml_binary_deps_out_transition",
     "ocaml_module_deps_out_transition")

load("//ocaml/_transitions:ns_transitions.bzl",
     "ocaml_module_cc_deps_out_transition",
     "ocaml_nslib_main_out_transition",
     "ocaml_nslib_resolver_out_transition",
     "ocaml_nslib_submodules_out_transition",
     # "ocaml_nslib_sublibs_out_transition",
     "ocaml_nslib_ns_out_transition",
     )

load("//ocaml/_debug:colors.bzl", "CCRED", "CCDER", "CCMAG", "CCRESET")

#########################################
def _ppx_transition_impl(settings, attr):
    print("{color}_ppx_transition{reset}: {lbl}".format(
        color=CCDER, reset = CCRESET, lbl = attr.name
    ))

    print("build host: %s" % settings["//command_line_option:host_platform"])
    print("target host: %s" % settings["//command_line_option:platforms"])

    return {
        "@rules_ocaml//cfg/toolchain:build-host":
        settings["//command_line_option:host_platform"].name,
        "@rules_ocaml//cfg/toolchain:target-host":
        [x.name for x in settings["//command_line_option:platforms"]]
    }

################
_ppx_transition = transition(
    implementation = _ppx_transition_impl,
    inputs = [
        "@rules_ocaml//cfg/toolchain:build-host",
        "@rules_ocaml//cfg/toolchain:target-host",
        # special labels for Bazel native command line args:
        "//command_line_option:host_platform",
        "//command_line_option:platforms",
    ],
    outputs = [
        "@rules_ocaml//cfg/toolchain:build-host",
        "@rules_ocaml//cfg/toolchain:target-host"
    ]
)

################
def options(ws):

    # ws = "@" + ws
    ws = "@rules_ocaml"

    return dict(
        opts             = attr.string_list(
            doc          = "List of compile options; overrides configurable default options. Supports `+-no-+` prefix for each option; for example, `-no-linkall`."
        ),
        opts_ocamlc      = attr.string_list(
            doc          = "Compile options for toolchains targetting the VM."
        ),
        opts_ocamlopt    = attr.string_list(
            doc          = "Compile options for toolchains targetting sys native code."
        ),
        ## GLOBAL CONFIGURABLE DEFAULTS (all ppx_* rules)
        ## these should never be directly set.
        _debug           = attr.label(default = ws + "//cfg:debug"),
        _cmt             = attr.label(default = ws + "//cfg:cmt"),
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

        argsfile       = attr.label(
            doc = """
Name of file containing newline-terminated arg lines, to be passed with `-args`.
            NOT YET SUPPORTED
            """,
            allow_single_file = True,
        ),

        args0file       = attr.label(
            doc = """
Name of file containing null-terminated arg lines, to be passed with `-args0`.
            NOT YET SUPPORTED
            """,
            allow_single_file = True,
        ),

        # _sdkpath = attr.label(
        #     default = Label("@rules_ocaml//cfg:sdkpath") # ppx also uses this
        # ),
    )

#######################
def options_binary():

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
            providers = [[OcamlProvider,OcamlModuleMarker]],
            default = None,
            # cfg = ocaml_binary_deps_out_transition
        ),
        data = attr.label_list(
            allow_files = True,
            doc = "Runtime dependencies: list of labels of data files needed by this executable at runtime."
        ),
        strip_data_prefixes = attr.bool(
            doc = "Symlink each data file to the basename part in the runfiles root directory. E.g. test/foo.data -> foo.data.",
            default = False
        ),

        # This is a list of modules to link into the executable; it is
        # NOT a list of "executable dependencies", which would make no
        # sense. IOW not like a module's compile dependencies. So this
        # is a list of components but not "submodules"; hence
        # 'manifest' instead of 'submodules'. Compare
        # ocaml_library.manifest v. ocaml_ns_library.submodules.
        manifest = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = [[OcamlArchiveMarker],
                         [OcamlImportMarker],
                         [OcamlLibraryMarker],
                         [OcamlModuleMarker],
                         [OcamlNsMarker],
                         [CcInfo]],
            # cfg = ocaml_binary_deps_out_transition
        ),

        _deps = attr.label(
            doc = "Dependency to be added last.",
            default = "@rules_ocaml//cfg/executable:deps"
        ),


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
            doc = "List of C/C++ link options. E.g. `[\"-lstd++\"]`.",

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
        [OcamlLibraryMarker],
        [OcamlModuleMarker],
        [OcamlNsResolverProvider],
        [OcamlNsMarker],
        [OcamlSignatureProvider],
    ]

    return dict(
        manifest = attr.label_list(
            doc = "List of component modules, for libraries and archives.",
            providers = [[OcamlArchiveMarker],
                         [OcamlImportMarker],
                         [OcamlLibraryMarker],
                         [OcamlModuleMarker],
                         [OcamlNsMarker],
                         ## sigs are ok in libraries, not archives
                         # [OcamlSignatureMarker]
                         ],
        ),


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
def options_ns_aggregators():

    ws_prefix = "@rules_ocaml" ## + ws

    return dict(
        _opts     = attr.label(default = ws_prefix + "//cfg/module:opts"),     # string list
        _linkall  = attr.label(default = ws_prefix + "//cfg/module/linkall"),  # bool
        # _threads   = attr.label(default = ws_prefix + "//module/threads"),   # bool
        _warnings = attr.label(default = ws_prefix + "//cfg/module:warnings"), # string list

        ## Note: this is for the user; transition fn uses it to populate ns:submodules

        ns = attr.string(
            doc = "Namespace name is derived from 'name' attribute by default; use this to override."
        ),

        resolver = attr.label(
            doc = """User-provided resolver module.""",
            allow_single_file = True,
            providers = [OcamlModuleMarker],
            ## user-provided resolver is not itself namespaced,
            ## do not use transition
            # cfg = ocaml_nslib_submodules_out_transition
        ),

        submodules = attr.label_list(
            doc = "List of namespaced submodules; will be renamed by prefixing the namespace,",
            allow_files = [".cmo", ".cmx", ".cmi"],
            providers   = [[OcamlModuleMarker], [OcamlNsMarker]],
            cfg = ocaml_nslib_submodules_out_transition
        ),

        _ns_submodules = attr.label(
            doc = "List of submodules.",
            default = "@rules_ocaml//cfg/ns:submodules",
        ),

        _ns_resolver = attr.label(
            doc = "Resolver module generated by ocaml_ns_resolver",
            providers = [OcamlNsResolverProvider],
            default = "@rules_ocaml//cfg/ns:resolver",
            cfg = ocaml_nslib_resolver_out_transition
        ),

        _ns_prefixes   = attr.label(
            doc = "String to be prefixed to submodule filenames.",
            default = "@rules_ocaml//cfg/ns:prefixes"
        ),

        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
        # _projroot = attr.label(
        #     default = "@rules_ocaml//cfg:projroot" # used by ppx too
        # ),

    )

#######################
## DEPRECATED - use options_ns_aggregators
def options_ns_archive():

    # _submod_providers   = [
    #     [OcamlModuleMarker],
    #     [OcamlNsMarker],
    #     [OcamlSignatureProvider]
    # ]

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

        ns_resolver = attr.label(
            doc = """User-provided resolver module.""",
            allow_single_file = True,
            providers = [OcamlModuleMarker],
            ## user-provided resolver is not itself namespaced,
            ## do not use transition
            # cfg = ocaml_nslib_submodules_out_transition
        ),

        submodules = attr.label_list(
            doc = "List of *_module submodules",
            allow_files = [".cmo", ".cmx", ".cmi"],
            providers   = [[OcamlModuleMarker], [OcamlNsMarker]],
            # providers   = _submod_providers,
            cfg = ocaml_nslib_submodules_out_transition
        ),

        _ns_submodules = attr.label( # Not needed?
            doc = "A configuration setting set by transition function on submodules attribute, passed to submodules and ns resolver.",
            default = "@rules_ocaml//cfg/ns:submodules",
        ),

        _ns_resolver = attr.label(
            doc = "Resolver module generated by ocaml_ns_resolver",
            providers = [OcamlNsResolverProvider],
            default = "@rules_ocaml//cfg/ns:resolver",
            cfg = ocaml_nslib_submodules_out_transition
        ),

        _ns_prefixes   = attr.label(
            doc = "String to be prefixed to submodule filenames. Set by transition function.",
            default = "@rules_ocaml//cfg/ns:prefixes"
        ),

        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),

        # _mode = attr.label(
        #     default = ws + "//build/mode"
        # ),
        # _projroot = attr.label(
        #     default = "@rules_ocaml//cfg:projroot"
        # )
    )

#######################
## DEPRECATED - use options_ns_aggregators
def options_ns_library():

    ws_prefix = "@rules_ocaml" ## + ws

    return dict(
        _opts     = attr.label(default = ws_prefix + "//cfg/module:opts"),     # string list
        _linkall  = attr.label(default = ws_prefix + "//cfg/module/linkall"),  # bool
        # _threads   = attr.label(default = ws_prefix + "//module/threads"),   # bool
        _warnings = attr.label(default = ws_prefix + "//cfg/module:warnings"), # string list

        ## Note: this is for the user; transition fn uses it to populate ns:submodules

        ns = attr.string(
            doc = "Namespace name is derived from 'name' attribute by default; use this to override."
        ),

        ns_resolver = attr.label(
            doc = """User-provided resolver module.""",
            allow_single_file = True,
            providers = [OcamlModuleMarker],
            ## user-provided resolver is not itself namespaced,
            ## do not use transition
            # cfg = ocaml_nslib_submodules_out_transition
        ),

        submodules = attr.label_list(
            doc = "List of namespaced submodules; will be renamed by prefixing the namespace,",
            allow_files = [".cmo", ".cmx", ".cmi"],
            providers   = [[OcamlModuleMarker], [OcamlNsMarker]],
            cfg = ocaml_nslib_submodules_out_transition
        ),

        _ns_submodules = attr.label(
            doc = "List of submodules.",
            default = "@rules_ocaml//cfg/ns:submodules",
        ),

        _ns_resolver = attr.label(
            doc = "Resolver module generated by ocaml_ns_resolver",
            providers = [OcamlNsResolverProvider],
            default = "@rules_ocaml//cfg/ns:resolver",
            cfg = ocaml_nslib_resolver_out_transition
        ),

        _ns_prefixes   = attr.label(
            doc = "String to be prefixed to submodule filenames.",
            default = "@rules_ocaml//cfg/ns:prefixes"
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
    _ppx_only = attr.label(
        doc = "Stop processing after ppx xform action. Tools can use this to inspect the ppx xform output, e.g. @obazl//inspect:ppx",
        default = "@rules_ocaml//ppx:stop" # default False
        ),

    ppx  = attr.label(
        doc = """
        Label of `ppx_executable` target to be used to transform source before compilation.
        """,
        executable = True,
        cfg = "target",
        # cfg = _ppx_transition,
        allow_single_file = True,
        providers = [PpxExecutableMarker]
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

    ns_resolver = attr.label(
        doc = "Bottom-up namespacing",
        allow_single_file = True,
        mandatory = False
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
        default = "@rules_ocaml//cfg/ns:resolver",
        # default = "@rules_ocaml//cfg/ns:bootstrap",
        # default = "@rules_ocaml//cfg/bootstrap/ns:resolver",
    ),

    # _ns_submodules = attr.label( # _list(
    #     doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
    #     default = "@rules_ocaml//cfg/ns:submodules", ## NB: ppx modules use ocaml_signature
    # ),

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
        _opts     = attr.label(default = ws + "//cfg/module:opts"),
        _linkall  = attr.label(default = ws + "//cfg/module/linkall"),
        _warnings = attr.label(
            default = "@rules_ocaml//cfg/module:warnings"
        ),

        _rule = attr.string( default = "ocaml_module" ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),

        module = attr.string(
            doc = "Use this string as module name, instead of deriving it from sig or struct"
        ),

        struct = attr.label(
            doc = "A single module (struct) source file label.",
            mandatory = True,
            allow_single_file = True # no constraints on extension
        ),

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

        pack = attr.label_list(
            doc = "Experimental.  List of pack submodules. They will be compiled with -for-pack, and this module will be compile with -pack."
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
            default = ws + "//cfg/module:deps"
        ),

        ################
        ## for namespacing we only need the resolver, we get the ns
        ## prefix and submodules list from it.

        ## we have both a public and a hidden ns resolver attribute.
        ## the latter is for top-down namespacing, for former for bottom-up
        ns_resolver = attr.label(
            doc = """
NS resolver module for bottom-up namespacing. Modules may use this attribute to elect membership in a bottom-up namespace.
            """,
            allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            mandatory = False
        ),

        # ns = attr.label(
        #     doc = "Label of ocaml_ns target"
        # ),
        _ns_resolver = attr.label(
            doc = "NS resolver module for bottom-up namespacing",
            # allow_single_file = True,
            providers = [OcamlNsResolverProvider],
            ## @rules_ocaml//cfg/ns is a 'label_setting' whose value is an
            ## `ocaml_ns_resolver` rule. so this institutes a
            ## dependency on a resolver whose build params will be set
            ## dynamically using transition functions.
            default = "@rules_ocaml//cfg/ns:resolver",

            ## TRICKY BIT: if our struct is generated (e.g. by
            ## ocaml_lex), this transition will prevent ns renaming:
            # cfg = ocaml_module_deps_out_transition
        ),

        _xmo = attr.label(
            doc = "Cross-module optimization. Boolean",
            default = "@rules_ocaml//cfg:xmo"
        )
    )

