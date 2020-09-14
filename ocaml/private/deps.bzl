load("//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider",
     "OpamPkgInfo",
     "PpxArchiveProvider",
     "PpxBinaryProvider",
     "PpxNsModuleProvider",
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

################################################################
def get_all_deps(rule, ctx):
  """Obtain the deps for a target and its transitive dependencies.

  Args:
    rule: the calling rule name
    ctx:  context
  Returns:
    two depsets, on for opam deps (Labels), the other for non-opam deps (Files)
  """

  # for each direct dep
  # a. add the info struct as direct dep
  # b. iterate over the deps of the direct dep, adding them to transitive

  debug = False
  if (ctx.label.name == "election"):
      debug = True

  direct_deps = ctx.attr.deps

  if debug:
      print("\n\n\t\t\t\t\tGET_ALL_DEPS {rule}({target})\n\n".format(rule=rule, target=ctx.label.name))

  defaults = []

  # payload lists
  opam_directs = []
  nopam_directs = []
  # depset lists
  opam_transitives = []
  nopam_transitives = []

  for dep in direct_deps:
    # print()
    # print("XXXX TARGET DEP: %s" % dep)
    # print(" TARGET DEP.label: %s" % dep.label)
    # print(" TARGET DEP.files: %s" % dep.files)

    # print(" Target dir: %s" % dir(dep))

    # for d in dir(dep):
    #   print(" Provider name: %s" % d)
    #   print(" Provider: %s" % getattr(dep, d))
    #   print(" dep.actions: %s" % dep.actions)
    #   print(" dep.actions type: %s" % type(dep.actions))
    #   for action in dep.actions:
    #     print("    action type: %s" % type(action))
    #     print("    action: %s" % action)
    #     print("    action mnemonic: %s" % action.mnemonic)

    defaults.append(dep[DefaultInfo])
    # print("GETALL: DEP: %s" % dep)
    if OpamPkgInfo in dep:
      op = dep[OpamPkgInfo]
      # print("OpamPkgInfo dep: %s" % op)
      # print("OpamPkgInfo type: %s" % type(op))
      opam_directs.append(op)
      # opam_transitives.append(op.pkg)

    elif OcamlArchiveProvider in dep:
      dep_provider = dep[OcamlArchiveProvider]
      # print("#### OcamlArchiveProvider: %s" % dep_provider)
      # print("#### OcamlArchiveProvider DefaultInfo: %s" % dep[DefaultInfo])
      if dep_provider.deps.opam:
          opam_transitives.append(dep_provider.deps.opam)

      if rule == "ocaml_archive":
          # print("\n\n XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX \n\n")
          ## this includes both direct deps (submods) and indirect deps!
          # nopam_directs.extend(dep_provider.deps.nopam.to_list())
          nopam_transitives.append(dep_provider.deps.nopam)
      elif rule == "ocaml_executable":
          # print("\n\n XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX \n\n")
          # print("payload: %s" % dep_provider.payload)
          ## this includes both direct deps (submods) and indirect deps!
          # nopam_directs.append(dep_provider.payload.cmxa)
          nopam_directs.extend(dep_provider.deps.nopam.to_list())
      else:
          nopam_directs.extend(dep_provider.deps.nopam.to_list())
          # nopam_directs.append(dep_provider.payload.cmxa)
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          ## no nopam transitives, they're already in the cmxa file(?)
          ## what about second-order deps?
          # nopam_transitives.append(dep_provider.deps.nopam)

    elif OcamlLibraryProvider in dep:
      lp = dep[OcamlLibraryProvider]
      # print("OcamlLibraryProvider: %s" % lp)
      nopam_directs.append(lp.payload)
      nopam_transitives.append(lp.deps.nopam)
      if lp.deps.opam:
        opam_transitives.append(lp.deps.opam)

    elif OcamlModuleProvider in dep:
      dep_provider = dep[OcamlModuleProvider]
      # print("____ OcamlModuleProvider provider: %s" % dep_provider)
      # print("____ OcamlModuleProvider DefaultInfo: %s" % dep[DefaultInfo])

      if dep_provider.deps.opam:
        opam_transitives.append(dep_provider.deps.opam)
      # opams = opams + d.opam_deps.to_list()

      nopam_directs.append(dep_provider.payload.cm)
      if dep_provider.deps.nopam:
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          nopam_transitives.append(dep_provider.deps.nopam)
          # opam_directs.append(None)
      # print("____ nopam transitives: %s" % nopam_transitives)
    elif OcamlNsModuleProvider in dep:
      dep_provider = dep[OcamlNsModuleProvider]
      # print("++++ OcamlNsModuleProvider dep: %s" % dep_provider)
      # print("++++ OcamlNsModuleProvider DefaultInfo: %s" % dep[DefaultInfo])
      if dep_provider.deps.opam:
        opam_transitives.append(dep_provider.deps.opam)
      # opams = opams + d.opam_deps.to_list()

      nopam_directs.append(dep_provider.payload.cm)
      if dep_provider.deps.nopam:
          # nopam_directs.append(dep_provider.payload)
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          nopam_transitives.append(dep_provider.deps.nopam)
          # opam_directs.append(None)

    elif OcamlInterfaceProvider in dep:
      ip = dep[OcamlInterfaceProvider]
      # print("OcamlInterfaceProvider dep: %s" % ip)
      nopam_directs.append(ip.payload)
      nopam_transitives.append(ip.deps.nopam)
      # opams = opams + d.opam_deps.to_list()
      # nopam_deps.append(d)
      # nopam_transitive_deps.append(d)

    elif CcInfo in dep:
      cp = dep[CcInfo]
      # print("CcInfo dep: %s" % cp)
      # print("CcInfo payload: %s" % dep[DefaultInfo])
      nopam_directs.append(struct( clib = dep[DefaultInfo]) )
    elif PpxArchiveProvider in dep:
      ap = dep[PpxArchiveProvider]
      # print("PpxArchiveProvider: %s" % ap)
      # print(ap.deps)
      nopam_directs.append(ap.payload)
      nopam_transitives.append(ap.deps.nopam)
      opam_transitives.append(ap.deps.opam)
    elif PpxBinaryProvider in dep:
      bp = dep[PpxBinaryProvider]
      # print("PpxBinaryProvider: %s" % bp)
      nopam_directs.append(bp.payload)
      nopam_transitives.append(bp.deps.nopam)
      opam_transitives.append(bp.deps.opam)
    elif PpxModuleProvider in dep:
      pmp = dep[PpxModuleProvider]
      # print("OcamlInterfaceProvider dep: %s" % pmp)
      nopam_directs.append(pmp.payload)
      nopam_transitives.append(pmp.deps.nopam)
      opam_transitives.append(pmp.deps.opam)
    elif PpxNsModuleProvider in dep:
      pnmp = dep[PpxNsModuleProvider]
      # print("OcamlInterfaceProvider dep: %s" % pmp)
      nopam_directs.append(pnmp.payload)
      nopam_transitives.append(pnmp.deps.nopam)
      opam_transitives.append(pnmp.deps.opam)
      # opams = opams + d.opam_deps.to_list()
      # nopam_deps.append(d)
      # nopam_transitive_deps.append(d)
    else:
      fail("UNKNOWN DEP TYPE: %s" % dep)

  if hasattr(ctx.attr, "cc_deps"):
      if debug:
          print("DEPSET TARGET: %s" % ctx.label.name)
          print("DEPSET CC_DEPS: %s" % ctx.attr.cc_deps)
      for cc_dep in ctx.attr.cc_deps.items():
          if debug:
              print("CC_DEP TYPE: %s" % cc_dep[1])
          for depfile in cc_dep[0].files.to_list():
              if debug:
                  print("CC_DEP FILE: %s" % depfile)
          if cc_dep[1] == "static":
              if debug:
                  print("DEPSET STATIC")
              for depfile in cc_dep[0].files.to_list():
                  if (depfile.extension == "a"):
                      nopam_directs.append(depfile)
          elif cc_dep[1] == "dynamic":
              if debug:
                  print("DEPSET STATIC")
              for depfile in cc_dep[0].files.to_list():
                  if (depfile.extension == "so"):
                      if debug:
                          print("DEPSET DSO")
                      nopam_directs.append(depfile)
                  elif (depfile.extension == "dylib"):
                      if debug:
                          print("DEPSET DYLIB")
                      nopam_directs.append(depfile)
          else:
              ## any other value treated as "default"
              if debug:
                  print("DEPSET DEFAULT")
              if ctx.attr.cc_linkstatic:
                  if debug:
                      print("DEPSET LINKSTATIC")
                  for depfile in cc_dep[0].files.to_list():
                      if (depfile.extension == "a"):
                          nopam_directs.append(depfile)
                      elif (depfile.extension == "lo"):
                          nopam_directs.append(depfile)
              else:
                  if debug:
                      print("DEPSET LINKDYNAMIC")
                  for depfile in cc_dep[0].files.to_list():
                      if (depfile.extension == "so"):
                          if debug:
                              print("DEPSET SO")
                          nopam_directs.append(depfile)
                      elif (depfile.extension == "dylib"):
                          if debug:
                              print("DEPSET DYLIB")
                          nopam_directs.append(depfile)

  opam_depset = depset(
    # order      = "preorder",
    direct     = opam_directs,
    transitive = opam_transitives
  )

  # print("\n\n\t\tGET_ALL_DEPS {rule}({target})\n\n".format(rule=rule, target=ctx.label.name))
  # print("\n\n\t\t\t NOPAM DIRECTS: %s\n\n" % nopam_directs)
  # print("\n\n\t\t\t NOPAM TRANSITIVES: %s\n\n" % nopam_transitives)

  nopam_depset = depset(
    order      = "postorder",
    direct = nopam_directs,
    transitive = nopam_transitives
  )

  # print("\n\n\t\t\t NOPAM DEPSET FILES: %s\n\n" % nopam_depset.to_list())

  return struct( default = defaults,
                 opam = opam_depset, nopam = nopam_depset )
