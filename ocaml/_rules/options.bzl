load("//ocaml:providers.bzl",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlSignatureProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlNsResolverProvider",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxLibraryProvider",
     "PpxModuleProvider",
     "PpxNsArchiveProvider",
     "PpxNsLibraryProvider")

load("//ocaml/_transitions:transitions.bzl",
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
            default = "@ocaml//mode",  ## @ppx//mode only used for ppx_executable
        ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path") # ppx also uses this
        ),
    )

#######################
def options_executable(ws):
    attrs = dict(
        _linkall     = attr.label(default = "@ocaml//executable/linkall"),
        _thread     = attr.label(default = "@ocaml//executable/thread"),
        _warnings  = attr.label(default   = "@ocaml//executable:warnings"),
        _opts = attr.label(
            doc = "Hidden options.",
            default = "@ocaml//executable:opts"
        ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        main = attr.label(
            doc = "Label of module containing entry point of executable. This module will be placed last in the list of dependencies.",
            providers = [[OcamlModuleProvider], [PpxModuleProvider]],
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
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsArchiveProvider],
                         [OcamlNsLibraryProvider],
                         [PpxArchiveProvider],
                         [PpxLibraryProvider],
                         [PpxModuleProvider],
                         [PpxNsArchiveProvider],
                         [PpxNsLibraryProvider],
                         [CcInfo]],
        ),
        _deps = attr.label(
            doc = "Dependency to be added last.",
            default = "@ocaml//executable:deps"
        ),
        deps_opam = attr.string_list(
            doc = "List of OPAM package names"
        ),
        deps_adjunct = attr.label_list(
            doc = """List of non-opam adjunct dependencies (labels).""",
            # providers = [[DefaultInfo], [PpxModuleProvider]]
        ),
        deps_adjunct_opam = attr.string_list(
            doc = """List of opam adjunct dependencies (pkg name strings).""",
        ),
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
        _mode = attr.label(
            default = "@ocaml//mode"
        ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    )
    return attrs


