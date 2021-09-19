load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml:providers.bzl",
     "OcamlNsLibraryMarker",
     "OcamlNsResolverProvider")
     # "PpxNsLibraryMarker")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_fs_prefix",
     "get_opamroot",
     "get_sdkpath",
     "submodule_from_label_string"
)

load("//ocaml/_rules:impl_common.bzl", "tmpdir")

######################################################
def _this_module_in_submod_list(ctx, src, submodules):
    ## NB: src is a File, from a label attrib (struct/src), not to be confused with the rule name.
    # src.owner is the label of the rule that produces the file.
    # By obazl rules, module names after normalization must match the filename in their src/struct attrib.
    (this_module, ext) = paths.split_extension(src.basename)
    this_module = capitalize_initial_char(this_module)
    this_owner  = src.owner
    ns_resolver = ctx.attr._ns_resolver[OcamlNsResolverProvider]

    result = False

    submods = []
    for lbl_string in submodules:
        submod = Label(lbl_string + ".ml")
        (submod_path, submod_name) = submodule_from_label_string(lbl_string)
        if this_module == submod_name:
            if this_owner.package == submod.package:
                result = True

    return result

###################################
## FIXME: we don't need this for executables (including test rules)
# if this is a submodule, add the prefix
# otherwise, if ppx, rename
def get_module_name (ctx, src):
    ## src: for modules, ctx.file.struct, for sigs, ctx.file.src
    debug = False
    # if ctx.label.name in ["_Red", "_Green", "_Blue"]:
    #     debug = True

    ns_resolver = ctx.attr._ns_resolver[OcamlNsResolverProvider]

    ns     = None
    ns_sep = "__"

    (this_module, extension) = paths.split_extension(src.basename)
    this_module = capitalize_initial_char(this_module)

    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "prefixes"): # "prefix"):
        ns_prefixes = ctx.attr._ns_resolver[OcamlNsResolverProvider].prefixes # .prefix
        if len(ns_prefixes) == 0:
            out_module = this_module
        elif this_module == ns_prefixes[-1]:
            # this is a main ns module
            out_module = this_module
        else:
            if len(ns_resolver.submodules) > 0:
                if _this_module_in_submod_list(ctx, src, ns_resolver.submodules):
                    # if ctx.attr._ns_strategy[BuildSettingInfo].value == "fs":
                    #     fs_prefix = get_fs_prefix(str(ctx.label)) + "__"
                    # else:
                    fs_prefix = "__".join(ns_prefixes) + "__"
                    out_module = fs_prefix + this_module
                else:
                    out_module = this_module
            else:
                out_module = this_module
    else: ## not a submodule
        out_module = this_module

    return this_module, out_module

################################################################
def rename_module(ctx, src):  # , pfx):
  """Rename implementation and interface (if given) using ns_resolver.

  Inputs: context, src
  Outputs: outfile :: declared File
  """

  debug = False
  # if ctx.label.name in ["_Red", "_Green", "_Blue"]:
  #     debug = True

  out_filename = get_module_name(ctx, src)

  inputs  = []
  outputs = {}
  inputs.append(src)

  scope = tmpdir

  outfile = ctx.actions.declare_file(scope + out_filename)

  destdir = paths.normalize(outfile.dirname)

  cmd = ""
  dest = outfile.path
  cmd = cmd + "mkdir -p {destdir} && cp {src} {dest} && ".format(
    src = src.path,
    destdir = destdir,
    dest = dest
  )

  cmd = cmd + " true;"

  ## use native.genrule?
  ctx.actions.run_shell(
      exec_group = "compile",
      command = cmd,
      inputs = inputs,
      outputs = [outfile],
      mnemonic = ctx.attr._rule + "_rename_module",
      progress_message = "{rule}: rename_module {src}".format(
          rule = ctx.attr._rule,
          # n    = ctx.label.name,
        src  = src
      )
  )
  return outfile

################################################################
def rename_srcfile(ctx, src, dest):
    """Rename src file.  Copies input src to output dest"""
    print("**** RENAME SRC {s} => {d} ****".format(s=src, d=dest))

    inputs  = [src]

    scope = tmpdir

    outfile = ctx.actions.declare_file(scope + dest)

    destdir = paths.normalize(outfile.dirname)

    cmd = ""
    destpath = outfile.path
    cmd = cmd + "mkdir -p {destdir} && cp {src} {dest} && ".format(
      src = src.path,
      destdir = destdir,
      dest = destpath
    )

    cmd = cmd + " true;"

    ctx.actions.run_shell(
      command = cmd,
      inputs = inputs,
      outputs = [outfile],
      mnemonic = (ctx.attr._rule + "_rename_src").replace("_", ""),
      progress_message = "{rule}: rename_src {src}".format(
          rule =  ctx.attr._rule,
          # ctx.label.name,
          src  = src
      )
    )
    return outfile
