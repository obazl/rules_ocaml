load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlArchiveProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "PpxExecutableProvider",
     "PpxInfo",
     "PpxArchiveProvider",
     "PpxLibraryProvider",
     "PpxModuleProvider",
     "PpxNsArchiveProvider",
     "PpxNsLibraryProvider")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_functions:utils.bzl",
     "file_to_lib_name",
     "get_opamroot",
     "get_sdkpath",
)

load("//ocaml/_transitions:transitions.bzl", "ocaml_test_deps_out_transition")

load(":options.bzl", "options", "options_ppx")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl",
     "merge_deps",
     "tmpdir")

##########################
def _ocaml_test_impl(ctx):

    debug = False
    # if (ctx.label.name == "test"):
    #     debug = True

    if debug:
        print("EXECUTABLE TARGET: %s" % ctx.label.name)

    env = {"OPAMROOT": get_opamroot(),
           "PATH": get_sdkpath(ctx)}

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ################
    direct_file_deps = []
    indirect_file_depsets = []

    indirect_opam_depsets = []

    indirect_adjunct_depsets = []  # list of depsets gathered from direct deps
    indirect_adjunct_path_depsets = []
    indirect_adjunct_opam_depsets  = []  # list of depsets gathered from direct deps

    indirect_path_depsets = []

    direct_resolver = None
    indirect_resolver_depsets = []

    direct_cc_deps  = {}
    indirect_cc_deps  = {}
    ################

    includes = []

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    if ctx.attr.ppx:
        ## this will also handle ns_resolver
        out_srcfile = impl_ppx_transform(ctx.attr._rule, ctx, ctx.file.main)
        # direct_file_deps.append(ctx.file.ppx)
        # a ppx executable may have adjunct deps; they are handled by get_all_deps
    else:
        out_srcfile = ctx.file.main
    # print("OUT SRCFILE: %s" % out_srcfile)
    # if mode == "native":
    #     fname = paths.replace_extension(out_srcfile.basename, ".out")
    # else:
    #     fname = paths.replace_extension(out_srcfile.basename, ".byte")

    fname = paths.replace_extension(out_srcfile.basename, "")
    print("Test FNAME: %s" % fname)

    out_exe = ctx.actions.declare_file(fname)
    # print("OUT_EXE: %s" % out_exe)

    ################################################################
    args = ctx.actions.args()
    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

        # dynamic linking does not currently work on the mac - ocamlrun
        # wants a file named 'dllfoo.so', which rust cannot produce. to
        # support this we would need to rename the file using install_name_tool

        # see https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#ss%3Adynlink-c-code
        # if ctx.attr.linkstatic:
        args.add("-custom") # statically link cc code for ocamlrun

    for opt in ctx.attr._opts[BuildSettingInfo].value:
        # print("EXTRA OPT: %s" % opt)
        args.add(opt)
    # args.add_all(ctx.attr.opts)
    options = get_options(rule, ctx)
    args.add_all(options)

    # if ctx.attr.linkopts:
    #     # lflags = " ".join(ctx.attr.linkopts)
    #     args.add_all(ctx.attr.linkopts)

    ## deps are the same for all sources (.mli, .ml)
    ## we need to accumulate them so we can add them to the action inputs arg,
    ## in order to  register the dependency with Bazel.

    ## FIXME: work from mydeps, match against cc_alwayslink list of libs
    if hasattr(ctx.attr, "cc_linkall"):
        if debug:
            print("DEPSET CC_LINKALL: %s" % ctx.attr.cc_linkall)
        for cc_dep in ctx.files.cc_linkall:
            if cc_dep.extension == "a":
                direct_file_deps.append(cc_dep)
                path = cc_dep.path

                if tc.cc_toolchain == "clang":
                    args.add("-ccopt", "-Wl,-force_load,{path}".format(path = path))
                elif tc.cc_toolchain == "gcc":
                    libname = file_to_lib_name(cc_dep)
                    args.add("-ccopt", "-L{dir}".format(dir=cc_dep.dirname))
                    args.add("-ccopt", "-Wl,--push-state,-whole-archive")
                    args.add("-ccopt", "-l{lib}".format(lib=libname))
                    args.add("-ccopt", "-Wl,--pop-state")
                else:
                    fail("NO CC")

    # args.add("-linkpkg")  ## an ocamlfind parameter
    # print("OPAM_DEPS: %s" % mydeps.opam)
    # for dep in mydeps.opam.to_list():
    #   # print("OPAM DEP: %s" % dep)
    #   # for depdep in dep.to_list():
    #     # print("OPAM DEPDEP: %s" % depdep)
    #   args.add("-package", dep.pkg.to_list()[0].name)

    # args.add_all([dep.pkg.name for dep in mydeps.opam.to_list()], before_each="-package")
    # args.add_all([dep.pkg.to_list()[0].name for dep in mydeps.opam.to_list()], before_each="-package")

    # for debugging:
    # args.add("-absname")

    # print("NOPAM_DEPS for {bin}: {deps}".format(bin=ctx.label.name, deps=mydeps.nopam))
    # for dep in mydeps.nopam.to_list():  # ctx.attr.deps:
    #   print("################ NOPAM_DEP ################ :\n\t\t %s" % dep)
    #   # if hasattr(dep, "clib"):
    #   #   direct_file_deps = direct_file_deps + dep.clib.files.to_list()

    #   #   ##FIXME:
    #   #   # args.add("-cclib", "-lrakia")

    #   if hasattr(dep, "cmxa"):    ## composited lib
    #     # print("ARCHIVE DEP: %s" % dep)
    #     direct_file_deps.append(dep.cmxa)
    #     includes.append(dep.cmxa.dirname)

    #   if hasattr(dep, "cm"):    ## composited lib
    #     direct_file_deps.append(dep.cm)
    #     includes.append(dep.cm.dirname)
    #     args.add(dep.cm)

    dso_deps = []
    build_deps = []

    ## FIXME: transitive deps

    # The problem: the dep graph contains both cmxa and the cmx they
    # contain. we cannot add both or we get dups. Cause: maybe the way
    # ocaml_archive handles dep graph. it should not include its direct
    # deps in its direct deps depset, because they are already in the
    # cmxa payload.  But it does need to add indirect deps.

    # for dep in ctx.files.deps:
    #   if dep.extension == "cmx":
    #     includes.append(dep.dirname)
    #     build_deps.append(dep) # .basename)
    #     direct_file_deps.append(dep)

    # execroot = "/private/var/tmp/_bazel_gar/a96cd3ac87eaeba07bfd00b35d52a61a/execroot/mina"

    resolvers = []
    # for dep in ctx.attr.deps:
    #     if OpamPkgInfo in dep:
    #         fail("OPAM deps must be moved to attrib deps_opam: %s" % dep)

    #     indirect_file_depsets.append(dep[DefaultInfo].files)
    #     indirect_path_depsets.append(dep[DefaultMemo].paths)
    #     indirect_resolver_depsets.append(dep[DefaultMemo].resolvers)
    merge_deps(ctx.attr.deps,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_resolver_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    indirect_paths_depset = depset(transitive = indirect_path_depsets)
    for path in indirect_paths_depset.to_list():
        # print("TPATH %s" % path)
        includes.append(path)

    indirect_resolvers_depset = depset(transitive = indirect_resolver_depsets)
    for resolver in indirect_resolvers_depset.to_list():
        args.add("-open", resolver)

    # if ctx.attr.deps_opam:
    #     args.add("-linkpkg")
    #     for dep in ctx.attr.deps_opam:
    #         args.add("-package", dep)
    opam_depset = depset(direct = ctx.attr.deps_opam, transitive = indirect_opam_depsets)
    args.add("-linkpkg")
    for opam in opam_depset.to_list():
        args.add("-package", opam)


    #   elif dep.extension == "o":
    #       if debug:
    #           print("NOPAM .o DEP: %s" % dep)
    #       includes.append(dep.dirname)
    #       direct_file_deps.append(dep)
    #   elif dep.extension == "a":
    #       if debug:
    #           print("NOPAM .a DEP: %s" % dep)
    #       direct_file_deps.append(dep)
    #       ## FIXME: implement this:
    #       # if dep in mydeps.cc_alwayslink:
    #       #     if tc.cc_toolchain == "clang":
    #       #         args.add("-ccopt", "-Wl,-force_load,{path}".format(path = path))
    #       #     elif tc.cc_toolchain == "gcc":
    #       #         libname = file_to_lib_name(cc_dep)
    #       #         args.add("-ccopt", "-L{dir}".format(dir=cc_dep.dirname))
    #       #         args.add("-ccopt", "-Wl,--push-state,-whole-archive")
    #       #         args.add("-ccopt", "-l{lib}".format(lib=libname))
    #       #         args.add("-ccopt", "-Wl,--pop-state")
    #       # else:
    #       args.add(dep)
    #   elif dep.extension == "so":
    #       if debug:
    #           print("NOPAM .so DEP: %s" % dep)
    #       direct_file_deps.append(dep)
    #       libname = file_to_lib_name(dep)
    #       args.add("-ccopt", "-L" + dep.dirname)
    #       args.add("-cclib", "-l" + libname)
    #       # build_deps.append(dep)
    #   elif dep.extension == "dylib":
    #       if debug:
    #           print("NOPAM .dylib DEP: %s" % dep)
    #       direct_file_deps.append(dep)
    #       libname = file_to_lib_name(dep)
    #       # libname = dep.basename[:-6]
    #       # libname = libname[3:]
    #       if debug:
    #         print("LIBNAME: %s" % libname)
    #       ## -ccopt is for static linking? see chs. 8, 9, 11.3, 20 of the manual
    #       if mode == "native":
    #           args.add("-ccopt", "-L" + dep.dirname)
    #           args.add("-cclib", "-l" + libname)
    #       else:
    #           args.add("-dllpath", execroot + "/" + dep.dirname)
    #           args.add("-ccopt", "-L" + dep.dirname)
    #           # args.add("-ccopt", "-L" + execroot + "/" + dep.dirname)
    #           args.add("-cclib", "-l" + libname)
    #       # includes.append(dep.dirname)
    #       # dso_deps.append(dep)
    #   # elif dep.extension == "lo":
    #   #     if debug:
    #   #       print("NOPAM .lo DEP: %s" % dep)
    #   #     direct_file_deps.append(dep)
    #   #     args.add("-ccopt", "-L" + dep.path)
    #   #     args.add("-ccopt", "-l" + dep.path)
    #       # libname = dep.basename[:-2]
    #       # libname = libname[3:]
    #       # if debug:
    #       #   print("LIBNAME: %s" % libname)
    #       # args.add("-ccopt", "-L" + dep.dirname)
    #       # args.add("-cclib", "-l" + libname)
    #   else:
    #       if debug:
    #           print("NOMAP DEP not .cmx, cmo, cmxa, cma, cmi, .o, .lo, .so, .dylib: %s" % dep.path)

    # # if mode == "bytecode":
    # #     ## FIXME.  REALLY!!!
    # #     dllpath = ctx.attr._sdkpath[OcamlSDK].path + "/lib/stublibs"
    #     # args.add("-dllpath", dllpath)

    #     ## FIXME: for f in toolchain ocamlrun libs
    #     # for f in ctx.files._dllpaths:
    #     #     direct_file_deps.append(f)

    cclib_deps = []
    for dep in ctx.attr.cc_deps.items():
      if debug:
          print("CCLIB DEP: ")
          print(dep)
      if dep[1] == "static":
          if debug:
              print("STATIC lib: %s:" % dep[0])
          for depfile in dep[0].files.to_list():
              if (depfile.extension == "a"):
                  args.add(depfile)
                  cclib_deps.append(depfile)
                  includes.append(depfile.dirname)
      elif dep[1] == "dynamic":
          if debug:
              print("DYNAMIC lib: %s" % dep[0])
          for depfile in dep[0].files.to_list():
              print("DEPFILE: %s" % depfile)
              print("DEPFILE extension: %s" % depfile.extension)
              if (depfile.extension == "so"):
                  libname = depfile.basename[:-3]
                  print("LIBNAME: %s" % libname)
                  libname = libname[3:]
                  print("LIBNAME: %s" % libname)
                  args.add("-ccopt", "-L" + depfile.dirname)
                  args.add("-cclib", "-l" + libname)
                  cclib_deps.append(depfile)
              elif (depfile.extension == "dylib"):
                  libname = depfile.basename[:-6]
                  libname = libname[3:]
                  print("LIBNAME: %s:" % libname)
                  args.add("-cclib", "-l" + libname)
                  args.add("-ccopt", "-L" + depfile.dirname)
                  cclib_deps.append(depfile)

    # args.add_all(build_deps)

    if ctx.attr.cc_linkopts:
        args.add_all(ctx.attr.cc_linkopts, before_each="-ccopt")

    ## FIXME: optimize
    args.add_all(includes, before_each="-I", uniquify = True)
    # indirect_paths_depset = depset(transitive = indirect_path_depsets)
    # args.add_all(indirect_paths_depset.to_list(), before_each="-I")

    # deps of an executable must be enumerated on the cmd line, so OCaml
    # knows they're needed.
    # we use a depset to remove dups while preserving order.
    # for dep in depset(transitive = indirect_file_depsets).to_list():
    #     if dep.extension not in ["cmi", "mli", "o"]:
    #         args.add(dep)
    for dep in ctx.files.deps:
        # if OcamlNsEnvProvider in dep:
        #     args.add_all(dep[OcamlNsEnvProvider].resolver)

        if dep.extension not in ["cmi", "mli", "o"]:
            args.add(dep)

        # does not work: color.cmo does not depend on the submodules, they depend on it
        # if dep.basename == "Color.cmo":
        #     args.add(dep)

    # args.add_all(resolvers, before_each="-open")

    args.add("-o", out_exe)

    direct_file_deps.append(out_srcfile)
    args.add("-impl", out_srcfile)
    # direct_file_deps.append(ctx.file.main)
    # args.add(ctx.file.main)

    if ctx.attr.strip_data_prefixes:
      myrunfiles = ctx.runfiles(
        files = ctx.files.data,
        symlinks = {dfile.basename : dfile for dfile in ctx.files.data}
      )
    else:
      myrunfiles = ctx.runfiles(
        files = ctx.files.data,
      )

    direct_file_deps = direct_file_deps + cclib_deps #  srcs_ml + outs_cmi
    # print("DIRECT_FILE_DEPS: %s" % direct_file_deps)

    inputs_depset = depset(direct = direct_file_deps, transitive = indirect_file_depsets)
    # print("INPUTS_DEPSET: %s" % inputs_depset)

    # then compile implementation files and produce executable
    # if srcs_ml:
    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = inputs_depset,
        outputs = [out_exe],
        # tools = build_deps,
        progress_message = "ocaml_executable({}): compiling implementations {}".format(
            ctx.label.name, ctx.attr.message
        )
    )

    # return [DefaultInfo(executable = out_exe,
    #                     runfiles = myrunfiles)]

    return [DefaultInfo( runfiles = myrunfiles,
                        ##runfiles = ctx.runfiles(collect_data = True),
                        executable = ctx.outputs.executable)]

