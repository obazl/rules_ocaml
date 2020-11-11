load("//ocaml/_providers:ocaml.bzl",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider")
load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("//ocaml/_providers:ppx.bzl",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

OCAML_FILETYPES = [
    ".ml", ".mli", ".cmx", ".cmo", ".cma"
]
OCAML_IMPL_FILETYPES = [
    ".ml", ".cmx", ".cmo", ".cma"
]
OCAML_INTF_FILETYPES = [
    ".mli", ".cmi"
]

WARNING_FLAGS = "@1..3@5..28@30..39@43@46..47@49..57@61..62-40"

def capitalize_initial_char(s):
  """Starlark's capitalize fn downcases everything but the first char.  This fn only affects first char."""
  first = s[:1]
  rest  = s[1:]
  return first.capitalize() + rest

def file_to_lib_name(file):
    if file.extension == "so":
        libname = file.basename[:-3]
        if libname.startswith("lib"):
            libname = libname[3:]
        else:
            fail("Found '.so' file without 'lib' prefix: %s" % file)
        return libname
    elif file.extension == "dylib":
        libname = file.basename[:-6]
        if libname.startswith("lib"):
            libname = libname[3:]
        else:
            fail("Found '.so' file without 'lib' prefix: %s" % file)
        return libname

def get_target_file(target):
  return target.files.to_list()[0]

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

def strip_ml_extension(path):
  if path.endswith(".ml"):
    return path[:-3]
  else:
    return path

def get_opamroot():
  return Label("@ocaml_sdk//opamroot").workspace_root + "/" + Label("@ocaml_sdk//opamroot").package

def get_sdkpath(ctx):
  sdkpath = ctx.attr._sdkpath[OcamlSDK].path + "/bin"
  return sdkpath + ":/usr/bin:/bin:/usr/sbin:/sbin"

def split_srcs(srcs):
  intfs = []
  impls = []
  for s in srcs:
    if s.extension == "ml":
      impls.append(s)
    else:
      intfs.append(s)
  return intfs, impls

################################################################
# def xget_all_deps(direct_deps):
#   """Obtain the deps for a target and its transitive dependencies.

#   Args:
#     deps: a list of targets that are direct dependencies
#   Returns:
#     two depsets, on for opam deps (Labels), the other for non-opam deps (Files)
#   """

#   # for each direct dep
#   # a. add the info struct as direct dep
#   # b. iterate over the deps of the direct dep, adding them to transitive

#   defaults = []

#   opam_directs = []
#   opam_transitives = []
#   nopam_directs = []
#   nopam_transitives = []
#   for dep in direct_deps:
#     defaults.append(dep[DefaultInfo])
#     # print("GETALL: DEP: %s" % dep)
#     if OpamPkgInfo in dep:
#       op = dep[OpamPkgInfo]
#       # print("OpamPkgInfo dep: %s" % op)
#       # print("OpamPkgInfo type: %s" % type(op))
#       opam_directs.append(op)
#       # opam_transitives.append(op.pkg)
#     elif OcamlArchiveProvider in dep:
#       ap = dep[OcamlArchiveProvider]
#       # print("OcamlArchiveProvider: %s" % ap)
#       nopam_directs.append(ap.payload)
#       nopam_transitives.append(ap.deps.nopam)
#       if ap.deps.opam:
#         opam_transitives.append(ap.deps.opam)
#     elif OcamlLibraryProvider in dep:
#       lp = dep[OcamlLibraryProvider]
#       # print("OcamlLibraryProvider: %s" % lp)
#       nopam_directs.append(lp.payload)
#       nopam_transitives.append(lp.deps.nopam)
#       if lp.deps.opam:
#         opam_transitives.append(lp.deps.opam)
#     elif OcamlModuleProvider in dep:
#       mp = dep[OcamlModuleProvider]
#       # print("OcamlModuleProvider dep: %s" % mp)
#       # print("OcamlModuleProvider dep type: %s" % type(mp))
#       nopam_directs.append(mp.payload)
#       nopam_transitives.append(mp.deps.nopam)
#       # opam_directs.append(None)
#       if mp.deps.opam:
#         opam_transitives.append(mp.deps.opam)
#       # opams = opams + d.opam_deps.to_list()
#     elif OcamlNsModuleProvider in dep:
#       nsmp = dep[OcamlNsModuleProvider]
#       # print("OcamlNsModuleProvider dep: %s" % nsmp)
#       # print("OcamlNsModuleProvider dep type: %s" % type(nsmp))
#       nopam_directs.append(nsmp.payload)
#       nopam_transitives.append(nsmp.deps.nopam)
#       if nsmp.deps.opam:
#         opam_transitives.append(nsmp.deps.opam)
#       # opams = opams + d.opam_deps.to_list()
#     elif OcamlInterfaceProvider in dep:
#       ip = dep[OcamlInterfaceProvider]
#       # print("OcamlInterfaceProvider dep: %s" % ip)
#       nopam_directs.append(ip.payload)
#       nopam_transitives.append(ip.deps.nopam)
#       # opams = opams + d.opam_deps.to_list()
#       # nopam_deps.append(d)
#       # nopam_transitive_deps.append(d)
#     elif CcInfo in dep:
#       cp = dep[CcInfo]
#       # print("################################################################")
#       # print("################################################################")
#       # print("CcInfo dep: %s" % cp)
#       # print("CcInfo payload: %s" % dep[DefaultInfo])
#       nopam_directs.append(struct( clib = dep[DefaultInfo]) )
#     elif PpxArchiveProvider in dep:
#       ap = dep[PpxArchiveProvider]
#       # print("PpxArchiveProvider: %s" % ap)
#       # print(ap.deps)
#       nopam_directs.append(ap.payload)
#       nopam_transitives.append(ap.deps.nopam)
#       opam_transitives.append(ap.deps.opam)
#     elif PpxExecutableProvider in dep:
#       bp = dep[PpxExecutableProvider]
#       # print("PpxExecutableProvider: %s" % bp)
#       nopam_directs.append(bp.payload)
#       nopam_transitives.append(bp.deps.nopam)
#       opam_transitives.append(bp.deps.opam)
#     elif PpxModuleProvider in dep:
#       pmp = dep[PpxModuleProvider]
#       # print("OcamlInterfaceProvider dep: %s" % pmp)
#       nopam_directs.append(pmp.payload)
#       nopam_transitives.append(pmp.deps.nopam)
#       opam_transitives.append(pmp.deps.opam)
#     # elif PpxNsModuleProvider in dep:
#     #   pnmp = dep[PpxNsModuleProvider]
#     #   # print("OcamlInterfaceProvider dep: %s" % pmp)
#     #   nopam_directs.append(pnmp.payload)
#     #   nopam_transitives.append(pnmp.deps.nopam)
#     #   opam_transitives.append(pnmp.deps.opam)
#       # opams = opams + d.opam_deps.to_list()
#       # nopam_deps.append(d)
#       # nopam_transitive_deps.append(d)
#     # else:
#     #   # e.g. a file used with [%%import ]
#     #   nopam_directs.extend(dep[DefaultInfo])


#   opam_depset = depset(
#     order      = "postorder",
#     direct     = opam_directs,
#     transitive = opam_transitives
#   )

#   nopam_depset = depset(
#     order      = "postorder",
#     direct = nopam_directs,
#     transitive = nopam_transitives
#   )

#   return struct( default = defaults,
#                  opam = opam_depset, nopam = nopam_depset )
