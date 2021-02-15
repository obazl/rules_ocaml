load("//ocaml:providers.bzl",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlArchiveProvider",
     "OcamlImportProvider",
     "OcamlSignatureProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxArchiveProvider")

load(":impl_library.bzl", "impl_library")

################################################################
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
       _sdkpath = attr.label( ## FIXME: delete?
            default = Label("@ocaml//:path")
        ),
        # lib_name = attr.string(),
        # doc = attr.string(),
        ## FIXME: remove opts
        # opts                    = attr.string_list(),
        ## FIXME: 'srcs' instead of 'deps'
        srcs = attr.label_list(
            providers = [[OpamPkgInfo],
                         [OcamlImportProvider],
                         [OcamlSignatureProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsLibraryProvider],
                         [OcamlArchiveProvider],
                         [PpxArchiveProvider]],
        ),
        modules = attr.label_list(
            doc = "List of OCaml dependencies.",
            providers = [[OpamPkgInfo],
                         [OcamlImportProvider],
                         [OcamlSignatureProvider],
                         [OcamlLibraryProvider],
                         [OcamlModuleProvider],
                         [OcamlNsArchiveProvider],
                         [OcamlNsLibraryProvider],
                         [OcamlArchiveProvider],
                         [PpxArchiveProvider]],
        ),
        _mode = attr.label(  ## FIXME: not needed?
            default = "@ocaml//mode"
        ),
        msg = attr.string( doc = "DEPRECATED" ),
        _rule = attr.string( default = "ocaml_library" )
    ),
    provides = [OcamlLibraryProvider],
    executable = False,
    toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
