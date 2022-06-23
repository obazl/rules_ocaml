load("//ocaml:providers.bzl",
     "OcamlVerboseFlagProvider",
     "OcamlModuleMarker")

################################################################
def _ocaml_null_module_impl(ctx):
  return OcamlModuleMarker()

ocaml_null_module = rule(
  implementation = _ocaml_null_module_impl,
)

################################################################
def _ocaml_verbose_impl(ctx):
    return OcamlVerboseFlagProvider(value = ctx.build_setting_value)

ocaml_verbose_flag = rule(
    implementation = _ocaml_verbose_impl,
    build_setting = config.bool(flag = True)
)

ocaml_verbose_setting = rule(
    implementation = _ocaml_verbose_impl,
    build_setting = config.bool(),
    doc = "A string-typed build setting that cannot be set on the command line",
)

################################################################
# def _ns_impl(ctx):
#     return NsProvider(
#         prefix  = "foo",
#         aliases = {"a" : "Alpha", "b": "Beta", "c": "Gamma"}
#     )

# ns_flag = rule(
#     implementation = _ns_impl,
#     build_setting = config.string_list(flag = True),
#     doc = "A string-typed build setting that can be set on the command line",
# )

# ns_setting = rule(
#     implementation = _ns_impl,
#     build_setting = config.string_list(),
#     doc = "A string-typed build setting that cannot be set on the command line",
# )

