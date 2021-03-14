load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

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
    # if ctx.attr._rule == "ocaml_executable":
    #     debug = True

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

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    outfilename = ctx.label.name

    outbinary = ctx.actions.declare_file(outfilename)

    ################
    direct_file_deps = []
    indirect_file_depsets = []

    indirect_opam_depsets = []

    indirect_adjunct_depsets      = []
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets = []

    indirect_path_depsets = []

    direct_resolver = None

    direct_cc_deps    = {}
    direct_cc_deps.update(ctx.attr.cc_deps) # if ctx.attr.cc_deps else []
    indirect_cc_deps  = {}
    ################

    includes  = []

    ################################################################
    args = ctx.actions.args()

    if mode == "bytecode":
        args.add(tc.ocamlc.basename)
        args.add("-custom")
    else:
        args.add(tc.ocamlopt.basename)

    for opt in ctx.attr._opts[BuildSettingInfo].value:
        args.add(opt)
    options = get_options(rule, ctx)
    args.add_all(options)

    # if mode == "bytecode":
    #     dllpath = ctx.attr._sdkpath[OcamlSDK].path + "/lib/stublibs"
    #     args.add("-dllpath", dllpath)

        # args.add("-dllpath", "/private/var/tmp/_bazel_gar/d8a1bb469d0c2393045b412d4daaa038/execroot/ppx_version/external/ocaml/switch/lib/stublibs")

        # args.add("-I", "external/ocaml/switch/lib/stublibs")

    dynamic_libs = []
    static_libs  = []
    link_search  = []

    merge_deps(ctx.attr.deps,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    ## main is a dep, just like the deps in 'deps'
    ## passing it to merge_deps here ensures that it will come last
    if ctx.attr.main != None:
        merge_deps([ctx.attr.main],
                   indirect_file_depsets,
                   indirect_path_depsets,
                   indirect_opam_depsets,
                   indirect_adjunct_depsets,
                   indirect_adjunct_path_depsets,
                   indirect_adjunct_opam_depsets,
                   indirect_cc_deps)

    indirect_paths_depset = depset(transitive = indirect_path_depsets)
    for path in indirect_paths_depset.to_list():
        includes.append(path)

    if ctx.attr.deps_opam:
        args.add("-linkpkg")
        for dep in ctx.attr.deps_opam:
            args.add("-package", dep)

    opams = depset(transitive = indirect_opam_depsets).to_list()
    if len(opams) > 0:
        args.add("-linkpkg")
        [args.add("-package", opam) for opam in opams if opams]

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

    args.add_all(includes, before_each="-I")

    modules = depset(transitive = indirect_file_depsets).to_list()
    if len(modules) > 0:
        for m in modules:
            if m.extension in ["cmo", "cmx", "cma", "cmxa"]:
                args.add(m)

    args.add("-o", outbinary)

    input_depset = depset(
        direct = direct_file_deps + cclib_deps,
        transitive = indirect_file_depsets
    )

    if ctx.attr.strip_data_prefixes:
      myrunfiles = ctx.runfiles(
        files = ctx.files.data,
        symlinks = {dfile.basename : dfile for dfile in ctx.files.data}
      )
    else:
      myrunfiles = ctx.runfiles(
        files = ctx.files.data,
      )

    ctx.actions.run(
      env = env,
      executable = tc.ocamlfind,
      arguments = [args],
      inputs = input_depset,
      outputs = [outbinary],
      tools = [tc.ocamlfind, tc.ocamlopt], # tc.opam,
      mnemonic = "OcamlExecutable" if ctx.attr._rule == "ocaml_executable" else "PpxExecutable",
      progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
          mode = mode,
          rule = ctx.attr._rule,
          ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
          pkg = ctx.label.package,
          tgt = ctx.label.name,
        )
    )

    defaultInfo = DefaultInfo(
        executable=outbinary,
        runfiles = myrunfiles
    )

    nopam_direct_paths = []
    for dep in ctx.files.deps_adjunct:
        nopam_direct_paths.append(dep.dirname)
    nopam_paths = depset(direct = nopam_direct_paths,
                         transitive = indirect_adjunct_path_depsets)

    adjuncts_provider = AdjunctDepsProvider(
        opam = depset(
            direct     = ctx.attr.deps_adjunct_opam,
            transitive = indirect_adjunct_opam_depsets
        ),
        nopam = depset(
            direct     = ctx.attr.deps_adjunct,
            transitive = indirect_adjunct_depsets
        ),
        nopam_paths = nopam_paths
    )

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

    return results
