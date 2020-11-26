load("//ppx:_providers.bzl",
     "PpxCompilationModeSettingProvider",
     "PpxPrintSettingProvider"
     )

################################################################
def _ppx_compilation_mode_impl(ctx):
    if ctx.build_setting_value not in ["native", "bytecode"]:
        fail("Bad value for @ppx//print. Allowed values: native | bytecode")
    return PpxCompilationModeSettingProvider(value = ctx.build_setting_value)

ppx_compilation_mode_flag = rule(
    implementation = _ppx_compilation_mode_impl,
    build_setting = config.string(flag = True),
    doc = "Compilation mode command-line option: native or bytecode",
)

ppx_compilation_mode_setting = rule(
    implementation = _ppx_compilation_mode_impl,
    build_setting = config.string(),
    doc = "Compilation mode constant setting.",
)

################################################################
def _ppx_print_impl(ctx):
    if ctx.build_setting_value not in ["binary", "text"]:
        fail("Bad value for @ppx//print. Allowed values: binary | text")
    return PpxPrintSettingProvider(value = ctx.build_setting_value)

ppx_print_flag = rule(
    implementation = _ppx_print_impl,
    build_setting = config.string(flag = True),
    doc = "PPX output format command-line option: binary or text.",
)

ppx_print_setting = rule(
    implementation = _ppx_print_impl,
    build_setting = config.string(),
    doc = "PPX output format constant setting."
)
