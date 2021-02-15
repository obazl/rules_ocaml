load("//ocaml:providers.bzl",
     "OcamlSignatureProvider",
     "OcamlNsEnvProvider",
     "OpamPkgInfo",
     "OpamDepsProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load("options.bzl", "options", "options_ppx")

load(":impl_module.bzl", "impl_module")

load("//ppx/_transitions:transitions.bzl", "ppx_mode_transition")

OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]

################################
rule_options = options("@ocaml")
rule_options.update(options_ppx)

##################
ppx_module = rule(
    implementation = impl_module,
    doc = """Compiles a Ppx module. Provides: [PpxModuleProvider](providers_ppx.md#ppxmoduleprovider).

TODO: finish docstring

    """,
    attrs = dict(
        rule_options,
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
            allow_files = True,
            ## FIXME: add providers constraints, issue #18
            # providers = [OpamPkgInfo]
        ),
        _deps = attr.label(
            doc = "Global deps, apply to all instances of rule. Added last.",
            default = "@ppx//module:deps"
        ),
        deps_opam = attr.string_list(
            doc = "List of OPAM package names"
        ),
        deps_adjunct = attr.string_list(
            doc = "List of adjunct deps.",
        ),
        deps_adjunct_opam = attr.string_list(
            doc = "List of OPAM adjunct deps.",
        ),
        runtime_deps  = attr.label_list(
            doc = "PPX runtime dependencies. E.g. a file used by %%import from ppx_optcomp.",
            allow_files = True,
        ),
        doc = attr.string(doc = "Docstring"),
        ns_env = attr.label(
            doc = "Label of an ocaml_ns_env target. Used for renaming struct source file. See [Namepaces](../namespaces.md) for more information.",
            providers = [OcamlNsEnvProvider],
            default = None
        ),
        # module_name = attr.string(
        #     doc = "Allows user to specify a module name different than the target name."
        # ),
        prefix = attr.label(
            doc = "Label of an ocaml_ns_env target. Used for renaming struct source file. See [Namepaces](../namespaces.md) for more information.",
            providers = [OcamlNsEnvProvider],
            default = None
        ),
        ns   = attr.label(
            doc = "Label of a [ppx_ns](#ppx_ns) target. Used to derive namespace, output name, -open arg, etc.",
        ),
        ns_init = attr.label(
            doc = "Experimental",
            # default = Label("@ocaml//ns/init")
        ),
        struct = attr.label(
            mandatory = True,  # use ocaml_signature for isolated .mli files
            doc = "A single .ml source file label.",
            allow_single_file = OCAML_IMPL_FILETYPES
        ),
        sig = attr.label(
            doc = "Single label of a target providing a single .cmi file (not a .mli source file). Optional",
            allow_single_file = [".cmi"],
            providers = [OcamlSignatureProvider],
        ),
        data = attr.label_list(
            doc = "Runtime dependencies: list of labels of data files needed by this module at runtime."
        ),
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ppx//module/linkall"), # FIXME: call it alwayslink?
        _thread         = attr.label(default = "@ppx//module/thread"),
        _warnings        = attr.label(default = "@ppx//module:warnings"),
        #### end options ####

        cc_deps = attr.label_keyed_string_dict(
            doc = "C/C++ library dependencies. Keys: lib target. Vals: 'default', 'static', 'dynamic'",
            providers = [[CcInfo]]
        ),
        cc_linkopts = attr.string_list(
            doc = "C/C++ link options",
        ),
        _allowlist_function_transition = attr.label(
            ## required for transition fn of attribute _mode
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
        _mode = attr.label(
            default = "@ppx//mode",
        ),
        _rule = attr.string( default = "ppx_module" ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        msg = attr.string( doc = "DEPRECATED" ),
    ),
    cfg     = ppx_mode_transition,
    provides = [DefaultInfo, PpxModuleProvider, OpamDepsProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
