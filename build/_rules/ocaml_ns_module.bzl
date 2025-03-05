## this rule compiles the ns resolver file produced
## by rule ocaml_ns

load("//build/_lib:apis.bzl", "options", "options_module", "options_ppx")

load("//build:providers.bzl",
     "OCamlModuleProvider",
     "OCamlNsResolverProvider",
     "OcamlNsSubmoduleMarker")
     # "OcamlProvider")

load("@rules_ocaml//build:providers.bzl", "OCamlDepsProvider")

# load("//ocaml/_rules:impl_module.bzl", "impl_module")

load("//build/_rules/ocaml_ns:impl_ns_module.bzl",
     "impl_ns_module")

##############################################
def _ns_config_out_transition_impl(settings, attr):
    print("NS CONFIG OUT TRANSITION")
    return {
        "@rules_ocaml//toolchain": "ocamlopt",
        "//command_line_option:host_platform": "@rules_ocaml//platform:ocamlopt.opt",
        "//command_line_option:platforms": "@rules_ocaml//platform:ocamlopt.opt",
        "@rules_ocaml//cfg/library/linkage:linkage": "static",
        "@rules_ocaml//cfg/library/linkage:level": 0,
    }

_ns_config_out_transition = transition(
    implementation = _ns_config_out_transition_impl,
    inputs = [ ],
    outputs = [
        "@rules_ocaml//toolchain",
        "//command_line_option:host_platform",
        "//command_line_option:platforms",
        "@rules_ocaml//cfg/library/linkage:linkage",
        "@rules_ocaml//cfg/library/linkage:level"
    ]
)

###############################
def _ocaml_ns_module(ctx):

    # return impl_module(ctx)

    return impl_ns_module(ctx)

###############################
rule_options = options("rules_ocaml")
rule_options.update(options_module("ocaml"))
rule_options.update(options_ppx)

# rule_options.update(options_ns_module("ocaml"))

#########################
ocaml_ns_module = rule(
  implementation = _ocaml_ns_module,
    doc = """OBSOLETE DOCSTRING!  under revision...

This rule initializes a 'namespace evaluation environment' consisting of a pseudo-namespace prefix string and optionally an ns resolver module.  A pseudo-namespace prefix string is a string that is used to form (by prefixation) a (presumably) globally unique name for a module. An ns resolver module is a module that contains nothing but alias equations mapping module names to pseudo-namespaced module names.

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

    """,
    attrs = dict(
        rule_options,

        ns_config = attr.label(
            doc = "A single module (struct) source file label.",
            mandatory = True,
            allow_single_file = True,
            cfg = _ns_config_out_transition
        ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),

        _warnings  = attr.label(default = "@rules_ocaml//cfg/ns:warnings"),
        _tags = attr.string_list( default  = ["ocaml"] ),

        _rule = attr.string(default = "ocaml_ns_resolver")
    ),
    provides = [OCamlNsResolverProvider,OCamlDepsProvider],
    executable = False,
    toolchains = [
        "@rules_ocaml//toolchain/type:std",
        "@rules_ocaml//toolchain/type:profile",
    ],
)
