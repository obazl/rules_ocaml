load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml/_transitions:ns_transitions.bzl", "nsarchive_in_transition")

load("//ocaml:providers.bzl",
     "OcamlProvider",

     "OcamlArchiveMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsResolverProvider",
     "OcamlSDK",
     "OcamlSignatureProvider")

load("//ppx:providers.bzl",
     "PpxCodepsProvider",
)

load("//ocaml/_rules/utils:rename.bzl",
     "get_module_name",
     "rename_srcfile")

load(":impl_ppx_transform.bzl", "impl_ppx_transform")

load("//ocaml/_transitions:transitions.bzl", "ocaml_signature_deps_out_transition")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     # "get_sdkpath",
)
load("//ocaml/_functions:module_naming.bzl",
     "normalize_module_name",
     "normalize_module_label")

load(":options.bzl",
     "options",
     "options_ns_opts",
     "options_ppx",
     "options_signature")

load("//ocaml/_rules/utils:utils.bzl", "get_options")

load(":impl_ccdeps.bzl", "extract_cclibs", "dump_CcInfo")

load(":impl_common.bzl",
     "dsorder",
     "opam_lib_prefix",
     "tmpdir")

workdir = tmpdir

#### DIRTY HACK ALERT ####
## Needed for tezos/src/lib_protocol_compiler, which passes a cmi file
## in a namespace to a cmd line tool.
## extracts cmi from ns resolver
########## RULE:  OCAML_NS_SIGNATURE  ################
def _ocaml_ns_signature_impl(ctx):

    ns = ctx.attr.ns
    # print("Extracting resolver cmi from {ns}".format(ns = ns))
    # print("NS marker: %s" % ns[OcamlNsMarker])
    # print("OcamlProvider: %s" % ns[OcamlProvider])

    in_cmi  = None
    out_cmi = None

    if OcamlNsMarker in ctx.attr.ns:
        ns_name = ctx.attr.ns[OcamlNsMarker].ns_name

    if ns_name == None:
        print("LBL: %s" % ctx.label)
        fail("ns resolver for {ns} not found".format(ns=ns))
    else:
        for f in ns[OcamlProvider].fileset.to_list():
            # print("fileset f: %s" % f)
            if f.basename.endswith(ns_name + ".cmi"):
                in_cmi = f

    if in_cmi == None:
        print("LBL: %s" % ctx.label)
        fail("ns resolver cmi {cmi} for {ns} not found".format(
            cmi = ns_name + ".cmi", ns=ns))

    if ctx.attr.as_cmi:
        if ctx.attr.as_cmi.endswith(".cmi"):
            as_cmi = ctx.attr.as_cmi
        else:
            as_cmi = ctx.attr.as_cmi + ".cmi"
        out_cmi = ctx.actions.declare_file(as_cmi)

        ctx.actions.symlink(
            output = out_cmi,
            target_file = in_cmi
        )

    else:
        out_cmi = in_cmi

    default_depset = depset(
        order = dsorder,
            direct = [out_cmi],
    )

    defaultInfo = DefaultInfo(
        files = default_depset
    )

    sigProvider = OcamlSignatureProvider(
        # mli = work_mli,
        cmi = out_cmi
    )

    outputGroupInfo = OutputGroupInfo(
        cmi        = default_depset,
    )

    return [defaultInfo, sigProvider, outputGroupInfo]

################################
rule_options = options("ocaml")
rule_options.update(options_signature)
rule_options.update(options_ns_opts("ocaml"))
rule_options.update(options_ppx)

#######################
ocaml_ns_signature = rule(
    implementation = _ocaml_ns_signature_impl,
    doc = """Extract .cmi from ns lib or archive.
    """,
    attrs = dict(
        rule_options,
        ## RULE DEFAULTS
        _linkall     = attr.label(default = "@rules_ocaml//cfg/signature/linkall"), # FIXME: call it alwayslink?
        # _threads     = attr.label(default = "@rules_ocaml//cfg/signature/threads"),
        _warnings  = attr.label(default = "@rules_ocaml//cfg/signature:warnings"),
        #### end options ####

        ns = attr.label(
            doc = "An ocaml_ns_library or ocaml_ns_archive",
            allow_single_file = True,
            providers = [OcamlNsMarker]
        ),

        # ex: tezos/src/lib_protocol_compiler passes a cmi file as arg to
        # a cmd problem is that .cmi is for a submodule in a namespace, so
        # we do not have a direct label for it. We can only pass the
        # (generated) filename to a rule to make it available under a
        # label. That's what as_cmi is for. NB with bottom-up ns we do not
        # need this.
        as_cmi = attr.string(
            doc = "For use with ns_module only. Creates a symlink from the extracted cmi file."
        ),

        # _mode       = attr.label(
        #     default = "@rules_ocaml//build/mode",
        # ),
        _rule = attr.string( default = "ocaml_ns_signature" ),
        # _sdkpath = attr.label(
        #     default = Label("@rules_ocaml//cfg:sdkpath")
        # ),
        # _allowlist_function_transition = attr.label(
        #     default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        # ),
    ),
    ## this is not an ns archive, and it does not use ns ConfigState,
    ## but we need to reset the ConfigState anyway, so the deps are
    ## not affected if this is a dependency of an ns aggregator.
    # cfg     = nsarchive_in_transition,
    incompatible_use_toolchain_transition = True,
    provides = [OcamlSignatureProvider],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain/type:std"],
)
