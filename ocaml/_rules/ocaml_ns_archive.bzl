# load("//ocaml/_actions:ppx.bzl",
     # "ocaml_ppx_library_compile",
     # "apply_ppx"
     # "ocaml_ppx_compile",
     # "ocaml_ppx_library_gendeps",
     # "ocaml_ppx_library_cmo",
     # "ocaml_ppx_library_link")
# load("//implementation/actions:ocamlopt.bzl",
#      "compile_native_with_ppx",
#      "link_native")
load("//ocaml/_providers:ocaml.bzl",
     "OcamlSDK")
load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("//implementation:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "split_srcs",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

# Starlark disallows recursion :(
def path2tree(node, # dictionary {string: dictionary}
               seglist):
    length = len(seglist)
    for i in range(length):
        hd = seglist[i]
        if hd in node:
            node = node[hd] # another dictionry
        else:
            newnode = dict()
            node[hd] = newnode
            node = newnode

##################################################
######## RULE DECL:  OCAML_NS_ARCHIVE  #########
#  Build namespaced .cmxa, .a
##################################################
def _ocaml_ns_archive_sequential(ctx):
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]

  if ctx.attr.archive_name:
    pkg_dir = ctx.attr.archive_name
  else:
    pkg_dir = ctx.build_file_path.split("/")[:-1]
  pfx_len = len(pkg_dir) - 1
  root_seg = pkg_dir[-1]
  pkg_dir = "/".join(pkg_dir)

  seglists = []
  for m in ctx.files.submodules:
    msegs = m.short_path.split("/")
    seglists.append(msegs[pfx_len:])
  seglists = sorted(seglists)
  # print("seglists: %s" % seglists)

  tree = dict()
  for seglist in seglists:
    path2tree(tree, seglist)
  # print("tree: %s" % tree[root_seg])

  srcs = []
  ns_module = {} # {filename : {"content": "", "src": srcFile, "cmx": objFile}}
  ns_module_submodules = {} # {redirector : [submodules]}

  obj_outfiles = {} # {string : File}

  # crawl the tree
  for submod in ctx.files.submodules:
    # print("****************")
    # print("SUBMOD: %s" % submod)
    ## drop the package prefix from short path
    seglist = submod.short_path.split("/")[pfx_len:]
    pfx = []
    node = tree
    # print("seglist: %s" % seglist)
    for i in range(len(seglist)):
      seg=seglist[i]
      # print("seg {}: {}".format(i, seg))
      # print("node: %s" % node)
      node = node[seg]
      if "done" in node:
        pfx.append(seg.capitalize())
        continue

      ## We construct a map taking (generated) src name string to presrc, src, and obj Files
      ## we also need a map from ns modules to their submodules, so that we
      ## can order compilation properly: first the ns_module, then the
      ## submodules, with -open ns_module
      if seg.endswith(".ml"):
        rename_srcfname = "__".join(pfx) + "__" + seg.capitalize()
        rename_srcfile  = ctx.actions.declare_file(rename_srcfname)
        ns_module[rename_srcfname] = {}
        ns_module[rename_srcfname]["presrc"] = submod # source to be renamed
        ns_module[rename_srcfname]["src"] = rename_srcfile # source to be compiled

        rename_cmxfname = rename_srcfname.rstrip(".ml") + ".cmx"
        rename_cmxfile  = ctx.actions.declare_file(rename_cmxfname)
        ns_module[rename_srcfname]["cmx"] = rename_cmxfile
        rename_ofname = rename_srcfname.rstrip(".ml") + ".o"
        rename_ofile  = ctx.actions.declare_file(rename_ofname)
        ns_module[rename_srcfname]["o"] = rename_ofile

        parent_src = "__".join(pfx) + ".ml"
        parent_src_File = ctx.actions.declare_file(parent_src)
        if parent_src not in ns_module:
          ns_module[parent_src] = {}
        ns_module[parent_src]["src"] = parent_src_File
        # ns_module[parent_src]["cmx"] = parent_cmx_File

        if parent_src in ns_module:  ## _file_map:
          parent_src_File = ns_module[parent_src]["src"]
          if parent_src_File in ns_module_submodules:
            ns_module_submodules[parent_src_File] += [submod]
          else:
            ns_module_submodules[parent_src_File] = [submod]
        else:
          ns_module_submodules[parent_src_File] = [rename_srcfile]
        continue
      # end processing .ml file
      pfx.append(seg.capitalize())
      # now we construct the ns module for the current node
      # we refer back to the tree, to get children of current node
      # print("CONTENT CTOR for %s" % submod)
      submods = node.keys()
      # print("submods: %s" % submods)
      ns_module_fname = "__".join(pfx) + ".ml"
      # print("NS_MODULE_FNAME: %s" % ns_module_fname)
      ns_module_file = ctx.actions.declare_file(ns_module_fname)
      cmxfname = "__".join(pfx) + ".cmx"
      cmxfile = ctx.actions.declare_file(cmxfname)
      ofname = "__".join(pfx) + ".o"
      ofile = ctx.actions.declare_file(ofname)
      aliases = []
      for sm in submods:
        alias = "module {sm} = {pfx}__{sm}".format(
          sm=sm.rstrip(".ml").capitalize(),
          pfx="__".join(pfx)
        )
        aliases.append(alias)
        ns_module[ns_module_fname] = {}
        # here src means compilation src, output of write action:
        ns_module[ns_module_fname]["src"] = ns_module_file
        ns_module[ns_module_fname]["cmx"] = cmxfile
        ns_module[ns_module_fname]["o"] = ofile
        ns_module[ns_module_fname]["content"] = "\n".join(aliases) + "\n"
        # print("pfx: {}, len {}".format(pfx, len(pfx)))
        # if len(pfx) > 1:
        #   genrule_name = name + "_" + "_".join(pfx)
        # else:
        #   genrule_name = name
        # # print("wrote file %s" % outfile)
        node["done"] = True
    # end inner for loop
  # end outer for loop
  # print("NS MODULE_SUBMODULES: %s" % ns_module_submodules)
  # print("NS MODULE: %s" % ns_module)

  ################################################################
  ## finally, actions

  # first generate the ns modules
  for item in ns_module.items():
    if "content" in item[1]:
      ctx.actions.write(
        output = item[1]["src"],
        content = item[1]["content"]
      )

  ## then rename submods (by copying):
  ## TODO: support ppx
  rename_args = ctx.actions.args()
  rename_args.add("-v")
  for item in ns_module.items():
    if "presrc" in item[1]:
      ctx.actions.run(
        env = env,
        executable = "cp",
        arguments = [rename_args, item[1]["presrc"].path, item[1]["src"].path],
        inputs = [item[1]["presrc"]],
        outputs = [item[1]["src"]],
        mnemonic = "OcamlNsArchiveRename",
        progress_message = "ocaml_ns_archive({}): renaming {}".format(
          ctx.label.name, ctx.attr.message
        )
      )

  ## FIXME: ns modules don't need to link against any libraries,
  ## but submodules might.  Need to configure the args list.
  args = ctx.actions.args()
  args.add("ocamlopt")
  ## FIXME: make these default values of interface args?
  args.add("-no-alias-deps")
  args.add("-w", "-49")
  args.add_all(ctx.attr.opts)

  ## declare outputs
  obj_files = []
  if "-c" in ctx.attr.opts:
    fail("-c option imcompatible with ocaml_ns_archive target.")

  ## TODO: do we need to explicitly list .o and .a outputs?  We do
  ## need to list .o files, to ensure that source changes trigger a
  ## proper rebuild. The cmxa file will not change if source changes
  ## do not affect the interface, e.g. if you just change a message.
  ## In that case the cmxa would be rebuilt, but clients of the cmxa
  ## would not be rebuilt, since the new cmxa would match the old one.
  ## So the .o files must be included as outputs, because they will
  ## change, for any source change, and thus trigger a client rebuild.
  ## And if we're going to include .o files, we might as well include
  ## the .a file.  Clients are not required to actually use them.
  if ctx.attr.archive_name:
    obj_cmxa = ctx.actions.declare_file(ctx.attr.archive_name + ".cmxa")
    obj_a = ctx.actions.declare_file(ctx.attr.archive_name + ".a")
  else:
    obj_a = ctx.actions.declare_file(ctx.label.name + ".a")
    obj_cmxa = ctx.actions.declare_file(ctx.label.name + ".cmxa")

  build_deps = []
  includes = []
  for dep in ctx.attr.deps:
    if OpamPkgInfo in dep:
      args.add("-package", dep[OpamPkgInfo].pkg)
    else:
      for g in dep[DefaultInfo].files.to_list():
        # if g.path.endswith(".cmi"):
        #   build_deps.append(g)
        if g.path.endswith(".cmx"):
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          build_deps.append(g)
          includes.append(g.dirname)
        # if g.path.endswith(".o"):
        #   build_deps.append(g)
        # if g.path.endswith(".cmxa"):
        #   build_deps.append(g)
        #   args.add(g) # dep[DefaultInfo].files)
        # else:
        #   args.add(g) # dep[DefaultInfo].files)

  args.add_all(includes, before_each="-I", uniquify = True)

  args.add_all(build_deps)

  ## FIXME: add non-opam libs to inputs, to get them in the dep graph.
  nsmod_inputs = []
  nsmod_outputs = []
  for item in ns_module.items():
    if "content" in item[1]:
      nsmod_inputs.append(item[1]["src"])
      nsmod_outputs.append(item[1]["cmx"])
      nsmod_outputs.append(item[1]["o"])
  # inputs = sorted([item[1]["src"] for item in ns_module.items()])

  nsmod_args = ctx.actions.args()
  nsmod_args.add_all(nsmod_inputs)

  ################################################################
  # first the ns modules
  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args, "-c", nsmod_args],
    inputs  = nsmod_inputs,
    outputs = nsmod_outputs,
    # outputs = [obj_cmxa, obj_a]
    # + [item[1]["cmx"] for item in ns_module.items()]
    # + [item[1]["o"] for item in ns_module.items()],
    mnemonic = "OcamlNsArchiveCompileNsModules",
    progress_message = "ocaml_ns_archive({}): {}".format(
      ctx.label.name, ctx.attr.message
    )
  )

  submod_args = ctx.actions.args()

  submod_inputs = []
  submod_outputs = []
  for item in ns_module.items():
    if "content" not in item[1]:
      submod_inputs.append(item[1]["src"])
      submod_outputs.append(item[1]["cmx"])
      submod_outputs.append(item[1]["o"])
    else:
      submod_args.add("-open", item[0].rstrip(".ml"))
  # submod_inputs = sorted([item[1]["src"] for item in ns_module.items()])
  # args.add_all(submod_inputs)

  submod_includes = []
  for input in submod_inputs:
    submod_includes.append(input.dirname)
  submod_args.add_all(submod_includes, before_each="-I", uniquify = True)
  submod_args.add_all(nsmod_outputs)
  submod_args.add_all(submod_inputs)

  ################################################################
  ## then the submodules
  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args, "-c", submod_args],
    inputs  = submod_inputs + nsmod_outputs,
    outputs = submod_outputs,
    # outputs = [obj_cmxa, obj_a]
    # + [item[1]["cmx"] for item in ns_module.items()]
    # + [item[1]["o"] for item in ns_module.items()],
    mnemonic = "OcamlNsArchiveCompileSubmodules",
    progress_message = "ocaml_ns_archive({}): {}".format(
      ctx.label.name, ctx.attr.message
    )
  )

  ################################################################
  ## finally, link ns modules and submodules
  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args, "-a", "-o", obj_cmxa.path],
    # arguments = [args, "-open", "Alpha__Beta1__Gamma", "-c", submod_args],
    inputs  = nsmod_outputs + submod_outputs,
    outputs = [obj_cmxa, obj_a],
    # + [item[1]["cmx"] for item in ns_module.items()]
    # + [item[1]["o"] for item in ns_module.items()],
    mnemonic = "OcamlNsArchiveLink",
    progress_message = "ocaml_ns_archive({}): {}".format(
      ctx.label.name, ctx.attr.message
    )
  )

  return [
    DefaultInfo(
      files = depset(
        direct = ## submod_outputs
        [obj_cmxa , obj_a]
        + [item[1]["cmx"] for item in ns_module.items()]
        # + [item[1]["o"] for item in ns_module.items()]
        # [item[1]["src"] for item in ns_module.items()]
      ))
  ]

