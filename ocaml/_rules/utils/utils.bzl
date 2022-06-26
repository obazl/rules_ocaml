load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//ocaml:providers.bzl", "OcamlVerboseFlagProvider")

NEGATION_OPTS = [
    "-no-g", "-no-noassert",
    "-no-linkall",
    "-no-short-paths", "-no-strict-formats", "-no-strict-sequence",
    "-no-keep-locs", "-no-opaque",
    "-no-thread", "-no-verbose"
]

# Hidden options (e.g. _debug, _opaque, etc.) are set by config
# setting rules, e.g. //cfg/debug, //cfg/opaque.
# We also check 'opts' to avoid duplicates.
# Special case: 'opaque' attr.
def get_options(rule, ctx):
    options = []

    if ctx.attr._debug[BuildSettingInfo].value:
        if not "-no-g" in ctx.attr.opts:
            if not "-g" in ctx.attr.opts: # avoid dup, use the one in opts
                options.append("-g")

    if hasattr(ctx.attr, "_cmt"):
        if ctx.attr._cmt[BuildSettingInfo].value:
            if not "-no-bin-annot" in ctx.attr.opts:
                if not "-bin-annot" in ctx.attr.opts: # avoid dup, use the one in opts
                    options.append("-bin-annot")

    if hasattr(ctx.attr, "_keep_locs"):
        if ctx.attr._keep_locs[BuildSettingInfo].value:
            if not "-no-keep-locs" in ctx.attr.opts:
                if not "-keep-locs" in ctx.attr.opts: # avoid dup, use the one in opts
                    options.append("-keep-locs")

    if hasattr(ctx.attr, "_noassert"):
        if ctx.attr._noassert[BuildSettingInfo].value:
            if not "-no-noassert" in ctx.attr.opts:
                if not "-noassert" in ctx.attr.opts: # avoid dup, use the one in opts
                    options.append("-noassert")

    # if hasattr(ctx.attr, "_opaque"):
    #     if ctx.attr._opaque[BuildSettingInfo].value:
    #         if not "-no-opaque" in ctx.attr.opts:
    #             if not "-opaque" in ctx.attr.opts: # avoid dup, use the one in opts
    #                 options.append("-opaque")

    # if hasattr(ctx.attr, "_xmo"):
    #     if not ctx.attr._xmo[BuildSettingInfo].value:
    #         if not "-no-opaque" in ctx.attr.opts:
    #             if not "-opaque" in ctx.attr.opts: # avoid dup, use the one in opts
    #                 options.append("-opaque")

    if hasattr(ctx.attr, "_short_paths"):
        if ctx.attr._short_paths[BuildSettingInfo].value:
            if not "-no-short-paths" in ctx.attr.opts:
                if not "-short-paths" in ctx.attr.opts: # avoid dup
                    options.append("-short-paths")
    if hasattr(ctx.attr, "_strict_formats"):
        if ctx.attr._strict_formats[BuildSettingInfo].value:
            if not "-no-strict-formats" in ctx.attr.opts:
                if not "-strict-formats" in ctx.attr.opts: # avoid dup, use the one in opts
                    options.append("-strict-formats")

    if hasattr(ctx.attr, "_strict_sequence"):
        if ctx.attr._strict_sequence[BuildSettingInfo].value:
            if not "-no-strict-sequence" in ctx.attr.opts:
                if not "-strict-sequence" in ctx.attr.opts: # avoid dup, use the one in opts
                    options.append("-strict-sequence")

    if hasattr(ctx.attr, "_verbose"):
        if ctx.attr._verbose[OcamlVerboseFlagProvider].value:
            if not "-no-verbose" in ctx.attr.opts:
                if not "-verbose" in ctx.attr.opts: # avoid dup, use the one in opts
                    options.append("-verbose")

    ################################################################
    if hasattr(ctx.attr, "_thread"):
        if ctx.attr._thread[BuildSettingInfo].value:
            if not "-no-thread" in ctx.attr.opts:
                if not "-thread" in ctx.attr.opts: # avoid dup, use the one in opts
                    options.append("-thread")

    if hasattr(ctx.attr, "_linkall"):
        if ctx.attr._linkall[BuildSettingInfo].value:
            if not "-no-linkall" in ctx.attr.opts:
                if not "-linkall" in ctx.attr.opts: # avoid dup
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
    for arg in ctx.attr.opts:
        if arg not in NEGATION_OPTS:
            options.append(arg)

    return options