################################
rule_options = options("ocaml")
rule_options.update(options_ppx)

##################
ocaml_test = rule(
    implementation = _ocaml_test_impl,
    test = True,
    doc = """OCaml test rule.

**CONFIGURABLE DEFAULTS** for rule `ocaml_executable`

In addition to the [OCaml configurable defaults](#configdefs) that apply to all
`ocaml_*` rules, the following apply to this rule:

| Label | Default | `opts` attrib |
| ----- | ------- | ------- |
| @ocaml//executable:linkall | True | `-linkall`, `-no-linkall`|
| @ocaml//executable:thread | True | `-thread`, `-no-thread`|
| @ocaml//executable:warnings | `@1..3@5..28@30..39@43@46..47@49..57@61..62-40`| `-w` plus option value |

**NOTE** These do not support `:enable`, `:disable` syntax.

 See [Configurable Defaults](../ug/configdefs_doc.md) for more information.
    """,
    attrs = dict(
        rule_options,
        _linkall     = attr.label(default = "@ocaml//executable/linkall"),
        _thread     = attr.label(default = "@ocaml//executable/thread"),
        _warnings  = attr.label(default   = "@ocaml//executable:warnings"),
        _opts = attr.label(
            doc = "Hidden options.",
            default = "@ocaml//executable:opts"
        ),
        # exe_name = attr.string(
        #     doc = "Name for output executable file.  Overrides 'name' attribute."
        # ),
        _sdkpath = attr.label(
            default = Label("@ocaml//:path")
        ),
        ## EITHER src OR main
        main = attr.label(
            doc = "Label of module containing entry point of executable. This module will be placed last in the list of dependencies.",
            # providers = [[OcamlModuleProvider], [OpamPkgInfo]],
            allow_single_file = [".ml"], ## ".cmx", ".cmo", ".cma"]
            default = None
        ),
        # main = attr.label(
        #     executable = True,
        #     # mandatory = True,
        #     # allow_single_file = [".ml", ".cmx"],
        #     # providers = [PpxModuleProvider],
        #     default = None
        # ),
        data = attr.label_list(
            allow_files = True,
            doc = "Runtime dependencies: list of labels of data files needed by this executable at runtime."
        ),
        strip_data_prefixes = attr.bool(
            doc = "Symlink each data file to the basename part in the runfiles root directory. E.g. test/foo.data -> foo.data.",
            default = False
        ),
        # copts = attr.string_list(
        # ),
        # linkopts = attr.string_list(
        # ),
        # preprocessor = attr.label(
        #     doc = "Preprocessor. Must be a single PPX executable.",
        #     allow_single_file = True,
        #     providers = [PpxInfo],
        #     executable = True,
        #     cfg = "exec",
        # ),
        deps = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = [[OcamlArchiveProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsArchiveProvider],
                         [OcamlNsLibraryProvider],
                         [PpxArchiveProvider],
                         [PpxLibraryProvider],
                         [PpxModuleProvider],
                         [PpxNsArchiveProvider],
                         [PpxNsLibraryProvider],
                         [CcInfo]],
            cfg     = ocaml_test_deps_out_transition,  # outgoing
        ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
        deps_opam = attr.string_list(
            doc = "List of OPAM package names."
        ),
        cc_deps = attr.label_keyed_string_dict(
            doc = """Dictionary specifying C/C++ library dependencies. Key: a target label; value: a linkmode string, which determines which file to link. Valid linkmodes: 'default', 'static', 'dynamic', 'shared' (synonym for 'dynamic'). For more information see [CC Dependencies: Linkmode](../ug/cc_deps.md#linkmode).
            """,
            ## FIXME: cc libs could come from LSPs that do not support CcInfo, e.g. rules_rust
            # providers = [[CcInfo]]
        ),
        _cc_deps = attr.label(
            doc = "Global C/C++ library dependencies. Apply to all instances of ocaml_executable.",
            ## FIXME: cc libs could come from LSPs that do not support CcInfo, e.g. rules_rust
            # providers = [[CcInfo]]
            default = "@ocaml//executable:cc_deps"
        ),
        cc_linkall = attr.label_list(
            ## equivalent to cc_library's "alwayslink"
            doc     = "True: use `-whole-archive` (GCC toolchain) or `-force_load` (Clang toolchain). Deps in this attribute must also be listed in cc_deps.",
            # providers = [CcInfo],
        ),
        cc_linkopts = attr.string_list(
            doc = "List of C/C++ link options. E.g. `[\"-lstd++\"]`.",

        ),
        _mode = attr.label(
            default = "@ocaml//mode"
        ),
        _dllpaths = attr.label_list(
            # default = "@opam//:bin/cppo"
            default = [ # FIXME
                # "@ocaml//:base_stubs",
                # "@ocaml//:base_bigstring_stubs",
                # "@ocaml//:bin_prot_stubs",
                # "@ocaml//:core_kernel_stubs",
                # "@ocaml//:ctypes_stubs",
                # "@ocaml//:ctypes-foreign-base_stubs",
                # "@ocaml//:expect_test_collector_stubs",
                # "@ocaml//:integers_stubs",
                # "@ocaml//:time_now_stubs",
            ]
        ),
        message = attr.string(
            doc = "Deprecated"
        ),
        _rule = attr.string( default = "ocaml_test" )
    ),
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
