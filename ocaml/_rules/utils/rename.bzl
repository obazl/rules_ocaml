load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml:providers.bzl",
     "OcamlNsLibraryProvider",
     "OcamlNsResolverProvider")
     # "PpxNsLibraryProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath"
)

tmpdir = "_obazl_/"

###################################
## FIXME: we don't need this for executables (including test rules)
def get_module_filename (ctx, src):

    debug = False
    if ctx.label.name in ["_Red", "_Green", "_Blue"]:
        debug = True
    #     print("GET_MODULE_FILENAME for src: %s" % src)

    ns     = None
    # if ctx.attr.ns_resolver:
    #     ns_sep = ctx.attr.ns_resolver[OcamlNsResolverProvider].sep
    # else:
    ns_sep = "__"

    if hasattr(ctx.attr, "_ns_resolver"):  # ocaml_module, ocaml_ns_library
        hidden_provider = ctx.attr._ns_resolver[OcamlNsResolverProvider]
        if hasattr(ctx.attr, "ns"): ## ocaml_module only
            # print("HASATTR NS: %s" % ctx.attr.ns)
            if ctx.attr.ns: # we're hand-rolling; make sure we're not also using ocaml_ns_library
                if hasattr(hidden_provider, "prefix"):
                    if hidden_provider.prefix:
                        if debug:
                            print("hidden_provider.prefix: {ap}, rule.ns: {ns}".format(
                                ap = hidden_provider.prefix, ns = ctx.attr.ns
                            ))
                        fail("Attribute 'ns' disallowed for ocaml_ns_library submodules.")
                    else:
                        ns = ctx.attr.ns[OcamlNsResolverProvider].prefix
                        if debug:
                            print("NS A %s" % ns)
                else:
                    ns = ctx.attr.ns[OcamlNsResolverProvider].prefix
                    if debug:
                        print("NS B %s" % ns)
            elif hasattr(hidden_provider, "prefix"):  ## we're using ocaml_ns_library
                ns = hidden_provider.prefix
                if debug:
                    print("NS C %s" % ns)
            # else:  ## not using any ns

        elif hasattr(ctx.attr, "_ns_prefix"):
            if debug:
                print("_NS_PREFIX: %s" % ctx.attr._ns_prefix[BuildSettingInfo].value)
            _apfx = ctx.attr._ns_prefix[BuildSettingInfo].value
            _pkg = paths.basename(ctx.label.package)
            if _apfx != "":
                if _apfx == _pkg:
                    print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXX _pkg %s" % _pkg)
                    print("LABEL: %s" % ctx.label)
                    ns = _apfx
                else:
                    ns = _apfx
    elif hasattr(ctx.attr, "_ns_prefix"):  # ocaml_signature
        ns = ctx.attr._ns_prefix[BuildSettingInfo].value
    elif ctx.attr._rule == "ocaml_test":
        ns = None
    else:
        fail("GET MODULE NAME unexpected condition")

    if debug:
        print("NS for renaming: %s" % ns)

    (basename, extension) = paths.split_extension(src.basename)
    # module = None
    # if hasattr(ctx.attr, "module"):
    #     if ctx.attr.module:
    #         module = ctx.attr.module
    #     else:
    #         module = basename
    # else:
    if ctx.attr._rule in ["ocaml_test", "ocaml_executable", "ppx_executable"]:
        module = basename
    else:
        module = capitalize_initial_char(basename)

    if ns == None: ## no ns
        out_filename = module
    else:
        if ns.find("/") > 0:
            fail("ERROR: ns contains '/' : '%s'" % ns)
        else:
            if ns.lower() == module.lower():
                out_filename = module
            elif ns != "":
                out_filename = capitalize_initial_char(ns) + ns_sep + module
            else:
                out_filename = module

    out_filename = out_filename + extension
    return out_filename

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

  out_filename = get_module_filename(ctx, src)
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
# def to_libarg(lib):
#   return "'library-name=\"{}\"'".format(lib)
