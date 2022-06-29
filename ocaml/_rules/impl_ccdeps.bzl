load("@bazel_skylib//lib:dicts.bzl", "dicts")
# load("//ocaml:providers.bzl", "CcDepsProvider")

load("//ocaml/_functions:module_naming.bzl", "file_to_lib_name")

load("@rules_ocaml//ocaml/_debug:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCMAG", "CCRESET")

## see: https://github.com/bazelbuild/bazel/blob/master/src/main/starlark/builtins_bzl/common/cc/cc_import.bzl

## does this still apply?
# "Library outputs of cc_library shouldn't be relied on, and should be considered as a implementation detail and are toolchain dependent (e.g. if you're using gold linker, we don't produce .a libs at all and use lib-groups instead, also linkstatic=0 on cc_test is something that might change in the future). Ideally you should wait for cc_shared_library (https://docs.google.com/document/d/1d4SPgVX-OTCiEK_l24DNWiFlT14XS5ZxD7XhttFbvrI/edit#heading=h.jwrigiapdkr2) or use cc_binary(name="libfoo.so", linkshared=1) with the hack you mentioned in the meantime. The actual location of shared library dependencies should be available from Skyalrk. Eventually."
## src: https://github.com/bazelbuild/bazel/issues/4218

## DefaultInfo.files will be empty for cc_import deps, so in
## that case use CcInfo.

## For cc_library, DefaultInfo.files will contain the
## generated files (usually .a, .so, unless linkstatic is set)

## At the end we'll have one CcInfo whose entire depset will go
## on cmd line. This includes indirect deps like the .a files
## in @//ocaml/c/lib and @ctypes//:ctypes

#########################
def dump_library_to_link(ctx, idx, lib):
    print("dump_library_to_link")
    print("  alwayslink[{i}]: {al}".format(i=idx, al = lib.alwayslink))
    flds = ["static_library",
            "pic_static_library",
            "interface_library",
            "dynamic_library",]
    for fld in flds:
        if hasattr(lib, fld):
            if getattr(lib, fld):
                print("  lib[{i}].{f}: {p}".format(
                    i=idx, f=fld, p=getattr(lib,fld).path))
            else:
                print("  lib[{i}].{f} == None".format(i=idx, f=fld))

    # if lib.dynamic_library:
    #     print(" lib[{i}].dynamic_library: {lib}".format(
    #         i=idx, lib=lib.dynamic_library.path))
    # else:
    #     print(" lib[{i}].dynamic_library == None".format(i=idx))

#########################
def dump_CcInfo(ctx, cc_info): # dep):
    # print("DUMP_CCINFO for %s" % ctx.label)
    # print("CcInfo dep: {d}".format(d = dep))

    # dfiles = dep[DefaultInfo].files.to_list()
    # if len(dfiles) > 0:

        # for f in dfiles:
        #     print("  %s" % f)

        ## ASSUMPTION: all files in DefaultInfo are also in CcInfo
        # print("dep[CcInfo].linking_context:")
        # cc_info = dep[CcInfo]
        compilation_ctx = cc_info.compilation_context
        linking_ctx     = cc_info.linking_context
        linker_inputs = linking_ctx.linker_inputs.to_list()
        # print("linker_inputs count: %s" % len(linker_inputs))
        lidx = 0
        for linput in linker_inputs:
            # print(" linker_input[{i}]".format(i=lidx))
            # print(" linkflags[{i}]: {f}".format(i=lidx, f= linput.user_link_flags))
            libs = linput.libraries
            # print(" libs count: %s" % len(libs))
            if len(libs) > 0:
                i = 0
                for lib in linput.libraries:
                    dump_library_to_link(ctx, i, lib)
                    i = i+1
            lidx = lidx + 1

    # else:
    #     for dep in dfiles:
    #         print(" Default f: %s" % dep)

################################################################
def lib_to_string(ctx, idx, lib):
    text = "  alwayslink[{i}]: {al}\n".format(i=idx, al = lib.alwayslink)
    flds = ["static_library",
            "pic_static_library",
            "interface_library",
            "dynamic_library",]
    for fld in flds:
        if hasattr(lib, fld):
            if getattr(lib, fld):
                text = text + "  lib[{i}].{f}: {c}{p}{noc}\n".format(
                    c=CCMAG, noc=CCRESET,
                    i=idx, f=fld, p=getattr(lib,fld).path)
            else:
                text = text + "  lib[{i}].{f} == None\n".format(i=idx, f=fld)
    return text

