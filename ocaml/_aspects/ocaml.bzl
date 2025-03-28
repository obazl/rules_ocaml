####################################
def _print_aspect_impl(target, ctx):
    print("TARGET: %s" % target)
    if hasattr(ctx.rule.attr, 'struct'):
        print("STRUCT %s" % ctx.rule.attr.struct)
    if hasattr(ctx.rule.attr, 'sig'):
        print("SIG %s" % ctx.rule.attr.sig)

    if hasattr(ctx.rule.attr, 'deps'):
        for dep in ctx.rule.attr.deps:
            print("dep: %s" % dep)
            # for path in dep[DefaultMemo].paths.to_list():
            #     print("Path: %s" % path)
            # if OpamDepsProvider in dep:
            #     for pkg in dep[OpamDepsProvider].pkgs.to_list():
            #         print("OPAM dep pkg: %s" % pkg)
    if hasattr(ctx.rule.attr, 'submodules'):
        print("submods: %s" % ctx.rule.attr.manifest)
        for [f, m] in ctx.rule.attr.manifest.items():
            print("submod: %s" % m)
            for fdep in f[DefaultInfo].files.to_list():
                print("NOPAM dep: %s" % fdep.path)
            # for path in f[DefaultMemo].paths.to_list():
            #     print("Path: %s" % path)
            # if OpamDepsProvider in f:
            #     print("OPAM deps: %s" % f[OpamDepsProvider])
            # if OCamlModuleProvider in f:
            #     print("Module Paths: %s" % f[OCamlModuleProvider].paths)
            #     print("Module resolvers: %s" % f[OCamlModuleProvider].resolvers)
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
    attr_aspects = ["submodules", "struct", "sig", "src", "deps"],
)

####################################
def _providers_impl(target, ctx):
    print("TARGET: %s" % target)
    for dep in target[DefaultInfo].files.to_list():
        print(dep)

    report = "REPORT "
    if CcInfo in target:
        report = report + "CC DEPS:"
        for cc in target[CcInfo].libs:
            report = report + str(cc)

    report_file = ctx.actions.declare_file("providers.txt")
    print("WRITING file: %s" % report_file.path)
    print("CONTENT: %s" % report)

    ctx.actions.write(
        report_file,
        report
    )

    return [
        OutputGroupInfo(
            providers = depset([report_file])
        )
    ]

providers = aspect(
    implementation = _providers_impl,
    attr_aspects = [],
)
