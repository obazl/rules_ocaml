load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "DefaultMemo",
     "OcamlDepsetProvider",
     "OcamlSignatureProvider",
     "OcamlModuleProvider",
     "OcamlNsLibraryProvider",
     "OcamlNsEnvProvider",
     "OpamDepsProvider",
     "OcamlSDK",
     "OpamPkgInfo")

def _print_aspect_impl(target, ctx):
    print("TARGET: %s" % target)
    if hasattr(ctx.rule.attr, 'deps'):
        for dep in ctx.rule.attr.deps:
            print("dep: %s" % dep)
            # for fdep in dep[DefaultInfo].files.to_list():
            #     print("NOPAM dep: %s" % fdep.path)
            for path in dep[DefaultMemo].paths.to_list():
                print("Path: %s" % path)
            if OpamDepsProvider in dep:
                for pkg in dep[OpamDepsProvider].pkgs.to_list():
                    print("OPAM dep pkg: %s" % pkg)
    if hasattr(ctx.rule.attr, 'submodules'):
        print("submods: %s" % ctx.rule.attr.submodules)
        for [f, m] in ctx.rule.attr.submodules.items():
            print("submod: %s" % m)
            for fdep in f[DefaultInfo].files.to_list():
                print("NOPAM dep: %s" % fdep.path)
            for path in f[DefaultMemo].paths.to_list():
                print("Path: %s" % path)
            # if OpamDepsProvider in f:
            #     print("OPAM deps: %s" % f[OpamDepsProvider])
            # if OcamlModuleProvider in f:
            #     print("Module Paths: %s" % f[OcamlModuleProvider].paths)
            #     print("Module resolvers: %s" % f[OcamlModuleProvider].resolvers)
            print("Submod: {m} -> {f}".format(
                m = m, f = f.label)
                  )
    if hasattr(ctx.rule.attr, 'struct'):
        print("struct: %s" % ctx.rule.attr.struct)
        for s in ctx.rule.attr.struct.files.to_list():
            print("Struct: %s" % s.path)
    return []

print_aspect = aspect(
    implementation = _print_aspect_impl,
    attr_aspects = ["submodules", "struct", "sig", "src", "deps", "deps_opam"],
)
