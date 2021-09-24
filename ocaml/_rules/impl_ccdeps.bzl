load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//ocaml:providers.bzl", "CcDepsProvider")

load("//ocaml/_functions:module_naming.bzl", "file_to_lib_name")

## returns:
##   depset to be added to action_inputs
##   updated args
##   a CcDepsProvider containing cclibs dictionary {dep: linkmode}
##   a depset containing ccdeps files, for OutputGroups
##   FIXME: what about cc_runfiles?
def handle_ccdeps(ctx,
                    # for_pack,
                    default_linkmode, # in
                    # cc_deps_dict, ## list of dicts
                    args, ## in/out
                    # includes,
                    # cclib_deps,
                    # cc_runfiles):
                  ):
    debug = True
    ## steps:
    ##   1. accumulate all ccdep dictionaries = direct + indirect
    ##      a. remove duplicate dict entries?
    ##   2. construct action_inputs list
    ##   3. derive cmd line args
    ##   4. construct CcDepsProvider

    # 1. accumulate
    #    a. direct cc deps
    direct_ccdeps_maps_list = []
    if hasattr(ctx.attr, "cc_deps"):
        direct_ccdeps_maps_list = [ctx.attr.cc_deps]

    ## FIXME: ctx.attr._cc_deps is a label_flag attr, cannot be a dict
    # all_ccdeps_maps_list.update(ctx.attr._cc_deps)

    # print("CCDEPS DIRECT: %s" % direct_ccdeps_maps_list)

    #    b. indirect cc deps
    all_deps = []
    if hasattr(ctx.attr, "deps"):
        all_deps.extend(ctx.attr.deps)
    if hasattr(ctx.attr, "_deps"):
        all_deps.append(ctx.attr._deps)
    if hasattr(ctx.attr, "deps_deferred"):
        all_deps.extend(ctx.attr.deps_deferred)
    if hasattr(ctx.attr, "sig"):
        all_deps.append(ctx.attr.sig)

    ## for ocaml_library
    if hasattr(ctx.attr, "modules"):
        all_deps.extend(ctx.attr.modules)
    ## for ocaml_ns_library
    if hasattr(ctx.attr, "submodules"):
        all_deps.extend(ctx.attr.submodules)
    ## [ocaml/ppx]_executable
    if hasattr(ctx.attr, "main"):
        all_deps.append(ctx.attr.main)

    indirect_ccdeps_maps_list = []
    for dep in all_deps:
        if None == dep: continue # e.g. attr.sig may be missing
        if CcDepsProvider in dep:
            if dep[CcDepsProvider].ccdeps_map: # skip empty maps
                indirect_ccdeps_maps_list.append(dep[CcDepsProvider].ccdeps_map)
    # print("CCDEPS INDIRECT: %s" % indirect_ccdeps_maps_list)

    ## depsets cannot contain dictionaries so we use a list
    all_ccdeps_maps_list = direct_ccdeps_maps_list + indirect_ccdeps_maps_list
    ## now merge the maps and remove duplicate entries
    all_ccdeps_map = {} # merged ccdeps maps
    for ccdeps_map in all_ccdeps_maps_list:
        # print("CCDEPS_MAP ITEM: %s" % ccdeps_map)
        for [ccdep, cclinkmode] in ccdeps_map.items():
            if ccdep in all_ccdeps_map:
                if cclinkmode == all_ccdeps_map[ccdep]:
                    ## duplicate
                    # print("Removing duplicate ccdep: {k}: {v}".format(
                    #     k = ccdep, v = cclinkmode
                    # ))
                    continue
                else:
                    # duplicate key, different linkmode
                    fail("CCDEP: duplicate dep {dep} with different linkmodes: {lm1}, {lm2}".format(
                        dep = dep,
                        lm1 = all_ccdeps_map[ccdep],
                        lm2 = cclinkmode
                    ))
            else:
                ## accum
                all_ccdeps_map.update({ccdep: cclinkmode})
    ## end: accumulate
    # print("ALLCCDEPS: %s" % all_ccdeps_map)
    # print("ALLCCDEPS KEYS: %s" % all_ccdeps_map.keys())

    # 2. derive action inputs
    action_inputs_ccdep_filelist = []
    for tgt in all_ccdeps_map.keys():
        action_inputs_ccdep_filelist.extend(tgt.files.to_list())
    # print("ACTION_INPUTS_ccdep_filelist: %s" % action_inputs_ccdep_filelist)
    ## 3. derive cmd line args

    ## FIXME: static v. dynamic linking of cc libs in bytecode mode
    # see https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html#ss%3Adynlink-c-code

    # default linkmode for toolchain is determined by platform
    # see @ocaml//toolchain:BUILD.bazel, ocaml/_toolchains/*.bzl
    # dynamic linking does not currently work on the mac - ocamlrun
    # wants a file named 'dllfoo.so', which rust cannot produce. to
    # support this we would need to rename the file using install_name_tool
    # for macos linkmode is dynamic, so we need to override this for bytecode mode

    cc_runfiles = [] # FIXME?

    for [dep, linkmode] in all_ccdeps_map.items():
        if debug:
            print("CCLIB DEP: ")
            print(dep)
            for f in dep.files.to_list():
                print("  f: %s" % f)
            if CcInfo in dep:
                print(" CcInfo: %s" % dep[CcInfo])

        if linkmode == "default":
            if debug: print("DEFAULT LINKMODE: %s" % default_linkmode)
            for depfile in dep.files.to_list():
                if default_linkmode == "static":
                    if (depfile.extension == "a"):
                        args.add(depfile)
                        # cclib_deps.append(depfile)
                        # includes.append(depfile.dirname)
                else:
                    for depfile in dep.files.to_list():
                        if (depfile.extension == "so"):
                            libname = file_to_lib_name(depfile)
                            args.add("-ccopt", "-L" + depfile.dirname)
                            args.add("-cclib", "-l" + libname)
                            # cclib_deps.append(depfile)
                        elif (depfile.extension == "dylib"):
                            libname = file_to_lib_name(depfile)
                            args.add("-cclib", "-l" + libname)
                            args.add("-ccopt", "-L" + depfile.dirname)
                            # cclib_deps.append(depfile)
                            cc_runfiles.append(dep.files)
        elif linkmode == "static":
            if debug:
                print("STATIC lib: %s:" % dep)
            # for depfile in dep.files.to_list():
            for depfile in dep.files.to_list():
                if (depfile.extension == "a"):
                    args.add(depfile)
                    # print("ADDING CC DEP: %s" % depfile.dirname)
                    # cclib_deps.append(depfile)
                    # if for_pack:
                    #     # print("LINKING CC DEP: %s" % depfile)
                    #     args.add(depfile)
                    #     includes.append(depfile.dirname)
        elif linkmode == "static-linkall":
            if debug:
                print("STATIC LINKALL lib: %s:" % dep)
            for depfile in dep.files.to_list():
                if (depfile.extension == "a"):
                    # cclib_deps.append(depfile)
                    # includes.append(depfile.dirname)
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
                    if debug:
                        print("so LIBNAME: %s" % libname)
                    args.add("-ccopt", "-L" + depfile.dirname)
                    args.add("-cclib", "-l" + libname)
                    # cclib_deps.append(depfile)
                elif (depfile.extension == "dylib"):
                    libname = file_to_lib_name(depfile)
                    if debug:
                        print("LIBNAME: %s:" % libname)
                    args.add("-cclib", "-l" + libname)
                    args.add("-ccopt", "-L" + depfile.dirname)
                    # cclib_deps.append(depfile)
                    cc_runfiles.append(dep.files)
    ## end: derive cmd options

    ## now derive CcDepsProvider:

    # for OutputGroups: use action_inputs_ccdep_filelist
    ccDepsProvider = CcDepsProvider(
        ccdeps_map = all_ccdeps_map
    )

    return [action_inputs_ccdep_filelist, ccDepsProvider]

