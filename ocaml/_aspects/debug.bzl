load("@rules_ocaml//build:providers.bzl", "OcamlProvider")

####################################
NsResolverInfo = provider(
    fields = {
        'files' : 'depset'
    }
)

FileCountInfo = provider(
    fields = {
        'count' : 'number of files'
    }
)

def _ns_resolver_impl(target, ctx):
    print("_ns_resolver aspect for rule: {}".format(ctx.label))
    # for a in dir(ctx.rule.attr):
    #     print("rule attr: %s" % a)
    resolver_src = None
    all
    if hasattr(ctx.rule.attr, '_ns_resolver'):
        print("_ns_resolver type: %s" % type(ctx.rule.attr._ns_resolver))
        if type(ctx.rule.attr._ns_resolver) == "list":
            for dep in ctx.rule.attr._ns_resolver:
                print("dep type: %s" % type(dep))
                print("dep.files type: %s" % type(dep.files))
                for f in dep.files.to_list():
                    print("ns_resolver: %s" % f)
                    if f.extension == "ml":
                        resolver_src = f
        else:
            return []

    # resolver_txt = ctx.actions.declare_file("%s.content" % resolver_src.basename)
    # print("RESOLVER_TXT: %s" % resolver_txt)

    # ctx.actions.run_shell(
    #     inputs = [resolver_src],
    #     outputs = [resolver_txt],
    #     command = "\n".join([
    #         "#!/bin/sh",
    #         "echo",
    #         "echo \"Content of {}:\"".format(resolver_src.path),
    #         "echo",
    #         "cat {src}".format(src = resolver_src.path),
    #         "echo",
    #         "touch {dst}".format(dst = resolver_txt.path)
    #     ])

    # )

    resolver_depset = depset([resolver_src])
    all_depset = depset(
        # direct = [resolver_txt],
        transitive=[dep.files for dep in ctx.rule.attr._ns_resolver]
    )

    resolverInfo = NsResolverInfo(files = resolver_depset )
    defaultInfo = DefaultInfo(files = resolver_depset)
    print("DEFAULT INFO %s" % defaultInfo)
    outputGroupInfo = OutputGroupInfo(
        all = all_depset,
        resolver = resolver_depset
    )
    return [defaultInfo, outputGroupInfo]

ns_resolver = aspect(
    implementation = _ns_resolver_impl,
    attr_aspects = []
)

