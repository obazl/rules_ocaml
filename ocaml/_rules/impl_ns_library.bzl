load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
    "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlModuleProvider",
     "OcamlNsEnvProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlSignatureProvider",
     "OpamDepsProvider",
     "PpxModuleProvider",
     "PpxNsLibraryProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath",
)

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl",
     "merge_deps",
     "tmpdir")

###########################
def get_module_name(f):
    "Derive module name from file name"

    basename = capitalize_initial_char(f.basename)
    ext = f.extension
    mname = basename[:-(len(ext)+1)]

    return mname

###########################
# def get_prefix(ctx):
#     print("LABEL: %s" % ctx.label)
#     print("WS: %s" % ctx.label.workspace_name)
#     # if ctx.workspace_name == "__main__": # default, if not explicitly named
#     #     ws = "Main"
#     # else:
#     #     # ws = ctx.workspace_name
#     #     # print("WS: %s" % ws)
#     ws = ctx.label.workspace_name
#     ws = capitalize_initial_char(ws)

#     ns_sep = "_" ## ctx.attr.sep
#     pathsegs = [x.replace("-", "_").capitalize() for x in ctx.label.package.split('/')]
#     ns_prefix = ws + ns_sep + ns_sep.join(pathsegs)

#     return ns_prefix

###########################
def get_resolver_name(ctx):

    ns_sep = "_" ## ctx.attr.sep

    if ctx.attr.ns_env:
        ns_prefix = ctx.attr.ns_env[OcamlNsEnvProvider].prefix
        ns_main   = ctx.label.name
        resolver_name = ns_prefix + "__" + capitalize_initial_char(ns_main)
    else:
        if ctx.workspace_name == "__main__": # default, if not explicitly named
            ws = "Main"
        else:
            ws = ctx.workspace_name
            # print("WS: %s" % ws)
        ws = capitalize_initial_char(ws)
        pathsegs = [x.replace("-", "_").capitalize() for x in ctx.label.package.split('/')]
        ns_prefix = ws + ns_sep + ns_sep.join(pathsegs)
        # ns_prefix = ws + "_" + ctx.label.package.replace("/", "_").replace("-", "_")
        ns_main   = ctx.label.name
        resolver_name = ns_prefix + "__" + capitalize_initial_char(ns_main)

    return resolver_name

########################
def build_resolvers(ctx, tc, env, mode, aliases):
    ## return the pkg-level resolver(s)
    ## the submodules list may contain submodules from different packages.
    ## we need to go through them all and deliver their pkg resolvers for output
    ## but some submodules may be ns modules - ???
    resolver_files = []
    indirect_resolver_depsets = []
    for [target, sm_name] in ctx.attr.submodules.items():
        indirect_resolver_depsets.append(target[DefaultMemo].resolvers)
        # if OcamlModuleProvider in target:
        #     indirect_resolver_depsets.append(target[OcamlModuleProvider].resolvers)
        # elif OcamlSignatureProvider in target:
        #     indirect_resolver_depsets.append(target[OcamlSignatureProvider].resolvers)
        # elif OcamlNsLibraryProvider in target:
        #     indirect_resolver_depsets.append(target[OcamlNsLibraryProvider].resolvers)
        # else:
        #     fail("oops?")

        for dep in target.files.to_list():
            resolver_files.append(dep)

    return [indirect_resolver_depsets, resolver_files]

