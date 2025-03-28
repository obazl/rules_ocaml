## this rule "configures" an ns - producing ns.ml,
## to be compiled by rule ocaml_ns_module

load("//build/_lib:apis.bzl", "options", "options_module", "options_ppx")

load("@rules_ocaml//build:providers.bzl",
     "OCamlDepsProvider",
     "OCamlModuleProvider",
     "OCamlNsResolverProvider",
     "OcamlNsSubmoduleMarker")

# load("//ocaml/_rules:impl_module.bzl", "impl_module")

load("//build/_rules/ocaml_ns:impl_ns_config.bzl",
     "impl_ns_config")


###############################
def _ocaml_ns_config_impl(ctx):

    # return impl_module(ctx)

    return impl_ns_config(ctx)

###############################
rule_options = options("rules_ocaml")
# rule_options.update(options_module("ocaml"))
# rule_options.update(options_ppx)

# rule_options.update(options_ns_config("ocaml"))

#########################
ocaml_ns_config = rule(
  implementation = _ocaml_ns_config_impl,
    doc = """
Generates a source `<ns>.ml` file containing the module aliasing equations needed to define an OCaml build namespace.

    """,
    attrs = dict(
        rule_options,

        ns_name = attr.string(
            doc = "Use this as the ns name (prefix string)",
            mandatory = False
        ),

        private = attr.bool(
            doc = """
When True, adds suffix `+__+` to ns name. Use this option when you have a module whose name matches the ns name. Such a module will function as the ns resolver, and may export only a subset of the members of the namespace.

Not to be confused with the https://bazel.build/concepts/visibility[visibility,window=_blank] attribute, which controls visibility of the target within the Bazel environment.
            """,
            default = False
        ),

        submodules = attr.string_list(
            # default = "@rules_ocaml//cfg/ns:submodules", # => string_list_setting
            doc = """
List of strings from which submodule names are to be derived for aliasing. Bazel labels may be used; the submodule name will be derived from the target part. For example, '//a/b:c' normalizes to C. But they are just strings, and will not be checked against any files.

The normalized submodule names must match the names of the modules electing membership via the 'ns_config' attribute.
            """,
            # allow_files = True,
            # mandatory = True
        ),

        # ns_deps = attr.label_list(
        # ),

        import_as = attr.label_keyed_string_dict(
            doc = """
Import exogenous (non-namepaced) modules.

Exogenous (sub)modules, namespaced or non-namespaced.  Aliased names will not be prefixed with ns name of this ns_config.

Keys: labels of modules;
Values: alias name to be used in this resolver.

e.g. `import_as = {"//mwe/rgb:R": "Red"}` will generate

module R = Red
            """,
            providers = [
                [OCamlModuleProvider],     ## exogenous non-namespaced
                [OcamlNsSubmoduleMarker] ## exogenous namespaced
            ]
        ),

        ns_import_as = attr.label_keyed_string_dict(
            doc = """
Import exogenous namespaces (`ocaml_ns` targets).

Dictionary: keys are exogenous namespaces (`ocaml_ns` modules),
values are strings to serve as ns name aliases.
Example: {"//foo/bar:nsbaz": "FBB"}
            """,
            providers = [
                [OCamlNsResolverProvider], ## subnamespace resolver
            ]
        ),

        ns_merge = attr.label_list(
            doc = """
Merges all submodules of an exogenous namespace.
            """,
            providers = [
                [OCamlNsResolverProvider], ## subnamespace resolver
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

        _normalize_modname = attr.label(
            default = "@rules_ocaml//cfg/module:normalize"
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

        _rule = attr.string(default = "ocaml_ns_config")
    ),
    # cfg = _in_transition,
    provides = [OCamlNsResolverProvider],
    executable = False,
    toolchains = [
        "@rules_ocaml//toolchain/type:std",
        "@rules_ocaml//toolchain/type:profile",
    ],
)