################
def ccinfo_to_string(ctx, cc_info):
    # print("DUMP_CCINFO for %s" % ctx.label)
    text = ""
    compilation_ctx = cc_info.compilation_context
    linking_ctx     = cc_info.linking_context
    linker_inputs = linking_ctx.linker_inputs.to_list()
    # print("linker_inputs count: %s" % len(linker_inputs))
    lidx = 0
    for linput in linker_inputs:
        # print(" linker_input[{i}]".format(i=lidx))
        # print(" linkflags[{i}]: {f}".format(i=lidx, f= linput.user_link_flags))
        libs = linput.libraries
        # print(" libs count: %s" % len(libs))
        if len(libs) > 0:
            i = 0
            for lib in linput.libraries:
                text = text + lib_to_string(ctx, i, lib)
                i = i+1
        lidx = lidx + 1
    return text

################################################################
## Extract all cc libs from merged CcInfo provider
## to be called from {ocaml,ppx}_executable
## tasks:
##     - construct args
##     - construct inputs_depset
##     - extract runfiles
def extract_cclibs(ctx,
                   default_linkmode, # platform default
                   args,
                   ccInfo):
    # print("link_ccdeps %s" % ctx.label)

    static_libs        = []
    dynamic_libs       = []
    # action_inputs_list = []
    # runfiles    = []

    compilation_ctx = ccInfo.compilation_context
    linking_ctx     = ccInfo.linking_context
    linker_inputs = linking_ctx.linker_inputs.to_list()
    # print("LINKER_INPUTS: %s" % linker_inputs)
    for linput in linker_inputs:
        libs = linput.libraries
        if len(libs) > 0:
            for lib in libs:
                # print("LIB: %s" % lib)
                if lib.pic_static_library:
                    # print("PIC static: %s" % lib.pic_static_library)
                    static_libs.append(lib.pic_static_library)
                    # action_inputs_list.append(lib.pic_static_library)
                    # args.add(lib.pic_static_library.path)
                if lib.static_library:
                    # print("static: %s" % lib.static_library)
                    static_libs.append(lib.static_library)
                    # action_inputs_list.append(lib.static_library)
                    # args.add(lib.static_library.path)
                if lib.dynamic_library:
                    # print("dynamic: %s" % lib.dynamic_library)
                    dynamic_libs.append(lib.dynamic_library)
                    # action_inputs_list.append(lib.dynamic_library)
                    # args.add("-ccopt", "-L" + lib.dynamic_library.dirname)
                    # args.add("-cclib", lib.dynamic_library.path)

    # print("static_libs: %s" % static_libs)
    return [static_libs, dynamic_libs]

################################################################
def x(ctx,
      cc_deps_dict,
      default_linkmode,
      args,
      includes,
      cclib_deps,
      cc_runfiles):
    dfiles = dep[DefaultInfo].files.to_list()
    # print("dep[DefaultInfo].files count: %s" % len(dfiles))
    if len(dfiles) > 0:
        for f in dfiles:
            print("  %s" % f)
        # print("dep[CcInfo].linking_context:")
        cc_info = dep[CcInfo]
        compilation_ctx = cc_info.compilation_context
        linking_ctx     = cc_info.linking_context
        linker_inputs = linking_ctx.linker_inputs.to_list()
        # print("linker_inputs count: %s" % len(linker_inputs))
        # for linput in linker_inputs:
            # print("NEW LINKER_INPUT")
            # print(" LINKFLAGS: %s" % linput.user_link_flags)
            # print(" LINKLIB[0]: %s" % linput.libraries[0].static_library.path)

            ## ?filter on prefix for e.g. csdk: example/ocaml
            # for lib in linput.libraries:
            #     print(" LINKLIB: %s" % lib.static_library.path)
    # else:
    #     for dep in dfiles:
    #         print(" Default f: %s" % dep)


    ## FIXME: static v. dynamic linking of cc libs in bytecode mode
    # see https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#ss%3Adynlink-c-code

    # default linkmode for toolchain is determined by platform
    # see @rules_ocaml//cfg/toolchain:BUILD.bazel, ocaml/_toolchains/*.bzl
    # dynamic linking does not currently work on the mac - ocamlrun
    # wants a file named 'dllfoo.so', which rust cannot produce. to
    # support this we would need to rename the file using install_name_tool
    # for macos linkmode is dynamic, so we need to override this for bytecode mode

    debug = False
    # if ctx.attr._rule == "ocaml_binary":
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
                    if ctx.toolchains["@rules_ocaml//toolchain:type"].cc_toolchain == "clang":
                        args.add("-ccopt", "-Wl,-force_load,{path}".format(path = depfile.path))
                    elif ctx.toolchains["@rules_ocaml//toolchain:type"].cc_toolchain == "gcc":
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

