load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml:providers.bzl",
     "OcamlNsLibraryProvider",
     "OcamlNsResolverProvider")
     # "PpxNsLibraryProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_fs_prefix",
     "get_opamroot",
     "get_sdkpath",
     "submodule_from_label_string"
)

tmpdir = "_obazl_/"

######################################################
def _this_module_in_submod_list(ctx, src, submodules):
    # print("XXXX SRC PATH: %s" % src.path)
    (this_module, ext) = paths.split_extension(src.basename)
    this_module = capitalize_initial_char(this_module)
    this_path   = paths.dirname(src.path)

    # print("THIS PATH: %s" % this_path)
    # print("THIS_MODULE: %s" % this_module)

    ns_resolver = ctx.attr._ns_resolver[OcamlNsResolverProvider]
    # print("SUBMODULES:  %s" % ns_resolver.submodules)

    submods = []
    for lbl_string in submodules:
        # print("Submod label: %s" % lbl_string)
        # print("Submod path: %s" % Label(lbl_string).package)
        # print("Submod target: %s" % Label(lbl_string).name)
        (submod_path, submod_name) = submodule_from_label_string(lbl_string)
        # print("Normalized submod path: %s" % submod_path)
        # print("Normalized submod name: %s" % submod_name)

        if this_module == submod_name:
            if this_path == submod_path:
                return True

    return False
    # submod_names = _submod_labels_to_submod_names(ns_resolver.submodules)
    # print("SUBMOD_NAMES: %s" % submod_names)
    # if this_module in submod_names:

###################################
## FIXME: we don't need this for executables (including test rules)
# if this is a submodule, add the prefix
# otherwise, if ppx, rename
def get_module_name (ctx, src):
    ## src: for modules, ctx.file.struct, for sigs, ctx.file.src
    debug = False
    # if ctx.label.name in ["_Red", "_Green", "_Blue"]:
    #     debug = True
    #     print("GET_MODULE_FILENAME for src: %s" % src)

    ns     = None
    ns_sep = "__"

    (this_module, extension) = paths.split_extension(src.basename)
    this_module = capitalize_initial_char(this_module)

    if hasattr(ctx.attr._ns_resolver[OcamlNsResolverProvider], "prefix"):
        ns = ctx.attr._ns_resolver[OcamlNsResolverProvider].prefix
        print("AAAAAAAAAAAAAAAA ns %s" % ns)
        print("AAAAAAAAAAAAAAAA this %s" % this_module)
        if this_module == ns:
            out_module = this_module
        else:
            ns_resolver = ctx.attr._ns_resolver[OcamlNsResolverProvider]
            if len(ns_resolver.submodules) > 0:
                # (this_module, ext) = paths.split_extension(src.basename)
                # this_module = capitalize_initial_char(this_module)
                # if debug:
                #     print("THIS_MODULE: %s" % this_module)
                #     print("SUBMODULES:  %s" % ns_resolver.submodules)

                # submod_names = _submod_labels_to_submod_names(ns_resolver.submodules)
                # print("SUBMOD_NAMES: %s" % submod_names)
                # if this_module in submod_names:

                if _this_module_in_submod_list(ctx, src, ns_resolver.submodules):
                    if ctx.attr._ns_strategy[BuildSettingInfo].value == "fs":
                        fs_prefix = get_fs_prefix(str(ctx.label)) + "__"
                    else:
                        fs_prefix = ns + "__"
                    # out_srcfile = rename_submodule(ctx, fs_prefix, src)
                    out_module = fs_prefix + this_module
                else:
                    # out_srcfile = src
                    out_module = this_module
            else:
                # out_srcfile = src
                out_module = this_module

    # if hasattr(ctx.attr, "_ns_resolver"):  # ocaml_module, ocaml_ns_library
    #     hidden_resolver = ctx.attr._ns_resolver[OcamlNsResolverProvider]
    #     ## disallow hand-rolled nslibs
    #     # if hasattr(ctx.attr, "ns"): ## ocaml_module only
    #     if hasattr(ctx.attr, "_ns_prefix"):
    #         if debug:
    #             print("_NS_PREFIX: %s" % ctx.attr._ns_prefix[BuildSettingInfo].value)
    #         _apfx = ctx.attr._ns_prefix[BuildSettingInfo].value
    #         _pkg = paths.basename(ctx.label.package)
    #         if _apfx != "":
    #             if _apfx == _pkg:
    #                 print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXX _pkg %s" % _pkg)
    #                 print("LABEL: %s" % ctx.label)
    #                 ns = _apfx
    #             else:
    #                 ns = _apfx

    # elif hasattr(ctx.attr, "_ns_prefix"):  # ocaml_signature
    #     ns = ctx.attr._ns_prefix[BuildSettingInfo].value

    # elif ctx.attr._rule == "ocaml_test":
    #     ns = None
    else: ## not a submodule
        out_module = this_module

    # (basename, extension) = paths.split_extension(src.basename)
    # if ctx.attr._rule in ["ocaml_test", "ocaml_executable", "ppx_executable"]:
    #     module = basename
    # else:
    #     module = capitalize_initial_char(basename)

    # if ns == None: ## no ns
    #     out_filename = out_module
    # else:
    #     if ns.lower() == module.lower(): # this is main ns module, do not rename
    #         out_filename = module
    #     elif ns != "":
    #         out_filename = capitalize_initial_char(ns) + ns_sep + module
    #     else:
    #         out_filename = module

    # out_filename = out_module + extension
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

  # print("RENAME module %s" % src)

  # if module name == ns, then output module name
  # otherwise, outputp ns + "__" + module name

  out_filename = get_module_name(ctx, src)
  # if (module == ns):
  #   out_filename = module + extension
  # else:
  #   out_filename = ns + capitalize_initial_char(module) + extension
  if debug:
      print("RENAMED MODULE %s" % out_filename)

  # if pfx.find("/") > 0:
  #   fail("ERROR: ns contains '/' : '%s'" % pfx)

  inputs  = []
  # outputs = []
  outputs = {}
  inputs.append(src)
  # if ctx.attr._ns_pkg[BuildSettingInfo].value == "":
  #     scope = tmpdir
  # else:
  #     print("NS_PKG: %s" % ctx.attr._ns_pkg[BuildSettingInfo])
  #     scope = ctx.attr._ns_pkg[BuildSettingInfo].value + "/"
  # scope = tmpdir
  # (scope, ext) = paths.split_extension(src.basename)
  # scope = ctx.attr._ns_prefix[BuildSettingInfo].value
  # outfile = ctx.actions.declare_file(scope + "/" + out_filename)
  outfile = ctx.actions.declare_file(out_filename)

  destdir = paths.normalize(outfile.dirname)
  # print("DESTDIR: %s" % destdir)

  cmd = ""
  dest = outfile.path
  # print("DEST: %s" % dest)
  # cmd = cmd + "touch {dest}; ".format(dest = bindir + "/" + tmpdir + src.path)
  cmd = cmd + "mkdir -p {destdir} && cp {src} {dest} && ".format(
    src = src.path,
    destdir = destdir,
    dest = dest
  )

  cmd = cmd + " true;"
  # print("CMD: %s" % cmd)
  # print("CP SRCS")

  ctx.actions.run_shell(
    # env = env,
    command = cmd,
    inputs = inputs,
    outputs = [outfile],
    progress_message = "rename_src_action ({}){}".format(
      ctx.label.name, src
    )
  )
  return outfile

