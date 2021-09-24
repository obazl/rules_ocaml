load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "CompilationModeSettingProvider",

     "PpxAdjunctsProvider",
     "OcamlArchiveMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider")

load("//ocaml/_functions:utils.bzl",
     "get_projroot",
     "get_sdkpath",
)

load(":impl_library.bzl", "impl_library")

load("//ocaml/_functions:module_naming.bzl", "normalize_module_name")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_common.bzl", "tmpdir", "dsorder")

#################
def impl_archive(ctx):

    # print("**** NS_ARCH {} ****************".format(ctx.label))

    debug = False
    # if ctx.label.name == "Bare_structs":
    #     debug = True #False

    env = {"PATH": get_sdkpath(ctx)}

    tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

    mode = ctx.attr._mode[CompilationModeSettingProvider].value

    ns_resolver = ctx.files._ns_resolver if ctx.attr._rule.startswith("ocaml_ns") else []

    ################################
    ####  call impl_ns_library  ####
    # FIXME: improve the return vals handling
    lib_providers = impl_library(ctx)

    defaultInfo = lib_providers[0]
    libOcamlProvider = lib_providers[1]
    ppxAdjunctsProvider = lib_providers[2]
    outputGroupInfo = lib_providers[3]
    _ = lib_providers[4] # OcamlLibraryMarker
    if ctx.attr._rule.startswith("ocaml_ns"):
        nslibMarker = lib_providers[5]
        ccInfo  = lib_providers[6] if len(lib_providers) == 7 else False
    else:
        ccInfo  = lib_providers[5] if len(lib_providers) == 6 else False

    ################################
    # print("==== resume NS_ARCH {} ****************".format(ctx.label))

    if libOcamlProvider.ns_resolver == None:
        print("NO NSRESOLVER FROM NSLIB")
        fail("NO NSRESOLVER FROM NSLIB")
    else:
        if debug:
            print("ARCH GOT NSRESOLVER FROM NSLIB: %s" % libOcamlProvider.ns_resolver)

    all_deps = libOcamlProvider.files
    paths_direct = []
    paths_indirect = libOcamlProvider.paths

    action_outputs = []

    _options = get_options(ctx.attr._rule, ctx)

    shared = False
    if ctx.attr.shared:
        shared = ctx.attr.shared or "-shared" in _options
        if shared:
            if "-shared" in _options:
                _options.remove("-shared") ## avoid dup

    if mode == "native":
        if shared:
            ext = ".cmxs"
        else:
            ext = ".cmxa"
    else:
        ext = ".cma"

    # ns_ext = ".cmxa" if mode == "native" else ".cma"

    #### declare output files ####
    ## same for plain and ns archives
    archive_name = normalize_module_name(ctx.label.name)
    archive_filename = tmpdir + archive_name + ext
    archive_file = ctx.actions.declare_file(archive_filename)
    paths_direct.append(archive_file.dirname)
    action_outputs.append(archive_file)

    if mode == "native":
        archive_a_filename = tmpdir + archive_name + ".a"
        archive_a_file = ctx.actions.declare_file(archive_a_filename)
        paths_direct.append(archive_a_file.dirname)
        action_outputs.append(archive_a_file)

    #########################
    args = ctx.actions.args()

    if mode == "native":
        args.add(tc.ocamlopt.basename)
    else:
        args.add(tc.ocamlc.basename)

    args.add_all(_options)

    provider_output = []
    ## Submodules can be listed in ctx.files.submodules in any order,
    ## so we need to put them in correct order on the command line.
    ## Order is encoded in their depsets, which were merged by
    ## impl_ns_library; the result contains the files of
    ## ctx.files.submodules in the correct order.
    ## submod[DefaultInfo].files won't work, it contains only one
    ## module OcamlProvider. linkargs contains the deptree we need,
    ## but it may contain additional modules, so we need to filter.

    submod_arglist = [] # direct deps
    subdeps_list = []   # indirect deps

    for dep in libOcamlProvider.linkargs.to_list():
        the_deps = ctx.attr.submodules if ctx.attr._rule.startswith("ocaml_ns") else ctx.attr.modules
        if dep in the_deps:
            submod_arglist.append(dep)
        else:
            subdeps_list.append(dep)

    ordered_submodules_depset = depset(direct=submod_arglist)

    # only direct deps go on cmd line:
    for dep in ordered_submodules_depset.to_list():
        if dep.extension == "cmx":
            args.add(dep)

    args.add("-a")

    args.add("-o", archive_file)

    if ctx.attr._rule == "ocaml_ns_archive":
        mnemonic = "CompileOcamlNsArchive"
    elif ctx.attr._rule == "ocaml_archive":
        mnemonic = "CompileOcamlArchive"
    else:
        fail("Unexpected rule type for impl_archive: %s" % ctx.attr._rule)

    ################
    ctx.actions.run(
        env = env,
        executable = tc.ocamlfind,
        arguments = [args],
        inputs = libOcamlProvider.inputs,
        outputs = action_outputs,
        mnemonic = mnemonic,
        progress_message = "{mode} compiling {rule}: @{ws}//{pkg}:{tgt}".format(
            mode = mode,
            rule = ctx.attr._rule,
            ws  = ctx.label.workspace_name,
            pkg = ctx.label.package,
            tgt=ctx.label.name,
        )
    )

    ###################
    #### PROVIDERS ####
    ###################
    default_depset = depset(
        order  = dsorder,
        direct = [archive_a_file, archive_file],
    )
    newDefaultInfo = DefaultInfo(files = default_depset)

    ppx_codeps_depset = ppxAdjunctsProvider.ppx_codeps

    new_inputs_depset = depset(
        direct     = action_outputs + ns_resolver,
        transitive = [libOcamlProvider.inputs]
    )

    subdeps_depset = depset(
        ## indirect deps (excluding direct deps, i.e. submodules)
        direct = subdeps_list
    )

    linkargs_depset = depset(
        direct     = action_outputs, #[archive_file],
        transitive = [subdeps_depset]
        # transitive = [libOcamlProvider.linkargs]
    )
    paths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = [libOcamlProvider.paths]
    )

    libOcamlProvider_files = depset(
        order  = dsorder,
        direct = action_outputs,
        transitive = [libOcamlProvider.files]
    )
    libOcamlProviderPaths_depset  = depset(
        order = dsorder,
        direct = paths_direct,
        transitive = [libOcamlProvider.paths]
    )

    libOcamlProvider = OcamlProvider(
        inputs   = new_inputs_depset,
        linkargs = linkargs_depset,
        paths    = paths_depset,
    )

    outputGroupInfo = OutputGroupInfo(
        resolver = ns_resolver,
        ppx_codeps = ppx_codeps_depset,
        linkargs = linkargs_depset,
        subdeps = subdeps_depset,
        all = depset(transitive=[
            libOcamlProvider_files,
            ppx_codeps_depset,
            # cclib_files_depset,
        ])
    )

    providers = [
        newDefaultInfo,
        libOcamlProvider,
        OcamlArchiveMarker(marker = "OcamlArchive"),
        outputGroupInfo,
        ppxAdjunctsProvider,
        # ccDepsProvider
    ]
    if ccInfo:
        providers.append(ccInfo)

    # we may be called by ocaml_ns_archive, so:
    if ctx.attr._rule.startswith("ocaml_ns"):
        providers.append(OcamlNsMarker(marker = "OcamlNsMarker"))

    return providers


