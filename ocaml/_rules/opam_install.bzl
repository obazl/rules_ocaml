load("//providers:ocaml.bzl",
     "OcamlArchiveMarker",
     "OcamlExecutableMarker",
     "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlNsResolverProvider",
     "OcamlModuleMarker",
     "OcamlNsMarker",
     "OcamlNsSubmoduleMarker",
     "OcamlProvider",
     "OcamlSignatureProvider",
)
load("//providers:codeps.bzl",
     "PpxExecutableMarker",
)

############################
def _opam_install_impl(ctx):

    print("opam_install rule: %s" % ctx.label)
    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]

    for dep in ctx.attr.lib:
        print("dep: %s" % dep)
        print("FILES: %s" % dep[DefaultInfo].files)
        provider = dep[OcamlProvider]
        print("ARCHIVES: %s" % provider.archives)
        print("SIGS: %s" % provider.sigs)
        print("STRUCTS: %s" % provider.structs)
        print("ASTRUCTS: %s" % provider.astructs)
        print("AFILES: %s" % provider.afiles)
        print("OFILES: %s" % provider.ofiles)

    return None

##########################
opam_install = rule(
    implementation = _opam_install_impl,
    doc = """Rule for installing to OPAM.""",
    executable = False,
    attrs = dict(
        bin = attr.label_list(
            providers = [OcamlProvider]
        ),
        lib = attr.label_list(
            providers = [OcamlProvider]
        ),
    ),
    toolchains = ["@rules_ocaml//toolchain/type:std"],
)
