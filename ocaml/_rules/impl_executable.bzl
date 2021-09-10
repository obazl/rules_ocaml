load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CompilationModeSettingProvider",
     "OcamlExecutableProvider",
     "OcamlSDK",
     "OcamlTestProvider",
     "PpxExecutableProvider"
)

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "file_to_lib_name",
)

load(":options.bzl", "options")

load(":impl_common.bzl", "merge_deps")

################################################################
def _handle_cc_deps(ctx,
                    default_linkmode,
                    cc_deps_dict, ## list of dicts
                    args,
                    includes,
                    cclib_deps,
                    cc_runfiles):

    ## FIXME: static v. dynamic linking of cc libs in bytecode mode
    # see https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#ss%3Adynlink-c-code

    # default linkmode for toolchain is determined by platform
    # see @ocaml//toolchain:BUILD.bazel, ocaml/_toolchains/*.bzl
    # dynamic linking does not currently work on the mac - ocamlrun
    # wants a file named 'dllfoo.so', which rust cannot produce. to
    # support this we would need to rename the file using install_name_tool
    # for macos linkmode is dynamic, so we need to override this for bytecode mode

    debug = False
    # if ctx.attr._rule == "ocaml_executable":
    #     debug = True
    if debug:
        print("EXEC _handle_cc_deps %s" % ctx.label)
        print("CC_DEPS_DICT: %s" % cc_deps_dict)

    # first dedup
    ccdeps = {}
    for ccdict in cclib_deps:
        for [dep, linkmode] in ccdict.items():
            if dep in ccdeps.keys():
                if debug:
                    print("CCDEP DUP? %s" % dep)
            else:
                ccdeps.update({dep: linkmode})

    for [dep, linkmode] in cc_deps_dict.items():
        if debug:
            print("CCLIB DEP: ")
            print(dep)
        if linkmode == "default":
            if debug: print("DEFAULT LINKMODE: %s" % default_linkmode)
            for depfile in dep.files.to_list():
                if default_linkmode == "static":
                    if (depfile.extension == "a"):
                        args.add(depfile)
                        cclib_deps.append(depfile)
                        includes.append(depfile.dirname)
                else:
                    for depfile in dep.files.to_list():
                        if (depfile.extension == "so"):
                            libname = file_to_lib_name(depfile)
                            args.add("-ccopt", "-L" + depfile.dirname)
                            args.add("-cclib", "-l" + libname)
                            cclib_deps.append(depfile)
                        elif (depfile.extension == "dylib"):
                            libname = file_to_lib_name(depfile)
                            args.add("-cclib", "-l" + libname)
                            args.add("-ccopt", "-L" + depfile.dirname)
                            cclib_deps.append(depfile)
                            cc_runfiles.append(dep.files)
        elif linkmode == "static":
            if debug:
                print("STATIC lib: %s:" % dep)
            for depfile in dep.files.to_list():
                if (depfile.extension == "a"):
                    args.add(depfile)
                    cclib_deps.append(depfile)
                    includes.append(depfile.dirname)
        elif linkmode == "static-linkall":
            if debug:
                print("STATIC LINKALL lib: %s:" % dep)
            for depfile in dep.files.to_list():
                if (depfile.extension == "a"):
                    cclib_deps.append(depfile)
                    includes.append(depfile.dirname)
                    if ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"].cc_toolchain == "clang":
                        args.add("-ccopt", "-Wl,-force_load,{path}".format(path = depfile.path))
                    elif ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"].cc_toolchain == "gcc":
                        libname = file_to_lib_name(depfile)
                        args.add("-ccopt", "-L{dir}".format(dir=depfile.dirname))
                        args.add("-ccopt", "-Wl,--push-state,-whole-archive")
                        args.add("-ccopt", "-l{lib}".format(lib=libname))
                        args.add("-ccopt", "-Wl,--pop-state")
                    else:
                        fail("NO CC")

        elif linkmode == "dynamic":
            if debug:
                print("DYNAMIC lib: %s" % dep)
            for depfile in dep.files.to_list():
                if (depfile.extension == "so"):
                    libname = file_to_lib_name(depfile)
                    print("so LIBNAME: %s" % libname)
                    args.add("-ccopt", "-L" + depfile.dirname)
                    args.add("-cclib", "-l" + libname)
                    cclib_deps.append(depfile)
                elif (depfile.extension == "dylib"):
                    libname = file_to_lib_name(depfile)
                    print("LIBNAME: %s:" % libname)
                    args.add("-cclib", "-l" + libname)
                    args.add("-ccopt", "-L" + depfile.dirname)
                    cclib_deps.append(depfile)
                    cc_runfiles.append(dep.files)

