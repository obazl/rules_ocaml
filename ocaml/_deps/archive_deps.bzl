load("//ocaml/_providers:ocaml.bzl",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlImportProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider")
load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")
load("//ppx:_providers.bzl",
     "PpxArchiveProvider",
     "PpxExecutableProvider",
     "PpxModuleProvider")

## FIXME: support for rules_foreign_cc: workspace must load the repo?
## or pass a param telling obazl to load it?
## before ocaml rules can use it as a dep the user must have loaded it, to build the deps
## 
# load("@rules_foreign_cc//tools/build_defs:framework.bzl", "ForeignCcDeps", "ForeignCcArtifact")

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
def get_archive_deps(rule, ctx):
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
  # if (ctx.label.name == "rocks"):
      # debug = True

  if debug:
      print("GET_ALL_DEPS {rule}({target})".format(rule=rule, target=ctx.label.name))

  defaults = []

  # payload lists
  opam_directs = []
  nopam_directs = []

  # depset lists
  opam_indirects = []
  nopam_indirects = []

  # lazy deps
  opam_lazy_directs = []
  opam_lazy_indirects = []
  nopam_lazy_directs = []
  nopam_lazy_indirects = []

  ## ppx rules may have a adjunct_deps attrib.
  if hasattr(ctx.attr, "adjunct_deps"):
      if debug:
          print("ADJUNCT_DEPS: %s" % ctx.attr.adjunct_deps)
      for dep in ctx.attr.adjunct_deps:
          if OpamPkgInfo in dep:
              provider = dep[OpamPkgInfo]
              opam_lazy_directs.append(provider)
          else:
              if OcamlModuleProvider in dep:
                  provider = dep[OcamlModuleProvider]
                  nopam_lazy_directs.append(provider.payload.cm)
                  nopam_lazy_directs.append(provider.payload.o)
                  if hasattr(provider.payload, "mli"):
                      if provider.payload.mli != None:
                          nopam_lazy_directs.append(provider.payload.mli)
                  nopam_lazy_directs.append(provider.payload.cmi)
                  if provider.deps.nopam:
                      nopam_lazy_indirects.append(provider.deps.nopam)
                  if provider.deps.opam:
                      opam_lazy_indirects.append(provider.deps.opam)
              elif OcamlArchiveProvider in dep:
                  provider = dep[OcamlArchiveProvider]
                  if debug:
                      print("LAZY OcamlArchiveProvider dep: %s" % dep)
                  provider = dep[OcamlArchiveProvider]
                  nopam_lazy_directs.append(provider.payload.cmxa)
                  if hasattr(provider.payload, "mli"):
                      if provider.payload.mli != None:
                          nopam_lazy_directs.append(provider.payload.mli)
                  nopam_lazy_directs.append(provider.payload.a)
                  if provider.deps.nopam:
                      nopam_lazy_indirects.append(provider.deps.nopam)
              elif PpxModuleProvider in dep:
                  provider = dep[PpxModuleProvider]
                  if debug:
                      print("LAZY PpxModuleProvider dep: %s" % dep)
                  provider = dep[PpxModuleProvider]
                  nopam_lazy_directs.append(provider.payload.cm)
                  nopam_lazy_directs.append(provider.payload.o)
                  if hasattr(provider.payload, "mli"):
                      if provider.payload.mli != None:
                          nopam_lazy_directs.append(provider.payload.mli)
                  nopam_lazy_directs.append(provider.payload.cmi)
                  if provider.deps.nopam:
                      nopam_lazy_indirects.append(provider.deps.nopam)
                  if provider.deps.opam:
                      opam_lazy_indirects.append(provider.deps.opam)
              elif PpxArchiveProvider in dep:
                  provider = dep[PpxArchiveProvider]
                  if debug:
                      print("LAZY PpxArchiveProvider dep: %s" % dep)
                  provider = dep[PpxArchiveProvider]
                  nopam_lazy_directs.append(provider.payload.cmxa)
                  if hasattr(provider.payload, "mli"):
                      if provider.payload.mli != None:
                          nopam_lazy_directs.append(provider.payload.mli)
                  nopam_lazy_directs.append(provider.payload.a)
                  if provider.deps.nopam:
                      nopam_lazy_indirects.append(provider.deps.nopam)
              else:
                      print("LAZY Unknown Provider dep: %s" % dep)

  if debug:
      print("DIRECT_DEPS: %s" % ctx.attr.deps)

  ## Direct cmx deps should NOT go in the output depsets as direct deps,
  ## since they are already included in the cmxa.

  ## OTOH cmxa deps cannot be passed to an archive rule, so we have to
  ## be able to get the contained cmx files of archive deps.

  ## Which suggests we pass on the created cmxa as payload, and its
  ## direct cmx deps as a depset, and all indirect deps as another
  ## depset. if we add direct and indirect deps to one depset, then we
  ## cannot distinguish them when it comes time to list the contents
  ## of the depset; we just have to_list() which lists the entire
  ## contents in dep order.

  for dep in ctx.attr.deps:
    # print()
    if debug:
        print(" DIRECT DEP: %s" % dep)
        # print(" DIRECT DEP files: %s" % dep.files)
        # print(" DIRECT DEP DefaultInfo: %s" % dep[DefaultInfo])
    defaults.append(dep[DefaultInfo])
    # print("GETALL: DEP: %s" % dep)
    if OpamPkgInfo in dep:
      provider = dep[OpamPkgInfo]
      # print("OpamPkgInfo dep: %s" % provider)
      # print("OpamPkgInfo type: %s" % type(provider))
      opam_directs.append(provider)
      # opam_indirects.append(provider.pkg)

    elif OcamlArchiveProvider in dep:
      dep_provider = dep[OcamlArchiveProvider]
      # print("#### OcamlArchiveProvider: %s" % dep_provider)
      # print("#### OcamlArchiveProvider DefaultInfo: %s" % dep[DefaultInfo])
      if dep_provider.deps.opam:
          opam_indirects.append(dep_provider.deps.opam)

      if rule == "ocaml_archive":
          # We cannot add cmxa to cmd args, so we ignore the payload
          # and just add all deps. The cmxa would be a direct dep, but
          # since we cannot use it we need to use the cmx it contains.
          # But we cannot obtain them separate from all other deps, so
          # we just add everything as indirect deps. So the depset
          # will contain both the cmxa and its contents, and the rule
          # must sort them out.

          # However. If we are using a cmxa to build an archive, then
          # there is no point including the cmxa itself as a dep - we
          # will never want to use a cmxa plus the cmxas it depended
          # on, since the (contents of) the latter will be included in
          # the (contents of) the former.  So here we filter out cmxas.
          archive_deps = dep_provider.deps.nopam.to_list()
          depset_tmp = []
          for dep in archive_deps:
              # if dep.extension == "cmxa":
                  # print("EXCLUDING CMXA DEP: %s" % dep)
              # else:
              if dep.extension != "cmxa":
                  depset_tmp.append(dep)
          if len(depset_tmp) > 1:
              nopam_indirects.append(depset(order = "postorder", direct=depset_tmp))
          if hasattr(dep_provider.payload, "mli"):
              if dep_provider.payload.mli != None:
                  nopam_directs.append(dep_provider.payload.mli)
      elif rule == "ocaml_executable":
          # print("payload: %s" % dep_provider.payload)
          ## this includes both direct deps (submods) and indirect deps!
          # nopam_directs.append(dep_provider.payload.cmxa)
          nopam_directs.extend(dep_provider.deps.nopam.to_list())
      else:
          # nopam_directs.extend(dep_provider.deps.nopam.to_list())
          nopam_directs.append(dep_provider.payload.cmxa)
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          ## no nopam transitives, they're already in the cmxa file(?)
          ## what about second-order deps?
          nopam_indirects.append(dep_provider.deps.nopam)

    elif OcamlLibraryProvider in dep:
      lp = dep[OcamlLibraryProvider]
      # print("OcamlLibraryProvider: %s" % lp)
      nopam_directs.append(lp.payload)
      nopam_indirects.append(lp.deps.nopam)
      if lp.deps.opam:
        opam_indirects.append(lp.deps.opam)

    elif OcamlModuleProvider in dep:
      dep_provider = dep[OcamlModuleProvider]
      # print("____ OcamlModuleProvider provider: %s" % dep_provider)
      # print("____ OcamlModuleProvider DefaultInfo: %s" % dep[DefaultInfo])

      if dep_provider.deps.opam:
        opam_indirects.append(dep_provider.deps.opam)
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
          nopam_indirects.append(dep_provider.deps.nopam)
          # opam_directs.append(None)
      # print("____ nopam transitives: %s" % nopam_indirects)
    elif OcamlNsModuleProvider in dep:
      dep_provider = dep[OcamlNsModuleProvider]
      # print("++++ OcamlNsModuleProvider dep: %s" % dep_provider)
      # print("++++ OcamlNsModuleProvider DefaultInfo: %s" % dep[DefaultInfo])
      if dep_provider.deps.opam:
        opam_indirects.append(dep_provider.deps.opam)
      # opams = opams + d.opam_deps.to_list()

      nopam_directs.append(dep_provider.payload.cm)
      nopam_directs.append(dep_provider.payload.cmi)
      nopam_directs.append(dep_provider.payload.o)
      if dep_provider.deps.nopam:
          # nopam_directs.append(dep_provider.payload)
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          nopam_indirects.append(dep_provider.deps.nopam)
          # opam_directs.append(None)

    elif OcamlInterfaceProvider in dep:
      ip = dep[OcamlInterfaceProvider]
      # print("OcamlInterfaceProvider dep: %s" % ip)
      nopam_directs.append(ip.payload.cmi)
      nopam_directs.append(ip.payload.mli)
      nopam_indirects.append(ip.deps.nopam)

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

      nopam_indirects.append(provider.indirect)

    ## rules_cc providers
    elif CcInfo in dep:
      cp = dep[CcInfo]
      if debug:
          print("CcInfo dep: %s" % cp)
          print("CcInfo payload: %s" % dep[DefaultInfo])
      nopam_directs.append(struct( clib = dep[DefaultInfo]) )

    # ## rules_foreign_cc providers
    # elif ForeignCcDeps in dep:
    #     ## depset of ForeignCcArtifact
    #     if debug:
    #         print("ForeignCcDeps dep: %s" % dep)
    #         print("ForeignCcDeps DefaultInfo: %s" % dep[DefaultInfo])
    #         print("ForeignCcDeps provider: %s" % dep[ForeignCcDeps])
    #         # nopam_directs.append(struct( clib = dep[DefaultInfo]) )

    ## PPX
    elif PpxArchiveProvider in dep:
        provider = dep[PpxArchiveProvider]
        if debug:
            print("PpxArchiveProvider: %s" % provider)
        # nopam_directs.append(provider.payload.cmxa)
        nopam_directs.append(provider.payload.a)
        nopam_indirects.append(provider.deps.nopam)
        nopam_lazy_indirects.append(provider.deps.nopam_lazy)
        opam_indirects.append(provider.deps.opam)
        opam_lazy_indirects.append(provider.deps.opam_lazy)
    elif PpxExecutableProvider in dep:
      bp = dep[PpxExecutableProvider]
      # print("PpxExecutableProvider: %s" % bp)
      nopam_directs.append(bp.payload)
      nopam_indirects.append(bp.deps.nopam)
      opam_indirects.append(bp.deps.opam)
    elif PpxModuleProvider in dep:
        if debug:
            print("PpxModuleProvider: %s" % provider)
        provider = dep[PpxModuleProvider]
        nopam_directs.append(provider.payload.cm)
        nopam_directs.append(provider.payload.cmi)
        nopam_directs.append(provider.payload.o)
        nopam_indirects.append(provider.deps.nopam)
        opam_indirects.append(provider.deps.opam)
        opam_lazy_indirects.append(provider.deps.opam_lazy)
        nopam_lazy_indirects.append(provider.deps.nopam_lazy)
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
              nopam_indirects.append(dep_provider.deps.nopam)
              # opam_directs.append(None)
          if dep_provider.deps.opam:
              opam_indirects.append(dep_provider.deps.opam)

  ## get lazy deps for ppx; ocaml_module and ppx_module only
  if hasattr(ctx.attr, "ppx"):
      if ctx.attr.ppx:
          if debug:
              print("{} PPX DEP: {}".format(ctx.label.name, ctx.attr.ppx))
          provider = ctx.attr.ppx[PpxExecutableProvider]
          if debug:
              print("PPX DEP PROVIDER: {}".format(provider))
          opam_lazy_indirects.append(provider.deps.opam_lazy)
          nopam_lazy_indirects.append(provider.deps.nopam_lazy)

  if hasattr(ctx.attr, "ns"):
      if ctx.attr.ns != None:
          dep_provider = ctx.attr.ns[OcamlNsModuleProvider]
          nopam_directs.append(dep_provider.payload.cm)
          nopam_directs.append(dep_provider.payload.cmi)
          nopam_directs.append(dep_provider.payload.o)
          if dep_provider.deps.nopam:
              # nopam_directs.append(dep_provider.payload)
              # nopam_directs.extend(dep[DefaultInfo].files.to_list())
              # nopam_directs.extend(dep[DefaultInfo].files.to_list())
              nopam_indirects.append(dep_provider.deps.nopam)
              # opam_directs.append(None)
          if dep_provider.deps.opam:
              opam_indirects.append(dep_provider.deps.opam)

  if hasattr(ctx.attr, "cc_deps"):
      if debug:
          print("DEPSET TARGET: %s" % ctx.label.name)
          print("DEPSET CC_DEPS: %s" % ctx.attr.cc_deps)
      for cc_dep in ctx.attr.cc_deps.items():
          dep = cc_dep[0]
          if debug:
              print("CC_DEP TYPE: %s" % cc_dep[1])
          # for depfile in cc_dep[0].files:
              # if debug:
              #     print("CC_DEP FILE: %s" % depfile)

          # if ForeignCcDeps in dep:
          #     # print("ForeignCcDeps dep: %s" % dep[ForeignCcDeps])
          #     for fdep in dep[DefaultInfo].files.to_list():
          #         if fdep.extension == "a":
          #             print("FCcDep: %s" % fdep)
          #             nopam_directs.append(fdep)
          #         # print("ForeignCcDeps DefaultInfo: %s" % dep[DefaultInfo])
          #         # print("ForeignCcDeps provider: %s" % dep[ForeignCcDeps])

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

  if hasattr(ctx.attr, "main"):
      print("MAIN")
      for dep in ctx.attr.main:
          if PpxModuleProvider in dep:
              if debug:
                  print("Main PpxModuleProvider: %s" % provider)
              provider = dep[PpxModuleProvider]
              nopam_directs.append(provider.payload.cm)
              nopam_directs.append(provider.payload.cmi)
              nopam_directs.append(provider.payload.o)
              nopam_indirects.append(provider.deps.nopam)
              opam_indirects.append(provider.deps.opam)
              opam_lazy_indirects.append(provider.deps.opam_lazy)
              nopam_lazy_indirects.append(provider.deps.nopam_lazy)
          else:
              fail("Main: must provide a PpxModuleModule")

  opam_depset = depset(
    order      = "postorder",
    direct     = opam_directs,
    transitive = opam_indirects
  )
  opam_adjunct_depset = depset(
    order      = "postorder",
    direct     = opam_lazy_directs,
    transitive = opam_lazy_indirects
  )

  nopam_depset = depset(
    order      = "postorder",
    direct = nopam_directs,
    transitive = nopam_indirects
  )
  nopam_adjunct_depset = depset(
    order      = "postorder",
    direct     = nopam_lazy_directs,
    transitive = nopam_lazy_indirects
  )


  if debug:
      print("\n\n\t\tGET_ALL_DEPS result {rule}({target})\n\n".format(rule=rule, target=ctx.label.name))
      print("\n\t\t\t OPAM DEPSET: %s\n\n"  % opam_depset)
      print("\n\t\t\t OPAM LAZY DEPSET: %s\n\n"  % opam_adjunct_depset)
      print("\n\t\t\t NOPAM DEPSET: %s\n\n" % nopam_depset)
      print("\n\t\t\t NOPAM LAZY DEPSET: %s\n\n" % nopam_adjunct_depset)

  # print("\n\n\t\t\t NOPAM DEPSET FILES: %s\n\n" % nopam_depset.to_list())

  return struct( default = defaults,
                 opam = opam_depset,
                 opam_lazy = opam_adjunct_depset,
                 nopam = nopam_depset,
                 nopam_lazy = nopam_adjunct_depset,
                )