################################################################
## returns:
##   depset to be added to action_inputs
##   updated args
##   a CcDepsProvider containing cclibs dictionary {dep: linkmode}
##   a depset containing ccdeps files, for OutputGroups
##   FIXME: what about cc_runfiles?
# def handle_ccdeps(ctx,
#                     # for_pack,
#                     default_linkmode, # in
#                     # cc_deps_dict, ## list of dicts
#                     args, ## in/out
#                     # includes,
#                     # cclib_deps,
#                     # cc_runfiles):
#                   ):
#     debug = False
#     ## steps:
#     ##   1. accumulate all ccdep dictionaries = direct + indirect
#     ##      a. remove duplicate dict entries?
#     ##   2. construct action_inputs list
#     ##   3. derive cmd line args
#     ##   4. construct CcDepsProvider

#     # 1. accumulate
#     #    a. direct cc deps
#     direct_ccdeps_maps_list = []
#     if hasattr(ctx.attr, "cc_deps"):
#         direct_ccdeps_maps_list = [ctx.attr.cc_deps]

#     ## FIXME: ctx.attr._cc_deps is a label_flag attr, cannot be a dict
#     # all_ccdeps_maps_list.update(ctx.attr._cc_deps)

#     # print("CCDEPS DIRECT: %s" % direct_ccdeps_maps_list)

#     #    b. indirect cc deps
#     all_deps = []
#     if hasattr(ctx.attr, "deps"):
#         all_deps.extend(ctx.attr.deps)
#     if hasattr(ctx.attr, "_deps"):
#         all_deps.append(ctx.attr._deps)
#     if hasattr(ctx.attr, "deps_deferred"):
#         all_deps.extend(ctx.attr.deps_deferred)
#     if hasattr(ctx.attr, "sig"):
#         all_deps.append(ctx.attr.sig)

#     ## for ocaml_library
#     if hasattr(ctx.attr, "modules"):
#         all_deps.extend(ctx.attr.modules)
#     ## for ocaml_ns_library
#     if hasattr(ctx.attr, "submodules"):
#         all_deps.extend(ctx.attr.submodules)
#     ## [ocaml/ppx]_executable
#     if hasattr(ctx.attr, "main"):
#         all_deps.append(ctx.attr.main)

#     indirect_ccdeps_maps_list = []
#     for dep in all_deps:
#         if None == dep: continue # e.g. attr.sig may be missing
#         if CcDepsProvider in dep:
#             if dep[CcDepsProvider].ccdeps_map: # skip empty maps
#                 indirect_ccdeps_maps_list.append(dep[CcDepsProvider].ccdeps_map)
#     # print("CCDEPS INDIRECT: %s" % indirect_ccdeps_maps_list)

#     ## depsets cannot contain dictionaries so we use a list
#     all_ccdeps_maps_list = direct_ccdeps_maps_list + indirect_ccdeps_maps_list
#     ## now merge the maps and remove duplicate entries
#     all_ccdeps_map = {} # merged ccdeps maps
#     for ccdeps_map in all_ccdeps_maps_list:
#         # print("CCDEPS_MAP ITEM: %s" % ccdeps_map)
#         for [ccdep, cclinkmode] in ccdeps_map.items():
#             if ccdep in all_ccdeps_map:
#                 if cclinkmode == all_ccdeps_map[ccdep]:
#                     ## duplicate
#                     # print("Removing duplicate ccdep: {k}: {v}".format(
#                     #     k = ccdep, v = cclinkmode
#                     # ))
#                     continue
#                 else:
#                     # duplicate key, different linkmode
#                     fail("CCDEP: duplicate dep {dep} with different linkmodes: {lm1}, {lm2}".format(
#                         dep = dep,
#                         lm1 = all_ccdeps_map[ccdep],
#                         lm2 = cclinkmode
#                     ))
#             else:
#                 ## accum
#                 all_ccdeps_map.update({ccdep: cclinkmode})
#     ## end: accumulate
#     # print("ALLCCDEPS: %s" % all_ccdeps_map)
#     # print("ALLCCDEPS KEYS: %s" % all_ccdeps_map.keys())

#     # 2. derive action inputs
#     action_inputs_ccdep_filelist = []
#     for tgt in all_ccdeps_map.keys():
#         action_inputs_ccdep_filelist.extend(tgt.files.to_list())
#     # print("ACTION_INPUTS_ccdep_filelist: %s" % action_inputs_ccdep_filelist)
#     ## 3. derive cmd line args

#     ## FIXME: static v. dynamic linking of cc libs in bytecode mode
#     # see https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#ss%3Adynlink-c-code

#     # default linkmode for toolchain is determined by platform
#     # see @rules_ocaml//cfg/toolchain:BUILD.bazel, ocaml/_toolchains/*.bzl
#     # dynamic linking does not currently work on the mac - ocamlrun
#     # wants a file named 'dllfoo.so', which rust cannot produce. to
#     # support this we would need to rename the file using install_name_tool
#     # for macos linkmode is dynamic, so we need to override this for bytecode mode

