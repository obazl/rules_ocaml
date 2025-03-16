load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

load("@bazel_skylib//lib:dicts.bzl", "dicts")

# load("//build:providers.bzl", "CcDepsProvider")
load("//build:providers.bzl", "OCamlRuntimeProvider")

load("//build/_lib:module_naming.bzl", "file_to_lib_name")

load("@rules_ocaml//lib:colors.bzl",
     "CCRED", "CCGRN", "CCBLU", "CCBLURED", "CCMAG", "CCYEL", "CCRESET")

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
    print("{c}dump_CcInfo for {lbl}{r}".format(c=CCBLURED,lbl=ctx.label,r=CCRESET))
    # print("DUMP_CCINFO for %s" % ctx.label)
    # print("CcInfo dep: {d}".format(d = dep))

    # dfiles = dep[DefaultInfo].files.to_list()
    # if len(dfiles) > 0:

    # for f in dfiles:
    #     print("  %s" % f)

    dump_compilation_context(cc_info)

    ## ASSUMPTION: all files in DefaultInfo are also in CcInfo
    # print("dep[CcInfo].linking_context:")
    # cc_info = dep[CcInfo]
    # compilation_ctx = cc_info.compilation_context

    print("{c}dumping linking_context{r}".format(c=CCRED,r=CCRESET))
    linking_ctx     = cc_info.linking_context
    linker_inputs = linking_ctx.linker_inputs.to_list()
    print("linker_inputs count: %s" % len(linker_inputs))
    lidx = 0
    for linput in linker_inputs:
        print(" linker_input[{i}]".format(i=lidx))
        print(" linkflags[{i}]: {f}".format(i=lidx, f= linput.user_link_flags))
        libs = linput.libraries
        print(" libs count: %s" % len(libs))
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
lib_to_link_private_methods = [
    "disable_whole_archive",
    "library_identifier",
    "lto_compilation_context",
    "must_keep_debug",
    "objects_private",
    "pic_lto_compilation_context",
    "pic_objects_private",
    "pic_shared_non_lto_backends",
    "shared_non_lto_backends"
]
def lib_to_string(ctx, i, j, lib):
    text = "\n"

    # flds = ["static_library",
    #         "pic_static_library",
    #         "interface_library",
    #         "dynamic_library",]
    for fld in dir(lib):
        if getattr(lib, fld):
            if fld not in lib_to_link_private_methods:
                text = text + "  lib[{i}][{j}].{f}: {c}{p}{noc}\n".format(
                    c=CCMAG, noc=CCRESET,
                    i=i, j=j, f=fld, p=getattr(lib,fld)) # .path)
        # else:
        #     text = text + "  lib[{i}][{j}].{f} == None\n".format(
        #         i=i, j=j, f=fld)
    return text

################
def ccinfo_to_string(ctx, cc_info):
    debug = False
    if debug: print("CCINFO_TO_STRING for %s" % ctx.label)
    if debug: print(CCYEL + "ccinfo: %s" % cc_info)

    text = ""
    compilation_ctx = cc_info.compilation_context
    if debug:
        print(CCYEL + "compilation_ctx: %s" % compilation_ctx)
        print("direct hdrs: %s" % compilation_ctx.direct_headers)
        # print("hdrs: %s" % compilation_ctx.headers)
        print("defines: %s" % compilation_ctx.defines)
        print("local defs: %s" % compilation_ctx.local_defines)
    linking_ctx     = cc_info.linking_context
    if debug: print(CCYEL + "linking_ctx: %s" % dir(linking_ctx))
    linker_inputs = linking_ctx.linker_inputs.to_list()
    if debug: print(CCYEL + "linker_inputs count: %s" % len(linker_inputs))
    if debug: print(CCYEL + "linker_inputs: %s" % linker_inputs)
    if debug: print(CCYEL + "linker_inputs: %s" % dir(linker_inputs))
    lidx = 0
    for linput in linker_inputs:
        if debug: print(CCYEL + " linker_input[{i}]: %s" %linput)
        if debug: print(CCYEL + " linker_input[{i}] flds: {li}".format(i=lidx, li=dir(linput)))
        if debug: print(CCYEL + " linkflags[{i}]: {f}".format(i=lidx, f= linput.user_link_flags))
        libs = linput.libraries
        if debug: print(CCYEL + " libs count: %s" % len(libs))
        if len(libs) > 0:
            j = 0
            for lib in libs:  # linput.libraries:
                if debug: print(CCYEL + " lib[{j}]: %s" % lib)
                if debug: print(CCYEL + " lib[{j}] dir: {l}".format(
                    j=j, l=dir(lib)))
                text = text + lib_to_string(ctx, lidx, j, lib)
                j = j+1
        lidx = lidx + 1
    return text

