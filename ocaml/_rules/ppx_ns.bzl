load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlNsEnvProvider")
     # "PpxNsLibraryProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
)

load(":options.bzl", "options")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]

tmpdir = "_obazl_/"

#################
def _impl_ppx_ns(ctx):

    debug = True
    # if ctx.label.name == "_Env":
    #     debug = True

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    outputs = []
    directs = []

    prefix = ctx.attr.prefix[BuildSettingInfo].value
    if debug:
        print("PREFIX: %s" % prefix)
    if ctx.attr.prefix:
        # segs = [x.capitalize() for x in ctx.attr.prefix.split('.')]
        segs = [x.capitalize() for x in prefix.split('.')]
        ns_prefix = ctx.attr.sep.join(segs)
    else:
        if ctx.label.workspace_name == "":
            if ctx.workspace_name == "__main__": # default, if not explicitly named
                ws = "O_B_Z_L"
            else:
                ws = ctx.workspace_name
        else:
            ws = ctx.label.workspace_name
        # if ctx.workspace_name == "__main__": # default, if not explicitly named
        #     ws = "Null"
        # else:
        #     ws = ctx.workspace_name
            # print("WS: %s" % ws)
        ws = capitalize_initial_char(ws) if ws else ""
        pathsegs = [x.replace("-", "_").capitalize() for x in ctx.label.package.split('/')]
        ns_prefix = ws + ctx.attr.sep + ctx.attr.sep.join(pathsegs)

    module_sep = "__"

    resolver_module_name = None

    obj_cm_ = None
    obj_cmi = None

    if debug:
        print("TGT: %s" % ctx.label)
        print("NAME: %s" % ctx.attr.name)
        print("SUBMODULES: %s" % ctx.attr.submodules[BuildSettingInfo].value)

    aliases = []
    submodules = ctx.attr.submodules[BuildSettingInfo].value
    if len(submodules) > 0:
    # if len(ctx.attr.aliases) > 0:

        # ## module names may not begin with a number, so this module
        # ## name will never clash with a user-defined module:
        # resolver_module_name = ns_prefix + module_sep + "00" + ctx.label.name
        resolver_module_name = capitalize_initial_char(ctx.attr.resolver[BuildSettingInfo].value)

        dep_graph = []
        for alias in submodules:
            module = capitalize_initial_char(alias)
            alias = "module {mod} = {ns}{sep}{mod}".format(
                mod = module,
                sep = module_sep,
                ns  = ns_prefix
            )
            aliases.append(alias)

        # for sm in ctx.files.aliases:
        #     sm_parts = paths.split_extension(sm.basename)
        #     module = capitalize_initial_char(sm_parts[0])
        #     alias = "module {mod} = {ns}{sep}{mod}".format(
        #         mod = module,
        #         sep = module_sep,
        #         ns  = ns_prefix
        #     )
        #     aliases.append(alias)

        # print("ALIASES: %s" % aliases)
        # if ctx.attr._rule == "ocaml_ns":
        #     mode = ctx.attr._mode[CompilationModeSettingProvider].value
        # elif ctx.attr._rule == "ppx_ns":
        #     mode = ctx.attr._mode[CompilationModeSettingProvider].value

        if ctx.attr.pkg[BuildSettingInfo].value == "":
            pkg_prefix = "" # tmpdir
        else:
            pkg_prefix = ctx.attr.pkg[BuildSettingInfo].value + "/"
        ns_filename = tmpdir + resolver_module_name + ".ml"
        if debug:
            print("PKG: %s" % pkg_prefix)
        ns_file = ctx.actions.declare_file(ns_filename)
        if debug:
            print("NS_FILE: %s" % ns_file)

        ## action: generate ns resolver module file with alias content
        ctx.actions.write(
            output = ns_file,
            content = "\n".join(aliases) + "\n"
        )
        outputs = []
        directs = []

        directs.append(ns_file)

        ## now declare compilation outputs. compiling always produces 3 files:
        obj_cmi_fname = pkg_prefix + resolver_module_name + ".cmi"
        obj_cmi = ctx.actions.declare_file(obj_cmi_fname)
        directs.append(obj_cmi)
        if mode == "native":
            obj_cm__fname = pkg_prefix + resolver_module_name + ".cmx" # tc.objext
        else:
            obj_cm__fname = pkg_prefix + resolver_module_name + ".cmo" # tc.objext
        obj_cm_ = ctx.actions.declare_file(obj_cm__fname)
        directs.append(obj_cm_)

        ################################
        args = ctx.actions.args()

        if mode == "bytecode":
            args.add(tc.ocamlc.basename)
        else:
            args.add(tc.ocamlopt.basename)
            obj_o_fname = resolver_module_name + ".o"
            obj_o = ctx.actions.declare_file(pkg_prefix + obj_o_fname)
            outputs.append(obj_o)
            directs.append(obj_o)

        # options = get_options(ctx.attr._rule, ctx)
        # args.add_all(options)

        outputs.append(obj_cm_)
        outputs.append(obj_cmi)

        if ctx.attr._warnings:
            args.add_all(ctx.attr._warnings[BuildSettingInfo].value, before_each="-w", uniquify=True)

        # if hasattr(ctx.attr, "opts"):
        #     args.add_all(ctx.attr.opts)

        # # dep_graph.append(ns_compile_src)
        args.add("-I", ns_file.dirname)
        dep_graph.append(ns_file)

        # # for dep in ctx.files.deps:
        # #     # dep_graph.append(dep)
        # #     args.add("-I", dep.path)

        # ## -no-alias-deps is REQUIRED for ns modules;
        # ## see https://caml.inria.fr/pub/docs/manual-ocaml/modulealias.html
        args.add("-no-alias-deps")

        args.add("-c")
        args.add("-o", obj_cm_)
        args.add(ns_file.path)

        ctx.actions.run(
            env = env,
            executable = tc.ocamlfind,
            arguments = [args],
            inputs = dep_graph,
            outputs = outputs,
            tools = [tc.ocamlfind, tc.ocamlopt],
            mnemonic = "PpxNsEnvAction",
            progress_message = "{mode} compiling: @{ws}//{pkg}:{tgt} (rule {rule})".format(
                mode = mode,
                ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
                pkg = ctx.label.package,
                rule=ctx.attr._rule,
                tgt=ctx.label.name,
            )
        )
    else:
        print("NO SUBMODULES")
        return [DefaultInfo(files = depset()),
                DefaultMemo(paths=depset(), resolvers=depset()),
                OcamlNsEnvProvider()]

    provider = OcamlNsEnvProvider(
        resolver = resolver_module_name,
        prefix   = ns_prefix,
        sep      = ctx.attr.sep,
    )

    defaultMemo = DefaultMemo(
        paths     = depset(direct = [obj_cmi.dirname]),
        resolvers = depset()
    )

    return [
        DefaultInfo(files = depset(
            order = "postorder",
            direct = outputs,  ## [obj_cm_] if obj_cm_ else [],
            transitive = [
                depset(order = "postorder", direct = [obj_cmi] if obj_cmi else [])
            ]
        )),
        defaultMemo,
        provider
    ]

