load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl",
     "OcamlProvider",
     "OcamlImportMarker")

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
     "PpxExecutableMarker",
)

load(":impl_common.bzl", "dsorder", "opam_lib_prefix")

##################################################
######## RULE DECL:  OCAML_IMPORT  #########
##################################################
def _ocaml_import_impl(ctx):

    """Import OCaml resources."""

    debug                = False
    debug_deps           = False
    debug_primary_deps   = False
    debug_secondary_deps = False
    debug_ppx            = False

    if debug: print("ocaml_import: %s" % ctx.label)

    # WARNING: some pkgs have a "dummy" target with no attribs, e.g
    # seq, byte
    # print("attr hasattr cmi? %s" % hasattr(ctx.attr, "cmi"))
    # print("file hasattr cmi? %s" % hasattr(ctx.file, "cmi"))
    # print("files hasattr cmi? %s" % hasattr(ctx.files, "cmi"))
    if (len(ctx.files.cmi) < 1):
        if debug: print("Skipping dummy target: %s" % ctx.label)
        return [
            OcamlImportMarker()
        ]

    tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

    if tc.target == "native":
        struct_extensions = ["cmxa", "cmx"]
    else:
        struct_extensions = ["cma", "cmo"]

    ################################################################
                   ####    DEPENDENCIES    ####
    ################################################################

    has_ppx_codeps  = False
    ## A note on ppx_codep dependencies - primary and secondary: ##

    # Ppx_codeps are resources for which a ppx module injects a
    # dependency when run as part of a ppx executable. So if this
    # import has a primary ppx_codep, we can infer that it must be a
    # ppx_module that injects the dependency. On the other hand, this
    # import may have an "ordinary" secondary dep (listed in 'deps')
    # that in turn has a primary ppx_codep. That would count as a
    # secondary ppx_codep. And so on, so we could have tertiary etc.
    # ppx_codeps.

    # Task: deliver PpxCodepsProvider merging all ppx_codeps for this
    # import, both primary (listed in ppx_codeps) and secondary
    # (found as a dependency listed in deps).

    # For example, @ppx_log//:ppx_log has ppx_codep
    # @ppx_sexp_conv//runtime-lib. But it also lists @ppx_log//kernel
    # as a primary dep, and @ppx_log//kernel in turn has its own
    # ppx_codep, @ppx_log//types. So in this case we would list both
    # ppx_codeps in the PpxCodepsProvider for @ppx_log//:ppx_log.

    # Only ppx modules and execs can have ppx_codeps, which will be
    # injected when the ppx executable runs.


    ################ PRIMARY OCAML DEPENDENCIES ################
    ## Primary deps: cm* attributes, which are label_lists.
    sigs_primary             = []
    structs_primary          = []
    ofiles_primary           = []  # .o files
    archives_primary         = []
    afiles_primary           = []  # .a files
    astructs_primary         = []
    cmts_primary             = []
    paths_primary            = []

    # cclibs_primary           = []

    cc_deps_primary             = []  ## file list
    cc_deps_secondary           = []  ## provider list?

    sigs_primary.extend(ctx.files.cmi)
    if tc.target == "native":
        if hasattr(ctx.attr, "cmxa"):
            archives_primary.extend(ctx.files.cmxa)
            if (len(ctx.files.cmxa) > 0):
                astructs_primary.extend(ctx.files.cmx)
            else:
                structs_primary.extend(ctx.files.cmx)

        ofiles_primary.extend(ctx.files.ofiles)
        afiles_primary.extend(ctx.files.afiles)
    else:
        archives_primary.extend(ctx.files.cma)
        if (len(ctx.files.cma) > 0):
            astructs_primary.extend(ctx.files.cmo)
        else:
            structs_primary.extend(ctx.files.cmo)

    # cclibs_primary.extend(ctx.files.cc_deps)
    cc_deps_primary.extend(ctx.files.cc_deps)

    cmts_primary.extend(ctx.files.cmti)
    cmts_primary.extend(ctx.files.cmt)

    paths_primary.append(ctx.files.cmi[0].dirname)

    if debug_primary_deps:
        print("PRIMARY DEPS for %s" % ctx.label)
        print("sigs_primary: %s" % sigs_primary)
        print("structs_primary: %s" % structs_primary)
        print("archives_primary: %s" % archives_primary)
        print("ofiles_primary: %s" % ofiles_primary)
        print("afiles_primary: %s" % afiles_primary)
        print("astructs_primary: %s" % astructs_primary)
        print("cmts_primary: %s" % cmts_primary)

        # print("cclibs_primary: %s" % cclibs_primary)

        print("paths_primary: %s" % paths_primary)

    ################ PRIMARY PPX_CODEPENDENCIES ################
    ## IMPORTANT: both primary and secondary lists contain depsets!
    ## A primary std dep is a file, but a primary codep is a target.
    codep_sigs_primary       = []
    codep_structs_primary    = []
    codep_ofiles_primary     = []
    codep_archives_primary   = []
    codep_afiles_primary     = []
    codep_astructs_primary   = []
    codep_cmts_primary       = []
    codep_paths_primary      = []

    # codep_cclibs_primary     = []

    ####################
    codep_sigs_secondary     = []
    codep_structs_secondary  = []
    codep_ofiles_secondary   = []
    codep_archives_secondary = []
    codep_afiles_secondary   = []
    codep_astructs_secondary = []
    codep_cmts_secondary     = []
    codep_paths_secondary    = []

    # codep_cclibs_secondary   = []

    if ctx.attr.ppx_codeps:
        has_ppx_codeps = True

    ## Each primary ppx_code has its standard deps (OcamlProvider);
    ## this must be merged into PpxCodepsProvider, not the
    ## OcamlProvider delivered by this import.

    for codep in ctx.attr.ppx_codeps:

        provider = codep[OcamlProvider]
        codep_sigs_primary.append(provider.sigs)
        codep_structs_primary.append(provider.structs)
        codep_ofiles_primary.append(provider.ofiles)
        codep_archives_primary.append(provider.archives)
        codep_afiles_primary.append(provider.afiles)
        codep_astructs_primary.append(provider.astructs)
        codep_cmts_primary.append(provider.cmts)
        codep_paths_primary.append(provider.paths)

        # codep_cclibs_primary.append(provider.cclibs)

        ######## SECONDARY PPX_CODEPENDENCIES ########
        # A primary ppx_codep may in turn have its own ppx_codeps.
        # We treat these as secondary ppx_codeps:
        if PpxCodepsProvider in codep:
            provider = codep[PpxCodepsProvider]
            codep_sigs_secondary.append(provider.sigs)
            codep_structs_secondary.append(provider.structs)
            codep_ofiles_secondary.append(provider.ofiles)
            codep_archives_secondary.append(provider.archives)
            codep_afiles_secondary.append(provider.afiles)
            codep_astructs_secondary.append(provider.astructs)
            codep_cmts_secondary.append(provider.cmts)
            codep_paths_secondary.append(provider.paths)

            # codep_cclibs_secondary.append(provider.cclibs)

        ################ SECONDARY CC DEPENDENCIES ################
        if CcInfo in codep:
            cc_deps_secondary.append(codep[CcInfo])

    if debug_ppx:
        print("PRIMARY PPX_CODEPS for %s" % ctx.label)
        print("codep_sigs_primary: %s" % codep_sigs_primary)
        print("codep_structs_primary: %s" % codep_structs_primary)
        print("codep_archives_primary: %s" % codep_archives_primary)
        print("codep_ofiles_primary: %s" % codep_ofiles_primary)
        print("codep_afiles_primary: %s" % codep_afiles_primary)
        print("codep_astructs_primary: %s" % codep_astructs_primary)
        print("codep_cmts_primary: %s" % codep_cmts_primary)
        print("codep_paths_primary: %s" % codep_paths_primary)
        # print("codep_cclibs_primary: %s" % codep_cclibs_primary)

        print("SECONDARY PPX_CODEPS for %s" % ctx.label)
        print("codep_sigs_secondary: %s" % codep_sigs_secondary)
        print("codep_structs_secondary: %s" % codep_structs_secondary)
        print("codep_archives_secondary: %s" % codep_archives_secondary)
        print("codep_ofiles_secondary: %s" % codep_ofiles_secondary)
        print("codep_afiles_secondary: %s" % codep_afiles_secondary)
        print("codep_astructs_secondary: %s" % codep_astructs_secondary)
        print("codep_cmts_secondary: %s" % codep_cmts_secondary)
        print("codep_paths_secondary: %s" % codep_paths_secondary)
        # print("codep_cclibs_secondary: %s" % codep_cclibs_secondary)

    ################ PRIMARY STUBLIB DEPENDENCIES ################
    # cc_deps_primary   = []
    # cc_deps_secondary = []
    for dep in ctx.attr.cc_deps:
        # print("STUBLIB DEP: {this}  {dep}".format(
        #     this=ctx.label, dep = dep))
        # print("STUBLIB PROVIDER: %s" % dep[CcInfo])
        cc_deps_primary.append(dep[CcInfo])

    # #########################
    # for dep in ctx.attr.deps:
    #     if OcamlProvider in dep:

    ################ SECONDARY OCAML DEPENDENCIES ################
    ## Secondary deps: whatever is in 'deps' attribute.
    ## Task: extract and merge the depsets from the OcamlProviders

    sigs_secondary           = []
    structs_secondary        = []
    ofiles_secondary         = []  # .o files
    archives_secondary       = []
    afiles_secondary         = []  # .a files
    astructs_secondary       = []
    cmts_secondary           = []
    paths_secondary          = []

    # cclibs_secondary         = []

    #########################
    for dep in ctx.attr.deps:
        if OcamlProvider in dep:
            provider = dep[OcamlProvider]
            sigs_secondary.append(provider.sigs)
            structs_secondary.append(provider.structs)
            ofiles_secondary.append(provider.ofiles)
            archives_secondary.append(provider.archives)
            afiles_secondary.append(provider.afiles)
            astructs_secondary.append(provider.astructs)
            paths_secondary.append(provider.paths)

            # cclibs_secondary.append(provider.cclibs)

        ######## TERTIARY PPX_CODEPENDENCIES ########
        # A secondary std dep may carry its own ppx_codeps;
        # we add these the the codep secondary lists:
        if PpxCodepsProvider in dep:
            has_ppx_codeps = True
            provider = dep[PpxCodepsProvider]
            codep_sigs_secondary.append(provider.sigs)
            codep_structs_secondary.append(provider.structs)
            codep_ofiles_secondary.append(provider.ofiles)
            codep_archives_secondary.append(provider.archives)
            codep_afiles_secondary.append(provider.afiles)
            codep_astructs_secondary.append(provider.astructs)
            codep_cmts_secondary.append(provider.cmts)
            codep_paths_secondary.append(provider.paths)

            # codep_cclibs_secondary.append(provider.cclibs)

        ################ SECONDARY CC DEPENDENCIES ################
        if CcInfo in dep:
            cc_deps_secondary.append(dep[CcInfo])

    ################################################################
    ######  IMPORT ACTION ######
    ################################################################
    # Null action - don't really need this but it marks the divide
    # between merging deps and creating providers.
    ctx.actions.do_nothing(
        mnemonic = "Ocaml_import",
        inputs = depset()
    )

    ################################################################
    ##  PROVIDERS ##
    ################################################################

    providers = []

    ## we don't produce anything by action, so default is empty:
    providers.append(DefaultInfo())

    ##################
    if has_ppx_codeps:
        ppxCodepsProvider = PpxCodepsProvider(
            sigs       = depset(order=dsorder,
                                # direct = codep_sigs_primary,
                                transitive = codep_sigs_primary
                                + codep_sigs_secondary),
            structs    = depset(order=dsorder,
                                # direct = codep_structs_primary,
                                transitive = codep_structs_primary
                                + codep_structs_secondary),
            ofiles     = depset(order=dsorder,
                                # direct = codep_ofiles_primary,
                                transitive = codep_ofiles_primary
                                + codep_ofiles_secondary),
            archives   = depset(order=dsorder,
                                # direct = codep_archives_primary,
                                transitive = codep_archives_primary
                                + codep_archives_secondary),
            afiles     = depset(order=dsorder,
                                # direct = codep_afiles_primary,
                                transitive = codep_afiles_primary
                                + codep_afiles_secondary),
            astructs   = depset(order=dsorder,
                                # direct = codep_astructs_primary,
                                transitive = codep_astructs_primary
                                + codep_astructs_secondary),
            cmts       = depset(order=dsorder,
                                # direct = codep_cmts_primary,
                                transitive = codep_cmts_primary
                                + codep_cmts_secondary),
            paths       = depset(order=dsorder,
                                 # direct = codep_paths_primary,
                                 transitive = codep_paths_primary
                                 + codep_paths_secondary),
            # cclibs       = depset(order=dsorder,
            #                        # direct = codep_cclibs_primary,
            #                       transitive = codep_cclibs_primary
            #                       + codep_cclibs_secondary),
        )
        providers.append(ppxCodepsProvider)
        if debug_ppx:
            print("PPX_CODEPS for %s" % ctx.label)
            print(ppxCodepsProvider)

    #### Std OcamlProvider
    _ocamlProvider = OcamlProvider(
        sigs    = depset(order="postorder",
                         direct=sigs_primary,
                         transitive=sigs_secondary),
        structs = depset(order="postorder",
                         direct=structs_primary,
                         transitive=structs_secondary),
        ofiles   = depset(order="postorder",
                          direct=ofiles_primary,
                          transitive=ofiles_secondary),
        archives = depset(order="postorder",
                            direct=archives_primary,
                            transitive=archives_secondary),
        afiles   = depset(order="postorder",
                          direct=afiles_primary,
                          transitive=afiles_secondary),
        astructs = depset(order="postorder",
                          direct=astructs_primary,
                          transitive=astructs_secondary),
        cmts     = depset(order="postorder",
                          direct=cmts_primary,
                          transitive=cmts_secondary),
        paths    = depset(order="postorder",
                          direct=paths_primary,
                          transitive=paths_secondary),

        # cclibs = depset(order="postorder",
        #                   direct=cclibs_primary,
        #                   transitive=cclibs_secondary),
    )
    providers.append(_ocamlProvider)

    ## CcInfo
    if cc_deps_primary or cc_deps_secondary:
        ccoutputs = []
        ccInfo = cc_common.merge_cc_infos(
            cc_infos = cc_deps_primary + cc_deps_secondary
        )
        providers.append(ccInfo)


    providers.append(OcamlImportMarker(marker = "OcamlImport"))

    ## --output_groups only prints generated stuff, so there's no
    ## --point in providing OutputGroupInfo for ocaml_import

    return providers

