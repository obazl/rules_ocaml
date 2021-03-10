load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlNsResolverProvider")
     # "PpxNsLibraryProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "normalize_module_name",
     "normalize_module_label",
     "get_fs_prefix",
     "get_opamroot",
     "get_sdkpath",
)

# load(":options.bzl", "options")

# load("//ocaml/_rules/utils:utils.bzl", "get_options")

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]

#################
def impl_ns_resolver(ctx):

    debug = True
    # if ctx.label.name == "":
    #     debug = True

    if debug:
        print("")
        print("Start: IMPL_NS %s" % ctx.label.name)
        print("LABEL: %s" % ctx.label)
        # print("PACKAGE: %s" % ctx.attr.pkg[BuildSettingInfo].value)
        # print("_NS_TRACE: %s" % ctx.attr._ns_trace[BuildSettingInfo].value)


        ## prefix always set by nslib out transition
        print("_NS_PREFIX: %s" % ctx.attr._ns_prefix[BuildSettingInfo].value)
        # print("_NS_RESOLVER: %s" % ctx.attr._ns_resolver[BuildSettingInfo].value)
        # print("ATTR.SUBMODULES: %s" % ctx.attr.submodules)
        print("_NS_SUBMODULES: %s" % ctx.attr._ns_submodules[BuildSettingInfo].value)

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    outputs = []
    directs = []

    # if ctx.attr.prefix:
    #     prefix = ctx.attr.prefix
    # else:
    ns_prefix = ctx.attr._ns_prefix[BuildSettingInfo].value

    if ns_prefix == "":
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
        ns_prefix = ws + "__" + "__".join(pathsegs) # ctx.attr.sep + ctx.attr.sep.join(pathsegs)
    else:
        segs = [x.capitalize() for x in ns_prefix.split('.')]
        ns_prefix = "_".join(segs)  ## ctx.attr.sep.join(segs)

    module_sep = "__"

    # resolver_module_name = None

    obj_cm_ = None
    obj_cmi = None

    aliases = []
    # if ctx.attr.submodules:
    #     explicit_ns = True
    #     ns_prefix     = capitalize_initial_char(ctx.attr.name)
    #     submodules = ctx.attr.submodules
    #     sublibs = ctx.attr.sublibs
    # else:
        # explicit_ns = False
    ns_prefix = capitalize_initial_char(ctx.attr._ns_prefix[BuildSettingInfo].value)
    submodules = ctx.attr._ns_submodules[BuildSettingInfo].value
    sublibs = ctx.attr._ns_sublibs[BuildSettingInfo].value

    if debug:
        print("NS_PREFIX:   %s" % ns_prefix)
        print("SUBMODULES: %s" % submodules)

    if len(submodules) < 1:
        if debug:
            print("NO SUBMODULES")
        if len(sublibs) < 1:
            print("NO SUBLIBS: returning null ns")
            return [DefaultInfo(files = depset()),
                    DefaultMemo(paths=depset(), resolvers=depset()),
                    OcamlNsResolverProvider(
                        # files=depset(),
                        # submodules = [],
                        # ap = "foo"
                    )]
    # else:
    pkg_prefix = ""

    resolver_module_name = capitalize_initial_char(ns_prefix)
    for submod_label in submodules:  # e.g. [Color, Red, Green, Blue], where main = Color
        if Label(submod_label).name == "_Color":
            print("RESOLVING SUBMODULE: %s" % submod_label)
        submodule = normalize_module_label(submod_label)
        print(" SUBMODULE: %s" % submodule)
        print(" NS_PREFIX: %s" % ns_prefix)
        # if explicit_ns:
        #     fs_prefix = ns_prefix
        # else:

        if ctx.attr._ns_strategy[BuildSettingInfo].value == "fs":
            fs_prefix = get_fs_prefix(submod_label) + "__"
            alias_prefix = fs_prefix
        else:
            fs_prefix = "" # ns_prefix + "__"
            alias_prefix = ns_prefix

        # submodule = normalize_module_name(submodule_label)
        if submodule == ns_prefix:  # submodule is 'main'
            resolver_module_name = fs_prefix + resolver_module_name + "_0Resolver"
            continue ## no alias for main module
        # elif submodule.startswith("__"):
        #     ## submodule is an nslib submodule
        #     pfx = ""
        #     submodule = submodule[2:]
        #     continue
        else:
            pfx = ns_prefix
        print("XXXX %s" % submodule)
        pfx = fs_prefix
        submodule = capitalize_initial_char(submodule)

        # if submodule == ns_prefix:
        #     # we skipped this above
        #     fail("Unexpected condition")
        # else:
        alias = "module {mod} = {ns}{sep}{mod}".format(
            mod = submodule,
            sep = "" if fs_prefix != "" else module_sep,
            ns  = alias_prefix # pfx # pkg_prefix + prefix ## ns_prefix
        )
        aliases.append(alias)
        # else:
        #     print("SKIPPING submodule for main module: %s" % module)

    print("ALIASES: %s" % aliases)
    for sublib in sublibs:
        # pfx = ns_prefix

        # sublib = capitalize_initial_char(sublib)
        # sublibs.append(sublib)

        alias = "module {mod} = {mod}".format(
            mod = sublib,
            # sep = "" if pfx == "" else module_sep,
            # ns  = pfx # pkg_prefix + prefix ## ns_prefix
        )
        aliases.append(alias)
        # else:
        #     print("SKIPPING sublib for main module: %s" % module)

    ns_filename = resolver_module_name + ".ml"
    # ns_filename = pkg_prefix + resolver_module_name + ".ml"
    ns_file = ctx.actions.declare_file(ns_filename)

    if debug:
        print("Generating NS resolver module %s" % ns_file)
        print(" %s" % ns_file.path)
        for alias in aliases:
            print("  %s" % alias)

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

    if debug:
        print("OUT: %s" % obj_cm_)
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
    dep_graph = []

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
        mnemonic = "OcamlNsResolverAction" if ctx.attr._rule == "ocaml_ns" else "PpxNsResolverAction",
        progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
            mode = mode,
            rule=ctx.attr._rule,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
            # msg = ""
            # msg = " pfx: " + ns_prefix
            # + "; Resolver: " + ctx.attr.resolver[BuildSettingInfo].value
            # + "; Submodules: " + " ".join(ctx.attr._ns_submodules[BuildSettingInfo].value)
        )
    )

    ## WARNING WARNING: we do not pass output via DefaultInfo!!!
    ## Why?  To keep from mixing it with all the other "ordinary" deps in the graph.
    ## Client must extract it from OcamlNsResolverProvider.

    defaultInfo = DefaultInfo(
        files = depset(
            order  = "postorder",
            direct = outputs
        )
    )

    defaultMemo = DefaultMemo(
        paths     = depset(direct = [obj_cmi.dirname]),
        resolvers = depset()
    )

    nsProvider = OcamlNsResolverProvider(
        files    = depset(
            order = "postorder",
            direct = outputs,  ## [obj_cm_] if obj_cm_ else [],
            transitive = [
                depset(order = "postorder", direct = [obj_cmi] if obj_cmi else [])
            ]
        ),
        submodules = submodules,
        resolver = resolver_module_name,
        prefix   = ns_prefix,
        # rp       = prefix,  ## resolver prefix
        # sep      = ctx.attr.sep,
    )

    # defaultInfo = DefaultInfo(files = depset(
    #     order = "postorder",
    #     direct = outputs,  ## [obj_cm_] if obj_cm_ else [],
    #     transitive = [
    #         depset(order = "postorder", direct = [obj_cmi] if obj_cmi else [])
    #     ]
    # ))

    return [
        defaultInfo,
        defaultMemo,
        nsProvider
    ]
