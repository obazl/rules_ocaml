load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlArchiveProvider",
     "OcamlModuleProvider",
     "OcamlNsLibraryProvider",
     "OcamlNsResolverProvider",
     "OcamlSignatureProvider",
     "OpamDepsProvider",
     "OcamlSDK",
     "PpxModuleProvider")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_rules/utils:rename.bzl", "rename_module")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "normalize_module_name",
     "get_opamroot",
     "get_sdkpath",
     "file_to_lib_name",
)

load(":impl_common.bzl",
     "merge_deps",
     "tmpdir")

################################################################
# def _handle_cc_deps(ctx,
#                     default_linkmode,
#                     cc_deps_dicts, ## list of dicts
#                     args,
#                     includes,
#                     cclib_deps,
#                     cc_runfiles):

#     execroot = ""

#     debug = False
#     # print("_handle_cc_deps: %s" % ctx.label)

#     for ccdict in cc_deps_dicts:
#         for [dep, linkmode] in ccdict.items():
#             if debug:
#                 print("CCLIB DEP: ")
#                 print(dep)
#                 print("CCLIB DefaultInfo: %s" % dep[DefaultInfo])
#                 print("CCLIB CcInfo: %s" % dep[CcInfo])
#             if linkmode == "default":
#                 if debug: print("DEFAULT LINKMODE: %s" % default_linkmode)
#                 for depfile in dep[DefaultInfo].files.to_list():
#                     if default_linkmode == "static":
#                         if (depfile.extension == "a"):
#                             args.add(depfile)
#                             cclib_deps.append(depfile)
#                             includes.append(depfile.dirname)
#                     else:
#                         # for depfile in dep.files.to_list():
#                         if (depfile.extension == "so"):
#                             libname = file_to_lib_name(depfile)
#                             if debug:
#                                 print("so LIBNAME: %s" % libname)
#                             args.add("-ccopt", "-L" + execroot + depfile.dirname)
#                             args.add("-cclib", "-l" + libname)
#                             cclib_deps.append(depfile)
#                         elif (depfile.extension == "dylib"):
#                             libname = file_to_lib_name(depfile)
#                             # libname = depfile.basename[:-6]
#                             # libname = libname[3:]
#                             if debug:
#                                 print("dylib LIBNAME: %s:" % libname)
#                             args.add("-cclib", "-l" + libname)
#                             args.add("-ccopt", "-L" + execroot + depfile.dirname)
#                             cclib_deps.append(depfile)
#                             cc_runfiles.append(dep)
#                         # elif (depfile.extension == "a"):
#                         #     continue
#                         # else:
#                         #     target may contain many files/dirs in addition to the binaries of interest
#             elif linkmode == "static":
#                 if debug:
#                     print("STATIC lib: %s:" % dep)
#                 for depfile in dep[DefaultInfo].files.to_list():
#                     if (depfile.extension == "a"):
#                         args.add(depfile)
#                         cclib_deps.append(depfile)
#                         includes.append(depfile.dirname)
#             elif linkmode == "static-linkall":
#                 if debug:
#                     print("STATIC LINKALL lib: %s:" % dep)
#                 for depfile in dep[DefaultInfo].files.to_list():
#                     if (depfile.extension == "a"):
#                         args.add(depfile)
#                         cclib_deps.append(depfile)
#                         includes.append(depfile.dirname)
#             elif linkmode == "dynamic":
#                 if debug:
#                     print("DYNAMIC lib: %s" % dep)
#                 for depfile in dep[DefaultInfo].files.to_list():
#                     if (depfile.extension == "so"):
#                         libname = file_to_lib_name(depfile)
#                         print("so LIBNAME: %s" % libname)
#                         args.add("-ccopt", "-L" + depfile.dirname)
#                         args.add("-cclib", "-l" + libname)
#                         cclib_deps.append(depfile)
#                     elif (depfile.extension == "dylib"):
#                         libname = file_to_lib_name(depfile)
#                         print("LIBNAME: %s:" % libname)
#                         args.add("-cclib", "-l" + libname)
#                         args.add("-ccopt", "-L" + depfile.dirname)
#                         cclib_deps.append(depfile)
#                         cc_runfiles.append(dep)