################
ppx_ns = rule(
  implementation = _impl_ppx_ns,
    doc = """This rule initializes a 'namespace evaluation environment' consisting of a pseudo-namespace prefix string and optionally an ns resolver module.  A pseudo-namespace prefix string is a string that is used to form (by prefixation) a (presumably) globally unique name for a module. An ns resolver module is a module that contains nothing but alias equations mapping module names to pseudo-namespaced module names.

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
ns_env() => Alpha_Beta_Gamma__foo.ml
ns_env(sep="") => AlphaBetaGamma__foo.ml
ns_env(sep="__") => Alpha__Beta__Gamma__foo.ml
ns_env(prefix="foo.bar") => Foo_Bar__foo.ml (pkg path ignored)
ns_env(prefix="foo.bar", sep="") => FooBar__foo.ml
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
        options("@ppx"),
        _sdkpath = attr.label(
          default = Label("@ocaml//:path")
        ),
        pkg   = attr.label(
            doc = "Experimental",
            default = "@ppx//ns:pkg"
        ),
        prefix   = attr.label(
            doc = "Experimental",
            default = "@ppx//ns:prefix"
        ),
        sep = attr.string(
            doc = "String used to replace segment separator ('.') in prefix string.",
            default = "_"
        ),
        resolver   = attr.label(
            doc = "Experimental",
            default = "@ppx//ns:resolver"
        ),
        submodules = attr.label( # _list(
            default = "@ppx//ns:submodules",
            doc = "List of files from which submodule names are to be derived for aliasing. The names will be formed by truncating the extension and capitalizing the initial character. Module source code generated by ocamllex and ocamlyacc can be accomodated by using the module name for the source file and generating a .ml source file of the same name, e.g. lexer.mll -> lexer.ml.",
            allow_files = True,
            # mandatory = True
        ),
        # deps = attr.label_list(
        #     doc = "Dependencies"
        # ),
        _mode = attr.label(
            default = "@ppx//mode"
        ),
        _warnings  = attr.label(default = "@ppx//ns:warnings"),
        _rule = attr.string(default = "ppx_ns")
    ),
    # provides = [DefaultInfo, OcamlNsLibraryProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
