load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("@rules_ocaml//build:providers.bzl", "OCamlProvider")
load("//build:providers.bzl",
     "OcamlExecutableMarker",
     # "OcamlImportMarker",
     # "OcamlModuleMarker",
     "OcamlTestMarker",
     "OCamlVmRuntimeProvider",
)
load("//build:providers.bzl", "OCamlCodepsProvider")

load("//build/_lib:utils.bzl", "get_options")

load("@rules_ocaml//build/_lib:impl_ccdeps.bzl", "extract_cclibs",
     "dump_compilation_context",
     "dump_CcInfo",)

load("@rules_ocaml//lib:merge.bzl",
     "aggregate_deps",
     "aggregate_codeps",
     "DepsAggregator",
     "COMPILE", "LINK", "COMPILE_LINK")

load("//build/_lib:module_naming.bzl", "file_to_lib_name")

load("//build/_lib:options.bzl", "options")

load("//build/_lib:impl_common.bzl", "dsorder", # "opam_lib_prefix",
     "tmpdir"
     )

load("//lib:colors.bzl",
     "CCBLU", "CCRED", "CCGRN", "CCMAG", "CCRESET")

# load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

load("@rules_cc//cc:action_names.bzl", "C_COMPILE_ACTION_NAME")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain")


DISABLED_FEATURES = [
#     "module_maps",  # copybara-comment-this-out-please
]

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

    # exe_provider = PpxExecutableMarker(
    #     args = ctx.attr.args
    # )
    providers = [
        defaultInfo,
        # exe_provider
    ]
    return providers

