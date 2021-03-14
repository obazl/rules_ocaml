load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlArchiveProvider",
     "PpxArchiveProvider")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_projroot",
)

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl", "merge_deps", "tmpdir")

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
        if "-linkpkg" in ctx.attr.opts:
            fail("-linkpkg option not supported for ppx_archive rule")

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

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets = []

    indirect_path_depsets = []

    direct_resolver = None

    direct_cc_deps  = {}
    indirect_cc_deps  = {}
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
    # cc_deps   = []
    link_search  = []

    merge_deps(ctx.attr.modules,
               indirect_file_depsets,
               indirect_path_depsets,
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

    args.add("-a")

    indirect_paths_depset = depset(transitive = indirect_path_depsets)
    for path in indirect_paths_depset.to_list():
        # print("PATH: %s" % path)
        includes.append(path)
    args.add_all(includes, before_each="-I", uniquify = True)

    ## modules to include must be on command line
    files_depset = depset(transitive = indirect_file_depsets)
    for dep in files_depset.to_list():
        ## 'Option -a cannot be used with .cmxa input files.'
        if dep.extension in ["cmo", "cmx"]: ## "cma", "cmxa"]:
            args.add(dep)

    args.add_all(link_search, before_each="-ccopt", uniquify = True)

    if mode == "native":
        obj_files.append(obj_a)

    obj_files.append(obj_cm_a)

    args.add("-o", obj_cm_a)

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = files_depset,
        outputs = obj_files,
        tools = [tc.ocamlfind, tc.ocamlopt],
        mnemonic = "OcamlArchiveImpl" if ctx.attr._rule == "ocaml_archive" else "PpxArchiveImpl",
        progress_message = "{mode} compiling ocaml_archive: @{ws}//{pkg}:{tgt}".format(
            mode = mode,
            ws  = ctx.label.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            direct = [obj_cm_a, obj_a] if obj_a else [obj_cm_a],
        )
    )

    execroot = get_projroot(ctx)
    apath = execroot + "/" + ctx.workspace_name + "/" + obj_cm_a.dirname

    defaultMemo = DefaultMemo(
        paths     = depset(direct = [apath]),
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
            ]


