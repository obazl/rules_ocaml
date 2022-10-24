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

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_ccdeps.bzl", "extract_cclibs", "dump_CcInfo")

load("//ocaml/_functions:deps.bzl",
     "aggregate_deps",
     "aggregate_codeps",
     "OCamlInfo",
     "DepsAggregator")

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

    # tasks
    # * merge deps
    # * construct action_inputs depset
    # * handle cc deps
    # * declare outputs and construct action_outputs depset
    # * construct command line
    # * run the link action
    # * construct and return providers

    debug     = False
    debug_deps= False
    debug_cc  = True
    debug_ppx = False
    debug_tc  = False
    debug_vm  = True

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

    # * merge deps  ###############################
    depsets = DepsAggregator(
        deps = OCamlInfo(
            sigs = [],
            structs = [],
            ofiles  = [],
            archives = [],
            afiles = [],
            astructs = [], # archived cmx structs, for linking
            cmts = [],
            paths  = [],
            jsoo_runtimes = [], # runtime.js files
        ),
        codeps = OCamlInfo(
            sigs = [],
            structs = [],
            ofiles = [],
            archives = [],
            afiles = [],
            astructs = [],
            cmts = [],
            paths = [],
            jsoo_runtimes = [],
        ),
        ccinfos = []
    )

    print("ctx.attr.deps: %s" % ctx.attr.deps)
    for dep in ctx.attr.deps:
        depsets = aggregate_deps(ctx, dep, depsets)

    # print("ctx.attr.ppx_codeps: %s" % ctx.attr.ppx_codeps)
    if hasattr(ctx.attr, "ppx_codeps"):
        for codep in ctx.attr.ppx_codeps:
            depsets = aggregate_codeps(ctx, codep, depsets)

    #### MAIN ####
    ## NB: 'main' only takes a target, not a file, so it counts as a
    ## 'secondary' dep. It providers deliver depsets, not files.
    ## Process it AFTER processing ctx.attr.deps
    ## (ctx.attr.initializers). (?)

    if debug: print("processing 'main' attribute")
    # if ctx.label.name == "ppx_1.exe":
    #     print("main op: %s" % ctx.attr.main[OcamlProvider])
    #     print("main codep: %s" % ctx.attr.main[PpxCodepsProvider])
        # fail("x")

    depsets = aggregate_deps(ctx, ctx.attr.main, depsets)

    ################
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
    includes   = []
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
    # for dep in ctx.attr.deps:
    #     if debug:
    #         print("DEP: %s" % dep)
    #         if OcamlProvider in dep:
    #             print("dep[OcamlProvider] %s" % dep[OcamlProvider])
    #         if OcamlImportMarker in dep:
    #             print("dep[OcamlImportMarker] %s" % dep[OcamlImportMarker])

    #     if OcamlProvider in dep:
    #         provider = dep[OcamlProvider]
    #         sigs_secondary.append(provider.sigs)
    #         structs_secondary.append(provider.structs)
    #         ofiles_secondary.append(provider.ofiles)
    #         archives_secondary.append(provider.archives)
    #         afiles_secondary.append(provider.afiles)
    #         astructs_secondary.append(provider.astructs)

    #         # if hasattr(provider, "cc_libs"):
    #         #     cc_libs.extend(provider.cc_libs)

    #         paths_secondary.append(provider.paths)

    #     ################ PpxCodepsProvider ################
    #     ## only for ocaml_imports listed in deps, not ppx_codeps
    #     if PpxCodepsProvider in dep:
    #         provider = dep[PpxCodepsProvider]
    #         ## aggregates may provide an empty PpxCodepsProvider
    #         if hasattr(provider, "sigs"):

    #             if debug_ppx:
    #                 print("PpxCodepsProvider in std dep: %s" % dep)
    #                 print(" provides archives: %s" % provider.archives)
    #             # if hasattr(ppxcdp, "ppx_codeps"):
    #             #     if ppxcdp.ppx_codeps:
    #             #         indirect_ppx_codep_depsets.append(ppxcdp.ppx_codeps)

    #             codep_sigs_secondary.append(provider.sigs)
    #             codep_structs_secondary.append(provider.structs)
    #             codep_ofiles_secondary.append(provider.ofiles)
    #             codep_archives_secondary.append(provider.archives)
    #             codep_afiles_secondary.append(provider.afiles)
    #             codep_astructs_secondary.append(provider.astructs)
    #             codep_paths_secondary.append(provider.paths)

    #             # cc_deps_secondary.append(provider.cc_deps)

    #         # if hasattr(provider, "paths"):
    #         #     if provider.paths:
    #         #         path_depsets.append(provider.paths)
    #         #         indirect_ppx_codep_depsets_paths.append(provider.paths)
    #         # if hasattr(ppxcdp, "cdeps"):
    #         #     if ppxcdp.cdeps:
    #         #         ppx_codep_cdeps.append(ppxcdp.cdeps)
    #         # if hasattr(ppxcdp, "ldeps"):
    #         #     if ppxcdp.ldeps:
    #         #         ppx_codep_ldeps.append(ppxcdp.ldeps)

    #     if CcInfo in dep:
    #         # print("CcInfo dep: %s" % dep)
    #         cc_deps_primary.append(dep[CcInfo])

    # if debug:
    #     print("finished deps iteration")
    #     print("sigs_primary: %s" % sigs_primary)
    #     print("sigs_secondary: %s" % sigs_secondary)
    #     print("structs_primary: %s" % structs_primary)
    #     print("structs_secondary: %s" % structs_secondary)
    #     print("ofiles_primary: %s" % ofiles_primary)
    #     print("ofiles_secondary: %s" % ofiles_secondary)
    #     ## archives cannot be direct deps
    #     print("archives_primary: %s" % archives_primary)
    #     print("archives_secondary: %s" % archives_secondary)
    #     print("afiles_primary: %s" % afiles_primary)
    #     print("afiles_secondary: %s" % afiles_secondary)
    #     print("astructs_primary: %s" % astructs_primary)
    #     print("astructs_secondary: %s" % astructs_secondary)
    #     print("cc_deps_primary: %s" % astructs_primary)
    #     print("cc_deps_secondary: %s" % astructs_secondary)

    ## FIXME: a ppx_executable just links modules - it should not have
    ## ppx_codeps?  they should be on the modules
    # if hasattr(ctx.attr, "ppx_codeps"):
    #     if debug_ppx: print("has ppx_codeps attrib")
    #     for codep in ctx.attr.ppx_codeps:
    #         # if OcamlImportMarker in codep:
    #         #     print("ppx_codep is import: %s" % codep)

    #         if OcamlProvider in codep:
    #             if debug_ppx:
    #                 print("ppx_codep has OcamlProvider: %s" % codep)

    #             coprovider = codep[OcamlProvider];
    #             # codep_sigs_primary.append(coprovider.sigs)
    #             # codep_structs_primary.append(coprovider.structs)
    #             # codep_ofiles_primary.append(coprovider.ofiles)
    #             # codep_archives_primary.append(coprovider.archives)
    #             # codep_astructs_primary.append(coprovider.astructs)
    #             # codep_afiles_primary.append(coprovider.afiles)
    #             # codep_paths_primary.append(coprovider.paths)

    #             codep_sigs_secondary.append(coprovider.sigs)
    #             codep_structs_secondary.append(coprovider.structs)
    #             codep_ofiles_secondary.append(coprovider.ofiles)
    #             codep_archives_secondary.append(coprovider.archives)
    #             codep_astructs_secondary.append(coprovider.astructs)
    #             codep_afiles_secondary.append(coprovider.afiles)
    #             codep_paths_secondary.append(coprovider.paths)

    #         ## a codep could carry its own codeps if it depends on a
    #         ## ppx_module with codeps
    #         if PpxCodepsProvider in codep:
    #             if debug_ppx: print("ppx_codep has PpxCodepsProvider")
    #             coprovider = codep[PpxCodepsProvider]
    #             codep_sigs_secondary.append(coprovider.sigs)
    #             codep_structs_secondary.append(coprovider.structs)
    #             codep_ofiles_secondary.append(coprovider.ofiles)
    #             codep_archives_secondary.append(coprovider.archives)
    #             codep_astructs_secondary.append(coprovider.astructs)
    #             codep_afiles_secondary.append(coprovider.afiles)
    #             codep_paths_secondary.append(coprovider.paths)

    #         if CcInfo in codep:
    #             codep_cc_deps_secondary.append(codep[CcInfo])

    #             # NB: codep[OcamlProvider]linkargs insufficient, it only
    #             # contains archive files, for linking executables.
    #             # We will need to list all modules as inputs


    # print("LDEPS: %s" % ppx_codep_ldeps)

    ################
    paths_depset  = depset(
        order = dsorder,
        direct = depsets.deps.paths + depsets.codeps.paths # paths_secondary
    )

    ############ CC DEPS ################
    # This is the tricky bit. We need to support both static and
    # dynamic linking for both bytecode and native targets.

    ## NOTE: OCaml automatically adds -lfoo if a libfoo dependency is
    ## recorded in an archive file. We have no way to detect this, so
    ## we may end up with duplicates. Which should not be problematic.

    # if debug_cc:
    #     print("cc_deps_primary: %s" % cc_deps_primary)
    #     for ccdep in cc_deps_primary:
    #         dump_CcInfo(ctx, ccdep)

    #     print("cc_deps_secondary: %s" % cc_deps_secondary)
    #     for ccdep in cc_deps_secondary:
    #         dump_CcInfo(ctx, ccdep)

    ## FIXME: need we separate ordinary ccdeps from ppx_codep ccdeps?
    ## No, they're only needed at link-time, without distinction.

    ## ccinfos were aggregated above
    ccInfo = cc_common.merge_cc_infos(
        # direct_cc_infos =
        cc_infos = depsets.ccinfos
        # cc_infos = cc_deps_primary + cc_deps_secondary
        # # + codep_cc_deps_primary
        # + codep_cc_deps_secondary
    )
    # if debug_cc:
    #     dump_CcInfo(ctx, ccInfo)

    # codeps_ccInfo = cc_common.merge_cc_infos(
    #     cc_infos = depsets.codeps_cc_deps_secondary)
    #     # cc_infos = codep_cc_deps_secondary)
    #     # cc_infos = codep_cc_deps_primary + codep_cc_deps_secondary)

    ## to construct cmd line we need to extract the cc files from
    ## merged CcInfo provider:
    [static_cc_deps, dynamic_cc_deps] = extract_cclibs(ctx, ccInfo)
    if debug_cc:
        print("static_cc_deps:  %s" % static_cc_deps)
        print("dynamic_cc_deps: %s" % dynamic_cc_deps)

    ## we put -lfoo before -Lpath/to/foo, to avoid iterating twice
    cclib_linkpaths = []
    cc_runfiles = []

    ## NB: -cclib -lfoo is just for -custom linking!
    ## for std (non-custom) linking use -dllib

    runfiles_root = out_exe.path + ".runfiles"
    # print("runfiles_root: %s" % runfiles_root)
    ws_name = ctx.workspace_name
    # print("ws name: %s" % ws_name)

    if tc.target == "vm":
        # vmlibs =  lib/stublibs/dll*.so, set by toolchain
        # only needed for bytecode mode, else we get errors like:
        # Error: I/O error: dllbase_internalhash_types_stubs.so: No such
        # file or directory

        # may also get e.g.
        # Fatal error: cannot load shared library dllbase_internalhash_types_stubs
        # Reason: dlopen(dllbase_internalhash_types_stubs.so, 0x000A): tried: 'dllbase_internalhash_types_stubs.so' (no such file) ... etc.

        print("vmruntime: %s" % ctx.attr.vm_runtime)
        # if ctx.label.name == "inline_test_runner.exe":
        #     fail("asdfsfd")

        vmlibs = tc.vmlibs

        ## WARNING: both -dllpath and -I are required!
        # args.add("-ccopt", "-L" + tc.vmlibs[0].dirname)
        args.add("-dllpath", tc.vmlibs[0].dirname)
        args.add("-I", tc.vmlibs[0].dirname)

        if debug_vm:
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

        for cclib in dynamic_cc_deps:
            args.add("-dllpath", cclib.dirname)
            cc_runfiles.append(cclib)
            # args.add("-ccopt", "-L" + cclib.dirname)
            # args.add("-cclib", "-l" + cclib.basename)

        if ctx.attr.vm_runtime[OcamlVmRuntimeProvider].kind == "dynamic":
            for cclib in dynamic_cc_deps:
                # print("cclib.short_path: %s" % cclib.short_path)
                # print("cclib.dirname: %s" % cclib.dirname)

                linkpath = "%s/%s/%s" % (
                    runfiles_root, ws_name, cclib.short_path)

                # this is for build-time:
                includes.append(cclib.dirname)
                # and this is for run-time:
                includes.append(paths.dirname(linkpath))
                args.add("-dllpath", cclib.dirname)
                args.add("-dllpath", paths.dirname(cclib.short_path))
                # as is this:
                cc_runfiles.append(cclib)

                bn = cclib.basename[3:]
                bn = bn[:-3]
                # args.add("-dllib", "-l" + bn)

                # args.add("-cclib", "-l" + bn)
                # cclib_linkpaths.append("-L" + cclib.dirname)
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

    # if ctx.label.name == "inline_test_runner.exe":
    #     fail("x")

    #### /end cc deps processing

    args.add_all(includes, before_each="-I", uniquify=True)

    # for lib in cc_libs:
    #     args.add(lib.path)

    # args.add_all(paths_depset.to_list(), before_each="-I")
    includes.extend(paths_depset.to_list())

    # codeps_depset = depset(
    #     order = dsorder,
    #     transitive = codep_archives_secondary
    # )
    # for codep in codeps_depset.to_list():
    #     args.add(codep)

    ## Archives and structs must be on the command line:
    if ctx.attr._rule == "ocaml_binary":
        bin_codeps = depsets.codeps.archives # codep_archives_secondary
    else:
        bin_codeps = []

    archives_depset = depset(
        order=dsorder,
        # direct=archives_primary,
        transitive= depsets.deps.archives + bin_codeps
        # transitive= archives_secondary + bin_codeps
        )

    for archive in archives_depset.to_list():
        if debug:
            print("ADDING ARCHIVE %s" % archive)

        ## ppx processing may result in different toolchains to be
        ## used to build a ppx executable (e.g. sys>sys) and to
        ## compile the result of a ppx transform (e.g. sys>vm). this
        ## is not a problem if bazel builds all deps, but if we import
        ## precompiled resources (e.g. using opam_import), then we run
        ## into a problem with ppx_codeps. They are not needed to link
        ## the ppx_executable, but we need to propagate them so they
        ## can be used later to compile/link ppx-transformed files.
        ## The problem is that linkage of the ppx executable may
        ## select one (e.g. cmxa, due to sys>sys toolchain) when later
        ## compilation of the ppx transform result may need the other
        ## (e.g. cma, due to sys>vm toolchain).

        ## To accomodate this, opam_import puts both cma and cmxa in
        ## the archive field of the OcmlProvider, and here we need to
        ## select one by checking the extension.

        ## There may be a better way of doing this, but this seems to
        ## work so far.

        if tc.target == "vm":
            if archive.extension == "cma":
                args.add(archive)
        else:
            if archive.extension == "cmxa":
                args.add(archive)

    ## free-standing struct deps (structs not archived)
    structs_depset = depset(order=dsorder,
                            transitive = depsets.deps.structs
                            + depsets.codeps.structs)
                            # direct=structs_primary,
                            # transitive=structs_secondary)

    for struct in structs_depset.to_list():
        args.add(struct)
        if debug:
            print("ADDING STRUCT %s" % struct)

    # if hasattr(ctx.attr, "main"):
    #     args.add(ctx.file.main)

    args.add("-o", out_exe)

    # if tc.target == "vm":
    #     # FIXME: requires that runtime and stubs files be added to cmd line
    #     # e.g. -lbase_stubs
    #     args.add("-output-complete-exe")

    data_inputs = []
    if ctx.attr.data:
        data_inputs = [depset(direct = ctx.files.data)]
        for f in ctx.files.data:
            # print("DATAFILE: %s" % f.path)
            args.add("-I", f.dirname)

    if hasattr(ctx.files, "main"):
        mainfile = ctx.files.main
    else:
        mainfile = []

    action_inputs_depset = depset(
        order=dsorder,
        direct = []
        # mainfile
        + vmlibs
        + static_cc_deps
        + dynamic_cc_deps
        ,
        transitive =
        depsets.deps.sigs
        + depsets.deps.structs
        + depsets.deps.ofiles
        + depsets.deps.archives
        + depsets.deps.afiles
        + depsets.deps.astructs

        + depsets.codeps.sigs
        + depsets.codeps.structs
        + depsets.codeps.ofiles
        + depsets.codeps.archives
        + depsets.codeps.afiles
        + depsets.codeps.astructs
    )

    if debug:
        for dep in action_inputs_depset.to_list():
            if dep.dirname.endswith("stublibs"):
                print("IDEP: {t} {d}".format(
                    t=ctx.label, d=dep.path))

    if "ppx" in ctx.attr._tags:
        if "executable" in ctx.attr._tags:
            mnemonic = "LinkPpxExecutable"
        elif "test" in ctx.rule._tags:
            mnemonic = "LinkPpxTest"
    elif "ocaml" in ctx.attr._tags:
        if "binary" in ctx.attr._tags:
            mnemonic = "LinkOCamlExecutable"
        elif "test" in ctx.attr._tags:
            mnemonic = "LinkOCamlTest"
    else:
        print("WARNING: unknown rule for executable: %s" % ctx.attr._rule)
        mnemonic = ctx.attr._rule

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
        progress_message = "{mode} linking {rule}: {ws}//{pkg}:{tgt}".format(
            mode = tc.host + ">" + tc.target,
            rule = ctx.attr._rule,
            ws  = "@" + ctx.label.workspace_name if ctx.label.workspace_name else "", ## ctx.workspace_name,
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
    if "ppx" in ctx.attr.tags or ctx.attr._rule in ["ppx_executable", "ppxlib_executable"]:
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

    # if hasattr(ctx.attr, "ppx_codeps"):
            # + depsets.codeps.sigs)
            # direct = codep_sigs_primary,
            # transitive = codep_sigs_secondary)

    _ocamlProvider = OcamlProvider(
        # struct = depset(direct = [outfile]),
        sigs    = depset(order="postorder",
                         # direct=sigs_primary,
                         transitive = depsets.deps.sigs),
        structs = depset(order="postorder",
                         # direct=structs_primary,
                         transitive = depsets.deps.structs),
        ofiles   = depset(order="postorder",
                          # direct=ofiles_primary,
                          transitive = depsets.deps.ofiles),
        archives = depset(order="postorder",
                          # direct=archives_primary,
                          transitive = depsets.deps.archives),
        afiles   = depset(order="postorder",
                          # direct=afiles_primary,
                          transitive = depsets.deps.afiles),
        astructs = depset(order="postorder",
                          # direct=astructs_primary,
                          transitive = depsets.deps.astructs),
        cmts     = depset(order="postorder",
                          # direct=cmts_primary,
                          transitive = depsets.deps.cmts),
        paths    = depset(order="postorder",
                          # direct=paths_primary,
                          transitive = depsets.deps.paths),
        jsoo_runtimes = depset(order="postorder",
                               # direct=jsoo_runtimes_primary,
                               transitive = depsets.deps.jsoo_runtimes),
    )
    # providers.append(_ocamlProvider)

    ppxCodepsProvider = PpxCodepsProvider(
        sigs       = depset(order=dsorder,
                            transitive = depsets.codeps.sigs),
        structs    = depset(order=dsorder,
                            transitive = depsets.codeps.structs),
        ofiles     = depset(order=dsorder,
                            transitive = depsets.codeps.ofiles),
        archives   = depset(order=dsorder,
                            transitive = depsets.codeps.archives),
        afiles     = depset(order=dsorder,
                            transitive = depsets.codeps.afiles),
        astructs   = depset(order=dsorder,
                                transitive = depsets.codeps.astructs),
        paths      = depset(order=dsorder,
                          transitive = depsets.codeps.paths),
        jsoo_runtimes = depset(order="postorder",
                               transitive = depsets.codeps.jsoo_runtimes),
    )
    providers.append(ppxCodepsProvider)

    providers.append(ccInfo)

        # outputGroupInfo = OutputGroupInfo(
        #     ppx_codeps = ppx_sigs_depset,
        #     # linkset = ppx_codeps_linkset,
        #     inputs = action_inputs_depset,
        #     all = depset(transitive=[
        #         ppx_codeps_depset,
        #     ])
        # )
        # providers.append(outputGroupInfo)

        ## no OcamlProvider?

    return providers
