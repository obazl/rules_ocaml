load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//build:providers.bzl", "OCamlArchiveProvider", "OCamlLibraryProvider")

load("//build/_lib:apis.bzl", "options", "options_aggregators")

load("//build/_rules/ocaml_library:impl_archive.bzl", "impl_archive")
# load("//build/_rules/ocaml_library:impl_library.bzl", "impl_library")

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

    ## _linklevel controls propagation of linkage strategy
    ## lib built on cmd line (level 0): maybe archive
    ## lib built as dep: do not archive (unless forced)
    if (ctx.attr._linklevel[BuildSettingInfo].value == 0):
        if _linkage == "static":
            return impl_archive(ctx, _linkage)
        elif _linkage == "shared":
            return impl_archive(ctx, _linkage)
        else:
            return impl_archive(ctx, "static") #_linkage)
            # return impl_library(ctx, _linkage)
    else:
        if ctx.attr.linkage: # explicit attr forces issue
            return impl_archive(ctx, _linkage)
        else:
            return impl_archive(ctx, "static") #_linkage)
            # return impl_library(ctx, _linkage)

###############################
rule_options = options("rules_ocaml")
rule_options.update(options_aggregators())

#####################
ocaml_library = rule(
    implementation = _ocaml_library,
    doc = """Aggregates a collection of OCaml modules.

An `ocaml_library` is a collection of modules packaged into an OBazl
target; it is not a single binary file. It is an OBazl convenience rule
that allows a target to depend on a collection of deps under a single
label, rather than having to list each individually.

By default, libraries are not archived unless the client explicitly requests archiving.  If you build a library directly from the command line, you'll get an archive.  But if a rule depends on an `ocaml_library` target, no archive will be produced. This default policy can be overridden. For example, an `ocaml_binary` target can set `force_archived_libdeps` to True.

WARNING: This feature - context-dependent archiving - is still under development.
    """,
    attrs = dict(
        rule_options,
        # archived = attr.bool(),
        archive_name = attr.string(
            doc = "Name of generated archive file, without extension. If not provided, name will be derived from target 'name' attribute."
        ),
        _rule = attr.string( default = "ocaml_library" ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    ),
    cfg     = toolchain_in_transition,
    provides = [OCamlLibraryProvider, OCamlArchiveProvider],
    executable = False,
    fragments = ["platform", "cpp"],
    host_fragments = ["platform",  "cpp"],
    toolchains = ["@rules_ocaml//toolchain/type:std",
                  "@rules_ocaml//toolchain/type:profile",
                  "@bazel_tools//tools/cpp:toolchain_type"]
)