################################################################
ocaml_import = rule(
    implementation = _ocaml_import_impl,
    doc = """Imports pre-compiled OCaml files. [User Guide](../ug/ocaml_import.md).

    """,
    attrs = dict(
        # _mode       = attr.label(
        #     default = "@rules_ocaml//build/mode",
        # ),

        cma  = attr.label_list(allow_files = True),
        cmxa = attr.label_list(allow_files = True),
        cmxs = attr.label_list(allow_files = True),
        cmi  = attr.label_list(allow_files = True),
        cmo  = attr.label_list(allow_files = True),
        cmx  = attr.label_list(allow_files = True),
        ofiles =  attr.label_list(
            doc = "list of .o files that go with .cmx files",
            allow_files = True
        ),
        afiles =  attr.label_list(
            doc = "list of .a files that go with .cmxa files",
            allow_files = True
        ),
        cc_deps = attr.label_list(
            doc = "C archive files (.a) for integrating OCaml and C libs",
            allow_files = True,
            providers = [CcInfo],
        ),
        vmlibs   = attr.label_list(
            doc = "Dynamically-loadable, for ocamlrun. Standard naming is 'dll<name>_stubs.so' or 'dll<name>.so'.",
            allow_files = [".so"]
        ),
        cmt  = attr.label_list(allow_files = True),
        cmti = attr.label_list(allow_files = True),
        srcs = attr.label_list(allow_files = True),

        all = attr.label_list(
            doc = "Glob all cm* files except for 'archive' or 'plugin' so theey can be added to action ldeps (rather than cmd line). I.e. the (transitive) deps of an archive, which must be accessible to the compiler (via search path, not command line), and so must be added to the action ldeps.",
            allow_files = True
        ),

        modules = attr.label_list(
            allow_files = True
        ),
        signature = attr.label_list(
            allow_files = True
        ),
        ppx = attr.label(
            doc = "precompiled ppx executable",
            allow_single_file = True,
            executable = True,
            cfg        = "exec"
        ),
        plugin = attr.label_list(
            allow_files = True
        ),
        # ocaml_import can only depend on other ocaml_imports
        deps = attr.label_list(
            allow_files = True,
            providers = [OcamlImportMarker],
        ),
        ppx_codeps = attr.label_list(
            allow_files = True,
            providers = [[OcamlImportMarker]]
        ),
        version = attr.string(),
        doc = attr.string(),
        _rule = attr.string( default = "ocaml_import" ),
    ),
    provides = [OcamlImportMarker],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain:type"],
)