#########################
def impl_binary(ctx): # , mode, tc, tool, tool_args):
    # print("impl_binary")
    # tasks
    # * merge deps
    # * construct action_inputs depset
    # * handle cc deps
    # * declare outputs and construct action_outputs depset
    # * construct command line
    # * run the link action
    # * construct and return providers

    # True if ctx.label.name == "Alpha" else False
    debug     = False
    debug_deps= False
    debug_cc  = False # True if ctx.label.name == "Alpha" else False
    debug_ppx = False
    debug_runfiles = False
    debug_tc  = False
    debug_vm  = False # True
    # False #True if ctx.label.name == "Alpha" else False

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

    cc_tc = find_cc_toolchain(ctx)
    # print("cc_tc: %s" % cc_tc)
    # for e in dir(cc_tc):
    #     print("tc fld: %s: %s" % (e, getattr(cc_tc, e)))

    # if cc_tc.toolchain_id.startswith("darwin"):
    #     print("DARWIN TC")
    # print("CMODE: %s" % ctx.var["COMPILATION_MODE"])

    # feature_configuration = cc_common.configure_features(
    #     ctx = ctx,
    #     cc_toolchain = cc_tc,
    #     requested_features = ctx.features,
    #     unsupported_features = DISABLED_FEATURES + ctx.disabled_features,
    # )
    # # print("fconfigs: %s" % feature_configuration)
    # # print("fconfigs[]: %s" % getattr(feature_configuration, "cpu"))
    # c_compile_variables = cc_common.create_compile_variables(
    #     feature_configuration = feature_configuration,
    #     cc_toolchain = cc_tc,
    #     user_compile_flags = ctx.fragments.cpp.copts + ctx.fragments.cpp.conlyopts,
    #     # source_file = source_file.path,
    #     # output_file = output_file.path,
    # )
    # print("ccvars: %s" % c_compile_variables)
    # command_line = cc_common.get_memory_inefficient_command_line(
    #     feature_configuration = feature_configuration,
    #     action_name = C_COMPILE_ACTION_NAME,
    #     variables = c_compile_variables,
    # )
    # print("cl: %s" % command_line)

    # print("ctx.features: %s" % ctx.features)

    # print("cpp frag: %s" % ctx.fragments.cpp.copts)

    if tc.target == "vm":
        struct_extensions = ["cma", "cmo"]
    else:
        struct_extensions = ["cmxa", "cmx"]

    # * merge deps  ###############################

    depsets = DepsAggregator()

    if hasattr(ctx.attr, "prologue"):
        ##FIXME: only for ppx_executable, do not pass on to consumers
        if debug_deps: print("ctx.attr.prologue: %s" % ctx.attr.prologue)
        for dep in ctx.attr.prologue:
            # print("PROLOG DEP: %s" % dep)
            depsets = aggregate_deps(ctx, dep, depsets)
            ## codeps already handled by aggregate_deps
            ## aggregate_codeps is just for ppx_codeps
            # if OCamlCodepsProvider in dep:
            #     depsets = aggregate_codeps(ctx, COMPILE_LINK, dep, depsets)
        # print("PROLOGUE depsets: %s" % depsets)

    if hasattr(ctx.attr, "ppx_codeps"):
        # print("ctx.attr.ppx_codeps: %s" % ctx.attr.ppx_codeps)
        for codep in ctx.attr.ppx_codeps:
            depsets = aggregate_codeps(ctx, COMPILE_LINK, codep, depsets)
        # print("codepsets: %s" % depsets.codeps)

    if hasattr(ctx.attr, "ppx_compile_codeps"):
        for codep in ctx.attr.ppx_compile_codeps:
            depsets = aggregate_codeps(ctx, COMPILE, codep, depsets)

    if hasattr(ctx.attr, "ppx_link_codeps"):
        for codep in ctx.attr.ppx_link_codeps:
            depsets = aggregate_codeps(ctx, LINK, codep, depsets)

    #### MAIN ####
    ## NB: 'main' only takes a target, not a file, so it counts as a
    ## 'secondary' dep. Its providers deliver depsets, not files.
    ## Process it AFTER processing ctx.attr.deps
    ## (ctx.attr.initializers). (?)

    if debug: print("processing 'main' attribute")
    # if ctx.label.name == "ppx_1.exe":
    #     print("main op: %s" % ctx.attr.main[OCamlProvider])
    #     print("main codep: %s" % ctx.attr.main[OCamlCodepsProvider])
        # fail("x")

    ## WARNING: we do not want ctx.attr.main to go in output codeps provider
    ## i.e. these deps are just for compiling the binary and should
    ## not be passed on (like codeps) to users of the (ppx) binary
    depsets = aggregate_deps(ctx, ctx.attr.main, depsets)
    # if ctx.label.name == "test":
    #     print("CLILINK %s" % depsets.deps.cli_link_deps)
    #     fail()

    if hasattr(ctx.attr, "epilogue"):
        ## as above, for the binary only, not to be passed on
        if debug_deps: print("ctx.attr.epilogue: %s" % ctx.attr.epilogue)
        for dep in ctx.attr.epilogue:
            depsets = aggregate_deps(ctx, dep, depsets)

    ##FIXME: cc_deps?

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

    ################################################################
    ##  construct command line ##
    #############################
    includes   = []
    args = ctx.actions.args()

    ## the bazel tc for macos, fastbuild, inserts -DDEBUG
    ## that forces us to use the debug runtime
    ## to avoid "ld: Undefined symbols:  _caml_failed_assert"
    ## which is caused by using #if DEBUG instead of #if NDEBUG
    ## in ocaml/runtime/caml/misc.h
    # if cc_tc.toolchain_id.startswith("darwin"):
    #     if ctx.var["COMPILATION_MODE"] == "fastbuild":
    #         # assump that -DDEBUG implies we need dbg runtime
    #         args.add("-runtime-variant", "d")

    _options = get_options(rule, ctx)
    # print("OPTIONS: %s" % _options)
    # do not uniquify options, it collapses all -I
    # (huh?)
    args.add_all(_options)

    ## FIXME: drive this with compilation_mode == dbg, not -g
    if tc.target == "vm":
        if "-g" in _options:
            args.add("-runtime-variant", "d") # FIXME: verify compile built for debugging

    ################
    paths_depset  = depset(
        order = dsorder,
        transitive = depsets.deps.paths + depsets.codeps.paths # paths_secondary
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
    if debug_cc:
        dump_CcInfo(ctx, ccInfo)

    # codeps_ccInfo = cc_common.merge_cc_infos(
    #     cc_infos = depsets.codeps_cc_deps_secondary)
    #     # cc_infos = codep_cc_deps_secondary)
    #     # cc_infos = codep_cc_deps_primary + codep_cc_deps_secondary)

    ## to construct cmd line we need to extract the cc files from
    ## merged CcInfo provider:
    [static_cc_deps, dynamic_cc_deps, runtime_variant] = extract_cclibs(ctx, ccInfo)
    if debug_cc:
        print("static_cc_deps:  %s" % static_cc_deps)
        print("dynamic_cc_deps: %s" % dynamic_cc_deps)

    # if host = macos and mode = fastbuild, then tc injects
    # -DEBUG, which requires debug runtime

    if runtime_variant:
        args.add("-runtime-variant", runtime_variant)

    ## we put -lfoo before -Lpath/to/foo, to avoid iterating twice
    cclib_linkpaths = []
    cclib_files = []
    cc_runfiles = []

    ## NB: -cclib -lfoo is just for -custom linking!
    ## for std (non-custom) linking use -dllib

    runtime_input = []
    runfiles_root = out_exe.path + ".runfiles"
    if debug_runfiles:
        print("runfiles_root: %s" % runfiles_root)
    ws_name = ctx.workspace_name
    # print("ws name: %s" % ws_name)

    if debug_vm:
        print("VMRUNTIME: %s" % ctx.attr.vm_runtime[OCamlVmRuntimeProvider].kind)

    if tc.target == "vm":
        # print("TC.TARGET: VM")
        # vmlibs =  lib/stublibs/dll*.so, set by toolchain
        # only needed for bytecode mode, else we get errors like:
        # Error: I/O error: dllbase_internalhash_types_stubs.so: No such
        # file or directory

        # may also get e.g.
        # Fatal error: cannot load shared library dllbase_internalhash_types_stubs
        # Reason: dlopen(dllbase_internalhash_types_stubs.so, 0x000A): tried: 'dllbase_internalhash_types_stubs.so' (no such file) ... etc.

        # print("vmruntime: %s" % ctx.attr.vm_runtime)
        # if ctx.label.name == "inline_test_runner.exe":
        #     fail("asdfsfd")

        ## vmlibs == "standard" stublibs, which is where
        ## ocamlrun will look for dll<name>.so files,
        ## which may be recorded in cma/cmxa files
        ## so we always add it
        ## ideally we would inspect the cma/cmxa files
        ## and only add if needed

        vmlibs = tc.vmlibs

        ## WARNING: both -dllpath and -I are required!
        args.add("-ccopt", "-L" + tc.vmlibs[0].dirname)
        # print("vmlibs[0]: %s" % tc.vmlibs[0])
        # print("vmlibs[0] owner: %s" % tc.vmlibs[0].owner)
        # print("vmlibs path 0: %s" % tc.vmlibs[0].path)
        # print("vmlibs short 0: %s" % tc.vmlibs[0].short_path)
        # print("ctx.bin_dir: %s" % ctx.bin_dir.path)

        # print("@ocaml: %s" % Label("@@ocaml~0.0.0//version"))

        ## WARNING: vm executables built "for tool"
        ## need -custom so they can run w/o ocamlrun?
        # args.add("-custom")

        ## FIXME: shared libs only if link strategy = dynamic

        ## "At link-time, shared libraries are searched in the
        ## standard search path (the one corresponding to the -I
        ## option)."
        args.add("-I", tc.vmlibs[0].dirname)

        ## "The -dllpath option simply stores dir in
        ## the produced executable file, where ocamlrun
        ## can find it."
        ## WARNING: path must be absolute?
        ## FIXME: only for dynamic link strategy?
        ## no, it's determined by whether or not
        ## archive files have registered clibs
        args.add("-dllpath",
                 tc.vmlibs_path)
                 # "/Users/gar/.opam/510a/lib")
                 # ctx.bin_dir.path + "/" +
                 # paths.dirname(tc.vmlibs[0].short_path))

        args.add("-dllpath", tc.vmlibs[0].dirname)

        if debug_vm:
            print("{c}vm_runtime:{r} {rt}".format(
                c=CCGRN,r=CCRESET, rt = ctx.attr.vm_runtime))
            print("vm_runtime[OCamlVmRuntimeProvider: %s" %
                  ctx.attr.vm_runtime[OCamlVmRuntimeProvider])

        # if "ppx" in ctx.attr.tags or ctx.attr._rule == "ppx_executable":
            ## Currently we default to a custom runtime.
            ## See section 20.1.3 "Statically linking C code with OCaml code"
            ## https://v2.ocaml.org/manual/intfc.html#ss:staticlink-c-code
            ## and https://ocaml.org/manual/runtime.html

        # args.add("-custom")

        # ## IMPORTANT: we may depend on opam pkgs
        # ## that require -custom or dynamic linking
        # ## (i.e. their cma/cmxa lists -l<foo>)
        # for cclib in dynamic_cc_deps:
        #     args.add("-dllpath", cclib.dirname)
        #     cc_runfiles.append(cclib)
        #     args.add("-I", cclib.dirname)
        #     args.add("-ccopt", "-L" + cclib.dirname)
        #     args.add("-cclib", "-l" + cclib.basename[3:-3])
        #     # args.add("-dllib", "-l" + cclib.basename[3:-3])

        # if ctx.attr.vm_runtime[OCamlVmRuntimeProvider].kind == "dynamic":
        #     args.add("-dllib", "-lcamlrun")
        #     args.add("-ccopt",
        #              "-Lexternal/ocaml~0.0.0/runtime")
                     # "-L`ocamlc -where`")

# LINKTIME: -custom build

# LINKTIME: non -custom build
# -dllib may be recorded in cma/cmxa files; then the linker will automatically add linktime -dllib args
# ditto for -dllpath args???

# RUNTIME (non -custom build):
# names for these [dso] libraries are provided at link time as described in section 22.1.4), and recorded in the bytecode executable file; ocamlrun, then, locates these libraries and resolves references to their primitives when the bytecode executable program starts.

# The ocamlrun command searches shared libraries in the following directories, in the order indicated:
# 1. ocamlrun -I options
# 2. CAML_LD_LIBRARY_PATH
# 3. link-time -dllpaths (recorded in the bytecode executable)
# 4. ld.conf file
# 5. system dynamic loader paths

            for cclib in dynamic_cc_deps:
                # print("cclib.short_path: %s" % cclib.short_path)
                # print("cclib.dirname: %s" % cclib.dirname)

                linkpath = "%s/%s/%s" % (
                    runfiles_root, ws_name, cclib.short_path)

                # this is for build-time:
                includes.append(cclib.dirname)

                # and this is for run-time:
# Under Unix and Windows, a library named dllname.so (respectively, .dll) residing in one of the standard library directories can also be specified as -dllib -lname.
# i.e. only use -dllib for "installed" dsos

                includes.append(paths.dirname(linkpath))
                print("cclib path 1: %s" % cclib.path)
                print("cclib short 1: %s" % cclib.short_path)
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

        elif ctx.attr.vm_runtime[OCamlVmRuntimeProvider].kind == "static":
            print("XXXXXXXXXXXXXXXX STATIC")
            ## should not be any .so files???
            sincludes = []
            for dep in static_cc_deps:
                # print("STATIC DEP: %s" % dep)
                args.add("-custom")
                args.add("-ccopt", dep.path)
                includes.append(dep.dirname)
                sincludes.append("-L" + dep.dirname)

                # args.add_all(sincludes, before_each="-ccopt", uniquify=True)
                # includes.append(cclib.dirname)
                # args.add(cclib.short_path)

        ## IMPORTANT: we may depend on opam pkgs
        ## that require -custom or dynamic linking
        ## (i.e. their cma/cmxa lists -l<foo>)
        for cclib in dynamic_cc_deps:
            cc_runfiles.append(cclib)
            args.add("-I", cclib.dirname)
            ## with -custom: -cclib -lfoo
            ## otherwise, for bytecode dynlinking, shared lib
            ## must be dllfoo.so, not libfoo.so (???)

# -dllpath: Adds the directory dir to the run-time search path for shared C libraries. At link-time, shared libraries are searched in the standard search path (the one corresponding to the -I option). The -dllpath option simply stores dir in the produced executable file, where ocamlrun can find it and use it (via dlopen)

# iow, OCaml dllpath corresponds to bazel runfiles dir

            if cclib.basename.startswith("dll"):
                args.add("-dllpath", cclib.dirname)
                args.add("-dllib", "-l" + cclib.basename[3:-3])
            else:
                args.add("-ccopt", "-L" + cclib.dirname)
                args.add("-cclib", "-l" + cclib.basename[3:-3])

            ## TESTING
            args.add("-ccopt", "-Lexternal/ocaml~0.0.0")
            args.add("-dllpath", "ocaml~0.0.0")
            ## /TESTING

    else: # tc.target == sys
        # print("TC.TARGET: sys")
        vmlibs = [] ## we never need vmlibs for native code

        # print("default runtime: %s" % tc.default_runtime)
        # print("path: %s" % tc.default_runtime.path)
        # print("path: %s" % tc.default_runtime.short_path)
        # fail("STOP")
        ## NB: not enough to list as an input dep,
        ## we also must tell ocaml where it is?
        rt = tc.default_runtime.basename
        # runtime_input.append(tc.default_runtime)
        # args.add("-ccopt", "-L" + tc.default_runtime.dirname)
        # args.add("-cclib", "-l" + rt[3:][:-2])
        # cclib_files.append(tc.default_runtime.basename)

        ## this accomodates ml libs with cc deps
        ## e.g. 'base' depends on libbase_stubs.a
        for cclib in static_cc_deps:
            # print("STATIC DEP: %s" % cclib)
            cclib_files.append(cclib.path)
            # cclib_linkpaths.append("-L" + cclib.dirname)

        for cclib in dynamic_cc_deps:
            # print("DYNAMIC DEP: %s" % cclib.basename)
            # args.add("-cclib", "-l" + cclib.basename[:-3])
            cclib_linkpaths.append("-L" + cclib.dirname)


    args.add_all(cclib_linkpaths, before_each="-ccopt", uniquify=True)
    args.add_all(cclib_files, before_each="-ccopt", uniquify=True)

    # if ctx.label.name == "inline_test_runner.exe":
    #     fail("x")

    #### /end cc deps processing
    ################################################################
    includes.extend(paths_depset.to_list())

    args.add_all(includes, before_each="-I", uniquify=True)

    # for lib in cc_libs:
    #     args.add(lib.path)

    # args.add_all(paths_depset.to_list(), before_each="-I")

    # codeps_depset = depset(
    #     order = dsorder,
    #     transitive = codep_archives_secondary
    # )
    # for codep in codeps_depset.to_list():
    #     args.add(codep)

    ################################################################
    ## Archives and structs must be on the command line:
    if ctx.attr._rule == "ocaml_binary":
        ## FIXME: why? codeps only for ppx_executables?
        bin_codeps = depsets.codeps.archives # codep_archives_secondary
    else:
        bin_codeps = []

    cli_depset = depset(
        order=dsorder,
        transitive= depsets.deps.structs
    )
    # for dep in cli_depset.to_list():
    #     args.add(dep)

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

        # if tc.target == "vm":
        #     if archive.extension == "cma":
        #         args.add(archive)
        # else:
        #     if archive.extension == "cmxa":
        #         args.add(archive)

    ## free-standing struct deps (structs not archived)
    structs_depset = depset(order=dsorder,
                            transitive = depsets.deps.structs
                            + depsets.codeps.structs)
                            # direct=structs_primary,
                            # transitive=structs_secondary)

    # for struct in structs_depset.to_list():
    #     args.add(struct)

    # if hasattr(ctx.attr, "main"):
    #     for f in ctx.attr.main[DefaultInfo].files.to_list():
    #         args.add(f)

    ## cli_link_deps should include prologue, main, epilogue, in order
    cli_link_depset = depset(
        order=dsorder,
        transitive= depsets.deps.cli_link_deps
    )
    for dep in cli_link_depset.to_list():
        args.add(dep)

    # args.add(ctx.file.main)

    args.add("-o", out_exe)

    # if tc.target == "vm":
    #     # FIXME: requires that runtime and stubs files be added to cmd line
    #     # e.g. -lbase_stubs
    #     args.add("-output-complete-exe")

    # data_inputs = []
    # if ctx.attr.data:
    #     data_inputs = [depset(direct = ctx.files.data)]
    #     for f in ctx.files.data:
    #         # print("DATAFILE: %s" % f.path)
    #         args.add("-I", f.dirname)

    if hasattr(ctx.files, "main"):
        mainfile = ctx.files.main
    else:
        mainfile = []

    # print("VMLIBS: %s" % vmlibs)

    action_inputs_depset = depset(
        order=dsorder,
        direct = []
        + runtime_input
        + vmlibs
        + cc_runfiles
        + static_cc_deps
        + dynamic_cc_deps
        ,
        transitive =
        [ctx.attr.main.files]
        + depsets.deps.sigs
        + depsets.deps.structs
        + depsets.deps.ofiles
        + depsets.deps.archives
        + depsets.deps.afiles
        + depsets.deps.astructs
        + depsets.deps.cli_link_deps

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

    path = "/usr/bin:/usr"  ## FIXME
    if hasattr(ctx.attr, "diff_cmd"):
        if ctx.attr.diff_cmd:
            path = path + ":" + ctx.file.diff_cmd.dirname
    env = {"PATH": path}
    ## sweet jeebus. this is the only way I could find to merge two
    ## dicts. sheesh.
    for i in ctx.attr.env.items():
        env[i[0]] = i[1]

    # print("ENV: %s" % env)
    # print("CTX VAR: %s" % ctx.var)
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
    if debug_runfiles:
        print("runfiles attr: %s" % ctx.attr.data)
        print("runfiles files: %s" % ctx.files.data)
        print("depsets.deps.runfiles:")
        for rf in depsets.deps.runfiles:
            print("rf: %s" % rf.files)
        # for item in ctx.attr.data_prefix_map.items:
        #     print("runfiles item: %s" % item)

    rfiles = cc_runfiles # tc.vmlibs

    rfsymlinks = {}
    # map prefixes
    for f in ctx.files.data:
        if debug_runfiles:
            print("runfile: %s" % f)
        added = False
        for (k,v) in ctx.attr.data_prefix_map.items():
            if debug_runfiles:
                print("k, v: {}, {}".format(k, v))
            if f.path.startswith(k):
                if debug_runfiles:
                    print("item path: %s" % f.path)
                rf = v + f.path.removeprefix(k)
                rfsymlinks.update({rf: f})
                added = True
                break
        if not added:
            rfsymlinks.update({f: f})

    if debug_runfiles:
        print("rfsymlinks: %s" % rfsymlinks)
        # if ctx.label.name == "test.exe":
        #     fail()

    if ctx.attr.data_prefix_map:
        myrunfiles = ctx.runfiles(
            files = rfiles,
            symlinks = rfsymlinks,
            root_symlinks = rfsymlinks
        )
    else:
        myrunfiles = ctx.runfiles(
            files = rfiles + ctx.files.data
        )

    ##########################
    defaultInfo = DefaultInfo(
        executable=out_exe,
        runfiles = myrunfiles.merge_all(depsets.deps.runfiles)
    )

    exe_provider = None
    # if "ppx" in ctx.attr.tags or ctx.attr._rule in ["ppx_executable", "ppxlib_executable"]:
    #     exe_provider = PpxExecutableMarker(
    #         args = ctx.attr.args
    #     )

    if ctx.attr._rule == "ocaml_binary":
        exe_provider = OcamlExecutableMarker()
    elif ctx.attr._rule == "ocaml_test":
        exe_provider = OcamlTestMarker()
    else:
        exe_provider = OcamlExecutableMarker()

    # else:
    #     fail("Wrong rule called impl_binary: %s" % ctx.attr._rule)

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

    _ocamlProvider = OCamlProvider(
        # struct = depset(direct = [outfile]),
        cli_link_deps = depset(order=dsorder,
                               # transitive = depsets.deps.cli_link_deps
                               ),
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
                          # transitive = depsets.deps.archives
                          ),
        afiles   = depset(order="postorder",
                          # direct=afiles_primary,
                          transitive = depsets.deps.afiles),
        astructs = depset(order="postorder",
                          # direct=astructs_primary,
                          transitive = depsets.deps.astructs),
        cmts     = depsets.deps.cmts,
        # cmts     = depset(order="postorder",
        #                   # direct=cmts_primary,
        #                   transitive = depsets.deps.cmts),
        paths    = depset(order="postorder",
                          # direct=paths_primary,
                          transitive = depsets.deps.paths),
        jsoo_runtimes = depsets.deps.jsoo_runtimes # FIXME
    )
    # providers.append(_ocamlProvider)

    # print("CODEPSETS: %s" % depsets.codeps)

    ppxCodepsInfo = OCamlCodepsProvider(
        sigs       = depset(order=dsorder,
                            transitive = depsets.codeps.sigs),
        cli_link_deps = depset(order=dsorder,
                               transitive = depsets.codeps.cli_link_deps),
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
        jsoo_runtimes = depsets.deps.jsoo_runtimes
        # jsoo_runtimes = depset(order="postorder",
        #                        transitive = depsets.codeps.jsoo_runtimes),
    )
    providers.append(ppxCodepsInfo)

    providers.append(ccInfo)

    # outputGroupInfo = OutputGroupInfo(
    #     # ppx_codeps = ppx_sigs_depset,
    #     # linkset = ppx_codeps_linkset,
    #         inputs = action_inputs_depset,
    #     all = depset(transitive=[
    #         ppx_codeps_depset,
    #     ])
    # )
    # providers.append(outputGroupInfo)

        ## no OCamlProvider?

    # print("PROVIDERS: %s" % providers)

    return providers