################
# CcSharedLibraryInfo:
# "dynamic_deps": "All shared libraries depended on transitively",
# "exports": "cc_libraries that are linked statically and exported",
# "link_once_static_libs": "All libraries linked statically into this library that should " +
#        "only be linked once, e.g. because they have static " +
#        "initializers. If we try to link them more than once, " +
#        "we will throw an error",
# "linker_input": "the resulting linker input artifact for the shared library",

def ccsharedlibinfo_to_string(ctx, cc_sharedlib_info):
    debug = True
    if debug: print("\nCCSHAREDLIBINFO_TO_STRING for %s" % ctx.label)
    if debug: print(CCYEL + "\nccsharedlibinfo: %s" % cc_sharedlib_info)

    text = ""
    text = text + "dynamic deps:\n"
    for lib in cc_sharedlib_info.dynamic_deps.to_list():
        text = text + "\t" + lib + "\n"
    text = text + "exports:\n"
    for lib in cc_sharedlib_info.exports:
        text = text + "\t" + lib + "\n"
    text = text + "link_once_static_libs:\n"
    for lib in cc_sharedlib_info.link_once_static_libs:
        text = text + "\t" + lib + "\n"

    linker_input     = cc_sharedlib_info.linker_input
    text = text + "linker_input:\n"
    text = text + "\tadditional_inputs: %s\n" % linker_input.additional_inputs
    text = text + "\tlibraries (LibraryToLink):"
    libs = linker_input.libraries
    if debug: print(CCYEL + " libs count: %s" % len(libs))
    if len(libs) > 0:
        j = 0
        for lib in libs:
            if debug: print(CCYEL + " lib[{j}]: %s" % lib)
            if debug: print(CCYEL + " lib[{j}] dir: {l}".format(
                j=j, l=dir(lib)))
            text = text + lib_to_string(ctx, 0, j, lib)
            j = j+1

    text = text + "\tlinkstamps: %s\n" % linker_input.linkstamps
    text = text + "\towner: %s\n" % linker_input.owner
    text = text + "\tuser_link_flags: %s\n" % linker_input.user_link_flags

    # lidx = 0
    # for linput in linker_inputs:
    #     if debug: print(CCYEL + " linker_input[{i}]: %s" %linput)
    #     if debug: print(CCYEL + " linker_input[{i}] flds: {li}".format(i=lidx, li=dir(linput)))
    #     if debug: print(CCYEL + " linkflags[{i}]: {f}".format(i=lidx, f= linput.user_link_flags))
    #     libs = linput.libraries
    #     if debug: print(CCYEL + " libs count: %s" % len(libs))
    #     if len(libs) > 0:
    #         j = 0
    #         for lib in libs:  # linput.libraries:
    #             if debug: print(CCYEL + " lib[{j}]: %s" % lib)
    #             if debug: print(CCYEL + " lib[{j}] dir: {l}".format(
    #                 j=j, l=dir(lib)))
    #             text = text + lib_to_string(ctx, lidx, j, lib)
    #             j = j+1
    #     lidx = lidx + 1
    return text

