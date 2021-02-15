load("@bazel_skylib//lib:paths.bzl", "paths")
load("//ocaml:providers.bzl",
     "OcamlNsLibraryProvider",
     "OcamlNsEnvProvider")
     # "PpxNsLibraryProvider")

load("//ocaml/_functions:utils.bzl",
     "capitalize_initial_char",
     "get_opamroot",
     "get_sdkpath"
)

tmpdir = "_obazl_/"

###################################
def get_module_filename (ctx, src):
    ns     = None
    # if ctx.attr.ns_env:
    #     ns_sep = ctx.attr.ns_env[OcamlNsEnvProvider].sep
    # else:
    ns_sep = "__"

    # if ctx.attr.ns_env:
    #     if OcamlNsLibraryProvider in ctx.attr.ns_env:
    #         ns  = ctx.attr.ns_env[OcamlNsLibraryProvider].payload.ns_env
    #         ns_sep = ctx.attr.ns_env[OcamlNsLibraryProvider].payload.sep
    #     else:
    #         ns = ctx.attr.ns_env[PpxNsLibraryProvider].payload.ns_env
    #         ns_sep = ctx.attr.ns_env[PpxNsLibraryProvider].payload.sep
    #         # sep = ctx.attr.ns_env[OcamlNsLibraryProvider].payload.sep
    if hasattr(ctx.attr, "ns_env"):
        if ctx.attr.ns_env:
            ns_provider = ctx.attr.ns_env[OcamlNsEnvProvider]
            ns = ns_provider.prefix
            ## ns target always produces two files, module (cmo or cmx) and interface (cmi)
            # ns_sep = "__"
            # for dep in ctx.files.ns_env:
            #     if dep.extension == "cmi":
            #         bn  = dep.basename
            #         ext = dep.extension
            #         ns = bn[:-(len(ext)+1)]

    parts = paths.split_extension(src.basename)
    module = None
    if hasattr(ctx.attr, "module"):
        if ctx.attr.module:
            module = ctx.attr.module
        else:
            module = parts[0]
    else:
        module = parts[0]

    extension = parts[1]

    if ns == None: ## no ns
        out_filename = module
    else:
        if ns.find("/") > 0:
            fail("ERROR: ns contains '/' : '%s'" % ns)
        else:
            if ns.lower() == module.lower():
                out_filename = module
            else:
                out_filename = capitalize_initial_char(ns) + ns_sep + capitalize_initial_char(module)

    out_filename = out_filename + extension
    return out_filename

################################################################
def rename_module(ctx, src):  # , pfx):
  """Rename implementation and interface (if given) using ns_env.

  Inputs: context, src
  Outputs: outfile :: declared File
  """

  # if module name == ns, then output module name
  # otherwise, outputp ns + "__" + module name

  out_filename = get_module_filename(ctx, src)
  # if (module == ns):
  #   out_filename = module + extension
  # else:
  #   out_filename = ns + capitalize_initial_char(module) + extension
  # print("RENAMED MODULE %s" % out_filename)

  # if pfx.find("/") > 0:
  #   fail("ERROR: ns contains '/' : '%s'" % pfx)

  inputs  = []
  # outputs = []
  outputs = {}
  inputs.append(src)
  outfile = ctx.actions.declare_file(tmpdir + out_filename)

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
