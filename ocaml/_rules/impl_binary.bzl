load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlExecutableMarker",
     "OcamlImportMarker",
     "OcamlModuleMarker",
     "OcamlTestMarker",
     "OcamlVmRuntimeProvider",
)

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
     "PpxExecutableMarker",
)

load(":impl_ccdeps.bzl", "extract_cclibs", "dump_CcInfo")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

# load("//ocaml/_functions:utils.bzl", "get_sdkpath")

load("//ocaml/_functions:module_naming.bzl", "file_to_lib_name")

load(":options.bzl", "options")

load(":impl_common.bzl", "dsorder", "opam_lib_prefix",
     "tmpdir"
     )

load("//ocaml/_debug:colors.bzl", "CCRED", "CCGRN", "CCMAG", "CCRESET")

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

workdir = tmpdir

#########################
def _import_ppx_executable(ctx):

    binout = ctx.actions.declare_file(
        workdir + ctx.file.bin.basename
    )
    ctx.actions.symlink(output = binout,
                        target_file = ctx.file.bin)

    defaultInfo = DefaultInfo(
        executable=binout
    )

    exe_provider = PpxExecutableMarker(
        args = ctx.attr.args
    )
    providers = [
        defaultInfo,
        exe_provider
    ]
    return providers

#########################
def impl_binary(ctx): # , mode, tc, tool, tool_args):

    debug     = False
    debug_deps= False
    debug_cc  = False
    debug_ppx = False
    debug_tc  = False

    if debug or debug_ppx:
        print("EXECUTABLE TARGET: {kind}: {tgt}".format(
            kind = ctx.attr._rule,
            tgt  = ctx.label.name
        ))

    if hasattr(ctx.attr, "bin"):
        if ctx.attr.bin:
            if debug_ppx: print("importing precompiled ppx executable: %s" % ctx,attr.bin)
            ## precompiled executable
            return _import_ppx_executable(ctx)

    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]

    if tc.target == "vm":
        struct_extensions = ["cma", "cmo"]
    else:
        struct_extensions = ["cmxa", "cmx"]

    # env = {
    #     "PATH": get_sdkpath(ctx),
    # }

    # direct file deps of this target
    # we don't use the directs but we need the data type instead of None
    sigs_primary             = []
    structs_primary          = []
    ofiles_primary           = []  # .o files
    archives_primary         = []
    afiles_primary           = []  # .a files
    astructs_primary         = []
    cc_deps_primary         = []
    cmts_primary             = []
    paths_primary   = []

    # depsets from 'deps' attribute:
    sigs_secondary           = []
    structs_secondary        = []
    ofiles_secondary         = []  # .o files
    archives_secondary       = []
    afiles_secondary         = []  # .a files
    astructs_secondary       = []
    cc_deps_secondary       = []
    paths_secondary = []

    codep_sigs_primary       = []
    codep_structs_primary    = []
    codep_ofiles_primary     = []
    codep_archives_primary   = []
    codep_afiles_primary     = []
    codep_astructs_primary   = []
    codep_cc_deps_primary   = []
    codep_paths_primary      = []

    codep_sigs_secondary     = []
    codep_structs_secondary  = []
    codep_ofiles_secondary   = []
    codep_archives_secondary = []
    codep_afiles_secondary   = []
    codep_astructs_secondary = []
    codep_cc_deps_secondary = []
    codep_paths_secondary    = []

    # cc_libs = []

    ################
    includes   = []

    #FIXME: executable name
    # use ctx.label.name or ctx.attr.exe if defined
    # 1. strip extension (e.g. name="foo.exe" => "foo")
    # 1b. throw warning if ctx.attr.exe has extension
    # 2. add configured extension (default: .byte / none)
    if ctx.attr.exe:
        out_exe = ctx.actions.declare_file(ctx.attr.exe) # + ".exe")
    else:
        out_exe = ctx.actions.declare_file(ctx.label.name)

    #########################
    args = ctx.actions.args()

    # args.add_all(tool_args)

    _options = get_options(rule, ctx)
    # print("OPTIONS: %s" % _options)
    # do not uniquify options, it collapses all -I
    args.add_all(_options)

    ## FIXME: drive this with compilation_mode == dbg, not -g
    if tc.target == "vm":
        if "-g" in _options:
            args.add("-runtime-variant", "d") # FIXME: verify compile built for debugging

    ################################################################
                   ####    DEPENDENCIES    ####
    ################################################################

    ################ SECONDARY DEPENDENCIES ################
    if debug: print("iterating deps")
    for dep in ctx.attr.deps:
        if debug:
            print("DEP: %s" % dep)
            if OcamlProvider in dep:
                print("dep[OcamlProvider] %s" % dep[OcamlProvider])
            if OcamlImportMarker in dep:
                print("dep[OcamlImportMarker] %s" % dep[OcamlImportMarker])

        if OcamlProvider in dep:
            provider = dep[OcamlProvider]
            sigs_secondary.append(provider.sigs)
            structs_secondary.append(provider.structs)
            ofiles_secondary.append(provider.ofiles)
            archives_secondary.append(provider.archives)
            afiles_secondary.append(provider.afiles)
            astructs_secondary.append(provider.astructs)

            # if hasattr(provider, "cc_libs"):
            #     cc_libs.extend(provider.cc_libs)

            paths_secondary.append(provider.paths)

        ################ PpxCodepsProvider ################
        ## only for ocaml_imports listed in deps, not ppx_codeps
        if PpxCodepsProvider in dep:
            provider = dep[PpxCodepsProvider]
            ## aggregates may provide an empty PpxCodepsProvider
            if hasattr(provider, "sigs"):

                if debug_ppx:
                    print("PpxCodepsProvider in std dep: %s" % dep)
                    print(" provides archives: %s" % provider.archives)
                # if hasattr(ppxcdp, "ppx_codeps"):
                #     if ppxcdp.ppx_codeps:
                #         indirect_ppx_codep_depsets.append(ppxcdp.ppx_codeps)

                codep_sigs_secondary.append(provider.sigs)
                codep_structs_secondary.append(provider.structs)
                codep_ofiles_secondary.append(provider.ofiles)
                codep_archives_secondary.append(provider.archives)
                codep_afiles_secondary.append(provider.afiles)
                codep_astructs_secondary.append(provider.astructs)
                codep_paths_secondary.append(provider.paths)

                # cc_deps_secondary.append(provider.cc_deps)

            # if hasattr(provider, "paths"):
            #     if provider.paths:
            #         path_depsets.append(provider.paths)
            #         indirect_ppx_codep_depsets_paths.append(provider.paths)
            # if hasattr(ppxcdp, "cdeps"):
            #     if ppxcdp.cdeps:
            #         ppx_codep_cdeps.append(ppxcdp.cdeps)
            # if hasattr(ppxcdp, "ldeps"):
            #     if ppxcdp.ldeps:
            #         ppx_codep_ldeps.append(ppxcdp.ldeps)

        if CcInfo in dep:
            # print("CcInfo dep: %s" % dep)
            cc_deps_primary.append(dep[CcInfo])

    if debug:
        print("finished deps iteration")
        print("sigs_primary: %s" % sigs_primary)
        print("sigs_secondary: %s" % sigs_secondary)
        print("structs_primary: %s" % structs_primary)
        print("structs_secondary: %s" % structs_secondary)
        print("ofiles_primary: %s" % ofiles_primary)
        print("ofiles_secondary: %s" % ofiles_secondary)
        ## archives cannot be direct deps
        print("archives_primary: %s" % archives_primary)
        print("archives_secondary: %s" % archives_secondary)
        print("afiles_primary: %s" % afiles_primary)
        print("afiles_secondary: %s" % afiles_secondary)
        print("astructs_primary: %s" % astructs_primary)
        print("astructs_secondary: %s" % astructs_secondary)
        print("cc_deps_primary: %s" % astructs_primary)
        print("cc_deps_secondary: %s" % astructs_secondary)

    ## FIXME: a ppx_executable just links modules - it should not have
    ## ppx_codeps?
    if hasattr(ctx.attr, "ppx_codeps"):
        if debug_ppx: print("has ppx_codeps attrib")
        for codep in ctx.attr.ppx_codeps:
            # if OcamlImportMarker in codep:
            #     print("ppx_codep is import: %s" % codep)

            if OcamlProvider in codep:
                if debug_ppx:
                    print("ppx_codep has OcamlProvider: %s" % codep)

                coprovider = codep[OcamlProvider];
                codep_sigs_secondary.append(coprovider.sigs)
                codep_structs_secondary.append(coprovider.structs)
                codep_ofiles_secondary.append(coprovider.ofiles)
                codep_archives_secondary.append(coprovider.archives)
                codep_astructs_secondary.append(coprovider.astructs)
                codep_afiles_secondary.append(coprovider.afiles)
                codep_paths_secondary.append(coprovider.paths)

            ## a codep could carry its own codeps if it depends on a
            ## ppx_module with codeps
            if PpxCodepsProvider in codep:
                if debug_ppx: print("ppx_codep has PpxCodepsProvider")
                coprovider = codep[PpxCodepsProvider]
                codep_sigs_secondary.append(coprovider.sigs)
                codep_structs_secondary.append(coprovider.structs)
                codep_ofiles_secondary.append(coprovider.ofiles)
                codep_archives_secondary.append(coprovider.archives)
                codep_astructs_secondary.append(coprovider.astructs)
                codep_afiles_secondary.append(coprovider.afiles)
                codep_paths_secondary.append(coprovider.paths)

            if CcInfo in codep:
                codep_cc_deps_secondary.append(codep[CcInfo])

                # NB: codep[OcamlProvider]linkargs insufficient, it only
                # contains archive files, for linking executables.
                # We will need to list all modules as inputs


    # print("LDEPS: %s" % ppx_codep_ldeps)

    ################################################################
    #### MAIN ####
    if debug: print("processing 'main' attribute")
    if ctx.attr.main:
        main = ctx.attr.main
        # main must have an OCamlProvider
        provider = main[OcamlProvider]
        sigs_secondary.append(provider.sigs)
        structs_secondary.append(provider.structs)
        ofiles_secondary.append(provider.ofiles)
        archives_secondary.append(provider.archives)
        afiles_secondary.append(provider.afiles)
        astructs_secondary.append(provider.astructs)
        paths_secondary.append(provider.paths)

        # cc_libs.extend(provider.cc_libs)

        if PpxCodepsProvider in main:
            if debug_ppx: print("main module has PpxCodepsProvider")
            coprovider = main[PpxCodepsProvider]
            codep_sigs_secondary.append(coprovider.sigs)
            codep_structs_secondary.append(coprovider.structs)
            codep_ofiles_secondary.append(coprovider.ofiles)
            codep_archives_secondary.append(coprovider.archives)
            codep_afiles_secondary.append(coprovider.afiles)
            codep_astructs_secondary.append(coprovider.astructs)
            codep_paths_secondary.append(coprovider.paths)

        if CcInfo in main:
            # print("MAIN CCINFO: %s" % main[CcInfo])
            cc_deps_secondary.append(main[CcInfo])

    ## end ctx.attr.main handling
    if debug:
        print("finished 'main' handling; archive deps:")
        print("sigs_primary: %s" % sigs_primary)
        print("sigs_secondary: %s" % sigs_secondary)
        print("structs_primary: %s" % structs_primary)
        print("structs_secondary: %s" % structs_secondary)
        print("ofiles_primary: %s" % ofiles_primary)
        print("ofiles_secondary: %s" % ofiles_secondary)
        ## archives cannot be direct deps
        print("archives_primary: %s" % archives_primary)
        print("archives_secondary: %s" % archives_secondary)
        print("afiles_primary: %s" % afiles_primary)
        print("afiles_secondary: %s" % afiles_secondary)
        print("astructs_primary: %s" % astructs_primary)
        print("astructs_secondary: %s" % astructs_secondary)

        print("cc_deps_primary: %s" % cc_deps_primary)
        print("cc_deps_secondary: %s" % cc_deps_secondary)

    if debug_ppx:
        print("finished 'main' handling; ppx codeps:")
        print("codep_sigs_primary: %s" % codep_sigs_primary)
        print("codep_sigs_secondary: %s" % codep_sigs_secondary)
        print("codep_structs_primary: %s" % codep_structs_primary)
        print("codep_structs_secondary: %s" % codep_structs_secondary)
        print("codep_ofiles_primary: %s" % codep_ofiles_primary)
        print("codep_ofiles_secondary: %s" % codep_ofiles_secondary)
        ## archives cannot be direct deps
        print("codep_archives_primary: %s" % codep_archives_primary)
        print("codep_archives_secondary: %s" % codep_archives_secondary)
        print("codep_afiles_primary: %s" % codep_afiles_primary)
        print("codep_afiles_secondary: %s" % codep_afiles_secondary)
        print("codep_astructs_primary: %s" % codep_astructs_primary)
        print("codep_astructs_secondary: %s" % codep_astructs_secondary)

        print("codep_cc_deps_primary: %s" % codep_cc_deps_primary)
        print("codep_cc_deps_secondary: %s" % codep_cc_deps_secondary)

    ################
    paths_depset  = depset(
        order = dsorder,
        direct = paths_primary,
        transitive = paths_secondary
    )

    ############ CC DEPS ################

    ## NOTE: OCaml automatically adds -lfoo if a libfoo dependency is
    ## recorded in an archive file. We have no way to detect this, so
    ## we may end up with duplicates. Which should not be problematic.

    if debug_cc:
        print("cc_deps_primary: %s" % cc_deps_primary)
        for ccdep in cc_deps_primary:
            dump_CcInfo(ctx, ccdep)

        print("cc_deps_secondary: %s" % cc_deps_secondary)
        for ccdep in cc_deps_secondary:
            dump_CcInfo(ctx, ccdep)

    ccInfo = cc_common.merge_cc_infos(
        cc_infos = cc_deps_primary + cc_deps_secondary
    + codep_cc_deps_primary + codep_cc_deps_secondary)
    if debug_cc: print("Merged CcInfo: %s" % ccInfo)

    ## extract cc_deps from merged CcInfo provider:
    [
        static_cc_deps, dynamic_cc_deps
    ] = extract_cclibs(ctx, tc.linkmode, args, ccInfo)

    if debug_cc:
        print("static_cc_deps:  %s" % static_cc_deps)
        print("dynamic_cc_deps: %s" % dynamic_cc_deps)

    ## we put -lfoo before -Lpath/to/foo, to avoid iterating twice
    cclib_linkpaths = []
    cc_runfiles = []

    ## NB: -cclib -lfoo is just for -custom linking!
    ## for std (non-custom) linking use -dllib

    runfiles_root = out_exe.path + ".runfiles"
    print("runfiles_root: %s" % runfiles_root)
    ws_name = ctx.workspace_name
    print("ws name: %s" % ws_name)

    if tc.target == "vm":
        # vmlibs =  lib/stublibs/dll*.so, set by toolchain
        # only needed for bytecode mode, else we get errors like:
        # Error: I/O error: dllbase_internalhash_types_stubs.so: No such
        # file or directory
        vmlibs = tc.vmlibs

        ## WARNING: both -dllpath and -I are required!
        args.add("-dllpath", tc.vmlibs[0].dirname)
        args.add("-I", tc.vmlibs[0].dirname)

        if debug:
            print("{c}vm_runtime:{r} {rt}".format(
                c=CCGRN,r=CCRESET, rt = ctx.attr.vm_runtime))
            print("vm_runtime[OcamlVmRuntimeProvider: %s" %
                  ctx.attr.vm_runtime[OcamlVmRuntimeProvider])

        # if "ppx" in ctx.attr.tags or ctx.attr._rule == "ppx_executable":
            ## Currently we default to a custom runtime.
            ## See section 20.1.3 "Statically linking C code with OCaml code"
            ## https://v2.ocaml.org/manual/intfc.html#ss:staticlink-c-code
            ## and https://ocaml.org/manual/runtime.html

        # args.add("-custom")

        if ctx.attr.vm_runtime[OcamlVmRuntimeProvider].kind == "dynamic":
            for cclib in dynamic_cc_deps:
                print("cclib.short_path: %s" % cclib.short_path)
                print("cclib.dirname: %s" % cclib.dirname)

                linkpath = "%s/%s/%s" % (
                    runfiles_root, ws_name, cclib.short_path)

                # this is for build-time:
                includes.append(cclib.dirname)
                # and this is for run-time:
                includes.append(paths.dirname(linkpath))
                # args.add("-dllpath", "-L" + cclib.dirname)
                args.add("-dllpath", paths.dirname(cclib.short_path))
                # as is this:
                cc_runfiles.append(cclib)

                bn = cclib.basename[3:]
                bn = bn[:-3]
                args.add("-dllib", "-l" + bn)

                # args.add("-cclib", "-l" + bn)
                cclib_linkpaths.append("-L" + cclib.dirname)
                # cclib_linkpaths.append("-L" + paths.dirname(cclib.short_path))
                # includes.append(paths.dirname(linkpath))
                # includes.append(paths.dirname(cclib.short_path))
                # cc_runfiles.append(cclib)
                # fail("xxxxxxxxxxxxxxxx")

        elif ctx.attr.vm_runtime[OcamlVmRuntimeProvider].kind == "static":
            ## should not be any .so files???
            sincludes = []
            for dep in static_cc_deps:
                print("STATIC DEP: %s" % dep)
                args.add("-custom")
                args.add("-ccopt", dep.path)
                includes.append(dep.dirname)
                sincludes.append("-L" + dep.dirname)

                # args.add_all(sincludes, before_each="-ccopt", uniquify=True)
                # includes.append(cclib.dirname)
                # args.add(cclib.short_path)
    else: # tc.target == sys
        vmlibs = [] ## we never need vmlibs for native code
        ## this accomodates ml libs with cc deps
        ## e.g. 'base' depends on libbase_stubs.a
        for cclib in static_cc_deps:
            # print("STATIC DEP: %s" % dep)
            cclib_linkpaths.append("-L" + cclib.dirname)

    args.add_all(cclib_linkpaths, before_each="-ccopt", uniquify=True)

    args.add_all(includes, before_each="-I", uniquify=True)

    # for lib in cc_libs:
    #     args.add(lib.path)

    # args.add_all(paths_depset.to_list(), before_each="-I")
    includes.extend(paths_depset.to_list())

    astructs_depset = depset(order=dsorder,
                            # direct=astructs_primary,
                            transitive=astructs_secondary)

    ## Archives and structs must be on the command line:
    archives_depset = depset(order=dsorder,
                             direct=archives_primary,
                             transitive=archives_secondary)

    for archive in archives_depset.to_list():
        if debug:
            print("ADDING ARCHIVE %s" % archive)
        args.add(archive)

    structs_depset = depset(order=dsorder,
                            direct=structs_primary,
                            transitive=structs_secondary)

    for struct in structs_depset.to_list():
        if debug:
            print("ADDING STRUCT %s" % struct)
        args.add(struct)

    # args.add(ctx.file.main)

    args.add("-o", out_exe)

    data_inputs = []
    if ctx.attr.data:
        data_inputs = [depset(direct = ctx.files.data)]
        for f in ctx.files.data:
            # print("DATAFILE: %s" % f.path)
            args.add("-I", f.dirname)

    if debug_deps:
        print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
        print("vmlibs: %s" % vmlibs)
        print("afiles_primary: %s" % afiles_primary)
        print("astructs_primary: %s" % astructs_primary)
        print("archives_primary: %s" % archives_primary)
        print("structs_primary: %s" % structs_primary)
        print("ofiles_primary: %s" % ofiles_primary)
        print("sigs_primary: %s" % sigs_primary)
        print("static_cc_deps: %s" % static_cc_deps)
        print("dynamic_cc_deps: %s" % dynamic_cc_deps)

        print("codep_afiles_primary: %s" % codep_afiles_primary)
        print("codep_astructs_primary: %s" % codep_astructs_primary)
        print("codep_archives_primary: %s" % codep_archives_primary)
        print("codep_structs_primary: %s" % codep_structs_primary)
        print("codep_ofiles_primary: %s" % codep_ofiles_primary)
        print("codep_sigs_primary: %s" % codep_sigs_primary)
        # print("codep_cc_deps_primary: %s" % codep_cc_deps_primary)
        # transitive
        print("ctx.files.main: %s" % ctx.files.main)
        print("sigs_secondary: %s" % sigs_secondary)
        print("structs_secondary: %s" % structs_secondary)
        print("archives_secondary: %s" % archives_secondary)
        print("afiles_secondary: %s" % afiles_secondary)
        print("ofiles_secondary: %s" % ofiles_secondary)
        print("astructs_secondary: %s" % astructs_secondary)

        print("codep_afiles_secondary: %s" % codep_afiles_secondary)
        print("codep_astructs_secondary: %s" % codep_astructs_secondary)
        print("codep_archives_secondary: %s" % codep_archives_secondary)
        print("codep_structs_secondary: %s" % codep_structs_secondary)
        print("codep_ofiles_secondary: %s" % codep_ofiles_secondary)
        print("codep_sigs_secondary: %s" % codep_sigs_secondary)
        # print("codep_cc_deps_secondary

    if ctx.files.main:
        mainfile = ctx.files.main
    else:
        mainfile = []

    action_inputs_depset = depset(
        order=dsorder,
        direct = mainfile
        + vmlibs
        + afiles_primary
        + astructs_primary
        + archives_primary
        + structs_primary
        + ofiles_primary
        + sigs_primary
        + static_cc_deps
        + dynamic_cc_deps

        + codep_afiles_primary
        + codep_astructs_primary
        + codep_archives_primary
        + codep_structs_primary
        + codep_ofiles_primary
        + codep_sigs_primary
        # + codep_cc_deps_primary
        ,
        transitive =
          sigs_secondary
        + structs_secondary
        + archives_secondary
        + afiles_secondary ## .a files for .cmxa files on cmd line
        + ofiles_secondary  ## .o files for .cmx files on cmd line
        + astructs_secondary

        + codep_afiles_secondary
        + codep_astructs_secondary
        + codep_archives_secondary
        + codep_structs_secondary
        + codep_ofiles_secondary
        + codep_sigs_secondary
        # + codep_cc_deps_secondary

        # + cc_deps_secondary
        # + [depset(action_inputs_ccdep_filelist)]
        # + [depset(transitive=ppx_codep_ldeps)]
        # + [structs_depset]
        # + vmlibs
    )
    if debug:
        for dep in action_inputs_depset.to_list():
            if dep.dirname.endswith("stublibs"):
                print("IDEP: {t} {d}".format(
                    t=ctx.label, d=dep.path))

    if ctx.attr._rule == "ocaml_binary":
        mnemonic = "LinkOCamlExecutable"
    elif "ppx" in ctx.attr.tags or ctx.attr._rule == "ppx_executable":
    # elif ctx.attr._rule == "ppx_executable":
        mnemonic = "LinkOCamlPpxExecutable"
    elif ctx.attr._rule == "ocaml_test":
        mnemonic = "LinkOCamlTest"
    else:
        fail("Unknown rule for executable: %s" % ctx.attr._rule)

    env = {"PATH": "/usr/bin:/usr"}
    ## sweet jeebus. this is the only way I could find to merge two
    ## dicts. sheesh.
    for i in ctx.attr.env.items():
        env[i[0]] = i[1]
    # print("ENV: %s" % env)
    ################
    ctx.actions.run(
        env = env,
        executable = tc.compiler, # tool,
        arguments = [args],
        inputs = action_inputs_depset,
        outputs = [out_exe],
        tools = [
            tc.compiler # tool,
            # cctc.static_runtime_lib()
        ], ## + tool_args,  # [tc.ocamlopt],
        mnemonic = mnemonic,
        progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
            mode = tc.host + ">" + tc.target,
            rule = ctx.attr._rule,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt = ctx.label.name,
        )
    )
    ################

    #### RUNFILE DEPS ####
    rfiles = ctx.files.data + tc.vmlibs + cc_runfiles
    if ctx.attr.strip_data_prefixes:
        myrunfiles = ctx.runfiles(
            files = rfiles,
            symlinks = {dfile.basename : dfile for dfile in ctx.files.data}
        )
    else:
        myrunfiles = ctx.runfiles(
            files = rfiles
        )

    ##########################
    defaultInfo = DefaultInfo(
        executable=out_exe,
        runfiles = myrunfiles
    )

    exe_provider = None
    if "ppx" in ctx.attr.tags or ctx.attr._rule == "ppx_executable":
        exe_provider = PpxExecutableMarker(
            args = ctx.attr.args
        )
    elif ctx.attr._rule == "ocaml_binary":
        exe_provider = OcamlExecutableMarker()
    elif ctx.attr._rule == "ocaml_test":
        exe_provider = OcamlTestMarker()
    else:
        fail("Wrong rule called impl_binary: %s" % ctx.attr._rule)

    providers = [
        defaultInfo,
        exe_provider
    ]

    ## for ppx_executable: in addition to the compiled exe and
    ## runfiles, we need to propagate ppx codeps, so that they can be
    ## passed on as deps of src files the ppx transforms. that is,
    ## an ocaml_module rule with a 'ppx' attribute will extract the
    ## ppx_codeps from its ppx_executable dependency, and use them
    ## in the ppx transform action that runs the ppx_executable.

    ## NB: ctx.files.ppx_codeps (== DefaultInfo.files) will not
    ## deliver imported source files, so we need to iterate over
    ## providers

    ## executables do not directly support ppx_codeps attr - they must
    ## be attached to the module that injects the dep.

    if hasattr(ctx.attr, "ppx_codeps"):
    # if ctx.attr._rule == "ppx_executable":
        # ppx_codeps_paths_depset = depset(
        #     direct = direct_ppx_codep_depsets_paths,
        #     transitive = depset(direct=indirect_ppx_codep_depsets_paths)
        # )

        # ppx_codeps_depset = depset(
        # odep
        #     transitive = indirect_ppx_codep_depsets
        # )

        # ppx_codeps_linkset = depset(
        #     transitive = ppx_codep_linksets
        # )

        # ppxCodepsProvider = PpxCodepsProvider(
        #     ppx_codeps = ppx_codeps_depset,
        #     # paths = ppx_codeps_paths_depset,
        #     # linkset = ppx_codeps_linkset,
        #     # sigs   = ppx_codep_cdeps,
        #     # structs   = ppx_codep_ldeps,
        # )

        ppx_sigs_depset = depset(order=dsorder,
                                 direct = codep_sigs_primary,
                                 transitive = codep_sigs_secondary)

        ppxCodepsProvider = PpxCodepsProvider(
            sigs       = ppx_sigs_depset,
            structs    = depset(order=dsorder,
                                direct = codep_structs_primary,
                                transitive = codep_structs_secondary),
            ofiles     = depset(order=dsorder,
                                direct = codep_ofiles_primary,
                                transitive = codep_ofiles_secondary),
            archives   = depset(order=dsorder,
                                direct = codep_archives_primary,
                                transitive = codep_archives_secondary),
            afiles     = depset(order=dsorder,
                                direct = codep_afiles_primary,
                                transitive = codep_afiles_secondary),
            astructs       = depset(order=dsorder,
                                   direct = codep_astructs_primary,
                                   transitive = codep_astructs_secondary),
            # cc_deps = depset(order=dsorder,
            #                 direct = codep_cc_deps_primary,
            #                 transitive = codep_cc_deps_secondary),
            paths    = depset(order=dsorder,
                              direct = codep_paths_primary,
                              transitive = codep_paths_secondary),
        )
        providers.append(ppxCodepsProvider)

        # outputGroupInfo = OutputGroupInfo(
        #     ppx_codeps = ppx_sigs_depset,
        #     # linkset = ppx_codeps_linkset,
        #     inputs = action_inputs_depset,
        #     all = depset(transitive=[
        #         ppx_codeps_depset,
        #     ])
        # )
        # providers.append(outputGroupInfo)

    return providers
