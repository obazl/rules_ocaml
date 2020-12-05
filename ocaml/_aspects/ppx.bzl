def _print_aspect_impl(target, ctx):
    # Make sure the rule has a ppx attribute.
    if hasattr(ctx.rule.attr, 'ppx'):
        # Iterate through the files that make up the sources and
        # print their paths.
        if ctx.rule.attr.ppx == None:
            print(ctx.label.name + ": None")
        else:
            print(ctx.label.name + ": " + ctx.rule.file.ppx.path)
    return []

print_aspect = aspect(
    implementation = _print_aspect_impl,
    attr_aspects = ['ppx'],
)

## deps aspect: run ocamldep with -ppx, print output to file

## ppx_deps aspect - run ppx transform then ocamldep and print deps
## run the transform on the original source - ignore ns

## maybe: run ocamldep with -ppx arg

## todo: show only direct deps
