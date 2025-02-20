# load("@rules_ocaml//build:providers.bzl",
#      # "OcamlDepsetProvider",
#      "OCamlSignatureProvider",
#      "OCamlModuleProvider",
#      "OcamlNsLibraryProvider",
#      "OCamlNsResolverProvider",
#      # "OpamDepsProvider",
#      "OcamlSDK")

####################################
## purpose: print all ccdeps in depgraph of target
## for this we use providers, not attributes
def _ccouts_aspect_impl(target, ctx):
    print("ccouts for rule: {}".format(ctx.label))
    print("OcamlProvider: %s" % target[OcamlProvider])
    # if hasattr(ctx.rule.attr, 'deps'):
    #     for dep in ctx.rule.attr.deps:
    #         print("dep: %s" % dep)
    #         # for path in dep[DefaultMemo].paths.to_list():
    #         #     print("Path: %s" % path)
    #         # if OpamDepsProvider in dep:
    #         #     for pkg in dep[OpamDepsProvider].pkgs.to_list():
    #         #         print("OPAM dep pkg: %s" % pkg)
    return []

ccouts = aspect(
    implementation = _ccouts_impl,
    attr_aspects = ["deps", "ppx_codeps", "modules", "submodules"],
)
