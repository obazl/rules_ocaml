# load("@rules_foreign_cc//tools/build_defs:framework.bzl",
#      "ForeignCcDeps",
#      "ForeignCcArtifact")

load("//ocaml/_providers:ocaml.bzl",
     "CompilationModeSettingProvider",
     "OcamlSDK",
     "OcamlArchiveProvider",
     "OcamlInterfaceProvider",
     "OcamlImportProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsModuleProvider")

# load("//ocaml/_providers:opam.bzl", "OpamPkgInfo")
load("@obazl_rules_opam//opam/_providers:opam.bzl", "OpamPkgInfo")

load("//ppx:_providers.bzl",
     "PpxArchiveProvider",
     "PpxCompilationModeSettingProvider",
     "PpxExecutableProvider",
     "PpxLibraryProvider",
     "PpxModuleProvider",
     "PpxNsModuleProvider")

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
  # if (ctx.label.name == "jemalloc"):
  #     debug = True

  if debug:
      print("GET_ALL_DEPS {rule}({target})".format(rule=rule, target=ctx.label))

  if CompilationModeSettingProvider in ctx.attr._mode:
      mode = ctx.attr._mode[CompilationModeSettingProvider].value
  else:
      if rule == "ppx_module":
          mode = ctx.attr._mode[0][PpxCompilationModeSettingProvider].value
      elif rule == "ppx_archive":
          mode = ctx.attr._mode[0][PpxCompilationModeSettingProvider].value
      else:
          mode = ctx.attr._mode[PpxCompilationModeSettingProvider].value

  defaults = []

  # used for Archives logic to filter out deps that are both direct and indirect
  target_directs = []
  for dep in ctx.files.deps:
      if dep.extension != "cmi":
          target_directs.append(dep)
  if debug:
      print("TARGET DIRECTS: %s" % target_directs)

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

  ## ppx rules may have a lazy_deps attrib.
  if hasattr(ctx.attr, "lazy_deps"):
      if debug:
          print("LAZY_DEPS: %s" % ctx.attr.lazy_deps)
      for dep in ctx.attr.lazy_deps:
          if OpamPkgInfo in dep:
              provider = dep[OpamPkgInfo]
              opam_lazy_directs.append(provider)
          else:
              if OcamlModuleProvider in dep:
                  provider = dep[OcamlModuleProvider]
                  if hasattr(provider.payload, "cmo"):
                      nopam_lazy_directs.append(provider.payload.cmo)
                  elif hasattr(provider.payload, "cmx"):
                      nopam_lazy_directs.append(provider.payload.cmx)
                  else:
                      fail("Lazy dep neither cmo nor cmx")
                  if hasattr(provider.payload, "o"):
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
                  if debug:
                      print("LAZY OcamlArchiveProvider dep: %s" % dep)
                  provider = dep[OcamlArchiveProvider]
                  nopam_lazy_directs.append(provider.payload.cm_a)
                  if hasattr(provider.payload, "mli"):
                      if provider.payload.mli != None:
                          nopam_lazy_directs.append(provider.payload.mli)
                  if hasattr(provider.payload, "a"):
                      nopam_lazy_directs.append(provider.payload.a)
                  if hasattr(provider, "deps"):
                      if provider.deps.nopam:
                          nopam_lazy_indirects.append(provider.deps.nopam)
              elif PpxModuleProvider in dep:
                  if debug:
                      print("LAZY PpxModuleProvider dep: %s" % dep)
                  provider = dep[PpxModuleProvider]
                  if mode == "native":
                      nopam_lazy_directs.append(provider.payload.cmx)
                  else:
                      nopam_lazy_directs.append(provider.payload.cmo)
                  if hasattr(provider.payload, "o"):
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
                  if debug:
                      print("LAZY PpxArchiveProvider dep: %s" % dep)
                  provider = dep[PpxArchiveProvider]
                  nopam_lazy_directs.append(provider.payload.cm_a)
                  if hasattr(provider.payload, "mli"):
                      if provider.payload.mli != None:
                          nopam_lazy_directs.append(provider.payload.mli)
                  if hasattr(provider.payload, "a"):
                      nopam_lazy_directs.append(provider.payload.a)
                  if provider.deps.nopam:
                      nopam_lazy_indirects.append(provider.deps.nopam)
              elif PpxExecutableProvider in dep:
                  provider = dep[PpxExecutableProvider]
                  if debug:
                      print("LAZY PpxExecutableProvider dep: %s" % dep)
                  nopam_lazy_directs.append(provider.payload)
                  if hasattr(provider.payload, "mli"):
                      if provider.payload.mli != None:
                          nopam_lazy_directs.append(provider.payload.mli)
                  if hasattr(provider.payload, "a"):
                      nopam_lazy_directs.append(provider.payload.a)
                  if provider.deps.nopam:
                      nopam_lazy_indirects.append(provider.deps.nopam)
              else:
                      print("LAZY Unknown Provider dep: %s" % dep)

  if debug:
      print("DIRECT_DEPS: %s" % ctx.attr.deps)
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
      if debug:
          print("OcamlArchiveProvider: %s" % dep)
      dep_provider = dep[OcamlArchiveProvider]
      # print("#### OcamlArchiveProvider: %s" % dep_provider)
      # print("#### OcamlArchiveProvider DefaultInfo: %s" % dep[DefaultInfo])
      if hasattr(dep_provider, "deps"):
          if dep_provider.deps.opam:
              opam_indirects.append(dep_provider.deps.opam)

      if rule == "ocaml_archive":
          ## this includes both direct deps (submods) and indirect deps!
          # nopam_directs.extend(dep_provider.deps.nopam.to_list())
          nopam_directs.append(dep_provider.payload.cm_a)
          if hasattr(dep_provider, "deps"):
              nopam_indirects.append(dep_provider.deps.nopam)
          if hasattr(dep_provider.payload, "cmmi"):
              if dep_provider.payload.mli != None:
                  nopam_directs.append(dep_provider.payload.cmi)
          if hasattr(dep_provider.payload, "mli"):
              if dep_provider.payload.mli != None:
                  nopam_directs.append(dep_provider.payload.mli)
      elif rule == "ocaml_executable":
          # print("payload: %s" % dep_provider.payload)
          ## this includes both direct deps (submods) and indirect deps!
          nopam_directs.append(dep_provider.payload.cm_a)
          # nopam_directs.extend(dep_provider.deps.nopam.to_list())
      else:
          # nopam_directs.extend(dep_provider.deps.nopam.to_list())
          nopam_directs.append(dep_provider.payload.cm_a)
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          ## no nopam transitives, they're already in the cmxa file(?)
          ## what about second-order deps?
          if hasattr(dep_provider, "deps"):
              nopam_indirects.append(dep_provider.deps.nopam)

    elif OcamlLibraryProvider in dep:
      if debug:
          print("OcamlLibraryProvider: %s" % dep)
      provider = dep[OcamlLibraryProvider]
      # print("OcamlLibraryProvider: %s" % provider)
      # nopam_directs.append(provider.payload)
      nopam_indirects.append(provider.deps.nopam)
      if provider.deps.opam:
        opam_indirects.append(provider.deps.opam)

    elif OcamlModuleProvider in dep:
      if debug:
          print("OcamlModuleProvider: %s" % dep)
      dep_provider = dep[OcamlModuleProvider]
      # print("____ OcamlModuleProvider provider: %s" % dep_provider)
      # print("____ OcamlModuleProvider DefaultInfo: %s" % dep[DefaultInfo])

      if dep_provider.deps.opam:
        opam_indirects.append(dep_provider.deps.opam)
      # opams = opams + d.opam_deps.to_list()

      # if rule != "ocaml_archive":
      if mode == "native":
          if hasattr(dep_provider.payload, "cmx"):
              nopam_directs.append(dep_provider.payload.cmx)
          else:
              fail("native ocaml_module without cmx: %s" % dep_provider)
      else:
          nopam_directs.append(dep_provider.payload.cmo)
      if hasattr(dep_provider.payload, "mli"):
          if dep_provider.payload.mli != None:
              nopam_directs.append(dep_provider.payload.mli)
      nopam_directs.append(dep_provider.payload.cmi)
      if hasattr(dep_provider.payload, "o"):
          nopam_directs.append(dep_provider.payload.o)
      if dep_provider.deps.nopam:
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          nopam_indirects.append(dep_provider.deps.nopam)
          # opam_directs.append(None)
      # print("____ nopam transitives: %s" % nopam_indirects)
    elif OcamlNsModuleProvider in dep:
      if debug:
          print("OcamlNsModuleProvider: %s" % dep)
      dep_provider = dep[OcamlNsModuleProvider]
      # print("++++ OcamlNsModuleProvider dep: %s" % dep_provider)
      # print("++++ OcamlNsModuleProvider DefaultInfo: %s" % dep[DefaultInfo])
      if dep_provider.deps.opam:
        opam_indirects.append(dep_provider.deps.opam)
      # opams = opams + d.opam_deps.to_list()

      # if rule != "ppx_archive":
      #     if rule != "ocaml_archive":
      if hasattr(dep_provider.payload, "cmx"):
          nopam_directs.append(dep_provider.payload.cmx)
      if hasattr(dep_provider.payload, "cmo"):
          nopam_directs.append(dep_provider.payload.cmo)
      nopam_directs.append(dep_provider.payload.cmi)
      if hasattr(dep_provider.payload, "o"):
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
      if provider.payload.cm_a:
          nopam_directs.append(provider.payload.cm_a.files.to_list()[0])
      if provider.payload.cmxs:
          nopam_directs.append(provider.payload.cmxs.files.to_list()[0])
      # nopam_directs.append(provider.payload.ml)

      nopam_indirects.append(provider.indirect)

    elif CcInfo in dep:
        cp = dep[CcInfo]
        if debug:
            print("CcInfo dep: %s" % cp)
            print("CcInfo payload: %s" % dep[DefaultInfo])
        for f in dep[DefaultInfo].files.to_list():
            nopam_directs.append(f)

    # https://docs.bazel.build/versions/master/integrating-with-rules-cc.html
    # Implementing starlark rules that depend on cc rules:
    # Be careful, however - if you only need to propagate CcInfo
    # through the graph to the binary rule that then makes use of it,
    # wrap CcInfo in a different provider

    # which suggests OcamlCcInfo

    # CcInfo contains linking info, so if we pass it along, the
    # ultimate executable can extract the linkopts from the trans. closure.
    # But then how to iterate over CcInfo.linking_context items in depset?

    ## rules_foreign_cc providers:
    # [
    #     DefaultInfo(files = depset(direct = rule_outputs + wrapped_files)),
    #     OutputGroupInfo(**output_groups),
    #     ForeignCcDeps(artifacts = depset(
    #         [externally_built],
    #         transitive = _get_transitive_artifacts(attrs.deps),
    #     )),
    #     CcInfo(
    #         compilation_context = out_cc_info.compilation_context,
    #         linking_context = out_cc_info.linking_context,
    #     ),
    # ]

    

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
        # nopam_directs.append(provider.payload.cm_a)
        if hasattr(provider.payload, "a"):
            nopam_directs.append(provider.payload.a)
        nopam_directs.append(provider.payload.cm_a)

        # if rule == "ppx_executable"
        nopam_indirects.append(provider.deps.nopam)

        opam_indirects.append(provider.deps.opam)
        opam_lazy_indirects.append(provider.deps.opam_lazy)
        nopam_lazy_indirects.append(provider.deps.nopam_lazy)
    elif PpxExecutableProvider in dep:
      bp = dep[PpxExecutableProvider]
      # print("PpxExecutableProvider: %s" % bp)
      nopam_directs.append(bp.payload)
      nopam_indirects.append(bp.deps.nopam)
      opam_indirects.append(bp.deps.opam)
    elif PpxLibraryProvider in dep:
      if debug:
          print("PpxLibraryProvider: %s" % dep)
      provider = dep[PpxLibraryProvider]
      # print("PpxLibraryProvider: %s" % provider)
      # nopam_directs.append(provider.payload)
      nopam_indirects.append(provider.deps.nopam)
      if provider.deps.opam:
        opam_indirects.append(provider.deps.opam)

    elif PpxModuleProvider in dep:
        provider = dep[PpxModuleProvider]
        if debug:
            print("PpxModuleProvider: %s" % dep)
            print("RULE: {r} : {l}".format(r=rule, l=ctx.label))
            print(provider)
        # if rule != "ppx_archive":
        #     if rule != "ocaml_archive":
        if mode == "native":
            nopam_directs.append(provider.payload.cmx)
        else:
            nopam_directs.append(provider.payload.cmo)
        nopam_directs.append(provider.payload.cmi)

        if hasattr(provider.payload, "o"):
            nopam_directs.append(provider.payload.o)
        nopam_indirects.append(provider.deps.nopam)
        # if rule == "ppx_archive":
        #     ## add all indirects EXCEPT those that are also directs
        #     ## e.g. if A and B are directs, and B depends on A, then B is both direct and indirect
        #     for dep in provider.deps.nopam.to_list():
        #         if dep.extension != "cmi":
        #             print("FILTERING INDIRECTS: %s" % dep)
        #             if dep not in target_directs:
        #                 nopam_indirects.append(provider.deps.nopam)
        #             else:
        #                 if debug:
        #                     print("OMITTING INDIRECT/DIRECT DEP: %s" % dep)

        opam_indirects.append(provider.deps.opam)
        opam_lazy_indirects.append(provider.deps.opam_lazy)
        nopam_lazy_indirects.append(provider.deps.nopam_lazy)
    elif PpxNsModuleProvider in dep:
      if debug:
          print("PpxNsModuleProvider: %s" % dep)
      dep_provider = dep[PpxNsModuleProvider]
      # print("++++ PpxNsModuleProvider dep: %s" % dep_provider)
      # print("++++ PpxNsModuleProvider DefaultInfo: %s" % dep[DefaultInfo])
      if dep_provider.deps.opam:
        opam_indirects.append(dep_provider.deps.opam)
      # opams = opams + d.opam_deps.to_list()

      # if rule != "ppx_archive":
      #     if rule != "ocaml_archive":
      if hasattr(dep_provider.payload, "cmx"):
          nopam_directs.append(dep_provider.payload.cmx)
      if hasattr(dep_provider.payload, "cmo"):
          nopam_directs.append(dep_provider.payload.cmo)
      nopam_directs.append(dep_provider.payload.cmi)
      if hasattr(dep_provider.payload, "o"):
          nopam_directs.append(dep_provider.payload.o)
      if dep_provider.deps.nopam:
          # nopam_directs.append(dep_provider.payload)
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          # nopam_directs.extend(dep[DefaultInfo].files.to_list())
          nopam_indirects.append(dep_provider.deps.nopam)
          # opam_directs.append(None)
    else:
      fail("UNKNOWN DEP TYPE: %s" % dep)

    # _deps is a label attribute
    if rule == "ppx_module":
        if hasattr(ctx.attr, "_deps"):
            if ctx.attr._deps.label.name != "null":
                print("HIDDEN _deps: %s" % ctx.attr._deps)
            if OpamPkgInfo in ctx.attr._deps:
                provider = ctx.attr._deps[OpamPkgInfo]
                print("Hidden OpamPkgInfo dep: %s" % provider)
                # print("OpamPkgInfo type: %s" % type(provider))
                # opam_directs.append(provider)
        elif OcamlLibraryProvider in ctx.attr._deps:
            print("HIDDEN Library: %s" % ctx.attr._deps[OcamlLibraryProvider])
        elif OcamlArchiveProvider in ctx.attr._deps:
            print("HIDDEN Archive: %s" % ctx.attr._deps[OcamlArchiveProvider])
        elif PpxArchiveProvider in ctx.attr._deps:
            print("HIDDEN PPX archive: %s" % ctx.attr._deps[PpxArchiveProvider])
        elif PpxLibraryProvider in ctx.attr._deps:
            print("HIDDEN PPX Library: %s" % ctx.attr._deps[PpxLibraryProvider])
        elif PpxModuleProvider in ctx.attr._deps:
            print("HIDDEN PPX Module: %s" % ctx.attr._deps[PpxModuleProvider])
      # rules_foreign_cc
      # if ForeignCcDeps in ctx.attr._deps:
      #     print("HIDDEN CcInfo: %s" % ctx.attr._deps[ForeignCcDeps])
      # if ForeignCcArtifact in ctx.attr._deps:
      #     print("HIDDEN CcInfo: %s" % ctx.attr._deps[ForeignCcArtifact])

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

  ## ns attribute: label for module and intf, string for ocaml_ns
  if (rule == "ocaml_module") or (rule == "ocaml_interface") or (rule == "ppx_module"):
      ## FIXME: do we need to propagate the deps of *.mli files?
      if hasattr(ctx.attr, "ns"):
          if ctx.attr.ns != None:
              if OcamlNsModuleProvider in ctx.attr.ns:
                  dep_provider = ctx.attr.ns[OcamlNsModuleProvider]
              else:
                  dep_provider = ctx.attr.ns[PpxNsModuleProvider]
              # if rule != "ppx_archive":
              #     if rule != "ocaml_archive":
              if hasattr(dep_provider.payload, "cmx"):
                  nopam_directs.append(dep_provider.payload.cmx)
              if hasattr(dep_provider.payload, "cmo"):
                  nopam_directs.append(dep_provider.payload.cmo)
              if hasattr(dep_provider.payload, "o"):
                  nopam_directs.append(dep_provider.payload.o)
              if hasattr(dep_provider.payload, "cmi"):
                  nopam_directs.append(dep_provider.payload.cmi)
              if hasattr(dep_provider.payload, "mli"):
                  nopam_directs.append(dep_provider.payload.mli)

              if dep_provider.deps.nopam:
                  # nopam_directs.append(dep_provider.payload)
                  # nopam_directs.extend(dep[DefaultInfo].files.to_list())
                  # nopam_directs.extend(dep[DefaultInfo].files.to_list())
                  nopam_indirects.append(dep_provider.deps.nopam)
                  # opam_directs.append(None)
              if dep_provider.deps.opam:
                  opam_indirects.append(dep_provider.deps.opam)

  ## FIXME: what if cc_deps says dynamic but a static lib is passed?
  ## the link type val sets a requirement, throw an error if the target key does not match
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
              for depfile in cc_dep[0].files.to_list():
                  if (depfile.extension == "a"):
                      if debug:
                          print("ADDING STATIC TO NOPAM_DIRECTS: %s " % depfile)
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

          elif cc_dep[1] == "default":
              if debug:
                  print("DEPSET DEFAULT")
              tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
              if tc.linkmode == "static":
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
          elif cc_dep[1] == "static-linkall":
              x = None
              ## skip these, they are handled by the rule and not in the dep graph
              ## FIXME: add a depset for linkalls
              ## FIXME: what about dynamic-linkall?
          else:
              fail("Allowed values of cc_deps attribute: 'default', 'dynamic', 'static' or 'static-linkall' %s" % cc_dep[1])

  # if hasattr(ctx.attr, "cc_linkall"):
  #     if debug:
  #         print("DEPSET CC_LINKALL: %s" % ctx.attr.cc_linkall)
  #     for cc_dep in ctx.attr.cc_linkall:
  #         nopam_directs.append(cc_dep)

  if hasattr(ctx.attr, "_cc_deps"):
      # print("################ HIDDEN DEPS: %s" % ctx.attr._cc_deps)
      # print("Target: %s" % ctx.label)
      if CcInfo in ctx.attr._cc_deps:
          # print("HIDDEN CcInfo: %s" % ctx.attr._cc_deps[CcInfo])
          # print("HIDDEN DefaultInfo: %s" % ctx.attr._cc_deps[DefaultInfo])
          tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
          for file in ctx.attr._cc_deps[DefaultInfo].files.to_list():
              # print("FILE: %s" % file)
              if file.extension == "a":
                  nopam_directs.append(file)
              elif file.extension == "so":
                  nopam_directs.append(file)
              elif file.extension == "dylib":
                  nopam_directs.append(file)

      elif OpamPkgInfo in ctx.attr._cc_deps:
          opam_dep = ctx.attr._cc_deps[OpamPkgInfo]
          # print("HIDDEN Opam pkg: %s" % opam_dep)
          # print("HIDDEN Opam ppx_driver?: %s" % opam_dep.ppx_driver)
          if opam_dep.ppx_driver:
              if rule == "ppx_executable":
                  opam_directs.append(opam_dep)
              if opam_dep.pkg == Label("@opam//pkg:bisect_ppx"):
                  opam_lazy_directs.append(
                      # Temporary hack until opam rules contain adjunct deps
                      OpamPkgInfo(
                          pkg = Label("@opam//pkg:bisect_ppx.runtime"),
                          ppx_driver = False
                      )
                  )
      else:

          ## FIXME: deal with cc libs produced by rules_foriegn_cc
          # print("HIDDEN CcInfo: %s" % ctx.attr._cc_deps[CcInfo])
          # print("HIDDEN DefaultInfo: %s" % ctx.attr._cc_deps[DefaultInfo])
          tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
          for file in ctx.attr._cc_deps[DefaultInfo].files.to_list():
              # print("FILE: %s" % file)
              if file.extension == "a":
                  nopam_directs.append(file)
              elif file.extension == "so":
                  nopam_directs.append(file)
              elif file.extension == "dylib":
                  nopam_directs.append(file)

  ## MUST COME LAST!!!
  if hasattr(ctx.attr, "main"):
      if debug:
          print("HASATTR MAIN")
      if ctx.attr.main != None:
          if (PpxModuleProvider in ctx.attr.main):
              provider = ctx.attr.main[PpxModuleProvider]
              nopam_lazy_indirects.append(provider.deps.nopam_lazy)
              opam_lazy_indirects.append(provider.deps.opam_lazy)
          elif (OcamlModuleProvider in ctx.attr.main):
              provider = ctx.attr.main[OcamlModuleProvider]
          else:
              fail("Main must be ocaml_module or ppx_module.")
          if mode == "native":
              nopam_directs.append(provider.payload.cmx)
          else:
              nopam_directs.append(provider.payload.cmo)
          nopam_directs.append(provider.payload.cmi)
          if hasattr(provider.payload, "o"):
              nopam_directs.append(provider.payload.o)
          nopam_indirects.append(provider.deps.nopam)
          opam_indirects.append(provider.deps.opam)

  ## HACK! digestif is special
  # for dep in opam_directs:
  #     if dep.pkg == Label("@opam//pkg:digestif.c"):
  #         print("DIGESTIF.C: {}".format(ctx.label))
  #     if dep.pkg == Label("@opam//pkg:digestif.ocaml"):
  #         print("DIGESTIF.OCAML: {}".format(ctx.label))

  opam_depset = depset(
    order      = "postorder",
    direct     = opam_directs,
    transitive = opam_indirects
  )
  opam_lazy_depset = depset(
    order      = "postorder",
    direct     = opam_lazy_directs,
    transitive = opam_lazy_indirects
  )

  nopam_depset = depset(
    order      = "postorder",
    direct =  [x for x in nopam_directs if x != None],
    transitive = nopam_indirects
  )
  nopam_lazy_depset = depset(
    order      = "postorder",
    direct     = nopam_lazy_directs,
    transitive = nopam_lazy_indirects
  )


  if debug:
      print("\n\n\t\tGET_ALL_DEPS result {rule}({target})\n\n".format(rule=rule, target=ctx.label.name))
      print("\n\t\t\t OPAM DEPSET: %s\n\n"  % opam_depset)
      print("\n\t\t\t OPAM LAZY DEPSET: %s\n\n"  % opam_lazy_depset)
      print("\n\t\t\t NOPAM DEPSET: %s\n\n" % nopam_depset)
      print("\n\t\t\t NOPAM LAZY DEPSET: %s\n\n" % nopam_lazy_depset)

  # print("\n\n\t\t\t NOPAM DEPSET FILES: %s\n\n" % nopam_depset.to_list())

  return struct( default = defaults,
                 opam = opam_depset,
                 opam_lazy = opam_lazy_depset,
                 nopam = nopam_depset,
                 nopam_lazy = nopam_lazy_depset,
                )
