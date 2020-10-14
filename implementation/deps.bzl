load("//implementation:providers.bzl",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlImportProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider",
     "OpamPkgInfo",
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
  # if (ctx.label.name == "ppx_exe"):
  # if (ctx.label.name == "good_version_syntax.cm_"):
  #     debug = True

  direct_deps = ctx.attr.deps

  if debug:
      print("GET_ALL_DEPS {rule}({target})".format(rule=rule, target=ctx.label.name))

  defaults = []

  # payload lists
  opam_directs = []
  entailed_opam_directs = []
  nopam_directs = []
  entailed_nopam_directs = []

  # depset lists
  opam_transitives = []
  entailed_opam_transtivies = []
  nopam_transitives = []
  entailed_nopam_transtivies = []

  if debug:
      print("DIRECT_DEPS: %s" % direct_deps)
  for dep in direct_deps:
    # print()
    if debug:
        print(" DIRECT DEP: %s" % dep)
        print(" DIRECT DEP files: %s" % dep.files)
        print(" DIRECT DEP DefaultInfo: %s" % dep[DefaultInfo])
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
          ## this includes both direct deps (submods) and indirect deps!
          # nopam_directs.extend(dep_provider.deps.nopam.to_list())
          nopam_transitives.append(dep_provider.deps.nopam)
          if hasattr(dep_provider.payload, "mli"):
              if dep_provider.payload.mli != None:
                  # print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA %s" % dep_provider.payload.mli)
                  nopam_directs.append(dep_provider.payload.mli)
      elif rule == "ocaml_executable":
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
      if hasattr(dep_provider.payload, "mli"):
          if dep_provider.payload.mli != None:
              # print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA %s" % dep_provider.payload.mli)
              nopam_directs.append(dep_provider.payload.mli)
      nopam_directs.append(dep_provider.payload.cmi)
      nopam_directs.append(dep_provider.payload.o)
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
      nopam_directs.append(dep_provider.payload.cmi)
      nopam_directs.append(dep_provider.payload.o)
      if dep_provider.deps.nopam:
          # nopam_directs.append(dep_provider.payload)
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          nopam_transitives.append(dep_provider.deps.nopam)
          # opam_directs.append(None)

    elif OcamlInterfaceProvider in dep:
      ip = dep[OcamlInterfaceProvider]
      # print("OcamlInterfaceProvider dep: %s" % ip)
      nopam_directs.append(ip.payload.cmi)
      nopam_directs.append(ip.payload.mli)
      nopam_transitives.append(ip.deps.nopam)

    elif OcamlImportProvider in dep:
      provider = dep[OcamlImportProvider]
      # print("OcamlImportProvider dep: %s" % provider)
      if provider.payload.cmx:
          nopam_directs.append(provider.payload.cmx.files.to_list()[0])
      if provider.payload.cma:
          nopam_directs.append(provider.payload.cma.files.to_list()[0])
      if provider.payload.cmxa:
          nopam_directs.append(provider.payload.cmxa.files.to_list()[0])
      if provider.payload.cmxs:
          nopam_directs.append(provider.payload.cmxs.files.to_list()[0])
      # nopam_directs.append(provider.payload.ml)

      nopam_transitives.append(provider.indirect)

    elif CcInfo in dep:
      cp = dep[CcInfo]
      if debug:
          print("CcInfo dep: %s" % cp)
          print("CcInfo payload: %s" % dep[DefaultInfo])
      nopam_directs.append(struct( clib = dep[DefaultInfo]) )
    elif PpxArchiveProvider in dep:
      ap = dep[PpxArchiveProvider]
      print("PpxArchiveProvider: %s" % ap)
      print(ap.deps)
      nopam_directs.append(ap.payload)
      # nopam_transitives.append(ap.deps.nopam)
      opam_transitives.append(ap.deps.opam)
    elif PpxExecutableProvider in dep:
      bp = dep[PpxExecutableProvider]
      # print("PpxExecutableProvider: %s" % bp)
      nopam_directs.append(bp.payload)
      nopam_transitives.append(bp.deps.nopam)
      opam_transitives.append(bp.deps.opam)
    elif PpxModuleProvider in dep:
      pmp = dep[PpxModuleProvider]
      # print("OcamlInterfaceProvider dep: %s" % pmp)
      nopam_directs.append(pmp.payload.cm)
      nopam_directs.append(pmp.payload.cmi)
      nopam_directs.append(pmp.payload.o)
      nopam_transitives.append(pmp.deps.nopam)
      opam_transitives.append(pmp.deps.opam)
    elif PpxNsModuleProvider in dep:
      pnmp = dep[PpxNsModuleProvider]
      # print("OcamlInterfaceProvider dep: %s" % pmp)
      # nopam_directs.append(pnmp.payload)
      nopam_directs.append(pnmp.payload.cm)
      nopam_directs.append(pnmp.payload.cmi)
      nopam_directs.append(pnmp.payload.o)
      nopam_transitives.append(pnmp.deps.nopam)
      opam_transitives.append(pnmp.deps.opam)
      # opams = opams + d.opam_deps.to_list()
      # nopam_deps.append(d)
      # nopam_transitive_deps.append(d)
    else:
      fail("UNKNOWN DEP TYPE: %s" % dep)

  if hasattr(ctx.attr, "cmi"):
      if ctx.attr.cmi != None:
          dep_provider = ctx.attr.cmi[OcamlInterfaceProvider]
          nopam_directs.append(dep_provider.payload.cmi)
          nopam_directs.append(dep_provider.payload.mli)
          if dep_provider.deps.nopam:
              # nopam_directs.append(dep_provider.payload)
              # nopam_directs.extend(dep[DefaultInfo].files.to_list())
              # nopam_directs.extend(dep[DefaultInfo].files.to_list())
              nopam_transitives.append(dep_provider.deps.nopam)
              # opam_directs.append(None)
          if dep_provider.deps.opam:
              opam_transitives.append(dep_provider.deps.opam)

  if hasattr(ctx.attr, "ns_module"):
      if ctx.attr.ns_module != None:
          dep_provider = ctx.attr.ns_module[OcamlNsModuleProvider]
          nopam_directs.append(dep_provider.payload.cm)
          nopam_directs.append(dep_provider.payload.cmi)
          nopam_directs.append(dep_provider.payload.o)
          if dep_provider.deps.nopam:
              # nopam_directs.append(dep_provider.payload)
              # nopam_directs.extend(dep[DefaultInfo].files.to_list())
              # nopam_directs.extend(dep[DefaultInfo].files.to_list())
              nopam_transitives.append(dep_provider.deps.nopam)
              # opam_directs.append(None)
          if dep_provider.deps.opam:
              opam_transitives.append(dep_provider.deps.opam)

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
    order      = "postorder",
    direct     = opam_directs,
    transitive = opam_transitives
  )

  nopam_depset = depset(
    order      = "postorder",
    direct = nopam_directs,
    transitive = nopam_transitives
  )

  if debug:
      print("\n\n\t\tGET_ALL_DEPS result {rule}({target})\n\n".format(rule=rule, target=ctx.label.name))
      print("\n\t\t\t OPAM DEPSET: %s\n\n"  % opam_depset)
      print("\n\t\t\t NOPAM DEPSET: %s\n\n" % nopam_depset)

  # print("\n\n\t\t\t NOPAM DEPSET FILES: %s\n\n" % nopam_depset.to_list())

  return struct( default = defaults,
                 opam = opam_depset, nopam = nopam_depset )
