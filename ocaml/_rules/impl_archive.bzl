load("@bazel_skylib//rules:common_settings.bzl",
     "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlArchiveProvider",
     # "OcamlDepsetProvider",
     "PpxArchiveProvider",
     "PpxDepsetProvider")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_projroot",
     "file_to_lib_name"
)

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl", "merge_deps")

##################################################
def impl_archive(ctx):

    debug = False
    # if (ctx.label.name == "zexe_backend_common"):
    #     debug = True

    if debug:
        print("ARCHIVE TARGET: %s" % ctx.label.name)

    if ctx.attr._rule == "ppx_module":
        mode = ctx.attr._mode[0]
    else:
        mode = ctx.attr._mode[CompilationModeSettingProvider].value

    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    ext  = ".cmxa" if  mode == "native" else ".cma"

    if ctx.attr._rule == "ppx_archive":
        ## -linkpkg is an ocamlfind parameter
        if "-linkpkg" in ctx.attr.opts:
            fail("-linkpkg option not supported for ppx_archive rule")

    ## declare outputs
    tmpdir = "_obazl_/"
    obj_files = []
    obj_cm_a = None
    obj_a    = None
    if ctx.attr.archive_name:
      obj_cm_a = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ext)
      if mode == "native":
          obj_a = ctx.actions.declare_file(tmpdir + ctx.attr.archive_name + ".a")
    else:
      obj_cm_a = ctx.actions.declare_file(tmpdir + ctx.label.name + ext)
      if mode == "native":
          obj_a = ctx.actions.declare_file(tmpdir + ctx.label.name + ".a")

    build_deps = []  # for the command line
    includes = []
    dep_graph = []  # for the run action inputs

    ################
    direct_file_deps = []
    indirect_file_depsets = []
    indirect_archive_depsets = []

    indirect_opam_depsets = []

    indirect_adjunct_depsets = []  # list of depsets gathered from direct deps
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets  = []  # list of depsets gathered from direct deps

    indirect_path_depsets = []

    direct_resolver = None
    indirect_resolver_depsets = []

    direct_cc_deps  = []
    indirect_cc_deps  = []
    ################

    ################################################################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    cc_linkmode = tc.linkmode            # used below to determine linkmode for deps
    if ctx.attr._cc_linkmode:
        if ctx.attr._cc_linkmode[BuildSettingInfo].value == "static": # override toolchain default?
            cc_linkmode = "static"

    configurable_defaults = get_options(ctx.attr._rule, ctx)
    args.add_all(configurable_defaults)

    ## No direct cc_deps for archives - they should be attached to archive members
    cc_deps   = []
    link_search  = []

    merge_deps(ctx.attr.modules,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_resolver_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    if len(indirect_opam_depsets) > 0:
        ## DO NOT USE -linkpkg, it tells ocamlfind to put dep files on command line,
        ## which for native mode may result in:
        ## `Option -a cannot be used with .cmxa input files.`
        opams = depset(transitive = indirect_opam_depsets)
        for opam in opams.to_list():
            # -package tells ocamlfind to add OPAM file dirs to search path with -I
            args.add("-package", opam)

    files_depset = depset(transitive = indirect_file_depsets)
    for dep in files_depset.to_list():
        ## 'Option -a cannot be used with .cmxa input files.'
        if dep.extension in ["cmo", "cmx"]: ## "cma", "cmxa"]:
            args.add(dep)

    # for dep in mydeps.nopam.to_list():

    #   ## cc deps
    #   elif dep.extension == "a":
    #       if cc_linkmode == "static":
    #           dep_graph.append(dep)
    #           build_deps.append(dep)
    #   elif dep.extension == "so":
    #       dep_graph.append(dep)
    #       if debug:
    #           print("NOPAM .so DEP: %s" % dep)
    #       if cc_linkmode == "dynamic":
    #           libname = file_to_lib_name(dep)
    #       if mode == "native":
    #           link_search.append("-L" + dep.dirname)
    #           cc_deps.append("-l" + libname)
    #       else:
    #           link_search.append(dep.dirname)
    #           cc_deps.append("-l" + libname)
    #   elif dep.extension == "dylib":
    #       if debug:

    #           print("NOPAM .dylib DEP: %s" % dep)
    #       if cc_linkmode == "dynamic":
    #           dep_graph.append(dep)
    #           libname = file_to_lib_name(dep)
    #           if mode == "native":
    #               link_search.append("-L" + dep.dirname)
    #               cc_deps.append("-l" + libname)
    #           else:
    #               link_search.append(dep.dirname)
    #               cc_deps.append(libname)
    #   else:
    #       if debug:
    #           print("NOMAP DEP not .cmx, cmxa, cmo, cma, .o, .lo, .so, .dylib: %s" % dep.path)

    args.add_all(link_search, before_each="-ccopt", uniquify = True)
    if mode == "native":
        args.add_all(cc_deps, before_each="-cclib", uniquify = True)
    else:
        args.add_all(link_search, before_each="-dllpath", uniquify = True)
        args.add_all(cc_deps, before_each="-dllib", uniquify = True)

    args.add_all(includes, before_each="-I", uniquify = True)

    ## since we're building an archive, we need all members on command line
    # args.add_all(build_deps)

    if mode == "native":
        obj_files.append(obj_a)

    obj_files.append(obj_cm_a)

    args.add("-a")
    args.add("-o", obj_cm_a)

    # dep_graph = dep_graph + build_deps

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = files_depset,  ## dep_graph,
        outputs = obj_files,
        tools = [tc.ocamlfind, tc.ocamlopt],
        mnemonic = "OcamlArchiveImpl" if ctx.attr._rule == "ocaml_archive" else "PpxArchiveImpl",
        progress_message = "{mode} compiling ocaml_archive: @{ws}//{pkg}:{tgt}".format(
            mode = mode,
            ws  = ctx.label.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
            # msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
        )
    )

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            direct = [obj_cm_a, obj_a] if obj_a else [obj_cm_a],
            # transitive = depset(indirect_archive_depsets)
        )
    )

    execroot = get_projroot(ctx)
    apath = execroot + "/" + ctx.workspace_name + "/" + obj_cm_a.dirname

    defaultMemo = DefaultMemo(
        paths     = depset(direct = [apath]),
        resolvers = depset()
        # resolvers = depset(direct = [direct_resolver] if direct_resolver else [],
        #                    transitive = [indirect_resolvers_depset]),
    )

    if ctx.attr._rule == "ocaml_archive":
        archiveProvider = OcamlArchiveProvider(
        )
    else:
        archiveProvider = PpxArchiveProvider(
        )

    return [defaultInfo,
            defaultMemo,
            archiveProvider,
            # opamProvider
            ]