#################
def impl_ns_library(ctx):

    ## FIXME: call impl_library ???

    # print("NS LIB rule: %s" % ctx.label.name)
    debug = False
    # if (ctx.label.name == "stdune"):
    #     debug = True

    # if (ctx.attr.include and ctx.attr.main):
    #     fail("Attributes 'include' and 'main' are mutually exclusive.")

    # name must be legal OCaml module name
    if not ctx.label.name[0].isalpha():
        fail("Name must be a legal OCaml module name: %s" % ctx.label.name)

    if ctx.files.main:
        if OcamlModuleProvider not in ctx.attr.main:
        #     print("MAIN MODULE: %s" % ctx.attr.main)
        # else:
            # print("MAIN FILES: %s" % len(ctx.files.main))
            if len(ctx.files.main) > 1:
                fail("Only one file allow in 'main' attribute.")

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    aliases = []

    ################
    direct_file_deps = []
    indirect_file_depsets  = []

    indirect_opam_depsets  = []

    indirect_adjunct_depsets = []  # list of depsets gathered from direct deps
    indirect_adjunct_path_depsets = [] # paths for indirect_adjunct deps
    indirect_adjunct_opam_depsets  = []  # list of depsets gathered from direct deps

    indirect_path_depsets  = []

    direct_resolver = None
    indirect_resolver_depsets = []

    direct_cc_deps  = []
    indirect_cc_deps  = []
    ################

    ns_resolver = None
    resolver_files = None

    submodules = []
    includes   = []

    if ctx.attr.ns:
        direct_resolver = get_resolver_name(ctx)
        # print("DIRECT_RESOLVER: %s" % direct_resolver)
        ns_library_name = direct_resolver #  + "__" + ctx.label.name.replace("-", "_")
    else:
        if ctx.attr.main:
            # ns_library_name = ctx.file.main.basename.replace("-", "_")[:3]
            ns_library_name = ctx.label.name.replace("-", "_")
        elif ctx.attr.includes:
            ns_library_name = ctx.label.name.replace("-", "_")
        else:
            ns_library_name = ctx.label.name.replace("-", "_")
    # print("NS_LIBRARY_NAME: %s" % ns_library_name)

    ## if no main, use ns module as resolver (generate it)
    ## otherwise, use main as ns module, and the resolver is computed from package name


    ns_filename = tmpdir + ns_library_name + ".ml"
    ns_file = None

    ## make aliases, one per submodule regardless of pkg
    ## the aliasing equations for this ns module may resolve to any pkg
    ## We may use main ns or submodules from other pkgs, but we do not use their resolvers.
    ## one reason for this is that there is no requirement that modules names match file names.
    ## so the same submodule could go under different submodule names in different packages.
    ## or even in different main ns modules in the same pkg.
    ## So: we always need to generate a resolver for the current package.

    ## Alternatively: module filenames are independent of aliasing
    ## equations. So to construct a resolver all we need is the
    ## filename, not the local resolver. In fact a given module may be
    ## resolved by multiple resolvers local to its own pkg (e.g. if
    ## the ns_librarys use different 'prefix' values.)

    ## In short: deriving alias equations from submodule items will always work.

    merge_deps(ctx.attr.submodules.keys(),
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_resolver_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    # for (dep,smname) in ctx.attr.submodules.items():
    #     # print("SUBMOD: {nm} -> {mod}".format(nm=smname, mod=dep))
    #     smimpl = None

    #     indirect_file_depsets.append(dep[DefaultInfo].files)
    #     indirect_path_depsets.append(dep[DefaultMemo].paths)
    #     indirect_resolver_depsets.append(dep[DefaultMemo].resolvers)
    #     if OpamDepsProvider in dep:
    #         indirect_opam_depsets.append(dep[OpamDepsProvider].pkgs)

    indirect_paths_depset = depset(transitive = indirect_path_depsets)
    for path in indirect_paths_depset.to_list():
        includes.append(path)
    # for path in dep[DefaultMemo].paths.to_list():
    #         includes.append(path)

    ## compute module name from file name - we have to unroll the depset
    for (dep,smname) in ctx.attr.submodules.items():
        if OcamlModuleProvider in dep:
            smimpl = dep[OcamlModuleProvider].name
        elif OcamlNsArchiveProvider in dep:
            smimpl = dep[OcamlNsArchiveProvider].name
        elif OcamlNsLibraryProvider in dep:
            smimpl = dep[OcamlNsLibraryProvider].name
        elif OcamlSignatureProvider in dep:
            smimpl = dep[OcamlSignatureProvider].name
        elif PpxModuleProvider in dep:
            smimpl = dep[PpxModuleProvider].name
        elif PpxNsLibraryProvider in dep:
            smimpl = dep[PpxNsLibraryProvider].name
        else:
            fail("Unexpected submodule type: %s" % dep)
        alias = "module {sm} = {smimpl}".format(
            sm=capitalize_initial_char(smname),
            smimpl = capitalize_initial_char(smimpl)
        )
        aliases.append(alias)

        # for depfile in dep.files.to_list():
        #     # if dep.extension == "cmo":
        #     bn = depfile.basename
        #     ext = depfile.extension
        #     smimpl = bn[:-(len(ext)+1)]
        #     # now construct alias statement
        #     alias = "module {sm} = {smimpl}".format(
        #         sm=capitalize_initial_char(smname),
        #         smimpl = capitalize_initial_char(smimpl)
        #     )
        #     aliases.append(alias)

    # print("ALIASES: %s" % aliases)

    # mode = "bytecode" # default
    # if ctx.attr._rule == "ocaml_ns_library":
    #     mode = ctx.attr._mode[CompilationModeSettingProvider].value
    # elif ctx.attr._rule == "ppx_ns_library":
    #     mode = ctx.attr._mode[CompilationModeSettingProvider].value
    mode = ctx.attr._mode[CompilationModeSettingProvider].value
    # print("NS LIB MODE %s" % mode)

    ## we always want the resolvers of submodules?
    [indirect_resolver_depsets, resolver_files] = build_resolvers(
        ctx, tc, env, mode, aliases
    )

    ## now we need to generate the resolver file. if no 'main' has
    ## been provided, then the generated ns module doubles as the resolver.
    ## if 'main' has been provided, then:
    ##     if it has the same name as the ocaml_ns_library, then:
    ##         use the provided 'main' directly as the ns module
    ##         generate resolver, named <pkg>_<ns-main>_00
    ##     if it has a different name, then:
    ##         copy provided 'main' file to the ocaml_ns_library name
    ##         generate resolver, named <pkg>_<ns-main>_00
    ## in sum: the ns module name will always be taken from ocaml_ns_library.name,
    ## and the resolver will always be generated, with name <pkg>_<nsmain>_00

    if ctx.attr.main:
        if OcamlModuleProvider in ctx.attr.main:
            print("MAIN MODULE: %s" % ctx.attr.main)
            provider = ctx.attr.main[OcamlModuleProvider]
            print("MAIN MODULE name: %s" % provider.name)
            print("MAIN MODULE dep: %s" % provider.module)

        if ctx.files.main:
            print("MAIN FILE: %s" % ctx.files.main[0])

            ## assumption is that main contains recursive alias equations,
            ## so we always use a separate resolver module, no matter what 'main' name is,
            ## because main ns module will always match ctx.label.name
            ## iow, using 'main' attrib obligates user to provide first-level aliases.

            ## main file has its own deps! use 'deps' attrib for those?

            ## RESOLVER module:
            ## Each pkg has its own resolver.
            ## The main ns needs one resolver per unique pkg in its submodule list.
            ## If the pkg of this ns module contains submodules, then we need to generate its resolver.

            ##
            ## Q: do we need to -open the resolvers in order to compile the main ns module?
            ## A: yes! the main module needs the ns resolvers?
            ## submodules may be enrolled in different ns envs.

            # print("RESOLVER_MODULE_NAME: %s" % resolver_module_name)
            # print("Resolver files: %s" % resolver_files)

            ## then we need to copy main to label.name, unless it already has that name
            ## output: ns_file, same as below
            if ctx.files.main[0].basename == ctx.label.name + ".ml":
                ns_file = ctx.files.main[0]
            else:
                # user-provided main source file has different name than ns lib,
                # so copy former to latter
                ns_file = ctx.actions.declare_file(ns_filename)
                ctx.actions.run_shell(
                    inputs  = [ctx.files.main[0]],
                    outputs = [ns_file],
                    command = "cp {src} {dest}".format(src = ctx.files.main[0].path, dest = ns_file.path),
                    progress_message = "Copying user-provided main ns module to {ns}.".format(
                        ns = ctx.label.name + ".ml"
                    )
                )
    else:
        ## no user-supplied main, so we need to generate main ns module as output,
        ## and concat include if present. in this case we do not use a separate resolver module
        # if ctx.attr.includes:
        #     # pfx = get_prefix(ctx)
        #     # ns_library_name = pfx + "__" + ctx.file.include.basename[:-3]
        #     # print("NSLIBNAME: %s" % ns_library_name)
        #     ns_filename = tmpdir + ns_library_name + ".ml"
        #     ns_file = ctx.actions.declare_file(ns_filename)
        # else:
        ns_file = ctx.actions.declare_file(ns_filename)
        # cmd = ""
        # if not ctx.file.include:
        cmd = "echo \"(**** GENERATED FILE - DO NOT EDIT ****)\n\" >> " + ns_file.path + "\n"

        for alias in aliases:
            cmd = cmd + "echo \"{alias}\" >> {out}\n".format(
                alias = alias,
                out = ns_file.path
            )

        if ctx.attr.includes:
            for incfile in ctx.attr.includes:
                # print("Including: %s" % incfile)
                indirect_file_depsets.append(incfile[DefaultInfo].files)
                if OcamlModuleProvider in incfile:
                    # print("Includes module: %s" % incfile[OcamlModuleProvider])
                    cmd = cmd + "echo \"include {m}\" >> {out}".format(
                        m = incfile[OcamlModuleProvider].name,
                        out = ns_file.path
                )
                # cmd = cmd + "cat {src} >> {out}".format(
                #     src = ctx.file.include.path,
                #     out = ns_file.path
                # )

            # cmd = cmd + "echo \"\n(**** everything above this line was generated ****)\n\" >> " + ns_file.path + "\n"

        # print("CMD: %s" % cmd)

        # infile = None
        # if ctx.file.include:
        #     infile = ctx.file.include

        ctx.actions.run_shell(
            # inputs  = [infile] if infile else [],
            outputs = [ns_file],
            command = cmd,
            progress_message = "Generating namespace module source file."
        )

    # we always have a direct resolver, either supplied by user or generated by rule
    direct_resolver = capitalize_initial_char(ns_library_name)
    # print("NS MOD: %s" % ns_library_name)
    # print("DIRECT_RESOLVER: %s" % direct_resolver)

    ## at this point, either ns_file contains either a user-supplied main ns
    ## module, or we generated it
    # print("NS_LIBRARY_NAME: %s" % ns_library_name)
    ## now declare compilation outputs. compiling always produces 3 files:
    outputs = []
    if mode == "bytecode":
        obj_cm__fname = ns_library_name + ".cmo" # tc.objext
    else:
        obj_cm__fname = ns_library_name + ".cmx" # tc.objext
        obj_o_fname = ns_library_name + ".o"
        obj_o = ctx.actions.declare_file(tmpdir + obj_o_fname)
        outputs.append(obj_o)
        # directs.append(obj_o)

    obj_cm_ = ctx.actions.declare_file(tmpdir + obj_cm__fname)
    outputs.append(obj_cm_)

    obj_cmi_fname = ns_library_name + ".cmi"
    obj_cmi = ctx.actions.declare_file(tmpdir + obj_cmi_fname)
    outputs.append(obj_cmi)

    # print("OBJ_CM_: %s" % obj_cm_)
    directs = []

    #### now compile
    ################################
    args = ctx.actions.args()

    if mode == "bytecode":
        args.add(tc.ocamlc.basename)
    else:
        args.add(tc.ocamlopt.basename)

    options = get_options(ctx.attr._rule, ctx)
    args.add_all(options)

    ## No 'deps' for ns libs?

    ## -no-alias-deps is REQUIRED for ns modules;
    ## see https://caml.inria.fr/pub/docs/manual-ocaml/modulealias.html
    args.add("-no-alias-deps")

    if resolver_files:
        ## only if ctx.attr.main
        for f in resolver_files:
            # print("RESOLVER FILE: %s" % f.basename)
            direct_file_deps.append(f)
            # directs.append(f)
            ## don't put cmi files on cmd line
            if ((f.extension == "cmo") or (f.extension == "cmx")):
                includes.append(f.dirname)
                # args.add(f.basename)

    includes.append(obj_cm_.dirname)

    direct_file_deps.append(ns_file)

    args.add_all(includes, before_each="-I", uniquify = True)

    # if ctx.attr.main:
    #     if ctx.file.main.basename != ctx.label.name + ".ml":
    #         if direct_resolver:
    #             print("DIRECT RESOLVER: %s" % direct_resolver)
                # args.add("-open", direct_resolver)

    if indirect_resolver_depsets != None:
        # print("INDRS: %s" % indirect_resolver_depsets)
        # using depset transitive causes merge, removes dups
        resolvers_depset = depset(transitive = indirect_resolver_depsets)
        for resolver in resolvers_depset.to_list():
            if resolver != None:
                # print("INDIRECT RESOLVER: %s" % resolver)
                args.add("-open", resolver)
    else:
        resolvers_depset = depset(
            # direct = [direct_resolver]
        )


    # if ctx.attr.ns:
    #     if ctx.attr.main:
    #         # this means our we have separate main and resolver modules, so we need to open the latter
    #         args.add("-open", resolver_module_name)
    # else:
    #     if resolver_module_name:
    #         # this too means our we have separate main and resolver (???)
    #         args.add("-open", resolver_module_name)

    args.add("-c")
    args.add("-o", obj_cm_)
    # if not ctx.file.main:
    args.add(ns_file.path)

    if ctx.attr._rule == "ocaml_ns_library":
        mnemonic = "OcamlNsLibraryAction"
    elif ctx.attr._rule == "ocaml_ns_archive":
        mnemonic = "OcamlNsLibraryArchiveAction"
    else:
        mnemonic = "PpxNsModuleAction"

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = depset(direct = direct_file_deps, transitive = indirect_file_depsets),
        outputs = outputs,
        tools = [tc.ocamlfind, tc.ocamlopt],
        mnemonic = mnemonic,
        progress_message = "{mode} compiling: @{ws}//{pkg}:{tgt} (rule {rule})".format(
            mode = mode,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            rule=ctx.attr._rule,
            tgt=ctx.label.name,
        )
    )

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            direct = outputs, # directs,
            transitive = indirect_file_depsets
            # transitive = [mydeps.nopam] # , mydeps.opam]
            # depset(order="postorder", direct = indirects)]
        )
    )

    search_paths = sets.to_list(sets.make(includes))
    search_paths.append(obj_cm_.dirname)

    defaultMemo = DefaultMemo(
        paths  = depset(direct = search_paths, transitive=indirect_path_depsets),
        resolvers = resolvers_depset,
    )

    nslibProvider = None
    if ctx.attr._rule == "ocaml_ns_library":
        nslibProvider = OcamlNsLibraryProvider(
            name      = capitalize_initial_char(paths.split_extension(obj_cm_.basename)[0]),
            module    = obj_cm_,
        )
    else:
        nslibProvider = PpxNsLibraryProvider(
            name      = capitalize_initial_char(paths.split_extension(obj_cm_.basename)[0]),
            module    = obj_cm_,
        )

    opam_depset = depset(transitive = indirect_opam_depsets)
    opamProvider = OpamDepsProvider(
        pkgs = opam_depset
    )

    return [
        defaultInfo,
        defaultMemo,
        nslibProvider,
        opamProvider
    ]

