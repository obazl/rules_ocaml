load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//build:providers.bzl", "OCamlLibraryProvider")

load("//build/_lib:apis.bzl", "options", "options_aggregators")

load("//build/_rules/ocaml_library:impl_archive.bzl", "impl_archive")
load("//build/_rules/ocaml_library:impl_library.bzl", "impl_library")

load("//build/_transitions:in_transitions.bzl",
     "toolchain_in_transition",
     "nslib_in_transition",
     "reset_in_transition")

###############################
def _ocaml_library(ctx):

    ## target 'linkage' attr overrides hidden '_linkage'
    if ctx.attr.linkage:
        _linkage = ctx.attr.linkage
    elif ctx.attr._linkage[BuildSettingInfo].value == "none":
        _linkage = None
    else:
        _linkage = ctx.attr._linkage[BuildSettingInfo].value

    # print("{} linkage: {}, linklevel: {}".format(
    #         ctx.label, _linkage,
    #         ctx.attr._linklevel[BuildSettingInfo].value))

    if (ctx.attr._linklevel[BuildSettingInfo].value == 0):
        if _linkage == "static":
            return impl_archive(ctx, _linkage)
        elif _linkage == "shared":
            return impl_archive(ctx, _linkage)
        else:
            return impl_library(ctx, _linkage)
    else:
        if ctx.attr.linkage: # explicit attr forces issue
            return impl_archive(ctx, _linkage)
        else:
            return impl_library(ctx, _linkage)

###############################
rule_options = options("rules_ocaml")
rule_options.update(options_aggregators())

#####################
ocaml_library = rule(
    implementation = _ocaml_library,
    doc = """Aggregates a collection of OCaml modules. [User Guide](../ug/ocaml_library.md). Provides: [OCamlLibraryProvider](providers_ocaml.md#ocamllibraryprovider).

An `ocaml_library` is a collection of modules packaged into an OBazl
target; it is not a single binary file. It is a OBazl convenience rule
that allows a target to depend on a collection of deps under a single
label, rather than having to list each individually.

Be careful not to confuse `ocaml_library` with `ocaml_archive`. The
latter generates OCaml binaries (`.cma`, `.cmxa`, '.a' archive files);
the former does not generate anything, it just passes on its
dependencies under a single label, packaged in a
[OCamlLibraryProvider](providers_ocaml.md#ocamllibraryprovider). For
more information see [Collections: Libraries, Archives and
Packages](../ug/collections.md).
    """,
    attrs = dict(
        rule_options,
        # archived = attr.bool(),
        archive_name = attr.string(
            doc = "Name of generated archive file, without extension. If not provided, name will be derived from target 'name' attribute.  Ignored if archived == False."
        ),
        _rule = attr.string( default = "ocaml_library" ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    ),
    ## this is not an ns library, and it does not use ns ConfigState,
    ## but we need to reset the ConfigState anyway, so the deps are not affected.
    # cfg     = module_in_transition,
    # cfg     = reset_in_transition,
    #NB: reset wipes configs, not good if this needs to pass on ns
    #deps to its deps
    # cfg     = nslib_in_transition,
    cfg     = toolchain_in_transition,
    provides = [OCamlLibraryProvider],
    executable = False,
    fragments = ["platform", "cpp"],
    host_fragments = ["platform",  "cpp"],
    toolchains = ["@rules_ocaml//toolchain/type:std",
                  "@rules_ocaml//toolchain/type:profile",
                  "@bazel_tools//tools/cpp:toolchain_type"]
)
