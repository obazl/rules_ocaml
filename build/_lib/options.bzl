load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

# these are obazl-defined pseudo opts:
NEGATION_OPTS = [
    "-no-g", "-no-noassert",
    # "-no-bin-annot",
    "-no-linkall",
    "-no-short-paths", "-no-strict-formats", "-no-strict-sequence",
    "-no-keep-locs", "-no-opaque",
    "-no-thread", "-no-verbose",
    # "-no-alias-deps"
]

WARNING_FLAGS = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"

###################
# Hidden options (e.g. _debug, _opaque, etc.) are set by config
# setting rules, e.g. //cfg/debug, //cfg/opaque.
# We also check 'opts' to avoid duplicates.
# Special case: 'opaque' attr.
## FIXME rename: get_compile_options
## OR: pass args array prefilled from tc and tc_profile
def _get_options(ctx, options):
    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
    options.extend(tc.compile_opts)

    tc_profile = ctx.toolchains["@rules_ocaml//toolchain/type:profile"]
    options.extend(tc_profile.compile_opts)

    if ctx.attr._debug[BuildSettingInfo].value:
        if not "-no-g" in ctx.attr.opts:
            if not "-g" in ctx.attr.opts:  # avoid dup, use the one in opts
                options.append("-g")

    if hasattr(ctx.attr, "_cmt"):
        # cmd line wins:
        if ctx.attr._cmt[BuildSettingInfo].value:
            if not "-bin-annot" in options:
                options.append("-bin-annot")
            if "-no-bin-annot" in options:
                options.remove("-no-bin-annot")

        # then bld target
        elif "-bin-annot" in ctx.attr.opts:
            if not "-bin-annot" in options:
                options.append("-bin-annot")
            if "-no-bin-annot" in options:
                options.remove("-no-bin-annot")
        if "-no-bin-annot" in ctx.attr.opts:
            if "-bin-annot" in options:
                options.remove("-bin-annot")
            if "-no-bin-annot" in options:
                options.remove("-no-bin-annot")

    if hasattr(ctx.attr, "_keep_locs"):
        if ctx.attr._keep_locs[BuildSettingInfo].value:
            if not "-no-keep-locs" in ctx.attr.opts:
                if not "-keep-locs" in ctx.attr.opts:
                    options.append("-keep-locs")

    if hasattr(ctx.attr, "_noassert"):
        if ctx.attr._noassert[BuildSettingInfo].value:
            if not "-no-noassert" in ctx.attr.opts:
                if not "-noassert" in ctx.attr.opts:
                    options.append("-noassert")

    if hasattr(ctx.attr, "_xmo"):
        if ctx.attr._xmo[BuildSettingInfo].value:
            # default is no xmo, so user must have overridden
            # on cmd line
            if "-opaque" in options:
                options.remove("-opaque")

        # target opts override tc/profile opts
        elif "-no-opaque" in ctx.attr.opts:
                if "-opaque" in options:
                    options.remove("-opaque")
                if "-no-opaque" in options:
                    options.remove("-no-opaque")
        elif "-opaque" in ctx.attr.opts:
            if not "-opaque" in options:
                options.append("-opaque")
            if "-no-opaque" in options:
                options.remove("-no-opaque")

    if hasattr(ctx.attr, "_short_paths"):
        if ctx.attr._short_paths[BuildSettingInfo].value:
            if not "-no-short-paths" in ctx.attr.opts:
                if not "-short-paths" in ctx.attr.opts:
                    options.append("-short-paths")

    if hasattr(ctx.attr, "_strict_formats"):
        # if "-no-strict-formats" in ctx.attr.opts:
        #     if "-strict-formats" in ctx.attr.opts:
        #         options.remove("-strict-formats")

        if ctx.attr._strict_formats[BuildSettingInfo].value:
            if not "-no-strict-formats" in ctx.attr.opts:
                if not "-strict-formats" in ctx.attr.opts:
                    options.append("-strict-formats")

    if hasattr(ctx.attr, "_strict_sequence"):
        # if "-no-strict-sequence" in ctx.attr.opts:
        #     if "-strict-sequence" in ctx.attr.opts:
        #         options.remove("-strict-sequence")

        if ctx.attr._strict_sequence[BuildSettingInfo].value:
            if not "-no-strict-sequence" in ctx.attr.opts:
                if not "-strict-sequence" in ctx.attr.opts:
                    options.append("-strict-sequence")

    if hasattr(ctx.attr, "_verbose"):
        if ctx.attr._verbose[BuildSettingInfo].value:
            if not "-no-verbose" in ctx.attr.opts:
                if not "-verbose" in ctx.attr.opts:
                    options.append("-verbose")

    ################################################################
    if hasattr(ctx.attr, "_thread"):
        if ctx.attr._thread[BuildSettingInfo].value:
            if not "-no-thread" in ctx.attr.opts:
                if not "-thread" in ctx.attr.opts:
                    options.append("-thread")

    if hasattr(ctx.attr, "_linkall"):
        if ctx.attr._linkall[BuildSettingInfo].value:
            if not "-no-linkall" in ctx.attr.opts:
                if not "-linkall" in ctx.attr.opts:
                    options.append("-linkall")

    if hasattr(ctx.attr, "_warnings"):
        if ctx.attr._warnings:
            for opt in ctx.attr._warnings[BuildSettingInfo].value:
                options.extend(["-w", opt])

    if hasattr(ctx.attr, "_opts"):
        for opt in ctx.attr._opts[BuildSettingInfo].value:
            if opt not in NEGATION_OPTS:
                options.append(opt)

    ################################################################
    ## MUST COME LAST - instance opts override configurable defaults
    ## FIXME: but we also want opts passed on the cmd line
    ## to have precedence.
    # print("OPTS {}: {}".format(ctx.label, options))
    # print("ATTR.OPTS {}: {}".format(ctx.label, ctx.attr.opts))

    ## FIXME: handle obazl-defined pseudo-opts like -no-opaque
    for arg in ctx.attr.opts:
        if arg not in NEGATION_OPTS:
            options.append(arg)

    return options

################################################################
def get_module_options(ctx):
    options = []
    tc = ctx.toolchains["@rules_ocaml//toolchain/type:std"]
    options.extend(tc.module_compile_opts)
    return _get_options(ctx, options)

def get_options(rule, ctx):
    options = []
    return _get_options(ctx, options)