#####################
def impl_module(ctx):

    debug = False
    # if ctx.label.name in ["_Field"]: # ["_Red", "_Green", "_Blue"]:
    #     debug = True
    # if str(ctx.label) in ["//src/lib/allocation_functor:_Make"]:
        # ["remove_keys_trigger"]:
        # ["_Constraint", "_Cvar"]:

    if normalize_module_name(ctx.label.name) != normalize_module_name(ctx.file.struct.basename):
        print("Rule name: %s" % normalize_module_name(ctx.label.name))
        print("Structname: %s" % normalize_module_name(ctx.file.struct.basename))
        fail("Rule name and structfile name must yield same module name. Rule name may be prefixed with one or more underscores ('_'). Rule name: {rn}; structfile: {s}".format(rn=ctx.label.name, s=ctx.file.struct.basename))

    ns_prefix     = ctx.attr._ns_prefix[BuildSettingInfo].value
    ns_submodules = ctx.attr._ns_submodules[BuildSettingInfo].value

    if debug:
        print("")
        if ctx.attr._rule == "ocaml_module":
            print("Start: OCAMLMOD %s" % ctx.label)
        elif ctx.attr._rule == "ppx_module":
            print("Start: PPXMOD %s" % ctx.label)
        else:
            fail("Unexpected rule for 'impl_module': %s" % ctx.attr._rule)

        print("  ns_prefix: %s" % ns_prefix)

        print("  _NS_RESOLVER files: %s" % ctx.attr._ns_resolver[DefaultInfo].files.to_list())
        print("  _NS_RESOLVER paths: %s" % ctx.attr._ns_resolver[DefaultMemo].paths)
        # if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
            # print("  _NS_RESOLVER alias pfx: %s" % ctx.attr._ns_resolver[OcamlNsResolverProvider].ap)
        print("  _NS_PREFIX: %s" % ns_prefix)
        print("  _NS_SUBMODULES: %s" % ns_submodules)
        # print("  _NS_RESOLVER_SUBMODULES: %s" % ctx.attr._ns_resolver[OcamlNsResolverProvider].submodules)

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    if hasattr(ctx.attr, "ppx_tags"):
        if len(ctx.attr.ppx_tags) > 1:
            fail("Only one ppx_tag allowed currently.")

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    ## FIXME: use a build flag to pass these dirs.
    ## topdirs.cmi, digestif.cmi, ...
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

    # build_deps = []

    ################
    direct_file_deps = []
    indirect_file_depsets = [] # will be added to inputs and passed on as transitive outputs

    indirect_opam_depsets = []
    # indirect_nopam_depsets = []

    indirect_path_depsets = []

    direct_resolver = None
    indirect_resolver_depsets = []

    # direct_cc_deps    = [] # list of dicts, from the cc_deps attrib
    indirect_cc_deps  = {}

    ## adjunct deps will be passed on but not used directly by this module
    indirect_adjunct_depsets = []  # list of depsets gathered from direct deps
    indirect_adjunct_path_depsets = [] # paths for indirect_adjunct deps
    indirect_adjunct_opam_depsets  = []  # list of depsets gathered from direct deps
    ################

    link_search = []

    includes   = []
    outputs   = []
    # directs = [] # list of (output) files
    # indirects = [] # list of file depsets

    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "files"):
        ns_files_depset = ctx.attr._ns_resolver[OcamlNsResolverProvider].files
    else:
        ns_files_depset = depset()

    if ctx.attr.ppx:
        ## this will also handle ns_resolver
        out_srcfile = impl_ppx_transform(ctx.attr._rule, ctx, ctx.file.struct)
        direct_file_deps.append(ctx.file.ppx)
    elif ctx.attr.ns:  # we're hand-rolling an ns lib
        print("HANDROLLING SUBMODULE %s" % ctx.file.struct)
        out_srcfile = rename_module(ctx, ctx.file.struct) #, ctx.attr._ns_resolver)

    elif hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "prefix"):
        ## or just use ctx.attr._ns_prefix? no, resolver could be null

        ns_provider = ctx.attr._ns_resolver[OcamlNsResolverProvider]
        if len(ns_provider.submodules) > 0:
            (this_module, ext) = paths.split_extension(ctx.file.struct.basename)
            this_module = capitalize_initial_char(this_module)
            if debug:
                print("THIS_MODULE: %s" % this_module)
                print("SUBMODULES:  %s" % ns_provider.submodules)

            ## FIXME: use _ns_submodules instead of _ns_resolver[OcamlNsResolverProvider].submodules?
            if this_module in ns_provider.submodules:
                # rename this module to put it in the namespace
                out_srcfile = rename_module(ctx, ctx.file.struct) #, ctx.attr._ns_resolver)
            else:
                out_srcfile = ctx.file.struct
        else:
            out_srcfile = ctx.file.struct

    # elif ctx.attr._ns_prefix:
    #     if len(ctx.attr._ns_submodules[BuildSettingInfo].value) > 0:
    #         (this_module, ext) = paths.split_extension(ctx.file.struct.basename)
    #         this_module = capitalize_initial_char(this_module)
    #         if debug:
    #             print("THIS_MODULE: %s" % this_module)
    #             print("SUBMODULES:  %s" % ctx.attr._ns_submodules[BuildSettingInfo].value)
    #         if this_module in ctx.attr._ns_submodules[BuildSettingInfo].value:
    #             # rename this module to put it in the namespace
    #             out_srcfile = rename_module(ctx, ctx.file.struct) #, ctx.attr._ns_resolver)
    #         else:
    #             out_srcfile = ctx.file.struct
    #     else:
    #         out_srcfile = ctx.file.struct
    else:
        out_srcfile = ctx.file.struct

    scope = ""

    if debug:
        print("OUT_SRCFILE: %s" % out_srcfile)

    basename = capitalize_initial_char(out_srcfile.basename)
    if mode == "native":
        ofname = paths.replace_extension(basename, ".o")
        out_o = ctx.actions.declare_file(scope + ofname)
        outputs.append(out_o)
        fname = paths.replace_extension(basename, ".cmx")
    else:
        fname = paths.replace_extension(basename, ".cmo")

    # if ctx.attr._ns_pkg[BuildSettingInfo].value == "":
    #     scope = tmpdir
    # else:
    #     print("NS_PKG: %s" % ctx.attr._ns_pkg[BuildSettingInfo])
    #     scope = ctx.attr._ns_pkg[BuildSettingInfo].value + "/"
    # scope = tmpdir
    # (scope, ext) = paths.split_extension(ctx.file.struct.basename)
    # scope = ctx.attr._ns_prefix[BuildSettingInfo].value + "/"
    out_cm_ = ctx.actions.declare_file(scope + fname)
    outputs.append(out_cm_)
    includes.append(out_cm_.dirname)

    out_cmi = None
    out_cmt = None

    #########################
    args = ctx.actions.args()

    ## NOTE: ocamlfind automatically uses the *.opt version of the compiler.
    ## When we switch to direct invocation we will need to select it.
    if mode == "bytecode":
        args.add(tc.ocamlc.basename)
    else:
        args.add(tc.ocamlopt.basename)

    options = get_options(ctx.attr._rule, ctx)
    args.add_all(options)

    # ## we don't really need direct_cc_deps, just use ctx.attr.cc_deps
    # if ctx.attr.cc_deps:
    #     direct_cc_deps.append(ctx.attr.cc_deps)

    ## When do we want to add _ns_resolver deps?  when we need a resolver?
    if debug:
        print("NS DEP: %s" % ctx.attr._ns_resolver)
        print("NS DEP ns provider: %s" % ctx.attr._ns_resolver[OcamlNsResolverProvider])
    mydeps = ctx.attr.deps + [ctx.attr._ns_resolver]
    if debug:
        print("MERGING DEPS: %s" % mydeps)
    merge_deps(mydeps,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_resolver_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps)

    # if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "files"):
    #     # indirect_file_depsets.append(ctx.attr._ns[0][OcamlNsResolverProvider].files)
    #     indirect_file_depsets.append(ctx.attr._ns_resolver[OcamlNsResolverProvider].files)
    #     # print("NS_RESOLVER paths: %s" % ctx.attr._ns_resolver[DefaultMemo].paths)
    #     # indirect_pa

    if debug:
        print("FILE DEPSETS: %s" % indirect_file_depsets)
    # print("RULE: %s" % ctx.attr._rule)
    # print("NAME: %s" % ctx.label.name)
    # print("OPAM %s" % indirect_opam_depsets)
    # if hasattr(ctx.attr, "deps_adjunct"):
    #     print(ctx.attr.deps_adjunct)

    #     indirect_file_depsets.append(dep[DefaultInfo].files)
    #     indirect_path_depsets.append(dep[DefaultMemo].paths)
    #     indirect_resolver_depsets.append(dep[DefaultMemo].resolvers)

    #     if OpamDepsProvider in dep:
    #         indirect_opam_depsets.append(dep[OpamDepsProvider].pkgs)

    # if we have an input cmi, we will add it to our Provider output,
    # but it is not an output of the action:
    # FIXME: make cmo depend on cmi, cmi on mli
    if ctx.attr.sig:
        for f in ctx.attr.sig:
            # print("SIG: %s" % f[DefaultInfo])
            indirect_file_depsets.append(f[DefaultInfo].files)
            ## now we need to augment the search path
            # print("SIGPATH: %s" % f[DefaultMemo])
            indirect_path_depsets.append(f[DefaultMemo].paths)
        # indirect_path_depsets.append(ctx.attr.sig[DefaultMemo].paths)

        ## do NOT add incoming cmi to action outputs
        ## TODO: support compile of mli source
        # args.add("-intf", dep_mli)
        ## FIXME: support -bin-annot

    else:
      ## no sigfile provided: compiler will infer and emit .cmi from .ml src
      cmifname = paths.replace_extension(basename, ".cmi")
      out_cmi = ctx.actions.declare_file(scope + cmifname)
      outputs.append(out_cmi)

      if "-bin-annot" in ctx.attr.opts:  ## Issue #17
          ## FIXME: only do this if no cmi intf provided
          out_cmt = ctx.actions.declare_file(scope + paths.replace_extension(out_srcfile.basename, ".cmt"))
          outputs.append(out_cmt)

    indirect_paths_depset = depset(transitive = indirect_path_depsets)
    for path in indirect_paths_depset.to_list():
        # print("PATH: %s" % path)
        includes.append(path)

    indirect_resolvers_depset = depset(transitive = indirect_resolver_depsets)

    ## FIXME: we only need -open for compiling submodules
    # for resolver in indirect_resolvers_depset.to_list():
    #     args.add("-open", resolver)

    args.add_all(includes, before_each="-I", uniquify = True)

    ## now we need to add cc deps to the cmd line
    # cclib_deps  = []
    # cc_runfiles = []
    # cc_deps = direct_cc_deps + indirect_cc_deps
    # if (len(direct_cc_deps) > 0) or (len(indirect_cc_deps) > 0):
    #     print(ctx.label)
    #     if debug:
    #         if len(direct_cc_deps) > 0:
    #             print("direct CCDEPS: %s" % direct_cc_deps)
    #         if len(indirect_cc_deps) > 0:
    #             print("indirect CCDEPS: %s" % indirect_cc_deps)

    # _handle_cc_deps(ctx, tc.linkmode,
    #                 cc_deps,
    #                 args,
    #                 includes,
    #                 cclib_deps,
    #                 cc_runfiles)

    # for [dep, linkmode] in ctx.attr.cc_deps.items():
    #     print("CC DEP: {dep} : {lm}".format(dep = dep, lm = linkmode))
    #     for f in dep.files.to_list():
    #         print("CC FILE: %s" % f)
    #         indirect_cc_deps.append(dep[DefaultInfo].files)
    #         if f.extension == "a":
    #             args.add("-ccopt", "-L" + f.dirname)
    #             args.add(f)


  #   for dep in mydeps.nopam.to_list():
  #       ...
  #       elif dep.extension == "a":
  #           direct_file_deps.append(dep)
  #           link_search.append("-L" + dep.dirname)
  #           build_deps.append(dep)

  # # linkall (gcc):
  # #         "-cclib",
  # #         "-Wl,--push-state,-Bstatic",
  # #         "-cclib",
  # #         "-lmylib",
  # #         "-cclib",
  # #         "-Wl,--pop-state",

  #       elif dep.extension == "so":
  #           direct_file_deps.append(dep)
  #           link_search.append("-L" + dep.dirname)
  #           libname = file_to_lib_name(dep)
  #           cc_deps.append("-l" + libname)
  #       elif dep.extension == "dylib":
  #           direct_file_deps.append(dep)
  #           link_search.append("-L" + dep.dirname)
  #           libname = file_to_lib_name(dep)
  #           cc_deps.append("-l" + libname)
  #       elif dep.extension == ".cmxs":
  #           includes.append(dep.dirname)

    # if len(cc_deps) > 0:
    #     ## FIXME: correctly handle static v. dynamic linking in bytecode mode ('-custom' flag)
    #     if tc.linkmode == "static":
    #         if mode == "bytecode":
    #             args.add("-custom")
    #     args.add_all(link_search, before_each="-ccopt", uniquify = True)
    #     args.add_all(cc_deps, before_each="-cclib", uniquify = True)

    # args.add_all(build_deps)

    opam_depset = depset(direct = ctx.attr.deps_opam,
                         transitive = indirect_opam_depsets)
    for dep in opam_depset.to_list():
        args.add("-package", dep)  ## add dirs to search path

    ## add adjunct_deps from ppx provider
    ## adjunct deps in the dep graph are NOT compile deps of this module.
    ## only the adjunct deps of the ppx are.
    if ctx.attr.ppx:
        provider = ctx.attr.ppx[AdjunctDepsProvider]
        for nopam in provider.nopam_paths.to_list():
            args.add("-I", nopam)
        for opam in provider.opam.to_list():
            args.add("-package", opam)

    ## if ocaml_module._ns_resolver, then it may depend on something in the ns_resolver's resolver,
    ## so we need to add it to our dep graph
    ns = None
    ## ns_resolver target produces two files, module and interface
    # if ctx.attr._ns_resolver:
    #     print("NS_RESOLVER ATR: %s" % ctx.attr._ns_resolver[OcamlNsResolverProvider])
    #     print("NS_RESOLVER file: %s" % ctx.attr._ns_resolver[DefaultInfo].files)
    #     indirect_file_depsets.append(ctx.attr._ns_resolver[DefaultInfo].files)
    #     for path in ctx.attr._ns_resolver[DefaultMemo].paths.to_list():
    #         args.add("-I", path)
    #     provider = ctx.attr._ns_resolver[OcamlNsResolverProvider]
        # if provider.resolver:
        #     direct_resolver = (provider.resolver)
        #     args.add("-no-alias-deps")
        #     args.add("-open", provider.resolver)

    # testdeps = depset(order="postorder", direct = [], transitive = indirect_file_depsets)
    # for dep in testdeps.to_list():
    #     if dep.extension == "cmxa":
    #         args.add("-I", dep.dirname)
    #         args.add(dep.path)
    #         if debug:
    #             print("ARCHIVE DEP: %s" % dep.path)

    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "resolver"):
        if debug:
            print("OPENING RESOLVER: %s" % ctx.attr._ns_resolver[OcamlNsResolverProvider].resolver)
        (mod, ext) = paths.split_extension(out_srcfile.basename)
        # if debug:
        #     print("CHECKING: module in submodules? %s" % mod)
        args.add("-no-alias-deps")
        # if capitalize_initial_char(mod) in ctx.attr._ns_submodules[BuildSettingInfo].value:
        args.add("-open", ctx.attr._ns_resolver[OcamlNsResolverProvider].resolver)

    args.add("-c")

    # if mode == "bytecode":
    #     args.add("-o", out_cm_)
    # else:
    if debug:
        print("MODULE OUT: %s" % out_cm_)

    args.add("-o", out_cm_)

    args.add("-impl", out_srcfile)

    direct_file_deps.append(out_srcfile)
    # direct_file_deps.extend(direct_cc_deps)

    # here we take care of adding cc dep files to the dep graph, but not to the command line:
    cc_direct_depfiles = []
    cc_indirect_depfiles = []
    for (dep, linkmode) in ctx.attr.cc_deps.items():
        if debug:
            print("Depgraph: direct CC dep %s" % dep[DefaultInfo].files.to_list())
        cc_direct_depfiles.extend(dep[DefaultInfo].files.to_list())

    for k in indirect_cc_deps.keys():
        if debug:
            print("Depgraph: Indirect CC k %s" % k[DefaultInfo].files.to_list())
        cc_indirect_depfiles.extend(k[DefaultInfo].files.to_list())

    input_depset = depset(
        direct = direct_file_deps + cc_direct_depfiles,
        transitive = indirect_file_depsets + [
            depset(direct=cc_indirect_depfiles),
            ns_files_depset
            # ctx.attr._ns_resolver[OcamlNsResolverProvider].files
        ]
    )
    # for dep in input_depset.to_list():
    #     # print("D: %s" % dep.extension)
    #     # print("Dpath: %s" % dep.path)
    #     if dep.extension == "a":
    #         args.add(dep)
    if debug:
        print("INPUT_DEPSET: %s" % input_depset)

    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs    = input_depset,
        outputs   = outputs,
        tools = [tc.ocamlfind, tc.ocamlopt, tc.ocamlc],
        mnemonic = "OCamlModuleCompile" if ctx.attr._rule == "ocaml_module" else "PpxModuleCompile",
        progress_message = "{mode} compiling {rule}: {ws}//{pkg}:{tgt}".format(
            mode = mode,
            rule=ctx.attr._rule,
            ws  = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
            # msg = "" if not ctx.attr.msg else ": " + ctx.attr.msg
        )
    )

    # if mode == "bytecode":
    #     directs.append(out_cm_)
    # elif mode == "native":
    #     directs.append(out_cm_)
    #     directs.append(out_o)

    # if dep_mli:
    #     directs.append(dep_mli)
    # directs.append(out_cmi)
    # if out_cmt:
    #     directs.append(out_cmt)

    # if ctx.attr._ns_resolver:
    #     for dep in ctx.files._ns_resolver:
    #         indirects.append(dep)

    search_paths = sets.to_list(sets.make(includes))  ## uniqify

    if debug:
        print("OUTPUTS: %s" % outputs)

    defaultInfo = DefaultInfo(
        files = depset(
            order = "postorder",
            direct = outputs, # directs,
            transitive = indirect_file_depsets
        ),
    )

    defaultMemo = DefaultMemo(
        paths     = depset(direct = search_paths, transitive = [indirect_paths_depset]),
        ## FIXME: pass resolvers using OcamlNsResolverProvider
        resolvers = depset(direct = [direct_resolver] if direct_resolver else [],
                           transitive = [indirect_resolvers_depset]),
    )
    if debug:
        print("MPATHS %s" % defaultMemo.paths)

    if ctx.attr._rule == "ocaml_module":
        moduleProvider = OcamlModuleProvider(
            name      = capitalize_initial_char(paths.split_extension(out_cm_.basename)[0]),
            module    = out_cm_,
        )
    elif ctx.attr._rule == "ppx_module":
        moduleProvider = PpxModuleProvider(
            name      = capitalize_initial_char(paths.split_extension(out_cm_.basename)[0]),
            module    = out_cm_,
        )

    # deps_opam = depset(direct = ctx.attr.deps_opam, transitive = indirect_opam_depsets)
    opamProvider = OpamDepsProvider(
        pkgs = opam_depset
    )
    # print("OPAM_PROVIDER: %s" % opam_provider)

    adjunctsProvider = AdjunctDepsProvider(
        opam        = depset(transitive = indirect_adjunct_opam_depsets),
        nopam       = depset(transitive = indirect_adjunct_depsets),
        nopam_paths = depset(transitive = indirect_adjunct_path_depsets)
    )

    # deps_cc = depset(direct = direct_cc_deps, transitive = indirect_cc_deps)
    ## FIXME: catch incompatible key dups
    cclibs = {}
    cclibs.update(ctx.attr.cc_deps)
    if len(indirect_cc_deps) > 0:
        if debug:
            print("cc deps for %s" % ctx.label)
            print(indirect_cc_deps)
        cclibs.update(indirect_cc_deps)
    ccProvider = CcDepsProvider(
        ## WARNING: cc deps must be passed as a dictionary, not a file depset!!!
        libs = cclibs

    )
    if debug:
        print(ctx.label)
        print("CcDepsProvider: %s" % ccProvider)

    # print("DEFAULT: %s" % defaultInfo)
    # if ctx.label.name == "_Template":
    #     print("MODULE PROVIDER: %s" % module_provider)

    # if ctx.attr._ns_resolver == none then omit OcamlNsResolverProvider from result

    return [
        defaultInfo,
        defaultMemo,
        moduleProvider,
        # ctx.attr._ns_resolver[OcamlNsResolverProvider], # ns resolvers
        opamProvider,
        adjunctsProvider,
        ccProvider
    ]