################################################################
def rename_srcfile(ctx, src, to):
    """Rename implementation and interface (if given) using ns_resolver.

    Inputs: context, prefix
    Outputs: outfile :: declared File
    """

    debug = True
    # if ctx.label.name in ["_Red", "_Green", "_Blue"]:
    #     debug = True

    print("RENAME submodule {src} to {dest}".format(src=src, dest=to))

    # if module name == ns, then output module name
    # otherwise, outputp ns + "__" + module name

    # (basename, extension) = paths.split_extension(src.basename)
    # if ctx.attr._rule in ["ocaml_test", "ocaml_executable", "ppx_executable"]:
    #     module = basename
    # else:
    #     module = capitalize_initial_char(basename)

    # if module == ctx.attr._ns_prefix[BuildSettingInfo].value:
    #     out_filename = module + extension
    # else:
    #     out_filename = prefix + "__" + module + extension

    # if debug:
    #     print("RENAMED MODULE %s" % out_filename)

    # if pfx.find("/") > 0:
    #   fail("ERROR: ns contains '/' : '%s'" % pfx)

    inputs  = []
    # outputs = []
    outputs = {}
    inputs.append(src)
    # if ctx.attr._ns_pkg[BuildSettingInfo].value == "":
    #     scope = tmpdir
    # else:
    #     print("NS_PKG: %s" % ctx.attr._ns_pkg[BuildSettingInfo])
    #     scope = ctx.attr._ns_pkg[BuildSettingInfo].value + "/"
    # scope = tmpdir
    # (scope, ext) = paths.split_extension(src.basename)
    # scope = ctx.attr._ns_prefix[BuildSettingInfo].value
    # outfile = ctx.actions.declare_file(scope + "/" + out_filename)
    outfile = ctx.actions.declare_file(to) # out_filename)

    destdir = paths.normalize(outfile.dirname)
    # print("DESTDIR: %s" % destdir)

    cmd = ""
    dest = outfile.path
    # print("DEST: %s" % dest)
    # cmd = cmd + "touch {dest}; ".format(dest = bindir + "/" + tmpdir + src.path)
    cmd = cmd + "mkdir -p {destdir} && cp {src} {dest} && ".format(
      src = src.path,
      destdir = destdir,
      dest = dest
    )

    cmd = cmd + " true;"
    # print("CMD: %s" % cmd)
    # print("CP SRCS")

    ctx.actions.run_shell(
      # env = env,
      command = cmd,
      inputs = inputs,
      outputs = [outfile],
      progress_message = "rename_src_action ({}){}".format(
        ctx.label.name, src
      )
    )
    return outfile

################################################################
# def to_libarg(lib):
#   return "'library-name=\"{}\"'".format(lib)
