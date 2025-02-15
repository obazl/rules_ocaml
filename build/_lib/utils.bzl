load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
# load("@bazel_skylib//lib:paths.bzl", "paths")

NEGATION_OPTS = [
    "-no-g", "-no-noassert",
    "-no-linkall",
    "-no-short-paths", "-no-strict-formats", "-no-strict-sequence",
    "-no-keep-locs", "-no-opaque",
    "-no-thread", "-no-verbose",
    "-no-alias-deps"
]

WARNING_FLAGS = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"

## ocaml/_rules/common.bzl
tmpdir = "__obazl/"

dsorder = "postorder"

# opam_lib_prefix = "external/ocaml/lib"

module_sep = "__"

resolver_suffix = module_sep + "0Resolver"

#######################
def get_fs_prefix(lbl_string):
    # print("GET_FS_PREFIX: %s" % lbl_string)
    ## lbl_string is a string, not a label

    # if ctx.workspace_name == "__main__": # default, if not explicitly named
    #     ws = ctx.workspace_name
    # else:
    #     ws = ctx.label.workspace_name
    # print("WS: %s" % ws)
    # ws = capitalize_initial_char(ws) if ws else ""

    lbl = Label(lbl_string)
    if lbl_string.startswith("@"):
        # ws  = capitalize_initial_char(lbl.workspace_name) + "_"
        ws = lbl.workspace_name[:1].capitalize() + lbl.workspace_name[1:]

    else:
        ws  = ""
    # print(" FS WS: %s" % ws)
    pathsegs = [x.replace("-", "_").capitalize() for x in lbl.package.split('/')]
    # ns_prefix = ws + ctx.attr.sep + ctx.attr.sep.join(pathsegs)

    prefix = ws + "_".join(pathsegs)
    # print("FS PREFIX: %s" % prefix)

    return prefix

###############################
# def capitalize_initial_char(s):
#   """Starlark's capitalize fn downcases everything but the first char.  This fn only affects first char."""
#   # first = s[:1]
#   # rest  = s[1:]
#   # return first.capitalize() + rest
#   return s[:1].capitalize() + s[1:]

#####################################################
def get_src_root(ctx, root_file_names = ["main.ml"]):
  if (ctx.file.src_root != None):
    return ctx.file.src_root
  elif (len(ctx.files.srcs) == 1):
    return ctx.files.srcs[0]
  else:
    for src in ctx.files.srcs:
      if src.basename in root_file_names:
        return src
  fail("No %s source file found." % " or ".join(root_file_names), "srcs")

#############################
def strip_ml_extension(path): #FIXME: use paths.split_extension()
  if path.endswith(".ml"):
    return path[:-3]
  else:
    return path

###################
def get_opamroot():
    return Label("@ocaml_sdk//opamroot").workspace_root + "/" + Label("@ocaml_sdk//opamroot").package

######################
def get_projroot(ctx):
    return ctx.attr._projroot[BuildSettingInfo].value

#####################
def get_sdkpath(ctx):
  sdkpath = ctx.attr._sdkpath[BuildSettingInfo].value + "/bin"
  return sdkpath + ":/usr/bin:/bin:/usr/sbin:/sbin"

#####################
def split_srcs(srcs):
  intfs = []
  impls = []
  for s in srcs:
    if s.extension == "ml":
      impls.append(s)
    else:
      intfs.append(s)
  return intfs, impls

####################
# Hidden options (e.g. _debug, _opaque, etc.) are set by config
# setting rules, e.g. //cfg/debug, //cfg/opaque.
# We also check 'opts' to avoid duplicates.
# Special case: 'opaque' attr.
def get_options(rule, ctx):
    options = []
    tc_options = ctx.toolchains["@rules_ocaml//toolchain/type:profile"]
    options.extend(tc_options.compile_opts)

    # last arg wins - target opts override profile opts
    options.extend(ctx.attr.opts)

    if ctx.attr._debug[BuildSettingInfo].value:
        if not "-no-g" in options:
            if not "-g" in options:  # avoid dup, use the one in opts
                options.append("-g")

    if hasattr(ctx.attr, "_cmt"):
        if ctx.attr._cmt[BuildSettingInfo].value:
            if not "-no-bin-annot" in options:
                if not "-bin-annot" in options:
                    options.append("-bin-annot")
    #options.append("-bin-annot")
    # elif "//command_line_option:output_groups" == "cmti":

    if hasattr(ctx.attr, "_keep_locs"):
        if ctx.attr._keep_locs[BuildSettingInfo].value:
            if not "-no-keep-locs" in options:
                if not "-keep-locs" in options:
                    options.append("-keep-locs")

    if hasattr(ctx.attr, "_noassert"):
        if ctx.attr._noassert[BuildSettingInfo].value:
            if not "-no-noassert" in options:
                if not "-noassert" in options:
                    options.append("-noassert")

    # if hasattr(ctx.attr, "_opaque"):
    #     if ctx.attr._opaque[BuildSettingInfo].value:
    #         if not "-no-opaque" in options:
    #             if not "-opaque" in options: # avoid dup, use the one in opts
    #                 options.append("-opaque")

    if hasattr(ctx.attr, "_xmo"):
        # print("XMO: %s" % ctx.attr._xmo[BuildSettingInfo].value)
        if "-no-opaque" in options:
            options.remove("-no-opaque")
        else:
            if not "-opaque" in options:
            #     options.append("-opaque")
            # else:
                if not ctx.attr._xmo[BuildSettingInfo].value:
                    options.append("-opaque")

    if hasattr(ctx.attr, "_short_paths"):
        if ctx.attr._short_paths[BuildSettingInfo].value:
            if not "-no-short-paths" in options:
                if not "-short-paths" in options:
                    options.append("-short-paths")

    if hasattr(ctx.attr, "_strict_formats"):
        # if "-no-strict-formats" in options:
        #     if "-strict-formats" in options:
        #         options.remove("-strict-formats")

        if ctx.attr._strict_formats[BuildSettingInfo].value:
            if not "-no-strict-formats" in options:
                if not "-strict-formats" in options:
                    options.append("-strict-formats")

    if hasattr(ctx.attr, "_strict_sequence"):
        # if "-no-strict-sequence" in options:
        #     if "-strict-sequence" in options:
        #         options.remove("-strict-sequence")

        if ctx.attr._strict_sequence[BuildSettingInfo].value:
            if not "-no-strict-sequence" in options:
                if not "-strict-sequence" in options:
                    options.append("-strict-sequence")

    if hasattr(ctx.attr, "_verbose"):
        if ctx.attr._verbose[BuildSettingInfo].value:
            if not "-no-verbose" in options:
                if not "-verbose" in options:
                    options.append("-verbose")

    ################################################################
    if hasattr(ctx.attr, "_thread"):
        if ctx.attr._thread[BuildSettingInfo].value:
            if not "-no-thread" in options:
                if not "-thread" in options:
                    options.append("-thread")

    if hasattr(ctx.attr, "_linkall"):
        if ctx.attr._linkall[BuildSettingInfo].value:
            if not "-no-linkall" in options:
                if not "-linkall" in options:
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

