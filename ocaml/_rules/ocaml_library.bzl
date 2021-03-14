load("//ocaml:providers.bzl", "OcamlLibraryProvider")

load(":options.bzl", "options", "options_library")

load(":impl_library.bzl", "impl_library")

###############################
rule_options = options("ocaml")
rule_options.update(options_library("ocaml"))

#####################
ocaml_library = rule(
    implementation = impl_library,
    doc = """Aggregates a collection of OCaml modules. [User Guide](../ug/ocaml_library.md). Provides: [OcamlLibraryProvider](providers_ocaml.md#ocamllibraryprovider).

**WARNING** Not yet fully supported - subject to change. Use with caution.

An `ocaml_library` is a collection of modules packaged into an OBazl
target; it is not a single binary file. It is a OBazl convenience rule
that allows a target to depend on a collection of deps under a single
label, rather than having to list each individually.

Be careful not to confuse `ocaml_library` with `ocaml_archive`. The
latter generates OCaml binaries (`.cma`, `.cmxa`, '.a' archive files);
the former does not generate anything, it just passes on its
dependencies under a single label, packaged in a
[OcamlLibraryProvider](providers_ocaml.md#ocamllibraryprovider). For
more information see [Collections: Libraries, Archives and
Packages](../ug/collections.md).
    """,
    attrs = dict(
        rule_options,
        _rule = attr.string( default = "ocaml_library" )
    ),
    provides = [OcamlLibraryProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