################################################################
## Extract all cc libs from merged CcInfo provider
## to be called from {ocaml,ppx}_executable
## tasks:
##     - construct args  (OBSOLETE?)
##     - construct inputs_depset
##     - extract runfiles
def extract_cclibs(ctx,
                   # default_linkmode, # platform default
                   # args,
                   ccInfo):
    # print("link_ccdeps %s" % ctx.label)

    static_libs        = []
    dynamic_libs       = []
    # action_inputs_list = []
    # runfiles    = []

    compilation_ctx = ccInfo.compilation_context
    ## In case user has built a cc lib with env var
    ## RUNTIME_VARIANT_DEBUG etc.
    ## I can't find a ref to this in the manual
    ## so I'm disabling it. It doesn't make much
    ## sense anyway for a lib. Runtimes are for executables.
    # runtime_variant = None
    # if compilation_ctx.defines:
    #     defns = compilation_ctx.defines.to_list()
    #     if "RUNTIME_VARIANT_DEBUG" in defns:
    #         runtime_variant = "d"
    #     elif "RUNTIME_VARIANT_INSTRUMENTED" in defns:
    #         runtime_variant = "i"

    linking_ctx     = ccInfo.linking_context
    linker_inputs = linking_ctx.linker_inputs.to_list()
    # print("LINKER_INPUTS: %s" % linker_inputs)
    for linput in linker_inputs:
        libs = linput.libraries
        if len(libs) > 0:

            # if lib contains both .a and .so, consult linkmode to choose

            ##FIXME: what about interface_library and
            ##resolved_symlink_interface_library?

            ## FIXME: what about lto_bitcode_files, pic_lto_bitcode_files?
            for lib in libs:
                # on linux, cc_library may produce both .a and .so files
                # on macos, only one is produced
                if lib.static_library:
                    static_libs.append(lib.static_library)
                if lib.resolved_symlink_dynamic_library:
                    dynamic_libs.append(lib.resolved_symlink_dynamic_library)
                elif lib.dynamic_library:
                    dynamic_libs.append(lib.dynamic_library)
                if lib.pic_static_library:
                    static_libs.append(lib.pic_static_library)
                # if lib.static_library:
                #     static_libs.append(lib.static_library)
                # if lib.resolved_symlink_dynamic_library:
                #     dynamic_libs.append(lib.resolved_symlink_dynamic_library)
                # elif lib.dynamic_library:
                #     dynamic_libs.append(lib.dynamic_library)

                # if lib.static_library and lib.dynamic_library:
                #     if ctx.attr.vm_runtime[OCamlRuntimeProvider].kind == "static":
                #     # if ctx.attr.cc_linkage == "static":
                #     # if default_linkmode == "static":
                #         ## FIXME: what about pic_static_library?
                #         static_libs.append(lib.static_library)
                #     else:
                #         if lib.resolved_symlink_dynamic_library:
                #             dynamic_libs.append(lib.resolved_symlink_dynamic_library)
                #         elif lib.dynamic_library:
                #             dynamic_libs.append(lib.dynamic_library)
                # else:
                #     if lib.pic_static_library:
                #         static_libs.append(lib.pic_static_library)
                #     if lib.static_library:
                #         static_libs.append(lib.static_library)
                #     if lib.resolved_symlink_dynamic_library:
                #         dynamic_libs.append(lib.resolved_symlink_dynamic_library)
                #     elif lib.dynamic_library:
                #         dynamic_libs.append(lib.dynamic_library)

    # print("static_libs: %s" % static_libs)
    return [static_libs, dynamic_libs] #, runtime_variant]

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
                    if ctx.toolchains["@rules_ocaml//toolchain/type:std"].cc_toolchain == "clang":
                        args.add("-ccopt", "-Wl,-force_load,{path}".format(path = depfile.path))
                    elif ctx.toolchains["@rules_ocaml//toolchain/type:std"].cc_toolchain == "gcc":
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
#         all_deps.extend(ctx.attr.manifest)
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
#                     if ctx.toolchains["@rules_ocaml//toolchain/type:std"].cc_toolchain == "clang":
#                         args.add("-ccopt", "-Wl,-force_load,{path}".format(path = depfile.path))
#                     elif ctx.toolchains["@rules_ocaml//toolchain/type:std"].cc_toolchain == "gcc":
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

def dump_compilation_context(ccinfo):
    print("{c}dumping compilation_context{r}".format(c=CCRED,r=CCRESET))
    compile_ctx = ccinfo.compilation_context
    print("compilation_context: %s" % compile_ctx)
    print("fields: %s" % dir(compile_ctx))
    for f in dir(compile_ctx):
        print("{f}: {val}".format(f=f, val = getattr(compile_ctx, f)))

###############################
def get_libname(linker_input):
    ## should only be one library
    lib = linker_input.libraries[0]
    libname = file_to_lib_name(lib.static_library)

    return libname

