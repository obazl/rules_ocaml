load(":options.bzl", "options", "options_module", "options_ppx")

load("//providers:ocaml.bzl",
     "OcamlModuleMarker",
     "OcamlNsResolverProvider",
     "OcamlNsSubmoduleMarker",
     "OcamlProvider")

load("//ocaml/_rules:impl_module.bzl", "impl_module")
load("//ocaml/_rules:impl_ns_resolver.bzl", "impl_ns_resolver")

###############################
def _ocaml_ns_resolver(ctx):

    # return impl_module(ctx)

    return impl_ns_resolver(ctx)

###############################
rule_options = options("ocaml")
rule_options.update(options_module("ocaml"))
rule_options.update(options_ppx)

# rule_options.update(options_ns_resolver("ocaml"))

#########################
ocaml_ns_resolver = rule(
  implementation = _ocaml_ns_resolver,
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

    """,
    attrs = dict(
        rule_options,

        struct = attr.label(
            doc = "A single module (struct) source file label.",
            mandatory = False,
            allow_single_file = True # no constraints on extension
        ),

        ns = attr.string(
            mandatory = True
        ),

        # submodules = attr.string_list(
        manifest = attr.string_list(
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

        # used by hidden ns resolvers for topdown nss
        _ns_prefixes   = attr.label(
            doc = "List of prefixes to use in renaming submodules",
            default = "@rules_ocaml//cfg/ns:prefixes"
        ),
        _ns_submodules = attr.label( # _list(
            default = "@rules_ocaml//cfg/ns:submodules", # => string_list_setting
            doc = "List of files from which submodule names are to be derived for aliasing. The names will be formed by truncating the extension and capitalizing the initial character. Module source code generated by ocamllex and ocamlyacc can be accomodated by using the module name for the source file and generating a .ml source file of the same name, e.g. lexer.mll -> lexer.ml.",
            allow_files = True,
            # mandatory = True
        ),

        ## OBSOLETE???
        # _ns_sublibs = attr.label(
        #     default = "@rules_ocaml//cfg/ns:sublibs",  # => string_list_setting
        #     doc = "List of *_ns_library submodules",
        #     allow_files = True,
        #     # mandatory = True
        # ),

        # ns = attr.string(),

        # _ns_prefixes   = attr.label(
        #     doc = "Experimental",
        #     default = "@rules_ocaml//cfg/ns:prefixes"
        # ),
        # # _ns_strategy = attr.label(
        # #     doc = "Experimental",
        # #     default = "@rules_ocaml//cfg/ns:strategy"
        # # ),
        # ## GLOBAL CONFIGURABLE DEFAULTS ##
        # opts             = attr.string_list(
        #     doc          = "List of OCaml options. Will override configurable default options."
        # ),

        # #### hidden attrs ####
        # _debug           = attr.label(default = "@rules_ocaml//cfg/debug"),
        # _cmt             = attr.label(default = "@rules_ocaml//cfg/cmt"),
        # _keep_locs       = attr.label(default = "@rules_ocaml//cfg/keep-locs"),
        # _noassert        = attr.label(default = "@rules_ocaml//cfg/noassert"),
        # _opaque          = attr.label(default = "@rules_ocaml//cfg/opaque"),
        # _short_paths     = attr.label(default = "@rules_ocaml//cfg/short-paths"),
        # _strict_formats  = attr.label(default = "@rules_ocaml//cfg/strict-formats"),
        # _strict_sequence = attr.label(default = "@rules_ocaml//cfg/strict-sequence"),
        # _verbose         = attr.label(default = "@rules_ocaml//cfg/verbose"),

        _warnings  = attr.label(default = "@rules_ocaml//cfg/ns:warnings"),
        _tags = attr.string_list( default  = ["ocaml"] ),

        _rule = attr.string(default = "ocaml_ns_resolver")
    ),
    provides = [OcamlNsResolverProvider,OcamlProvider],
    executable = False,
    toolchains = [
        "@rules_ocaml//toolchain/type:std",
        "@rules_ocaml//toolchain/type:profile",
    ],
)
