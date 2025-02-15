load("@bazel_skylib//lib:paths.bzl", "paths")

load("@rules_ocaml//lib:merge.bzl",
     "merge_deps",
     "aggregate_codeps",
     "DepsAggregator",
     "COMPILE", "LINK", "COMPILE_LINK")

load("@rules_ocaml//build:providers.bzl", "OCamlDepsProvider")
load("@rules_ocaml//build:providers.bzl",
     "OcamlImportMarker")
load("//build:providers.bzl", "OCamlCodepsProvider")

load("@rules_ocaml//build/_lib:utils.bzl", "dsorder")

load("@rules_ocaml//build/_lib:ccdeps.bzl", "dump_CcInfo")

load("@rules_ocaml//lib:colors.bzl",
     "CCRED", "CCDER", "CCMAG", "CCRESET")

##############################################
def _import_transition_impl(settings, attr):
    return {
        # "@rules_ocaml//cfg/manifest"   : [],
        "@rules_ocaml//cfg/ns:nonce"      : "",
        "@rules_ocaml//cfg/ns:prefixes"   : [],
        "@rules_ocaml//cfg/ns:submodules" : []
    }

_import_transition = transition(
    implementation = _import_transition_impl,
    inputs = [],
    #     "@rules_ocaml//cfg/ns:nonce",
    #     "@rules_ocaml//cfg/ns:prefixes",
    #     "@rules_ocaml//cfg/ns:submodules",
    # ],
    outputs = [
        # "@rules_ocaml//cfg/manifest",
        "@rules_ocaml//cfg/ns:nonce",
        "@rules_ocaml//cfg/ns:prefixes",
        "@rules_ocaml//cfg/ns:submodules",
    ]
)



