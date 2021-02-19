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

# load(":options.bzl", "options")

# load("//ocaml/_rules/utils:utils.bzl", "get_options")

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]

tmpdir = "_obazl_/"

#################
def impl_ns(ctx):

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
        ns_filename = pkg_prefix + resolver_module_name + ".ml"
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
            mnemonic = "OcamlNsModuleAction" if ctx.attr._rule == "ocaml_ns" else "PpxNsModuleAction",
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
