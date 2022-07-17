load(":options.bzl", "options") # , "options_ns_resolver")

# load("//ocaml:providers.bzl",
#      "OcamlProvider")

## ocaml_spi targets provide the package containing the module needed
## to satisfy a module's SPI (i.e. a direct dep).

###############################
def _ocaml_spi_impl(ctx):

    defaultInfo = DefaultInfo(
    )

    return [defaultInfo]

###############################
rule_options = options("ocaml")

#########################
ocaml_spi = rule(
  implementation = _ocaml_spi_impl,
    doc = ""
    attrs = dict(
        rule_options,

        provider = attr.label(
            doc = "Packager (module, lib) providing the resource",
        ),

        _rule = attr.string(default = "ocaml_spi")
    ),
    provides = [OcamlProvider],
    executable = False,
    toolchains = [
        "@rules_ocaml//toolchain:type",
    ],
)