##################################################
######## RULE DECL:  OCAML_IMPORT  #########
##################################################
def _ocaml_import_impl(ctx):

    """Import OCaml resources."""

    debug                = False
    debug_cc             = False
    debug_deps           = False
    debug_jsoo           = False
    debug_primary_deps   = False
    debug_secondary_deps = False
    debug_ppx            = False
    debug_tc             = False

    if debug: print("ocaml_import: %s" % ctx.label)

    # WARNING: some pkgs have a "dummy" target with no attribs, e.g
    # seq, byte; but others have only archives, e.g. @ocaml//num/core
    # print("attr hasattr sigs? %s" % hasattr(ctx.attr, "sigs"))
    # print("file hasattr sigs? %s" % hasattr(ctx.file, "sigs"))
    # print("files hasattr sigs? %s" % hasattr(ctx.files, "sigs"))
    if (len(ctx.files.sigs) < 1):
        if not ctx.file.archive:
            if debug: print("Skipping dummy target: %s" % ctx.label)
            return [
                OcamlImportMarker()
            ]

    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]

    depsets = DepsAggregator()

    if debug_deps: print("ctx.attr.deps: %s" % ctx.attr.deps)
    for dep in ctx.attr.deps:
        depsets = merge_deps(ctx, dep, depsets)
        # if OCamlCodepsProvider in dep:
        #     # print("this: %s" % ctx.label)
        #     # print("UX: %s" % dep[OCamlCodepsProvider])
        #     depsets = aggregate_codeps(ctx, COMPILE_LINK, dep, depsets)

    for dep in ctx.attr.cc_deps:
        depsets = merge_deps(ctx, dep, depsets)

    if debug_deps: print("ctx.attr.ppx_codeps: %s" % ctx.attr.ppx_codeps)
    if hasattr(ctx.attr, "ppx_codeps"):
        for codep in ctx.attr.ppx_codeps:
            depsets = aggregate_codeps(ctx, COMPILE_LINK, codep, depsets)

    ##FIXME: cc_deps in ppx_codeps?

    # if hasattr(ctx.attr, "ppx_compile_codeps"):
    #     for codep in ctx.attr.ppx_codeps:
    #         depsets = aggregate_codeps(ctx, COMPILE_LINK, codep, depsets)
    # if hasattr(ctx.attr, "ppx_codeps"):
    #     for codep in ctx.attr.ppx_codeps:
    #         depsets = aggregate_codeps(ctx, COMPILE_LINK, codep, depsets)

    ################################################################
    ## A note on ppx_codep dependencies - primary and secondary: ##

    # Ppx_codeps are resources for which a ppx module injects a
    # dependency when run as part of a ppx executable. So if this
    # import has a primary ppx_codep, we can infer that it must be a
    # ppx_module that injects the dependency. On the other hand, this
    # import may have an "ordinary" secondary dep (listed in 'deps')
    # that in turn has a primary ppx_codep. That would count as a
    # secondary ppx_codep. And so on, so we could have tertiary etc.
    # ppx_codeps.

    # Task: deliver OCamlCodepsProvider merging all ppx_codeps for this
    # import, both primary (listed in ppx_codeps) and secondary
    # (found as a dependency listed in deps).

    # For example, @ppx_log//:ppx_log has ppx_codep
    # @ppx_sexp_conv//runtime-lib. But it also lists @ppx_log//kernel
    # as a primary dep, and @ppx_log//kernel in turn has its own
    # ppx_codep, @ppx_log//types. So in this case we would list both
    # ppx_codeps in the OCamlCodepsProvider for @ppx_log//:ppx_log.

    # Only ppx modules and execs can have ppx_codeps, which will be
    # injected when the ppx executable runs.


    ################################################################
    ######  IMPORT ACTION ######
    ################################################################
    # Null action - don't really need this but it marks the divide
    # between merging deps and creating providers.
    ctx.actions.do_nothing(
        mnemonic = "ocaml_import",
        inputs = depset()
    )

    ################################################################
    ##  PROVIDERS ##
    ################################################################
    providers = []

    ## we don't produce anything by action, so default is empty:
    providers.append(
        DefaultInfo(
            # files = depset(direct = ctx.files.cmxa)
        )
    )

    ##################
    ## We will have OCamlCodepsProvider if:
    ## a. we have ctx.attr.ppx_codeps; or
    ## b. at least on of ctx.attr.deps has a OCamlCodepsProvider provider

    ## Case b will be handled by aggregating ctx.attr.deps - since
    ## every dep has at least one sig, we can use that to test.

    # if ctx.label.name == "ppx_inline_test":
    #     print("attr.ppx_codeps: %s" % ctx.attr.ppx_codeps)
    #     print("depsets.codeps.archives: %s" % depsets.codeps.archives)
    #     print("depsets.codeps.atructs: %s" % depsets.codeps.astructs)
    #     # fail()

    if (ctx.attr.ppx_codeps or depsets.codeps.sigs != []):

        ppxCodepsInfo = OCamlCodepsProvider(
            sigs       = depset(order=dsorder,
                                transitive = depsets.codeps.sigs),
            cli_link_deps = depset(order=dsorder,
                                   transitive=depsets.codeps.cli_link_deps),
            archives   = depset(order=dsorder,
                                transitive = depsets.codeps.archives),
            structs    = depset(order=dsorder,
                                transitive = depsets.codeps.structs),
            astructs   = depset(order=dsorder,
                                transitive = depsets.codeps.astructs),
            afiles     = depset(order=dsorder,
                                transitive = depsets.codeps.afiles),
            # ofiles always empty?
            ofiles     = depset(order=dsorder,
                                transitive = depsets.codeps.ofiles),
            cmts       = depset(order=dsorder,
                                transitive = depsets.codeps.cmts),
            cmtis      = depset(order=dsorder,
                                transitive = depsets.codeps.cmtis),
            paths       = depset(order=dsorder,
                                 transitive = depsets.codeps.paths),
            # FIXME: jsoo passed as separate jsoo_library target
            # jsoo_runtimes = depset(order=dsorder,
            #                        transitive = depsets.codeps.jsoo_runtimes),
        )
    # if ctx.label.name == "ppx_inline_test":
    #     print("OCamlCodepsProvider.astructs: %s" % ppxCodepsInfo.astructs)
        # fail()

        providers.append(ppxCodepsInfo)

    # if ctx.label.name == "ppx_inline_test":
    #     print("files.astructs: %s" % ctx.files.astructs)
    #     print("deps.astructs: %s" % depsets.deps.astructs)
    #     fail()

    ## To produce an OCamlDepsProvider provider, we merge the direct deps of
    ## this import with the depsets from ctx.attr.deps.
    ocamlProvider = OCamlDepsProvider(
        sigs    = depset(order=dsorder,
                         direct=ctx.files.sigs,
                         transitive = depsets.deps.sigs),
        cli_link_deps = depset(order=dsorder,
                               direct = [ctx.file.archive],
                               transitive = depsets.deps.cli_link_deps),
        archives = depset(order=dsorder,
                          direct = [ctx.file.archive],
                          transitive = depsets.deps.archives),
        ##FIXME: if no archive, then put ctx.files.astructs into structs
        structs = depset(order=dsorder,
                         # direct=ctx.files.structs,
                         transitive = depsets.deps.structs),
        astructs = depset(order=dsorder,
                          direct=ctx.files.astructs,
                          transitive = depsets.deps.astructs),
        afiles   = depset(order=dsorder,
                          direct=ctx.files.afiles,
                          transitive = depsets.deps.afiles),
        ofiles   = depset(order=dsorder,
                          direct=ctx.files.ofiles,
                          transitive = depsets.deps.ofiles),
        cmts     = depset(order=dsorder,
                          direct=ctx.files.cmts,
                          transitive = depsets.deps.cmts),
        cmtis     = depset(order=dsorder,
                           direct=ctx.files.cmtis,
                           transitive = depsets.deps.cmtis),
        # FIXME: to depend on an imported archive we do not need to
        # add the path to the search space with -I, presumably because
        # the .a, .cmi and .cmx files are in the same directory as the
        # archive. But we DO need to put .cmi files in search path,
        # e.g. when compiling a sigfile with imports.
        paths    = depset(order=dsorder,
                          direct = [ctx.files.sigs[0].dirname] if ctx.files.sigs else [],
                          transitive = depsets.deps.paths),
        # jsoo_runtimes = depset(order=dsorder,
        #                        direct=jsoo_runtimes_primary,
        #                        transitive = depsets.deps.jsoo_runtimes),
        # transitive=jsoo_runtimes_secondary),
    )
    # if ctx.label.name == "ppx_inline_test":
    #     print("OCamlDepsProvider.astructs: %s" % ocamlProvider.astructs)
    #     fail()

    providers.append(ocamlProvider)

    ccInfo = cc_common.merge_cc_infos(
        # direct_cc_infos = ccinfos_primary,
        cc_infos = depsets.ccinfos
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
        sigs     = attr.label_list(allow_files = True),

        archive  = attr.label(allow_single_file = True),
        afiles =  attr.label_list(
            doc = "list of .a files that go with .cmxa files",
            allow_files = True
        ),

        # archived structs - added to inputs_depset but not cli
        astructs  = attr.label_list(allow_files = True),

        ofiles =  attr.label_list(
            doc = "list of .o files that go with .cmx files",
            allow_files = True
        ),
        # unarchived structs, added to both inputs_depset and cli
        # (should never occur with opam pkgs?)
        #structs  = attr.label_list(allow_files = True),

        cmts  = attr.label_list(allow_files = True),
        cmtis = attr.label_list(allow_files = True),

        #FIXME: delete cma, cmxa, cmo, cmx
        # cma  = attr.label(allow_single_file = True),
        # cmxa = attr.label(allow_single_file = True),
        cmxs = attr.label(allow_single_file = True),
        # cmo  = attr.label_list(allow_files = True),
        # cmx  = attr.label_list(allow_files = True),
        cc_deps = attr.label_list(
            doc = "C archive files (.a) for integrating OCaml and C libs",
            allow_files = True,
            providers = [CcInfo],
        ),
        vmlibs   = attr.label_list(
            doc = "Dynamically-loadable, for ocamlrun. Standard naming is 'dll<name>_stubs.so' or 'dll<name>.so'.",
            allow_files = [".so"]
        ),
        jsoo_runtime = attr.label(allow_single_file = True),
        srcs = attr.label_list(allow_files = True),

        all = attr.label_list(
            doc = "Glob all cm* files except for 'archive' or 'plugin' so theey can be added to action ldeps (rather than cmd line). I.e. the (transitive) deps of an archive, which must be accessible to the compiler (via search path, not command line), and so must be added to the action ldeps.",
            allow_files = True
        ),

        # modules = attr.label_list(
        #     allow_files = True
        # ),
        # signature = attr.label_list(
        #     allow_files = True
        # ),

        # plugin = attr.label_list(allow_files = True),
        plugin = attr.label(allow_single_file = True),

        # ocaml_import can only depend on other ocaml_imports
        deps = attr.label_list(
            allow_files = True,
            providers = [[OcamlImportMarker],[CcInfo]],
            # cfg       = _import_transition,
        ),

        ## FIXME:
        # ppx = attr.label(
        #     doc = "precompiled ppx executable",
        #     allow_single_file = True,
        #     executable = True,
        #     cfg        = "exec"
        # ),

        ppx_codeps = attr.label_list(
            allow_files = True,
            providers = [[OcamlImportMarker]],
            # cfg = _ppx_codeps_transition,
        ),
        version = attr.string(),
        ocaml_version = attr.string(),
        doc = attr.string(),
        _rule = attr.string( default = "ocaml_import" ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    ),
    cfg     = _import_transition,
    provides = [OcamlImportMarker],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std"],
)