#     cc_runfiles = [] # FIXME?

#     debug = True

#     ## FIXME: always pass -fvisibility=hidden? see https://stackoverflow.com/questions/9894961/strange-warnings-from-the-linker-ld

#     for [dep, linkmode] in all_ccdeps_map.items():
#         if debug:
#             print("CCLIB DEP: ")
#             print(dep)
#             for f in dep.files.to_list():
#                 print("  f: %s" % f)
#             if CcInfo in dep:
#                 print(" CcInfo: %s" % dep[CcInfo])

#         if linkmode == "default":
#             if debug: print("DEFAULT LINKMODE: %s" % default_linkmode)
#             for depfile in dep.files.to_list():
#                 if default_linkmode == "static":
#                     if (depfile.extension == "a"):
#                         args.add(depfile)
#                         # cclib_deps.append(depfile)
#                         # includes.append(depfile.dirname)
#                 else:
#                     for depfile in dep.files.to_list():
#                         if debug:
#                             print("DEPFILE dir: %s" % depfile.dirname)
#                             print("DEPFILE path: %s" % depfile.path)
#                         if (depfile.extension == "so"):
#                             libname = file_to_lib_name(depfile)
#                             args.add("-ccopt", "-L" + depfile.dirname)
#                             args.add("-cclib", "-l" + libname)
#                             # cclib_deps.append(depfile)
#                         elif (depfile.extension == "dylib"):
#                             libname = file_to_lib_name(depfile)
#                             args.add("-cclib", "-l" + libname)
#                             args.add("-ccopt", "-L" + depfile.dirname)
#                             # cclib_deps.append(depfile)
#                             cc_runfiles.append(dep.files)
#         elif linkmode == "static":
#             if debug:
#                 print("STATIC LINK: %s:" % dep)
#                 lctx = dep[CcInfo].linking_context
#                 for linputs in  lctx.linker_inputs.to_list():
#                     for lib in linputs.libraries:
#                         print(" LINKLIB: %s" % lib.static_library)

#             for depfile in dep.files.to_list():
#                 if debug:
#                     print(" LIB: %s" % depfile)
#                     fail("xxxx")
#                 if (depfile.extension == "a"):
#                     # for .a files we do not need --cclib etc. just
#                     # add directly to command line:
#                     args.add(depfile)
#         elif linkmode == "static-linkall":
#             if debug:
#                 print("STATIC LINKALL lib: %s:" % dep)
#             for depfile in dep.files.to_list():
#                 if (depfile.extension == "a"):
#                     # cclib_deps.append(depfile)
#                     # includes.append(depfile.dirname)
#                     if ctx.toolchains["@rules_ocaml//toolchain:type"].cc_toolchain == "clang":
#                         args.add("-ccopt", "-Wl,-force_load,{path}".format(path = depfile.path))
#                     elif ctx.toolchains["@rules_ocaml//toolchain:type"].cc_toolchain == "gcc":
#                         libname = file_to_lib_name(depfile)
#                         args.add("-ccopt", "-L{dir}".format(dir=depfile.dirname))
#                         args.add("-ccopt", "-Wl,--push-state,-whole-archive")
#                         args.add("-ccopt", "-l{lib}".format(lib=libname))
#                         args.add("-ccopt", "-Wl,--pop-state")
#                     else:
#                         fail("NO CC")

#         elif linkmode == "dynamic":
#             if debug:
#                 print("DYNAMIC lib: %s" % dep)
#             for depfile in dep.files.to_list():
#                 if (depfile.extension == "so"):
#                     libname = file_to_lib_name(depfile)
#                     if debug:
#                         print("so LIBNAME: %s" % libname)
#                         print("so dir: %s" % depfile.dirname)
#                     args.add("-ccopt", "-L" + depfile.dirname)
#                     args.add("-cclib", "-l" + libname)
#                     # cclib_deps.append(depfile)
#                 elif (depfile.extension == "dylib"):
#                     libname = file_to_lib_name(depfile)
#                     if debug:
#                         print("LIBNAME: %s:" % libname)
#                     args.add("-cclib", "-l" + libname)
#                     args.add("-ccopt", "-L" + depfile.dirname)
#                     # cclib_deps.append(depfile)
#                     cc_runfiles.append(dep.files)
#     ## end: derive cmd options

#     ## now derive CcDepsProvider:

#     # for OutputGroups: use action_inputs_ccdep_filelist
#     ccDepsProvider = CcDepsProvider(
#         ccdeps_map = all_ccdeps_map
#     )

#     return [action_inputs_ccdep_filelist, ccDepsProvider]

