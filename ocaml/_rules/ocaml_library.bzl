load("//ocaml:providers.bzl",
     "OcamlLibraryMarker")

load(":options.bzl", "options", "options_library")

load(":impl_library.bzl", "impl_library")

load("//ocaml/_transitions:transitions.bzl", "reset_in_transition")

###############################
def _ocaml_library(ctx):

    tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

    return impl_library(ctx, tc.emitting, tc.compiler, [])

###############################
rule_options = options("ocaml")
rule_options.update(options_library("ocaml"))

#####################
ocaml_library = rule(
    implementation = _ocaml_library,
    doc = """Aggregates a collection of OCaml modules. [User Guide](../ug/ocaml_library.md). Provides: [OcamlLibraryMarker](providers_ocaml.md#ocamllibraryprovider).

**WARNING** Not yet fully supported - subject to change. Use with caution.

An `ocaml_library` is a collection of modules packaged into an OBazl
target; it is not a single binary file. It is a OBazl convenience rule
that allows a target to depend on a collection of deps under a single
label, rather than having to list each individually.

Be careful not to confuse `ocaml_library` with `ocaml_archive`. The
latter generates OCaml binaries (`.cma`, `.cmxa`, '.a' archive files);
the former does not generate anything, it just passes on its
dependencies under a single label, packaged in a
[OcamlLibraryMarker](providers_ocaml.md#ocamllibraryprovider). For
more information see [Collections: Libraries, Archives and
Packages](../ug/collections.md).
    """,
    attrs = dict(
        rule_options,
        _rule = attr.string( default = "ocaml_library" ),
        _allowlist_function_transition = attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    ),
    ## this is not an ns library, and it does not use ns ConfigState,
    ## but we need to reset the ConfigState anyway, so the deps are not affected.
    cfg     = reset_in_transition,
    provides = [OcamlLibraryMarker],
    executable = False,
    toolchains = ["@rules_ocaml//toolchain:type"],
)
