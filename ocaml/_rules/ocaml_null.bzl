def _null_impl(ctx):

    print("null rule: %s" % ctx.label)

    tc = ctx.toolchains["@rules_ocaml//toolchain:type"]

####################
ocaml_null = rule(
    implementation = _null_impl,
    doc = """Rule for testing toolchains, etc.""",
    executable = False,
    toolchains = ["@rules_ocaml//toolchain:type"],
)
