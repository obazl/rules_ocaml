load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

load("//ocaml:providers.bzl", "OcamlSDK")

WARNING_FLAGS = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"

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
        ws  = capitalize_initial_char(lbl.workspace_name) + "_"
    else:
        ws  = ""
    # print(" FS WS: %s" % ws)
    pathsegs = [x.replace("-", "_").capitalize() for x in lbl.package.split('/')]
    # ns_prefix = ws + ctx.attr.sep + ctx.attr.sep.join(pathsegs)

    prefix = ws + "_".join(pathsegs)
    # print("FS PREFIX: %s" % prefix)

    return prefix

###############################
def capitalize_initial_char(s):
  """Starlark's capitalize fn downcases everything but the first char.  This fn only affects first char."""
  # first = s[:1]
  # rest  = s[1:]
  # return first.capitalize() + rest
  return s[:1].capitalize() + s[1:]

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