################################################################
def _ocaml_ns_archive_impl(ctx):
  return _ocaml_ns_archive_sequential(ctx)

  # obj_files = []
  # for f in ctx.files.srcs:
  #   obj_files.append(_ocaml_ns_archive_parallel(ctx, f))
  # return [
  #   DefaultInfo(
  #     files = depset(
  #       direct = obj_files
  #     ))
  # ]

################################################################
ocaml_ns_archive = rule(
  implementation = _ocaml_ns_archive_impl,
  attrs = dict(
    archive_name = attr.string(),
    # preprocessor = attr.label(
    #   providers = [PpxInfo],
    #   executable = True,
    #   cfg = "exec",
    #   # allow_single_file = True
    # ),
    submodules = attr.label_list(
      allow_files = OCAML_FILETYPES
    ),
    # src_root = attr.label(
    #   allow_single_file = True,
    #   mandatory = True,
    # ),
    ####  OPTIONS  ####
    ##Flags. We set some flags by default; these params
    ## allow user to override.
    ## Problem is, this target registers two actions,
    ## compile and link, and each has its own params.
    ## for now, these affect the compile action:
    strict_sequence         = attr.bool(default = True),
    compile_strict_sequence = attr.bool(default = True),
    link_strict_sequence    = attr.bool(default = True),
    strict_formats          = attr.bool(default = True),
    short_paths             = attr.bool(default = True),
    keep_locs               = attr.bool(default = True),
    opaque                  = attr.bool(default = True),
    no_alias_deps           = attr.bool(default = True),
    debug                   = attr.bool(default = True),
    ## use these to pass additional args
    opts                    = attr.string_list(),
    linkopts                = attr.string_list(),
    warnings                = attr.string(
      default               = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"
    ),
    #### end options ####
    # lib = attr.bool(default = False)
    deps = attr.label_list(),
    mode = attr.string(default = "native"),
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    message = attr.string()
    # outputs = attr.output_list(
    #   # default = ["%{name}.pp.ml",
    #   #           "%{name}.pp.ml.d"],
    # )
  ),
  # provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
  executable = False,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
  # outputs = { "build_dir": "_build_%{name}" },
)
