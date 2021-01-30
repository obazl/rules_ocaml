load("//ocaml/_providers:ocaml.bzl",
     "OcamlInterfaceProvider")

load("//ppx:_providers.bzl",
     "PpxExecutableProvider",
     "PpxModuleProvider")

load("//ppx/_transitions:transitions.bzl", "ppx_mode_transition")

load("options_ppx.bzl", "options_ppx")

load(":impl_module.bzl", "impl_module")

OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]

##################
ppx_module = rule(
    implementation = impl_module,
    doc = """Compiles a Ppx module. Provides: [PpxModuleProvider](providers_ppx.md#ppxmoduleprovider).

TODO: finish docstring

    """,
    attrs = dict(
        options_ppx,
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
            allow_files = True
            ## FIXME: add providers constraints, issue #18
            # providers = [OpamPkgInfo]
        ),
        _deps = attr.label(
            doc = "Global deps, apply to all instances of rule. Added last.",
            default = "@ppx//module:deps"
        ),
        doc = attr.string(doc = "Docstring"),
        module_name = attr.string(
            doc = "Allows user to specify a module name different than the target name."
        ),
        _mode = attr.label(
            default = "@ppx//mode",
            cfg     = ppx_mode_transition
        ),
        _allowlist_function_transition = attr.label(
            ## required for transition fn 'ppx_mode_transition', for attribute _mode
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
        ns   = attr.label(
            doc = "Label of a [ppx_ns](#ppx_ns) target. Used to derive namespace, output name, -open arg, etc.",
        ),
        ns_init = attr.label(
            doc = "Experimental",
            # default = Label("@ocaml//ns/init")
        ),
        struct = attr.label(
            mandatory = True,  # use ocaml_interface for isolated .mli files
            doc = "A single .ml source file label.",
            allow_single_file = OCAML_IMPL_FILETYPES
        ),
        intf = attr.label(
            doc = "Single label of a target providing a single .cmi file (not a .mli source file). Optional",
            allow_single_file = [".cmi"],
            providers = [OcamlInterfaceProvider],
        ),
        data = attr.label_list(
            doc = "Runtime dependencies: list of labels of data files needed by this module at runtime."
        ),
        runtime_deps  = attr.label_list(
            doc = "PPX runtime dependencies. E.g. a file used by %%import from ppx_optcomp.",
            allow_files = True,
        ),
        adjunct_deps = attr.label_list(
            doc = "List of [adjunct dependencies](../ug/ppx.md#adjunct_deps).",
            # providers = [[DefaultInfo], [PpxModuleProvider]]
            allow_files = True,
        ),
        ppx  = attr.label(
            doc = "PPX binary (executable) used to transform source before compilation.",
            executable = True,
            cfg = "host",
            allow_single_file = True,
            providers = [PpxExecutableProvider]
        ),
        ppx_args  = attr.string_list(
            doc = "Arguments to pass to ppx executable.  (E.g. [\"-cookie\", \"library-name=\\\"ppx_version\\\"\"]"
        ),
        ppx_data  = attr.label_list(
            doc = "PPX runtime dependencies. List of labels of files needed by PPX at preprocessing runtime. E.g. a file used by `[%%import ]` from [ppx_optcomp](https://github.com/janestreet/ppx_optcomp).",
            allow_files = True,
        ),
        ppx_print = attr.label(
            doc = "Format of output of PPX transform, binary (default) or text",
            default = "@ppx//print"
        ),

        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@ppx//module:linkall"), # FIXME: call it alwayslink?
        _threads         = attr.label(default = "@ppx//module:threads"),
        _warnings        = attr.label(default = "@ppx//module:warnings"),
        #### end options ####

        cc_deps = attr.label_keyed_string_dict(
            doc = "C/C++ library dependencies. Keys: lib target. Vals: 'default', 'static', 'dynamic'",
            providers = [[CcInfo]]
        ),
        cc_linkopts = attr.string_list(
            doc = "C/C++ link options",
        ),

        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        msg = attr.string( doc = "DEPRECATED" ),
        _rule = attr.string( default = "ppx_module" )
    ),
    provides = [DefaultInfo, PpxModuleProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