##########################
def filter_ccinfo(target):

    debug = False

    if debug: print("{c}filter_ccinfo{r}: {t}".format(c=CCRED,t=target,r=CCRESET))


    # task: if target is produced by a cc_* rule, then filter out the
    # OCaml CSDK libs. (huh? this is a remnant from a discarded
    # previous strategy?)

    default_files = target[DefaultInfo].files.to_list()

    ## iterate over CcInfo LinkInputs and discard the CSDK libs

    ## Retain any LibraryToLink with both a static/dynamic lib and a
    ## list of objects. Infer that any additional libs (in the same
    ## LibraryToLink) are from the CSDK.

    ## BUT: can't we just take the first LinkInput? It looks like it
    ## should correspond to DefaultInfo.

    ## Then create a new CcInfo containing just the retained libs.

    cc_info = target[CcInfo]
    if debug: print("cc_info: %s" % cc_info)
    # dump_compilation_context(cc_info)

    # compilation_ctx = cc_info.compilation_context

    linking_ctx     = cc_info.linking_context
    if debug: print("LINKING_CTX: %s" % linking_ctx.linker_inputs)
    linker_inputs = linking_ctx.linker_inputs.to_list()

    if linker_inputs:
        linker_input = linker_inputs[0]
        # libname = get_libname(linker_input)
        lib = linker_input.libraries[0].static_library
        new_linking_ctx = cc_common.create_linking_context(
            linker_inputs = depset(direct = [linker_input])
        )
        ccinfo_out = CcInfo(
            # don't need the old compilation ctx
            compilation_context = cc_common.create_compilation_context(),
            linking_context = new_linking_ctx
        )
        return (lib, ccinfo_out)
    else:
        return (None, None)

##########################
def cc_shared_lib_to_ccinfo(ctx, ccinfo, ccfile):
    print("{c}cc_shared_lib_to_ccinfo{r}: {t}".format(
        c=CCRED,t=ccinfo,r=CCRESET))

    ## Create a new CcInfo containing just the ccfile

    cc_toolchain = find_cpp_toolchain(ctx)
    # cc_toolchain = ctx.toolchains["@bazel_tools//tools/cpp:toolchain_type"]

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    lib_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        dynamic_library = ccfile,
        dynamic_library_symlink_path = ccfile.path,
        cc_toolchain = cc_toolchain
    )
    print("lib_to_link: %s" % lib_to_link)

    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        libraries = depset(direct=[lib_to_link])
    )

    linking_ctx     = cc_common.create_linking_context(
        linker_inputs = depset(direct=[linker_input])
    )

    cc_info = CcInfo(
        compilation_context = cc_common.create_compilation_context(),
        linking_context = linking_ctx
    )

    return cc_info


################################################################
## target may contain shared libs in DefaultInfo, as well as
## a CcInfo provider.  Merge them.
def normalize_ccinfo(ctx, target):

    debug = False

    if debug:
        print("{c}normalize_ccinfo{r}: {t}".format(
            c=CCRED,t=target,r=CCRESET))

    ccInfo = target[CcInfo]
    if debug:
        print("ccInfo: %s" % ccInfo)

    files = target[DefaultInfo].files.to_list()
    ccfiles = []
    for f in files:
        if debug:
            print("DefaultInfo file: %s" % f)
        if f.extension in ["so", "dylib"]:
            if debug: print("found dso: %s" % f)
            ccfiles.append(f)

    if len(ccfiles) == 0:
        return ccInfo

    ## Create a new CcInfo containing just the ccfiles

    ## FIXME: here we've assumed that the CcInfo is empty if
    ## DefaultInfo contains a shared lib.

    cc_toolchain = find_cpp_toolchain(ctx)
    # cc_toolchain = ctx.toolchains["@bazel_tools//tools/cpp:toolchain_type"]

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    libs_to_link = []
    for ccfile in ccfiles:
        lib_to_link = cc_common.create_library_to_link(
            actions = ctx.actions,
            feature_configuration = feature_configuration,
            dynamic_library = ccfile,
            dynamic_library_symlink_path = ccfile.path,
            cc_toolchain = cc_toolchain
        )
        if debug: print("lib_to_link: %s" % lib_to_link)
        libs_to_link.append(lib_to_link)

    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        libraries = depset(direct=libs_to_link) #[lib_to_link])
    )

    linking_ctx     = cc_common.create_linking_context(
        linker_inputs = depset(direct=[linker_input])
    )

    cc_info = CcInfo(
        compilation_context = cc_common.create_compilation_context(),
        linking_context = linking_ctx
    )

    return cc_info