#######################
def options_module(ws):

    if ws == "ocaml":
        providers = [[OcamlArchiveProvider],
                     [OcamlImportProvider],
                     [OcamlSignatureProvider],
                     [OcamlLibraryProvider],
                     [OcamlModuleProvider],
                     [OcamlNsArchiveProvider],
                     [OcamlNsLibraryProvider],
                     # [OcamlNsResolverProvider],
                     [PpxArchiveProvider],
                     [PpxModuleProvider],
                     [PpxNsLibraryProvider]]

    else:
        ## FIXME: providers for ppx_module
        providers = []

    _module_deps_out_transition = ocaml_module_deps_out_transition

    ws = "@" + ws

    return dict(
        _opts     = attr.label(default = ws + "//module:opts"),     # string list
        _linkall  = attr.label(default = ws + "//module/linkall"),  # bool
        _thread   = attr.label(default = ws + "//module/thread"),   # bool
        _warnings = attr.label(default = ws + "//module:warnings"), # string list
        struct = attr.label(
            doc = "A single module (struct) source file label.",
            mandatory = True,
            allow_single_file = True # no constraints on extension
        ),
        sig = attr.label(
            doc = "Single label of a target producing OcamlSignatureProvider (i.e. rule 'ocaml_signature'). Optional.",
            # allow_single_file = [".cmi"],
            providers = [OcamlSignatureProvider],
            cfg = _module_deps_out_transition
        ),
        ################
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = providers,
            # transition undoes changes that may have been made by ns_lib
            cfg = _module_deps_out_transition
        ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
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
            cfg = ocaml_module_cc_deps_out_transition
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
            providers = [OcamlNsResolverProvider],
            default = "@ocaml//ns",
        ),
        _ns_submodules = attr.label(
            doc = "Experimental.  May be set by ocaml_ns_library containing this module as a submodule.",
            default = "@ocaml//ns:submodules",  # => string_list_setting
            # allow_files = True,
            # mandatory = True
        ),
        _ns_strategy = attr.label(
            doc = "Experimental",
            default = ws + "//ns:strategy"
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
        _ns_strategy = attr.label(
            doc = "Experimental",
            default = ws + "//ns:strategy"
        ),
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

#######################
def options_ns_library(ws):

    if ws == "ocaml":
        _submod_providers   = [
            [OcamlModuleProvider],
            [OcamlNsLibraryProvider],
            [PpxModuleProvider],
            # [OcamlSignatureProvider]
        ]
        _sublib_providers = [
            # [OcamlNsArchiveProvider],
            [OcamlNsLibraryProvider],
            [PpxNsLibraryProvider],
        ]
    else:
        ## FIXME: ppx providers
        _submod_providers = [PpxModuleProvider]
        _sublib_providers = [PpxNsLibraryProvider]

    ws_prefix = "@ocaml" ## + ws

    return dict(
        _opts     = attr.label(default = ws_prefix + "//module:opts"),     # string list
        _linkall  = attr.label(default = ws_prefix + "//module/linkall"),  # bool
        _thread   = attr.label(default = ws_prefix + "//module/thread"),   # bool
        _warnings = attr.label(default = ws_prefix + "//module:warnings"), # string list

        ## we need this when we have sublibs but no direct submodules
        _ns_resolver = attr.label(
            doc = "Experimental",
            providers = [OcamlNsResolverProvider],
            default = ws_prefix + "//ns",
            cfg = ocaml_nslib_submodules_out_transition
        ),

        _ns_pkg = attr.label(
            doc = "Experimental",
            # default = ws_prefix + "//ns:package",
            allow_single_file = True
        ),
        _ns_prefixes   = attr.label(
            doc = "Experimental",
            default = ws_prefix + "//ns:prefixes"
        ),
        ## Note: this is for the user; transition fn uses it to populate ns:submodules
        # submodules = attr.label_keyed_string_dict(
        submodules = attr.label_list(
            doc = "List of *_module submodules",
            allow_files = [".cmo", ".cmx", ".cmi"],
            providers   = _submod_providers,
            cfg = ocaml_nslib_submodules_out_transition
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

    ws = "@ocaml" # + ws

    return dict(
        _ns_prefixes   = attr.label(
            doc = "Experimental",
            default = ws + "//ns:prefixes"
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

################################################################
ns_docstring = """OBSOLETE DOCSTRING!  under revision...

This rule initializes a 'namespace evaluation environment' consisting of a pseudo-namespace prefix string and optionally an ns resolver module.  A pseudo-namespace prefix string is a string that is used to form (by prefixation) a (presumably) globally unique name for a module. An ns resolver module is a module that contains nothing but alias equations mapping module names to pseudo-namespaced module names.

You may use the [ppx_ns](macros.md#ppx_ns) macro instead of instantiating this rule directly.

This rule is designed to work in conjujnction with rules
[ocaml_module](rules_ocaml.md#ocaml_module) and
[ocaml_ns_module](rules_ocaml.md#ocaml_ns_module). An `ocaml_module`
instance can use the prefix string of an `ppx_ns` to rename its
source file by using attribute `ns` to reference the label of an
`ppx_ns` target. Instances of `ocaml_ns_module` can list such
modules as `submodule` dependencies. They can also use an
`ppx_ns` prefix string to name themselves, by using their `ns`
attribute similarly. This allows ns modules to be (pseudo-)namespaced in the
same way submodules are namespaced.

The prefix string defaults to the (Bazel) package name string, with
each segment capitalized and the path separator ('/') replaced by the
`sep` string (default: `_`). If you pass a prefix string it must be a
legal OCaml module path; each segment will be capitalized and the segment
separator ('.') will be replaced by the `sep` string. The resulting
prefix may be used by `ocaml_module` rules (via the `ns` attribute) to
rename their source files, and, if `module = True`, by this rule to
generate alias equations.

For example, if package `//alpha/beta/gamma` contains`foo.ml`:

```
ns_resolver() => Alpha_Beta_Gamma__foo.ml
ns_resolver(sep="") => AlphaBetaGamma__foo.ml
ns_resolver(sep="__") => Alpha__Beta__Gamma__foo.ml
ns_resolver(prefix="foo.bar") => Foo_Bar__foo.ml (pkg path ignored)
ns_resolver(prefix="foo.bar", sep="") => FooBar__foo.ml
```


The optional ns resolver module will be named `<prefix>__00.ml`; since
`0` is not a legal initial character for an OCaml module name, this
ensures it will never clash with a user-defined module.

The ns resolver module will contain alias equations mapping module
names derived from the `srcs` list to pseudo-namespaced module names
(and thus indirectly filenames). For example, if `srcs` contains
`foo.ml`, and the prefix is `a.b`, then the resolver module will
contain `module Foo = A_b_foo`.

Submodule file names will be formed by prefixing the pseudo-ns prefix to the (original, un-namespaced) module name, separated by 'sep' (default: '__'). For example, if the prefix is 'Foo_bar' and the module is 'baz.ml', the submodule file name will be 'Foo_bar__baz.ml'.

The main namespace module will contain aliasing equations that map module names to these prefixed module names.

By default, the ns prefix string is formed from the package name, with '/' replaced by '_'. You can use the 'ns' attribute to change this:

ns(ns = "foobar", srcs = glob(["*.ml"]))

    """