#########################
def impl_executable(ctx):

    debug = False
    # if ctx.label.name == "test":
        # debug = True

    if debug:
        print("EXECUTABLE TARGET: {kind}: {tgt}".format(
            kind = ctx.attr._rule,
            tgt  = ctx.label.name
        ))

    OCAMLFIND_IGNORE = ""
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/digestif/c"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml"
    OCAMLFIND_IGNORE = OCAMLFIND_IGNORE + ":" + ctx.attr._sdkpath[OcamlSDK].path + "/lib/ocaml/compiler-libs"

    env = {
        "OPAMROOT": get_opamroot(),
        "PATH": get_sdkpath(ctx),
        "OCAMLFIND_IGNORE_DUPS_IN": OCAMLFIND_IGNORE
    }

    ## FIXME: support ctx.attr.mode?
    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    # if len(ctx.attr.deps_opam) > 0:
    #     using_ocamlfind = True
    #     ocamlfind_opts = ["-predicates", "ppx_driver"]
    #     exe = tc.ocamlfind
    # else:
    using_ocamlfind = False
    ocamlfind_opts = []
    if mode == "native":
        exe = tc.ocamlopt.basename
    else:
        exe = tc.ocamlc.basename

    ## FIXME: default extension to .out?

    ################
    merged_module_links_depsets = []
    merged_archive_links_depsets = []

    merged_paths_depsets = []
    merged_depgraph_depsets = []
    merged_archived_modules_depsets = []

    indirect_opam_depsets = []

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets = []

    direct_cc_deps    = {}
    direct_cc_deps.update(ctx.attr.cc_deps)
    indirect_cc_deps  = {}

    ################
    includes  = []
    cli_args  = []

    out_exe = ctx.actions.declare_file(ctx.label.name)

    #########################
    args = ctx.actions.args()

    if using_ocamlfind:
        if mode == "native":
            args.add(tc.ocamlopt.basename)
        else:
            args.add(tc.ocamlc.basename)

    if mode == "bytecode":
        ## FIXME: -custom only needed if linking with CC code?
        ## see section 20.1.3 at https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#s%3Ac-overview
        args.add("-custom")

    # if ctx.attr._threads:
    #     print("THREADS - ADDING ARGS")
    #     args.add("-I", "+threads")

    _options = get_options(rule, ctx)
    args.add_all(_options, uniquify=True)

    args.add_all(ocamlfind_opts, uniquify=True)

    mdeps = []
    if ctx.attr.deps:
        mdeps.extend(ctx.attr.deps)
    # print("MDEPS 1: %s" % mdeps)

    if ctx.attr.main != None:
        mdeps.append(ctx.attr.main)
    # print("MDEPS 2: {tgt} {mdeps}".format(tgt=ctx.label.name, mdeps=mdeps))

    merge_deps(mdeps,
               merged_module_links_depsets,
               merged_archive_links_depsets,
               merged_paths_depsets,
               merged_depgraph_depsets,
               merged_archived_modules_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    # opam_depset = depset(direct = ctx.attr.deps_opam,
    #                      transitive = indirect_opam_depsets)
    # opams = opam_depset.to_list()
    # if using_ocamlfind:
    #     if len(opams) > 0:
    #         args.add("-linkpkg")  ## tell ocamlfind to add cmxa files to cmd line
    #         [args.add("-package", opam) for opam in opams if opams] ## add dirs to search path

    # if not using_ocamlfind:

    # if ctx.attr._threads:
    #     if mode == "native":
    #         # args.add("unix.cmxa")
    #         args.add("threads.cmxa")
    #     else:
    #         args.add("unix.cma")
    #         args.add("threads.cma")

    imports_test = depset(transitive = merged_depgraph_depsets)
    
    for f in imports_test.to_list():
        # FIXME: only relativize ocaml_imports
        # print("relativizing %s" % f.path)
        if f.extension in ["cmxa"]: # , "a"]:
            cli_args.append(f.basename)
            ## problem is ocaml compilers will not follow symlinks
            ## so we need abs paths
            if (f.path.startswith("external/opam")):
                dir = paths.relativize(f.dirname, "external/opam/_lib")
                includes.append( "+../" + dir )
            else:
                includes.append( f.dirname )
                ## don't do this for ocaml_test?
                # args.add(f.path)
    # else:
    #     paths_depset = depset(transitive = merged_paths_depsets)
    #     for path in paths_depset.to_list():
    #         includes.append(path)
    #         if f.extension in ["cmxa"]:
    #             args.add(f.path)

    ## now we need to add cc deps to the cmd line
    cclib_deps  = []
    cc_runfiles = []
    cc_deps_dict = {}
    cc_deps_dict.update(direct_cc_deps)
    cc_deps_dict.update(indirect_cc_deps)
    _handle_cc_deps(ctx, tc.linkmode,
                    cc_deps_dict,
                    args,
                    includes,
                    cclib_deps,
                    cc_runfiles)

    if "-g" in _options:
        args.add("-runtime-variant", "d") # FIXME: verify compile built for debugging

    ## FIXME: includes contains dups, why?
    args.add_all(includes, before_each="-I", uniquify=True)

    args.add_all(cli_args, uniquify=True)

    # args.add("-absname")
    ## use depsets to get the right ordering. archive and module links are mutually exclusive.
    links = depset(order = "postorder", transitive = merged_module_links_depsets).to_list()
    ### cmxa deps already added above, without dir part of path:
    if len(links) > 0:
        for m in links:
            # FIXME: merged_module_links_depset should not contain any
            # archives, but it does, so:
            if m.extension not in ["cmxa"]:
                args.add(m)

    # if ctx.attr.main != None:
    #     for f in ctx.attr.main.files.to_list():
    #         if f.extension in ["cmx", "o"]:
    #             cclib_deps.append(f)
    #         if f.extension in ["cmx"]:
    #             args.add("-I", f.dirname)
    #             args.add("-I", f.dirname + "/__obazl")
    #             args.add(f.basename)

    args.add("-o", out_exe)

    inputs_depset = depset(
        order = "postorder",
        direct = cclib_deps,
        transitive = merged_depgraph_depsets + merged_archived_modules_depsets
    )

    if ctx.attr._rule == "ocaml_executable":
        mnemonic = "CompileOcamlExecutable"
    elif ctx.attr._rule == "ppx_executable":
        mnemonic = "CompilePpxExecutable"
    elif ctx.attr._rule == "ocaml_test":
        mnemonic = "CompileOcamlTest"
    else:
        fail("Unknown rule for executable: %s" % ctx.attr._rule)

    ################
    ctx.actions.run(
      env = env,
      executable = exe, ## tc.ocamlfind,
      arguments = [args],
      inputs = inputs_depset,
      outputs = [out_exe],
      tools = [tc.ocamlfind, tc.ocamlopt],
      mnemonic = mnemonic,
      progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
          mode = mode,
          rule = ctx.attr._rule,
          ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
          pkg = ctx.label.package,
          tgt = ctx.label.name,
        )
    )
    ################
    ################

    ## FIXME: verify correctness
    if ctx.attr.strip_data_prefixes:
      myrunfiles = ctx.runfiles(
        files = ctx.files.data,
        symlinks = {dfile.basename : dfile for dfile in ctx.files.data}
      )
    else:
        myrunfiles = ctx.runfiles(
            files = ctx.files.data,
        )

    ##########################
    defaultInfo = DefaultInfo(
        executable=out_exe,
        runfiles = myrunfiles
    )

    ## We need to pass adjunct deps for ppx executables
    nopam_direct_paths = []
    for dep in ctx.files.deps_adjunct:
        nopam_direct_paths.append(dep.dirname)
    nopam_paths = depset(direct = nopam_direct_paths,
                         transitive = indirect_adjunct_path_depsets)

    # print("INDIRECT_ADJUNCTS: %s" % indirect_adjunct_depsets)
    # print("DEPS_ADJUNCTS: %s" % ctx.files.deps_adjunct)
    adjuncts_provider = AdjunctDepsProvider(
        # opam = depset(
        #     direct     = ctx.attr.deps_adjunct_opam,
        #     transitive = indirect_adjunct_opam_depsets
        # ),
        nopam = depset(
            # direct     = ctx.attr.deps_adjunct,
            direct     = ctx.files.deps_adjunct,
            transitive = indirect_adjunct_depsets
        ),
        nopam_paths = nopam_paths
    )

    ## Marker provider
    exe_provider = None
    if ctx.attr._rule == "ppx_executable":
        exe_provider = PpxExecutableProvider(
            args = ctx.attr.args
        )
    elif ctx.attr._rule == "ocaml_executable":
        exe_provider = OcamlExecutableProvider()
    elif ctx.attr._rule == "ocaml_test":
        exe_provider = OcamlTestProvider()
    else:
        fail("Wrong rule called impl_executable: %s" % ctx.attr._rule)

    results = [
        defaultInfo,
        adjuncts_provider,
        exe_provider
    ]
    # print("XXXXXXXXXXXXXXXX adjuncts_provider: %s" % adjuncts_provider)

    return results
