## ocaml/_rules/impl_common.bzl

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "AdjunctDepsMarker",
     "CcDepsProvider",
     "OcamlArchiveMarker",
     # "OcamlImportMarker",
     "OcamlLibraryMarker",
     "OcamlModuleMarker",
     "OcamlNsArchiveMarker",
     "OcamlNsLibraryMarker",
     "OcamlNsResolverProvider",
     "OcamlSignatureMarker",
     # "OpamDepsMarker",
     "PpxArchiveMarker",
     "PpxLibraryMarker",
     "PpxModuleMarker",
     "PpxNsArchiveMarker",
     "PpxNsLibraryMarker"
     )

# load("//ocaml:providers.bzl",
#      "OcamlImportMarker",
#      "OcamlImportArchivesMarker",
#      "OcamlImportPluginsMarker",
#      "OcamlImportSignaturesMarker",
#      "OcamlImportPathsMarker",
#      "OcamlImportPpxAdjunctsMarker")

tmpdir = "" # "__obazl/"

dsorder = "postorder"

opam_lib_prefix = "external/ocaml/_lib"

####################
def merge_deps(deps,
               merged_module_links_depsets,
               ## signatures ("virtual" modules) added to
               ## merged_module_links_depsets
               merged_archive_links_depsets,
               merged_paths_depsets,
               merged_depgraph_depsets,
               merged_archived_modules_depsets,

               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_cc_deps):

    ccdeps_labels = {}
    ccdeps = {}

    for dep in deps:
        # print("DEP: {d}, lbl: '{lbl}', type: {t}".format(
        #     d = dep, lbl = dep.label if type(dep) == "Target" else "",
        #     t = type(dep)))

        ## this is for ctx.attr.sig, which is single label/file
        if type(dep) == "list":
            if  OcamlSignatureMarker in dep[0]:
                # print("SIGDEP depgraph:")
                # print(dep[0][OcamlSignatureMarker].depgraph)
                if hasattr(dep[0][OcamlSignatureMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[0][OcamlSignatureMarker].archive_links)
                if hasattr(dep[0][OcamlSignatureMarker], "module_links"):
                    merged_module_links_depsets.append(dep[0][OcamlSignatureMarker].module_links)
                if hasattr(dep[0][OcamlSignatureMarker], "paths"):
                    merged_paths_depsets.append(dep[0][OcamlSignatureMarker].paths)
                if hasattr(dep[0][OcamlSignatureMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[0][OcamlSignatureMarker].depgraph)
                if hasattr(dep[0][OcamlSignatureMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[0][OcamlSignatureMarker].archived_modules)

        ## this is for ctx.attr.deps etc. - label lists
        else:
            if OcamlModuleMarker in dep:
                # print("MODULEDEP depgraph")
                # print(dep[OcamlModuleMarker].depgraph)
                if hasattr(dep[OcamlModuleMarker], "module_links"):
                    merged_module_links_depsets.append(dep[OcamlModuleMarker].module_links)
                if hasattr(dep[OcamlModuleMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[OcamlModuleMarker].archive_links)
                if hasattr(dep[OcamlModuleMarker], "paths"):
                    merged_paths_depsets.append(dep[OcamlModuleMarker].paths)
                if hasattr(dep[OcamlModuleMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[OcamlModuleMarker].depgraph)
                if hasattr(dep[OcamlModuleMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[OcamlModuleMarker].archived_modules)

            if  OcamlSignatureMarker in dep:
                # print("SIGDEP depgraph:")
                # print(dep[OcamlSignatureMarker].depgraph)
                if hasattr(dep[OcamlSignatureMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[OcamlSignatureMarker].archive_links)
                if hasattr(dep[OcamlSignatureMarker], "module_links"):
                    merged_module_links_depsets.append(dep[OcamlSignatureMarker].module_links)
                if hasattr(dep[OcamlSignatureMarker], "paths"):
                    merged_paths_depsets.append(dep[OcamlSignatureMarker].paths)
                if hasattr(dep[OcamlSignatureMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[OcamlSignatureMarker].depgraph)
                if hasattr(dep[OcamlSignatureMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[OcamlSignatureMarker].archived_modules)

            ################################################################
            ## ocaml_import provides: archives, plugins, sigs, etc.
            # if OcamlImportPathsMarker in dep:
            #     merged_paths_depsets.append(dep[OcamlImportPathsMarker].paths)

            # if OcamlImportArchivesMarker in dep:
            #     ideps = dep[OcamlImportArchivesMarker]
            #     merged_archive_links_depsets.append(ideps.archives)
            #     # if dep.label.name in ["bls12-381", "bls12-381-gen"]:
            #     #     print("X381A: %s" % ideps)

            # # if OcamlImportPluginsMarker in dep:
            # #     merged_???_depsets.append(dep[OcamlImportPluginsMarker].plugins)

            # if OcamlImportSignaturesMarker in dep:
            #     ## mix with modules for now...
            #     ideps = dep[OcamlImportSignaturesMarker]
            #     merged_module_links_depsets.append(ideps.signatures)
            #     if dep.label.name in ["bls12-381", "bls12-381-gen"]:
            #         print("X381SIG: %s" % ideps)

            # if OcamlImportPpxAdjunctsMarker in dep:
            #     indirect_adjunct_depsets.append(dep[OcamlImportPpxAdjunctsMarker].ppx_adjuncts)
            #     # if hasattr(dep[OcamlImportMarker], "deps_adjunct_paths"):
            #     #     indirect_adjunct_path_depsets.append(dep[OcamlImportMarker].deps_adjunct_paths)

            ################################################################
            if PpxModuleMarker in dep:
                if hasattr(dep[PpxModuleMarker], "module_links"):
                    merged_module_links_depsets.append(dep[PpxModuleMarker].module_links)
                if hasattr(dep[PpxModuleMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[PpxModuleMarker].archive_links)
                if hasattr(dep[PpxModuleMarker], "paths"):
                    merged_paths_depsets.append(dep[PpxModuleMarker].paths)
                if hasattr(dep[PpxModuleMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[PpxModuleMarker].depgraph)
                if hasattr(dep[PpxModuleMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[PpxModuleMarker].archived_modules)

            if OcamlArchiveMarker in dep:
                if hasattr(dep[OcamlArchiveMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[OcamlArchiveMarker].archive_links)
                if hasattr(dep[OcamlArchiveMarker], "module_links"):
                    merged_module_links_depsets.append(dep[OcamlArchiveMarker].module_links)
                if hasattr(dep[OcamlArchiveMarker], "paths"):
                    merged_paths_depsets.append(dep[OcamlArchiveMarker].paths)
                if hasattr(dep[OcamlArchiveMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[OcamlArchiveMarker].depgraph)
                if hasattr(dep[OcamlArchiveMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[OcamlArchiveMarker].archived_modules)

            if PpxArchiveMarker in dep:
                if hasattr(dep[PpxArchiveMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[PpxArchiveMarker].archive_links)
                if hasattr(dep[PpxArchiveMarker], "module_links"):
                    merged_module_links_depsets.append(dep[PpxArchiveMarker].module_links)
                if hasattr(dep[PpxArchiveMarker], "paths"):
                    merged_paths_depsets.append(dep[PpxArchiveMarker].paths)
                if hasattr(dep[PpxArchiveMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[PpxArchiveMarker].depgraph)
                if hasattr(dep[PpxArchiveMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[PpxArchiveMarker].archived_modules)

            if OcamlLibraryMarker in dep:
                if hasattr(dep[OcamlLibraryMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[OcamlLibraryMarker].archive_links)
                if hasattr(dep[OcamlLibraryMarker], "module_links"):
                    merged_module_links_depsets.append(dep[OcamlLibraryMarker].module_links)
                if hasattr(dep[OcamlLibraryMarker], "paths"):
                    merged_paths_depsets.append(dep[OcamlLibraryMarker].paths)
                if hasattr(dep[OcamlLibraryMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[OcamlLibraryMarker].depgraph)
                if hasattr(dep[OcamlLibraryMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[OcamlLibraryMarker].archived_modules)

            if PpxLibraryMarker in dep:
                if hasattr(dep[PpxLibraryMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[PpxLibraryMarker].archive_links)
                if hasattr(dep[PpxLibraryMarker], "module_links"):
                    merged_module_links_depsets.append(dep[PpxLibraryMarker].module_links)
                if hasattr(dep[PpxLibraryMarker], "paths"):
                    merged_paths_depsets.append(dep[PpxLibraryMarker].paths)
                if hasattr(dep[PpxLibraryMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[PpxLibraryMarker].depgraph)
                if hasattr(dep[PpxLibraryMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[PpxLibraryMarker].archived_modules)

            if OcamlNsArchiveMarker in dep:
                if hasattr(dep[OcamlNsArchiveMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[OcamlNsArchiveMarker].archive_links)
                if hasattr(dep[OcamlNsArchiveMarker], "module_links"):
                    merged_module_links_depsets.append(dep[OcamlNsArchiveMarker].module_links)
                if hasattr(dep[OcamlNsArchiveMarker], "paths"):
                    merged_paths_depsets.append(dep[OcamlNsArchiveMarker].paths)
                if hasattr(dep[OcamlNsArchiveMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[OcamlNsArchiveMarker].depgraph)
                if hasattr(dep[OcamlNsArchiveMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[OcamlNsArchiveMarker].archived_modules)

            if PpxNsArchiveMarker in dep:
                if hasattr(dep[PpxNsArchiveMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[PpxNsArchiveMarker].archive_links)
                if hasattr(dep[PpxNsArchiveMarker], "module_links"):
                    merged_module_links_depsets.append(dep[PpxNsArchiveMarker].module_links)
                if hasattr(dep[PpxNsArchiveMarker], "paths"):
                    merged_paths_depsets.append(dep[PpxNsArchiveMarker].paths)
                if hasattr(dep[PpxNsArchiveMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[PpxNsArchiveMarker].depgraph)
                if hasattr(dep[PpxNsArchiveMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[PpxNsArchiveMarker].archived_modules)

            if OcamlNsLibraryMarker in dep:
                if hasattr(dep[OcamlNsLibraryMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[OcamlNsLibraryMarker].archive_links)
                if hasattr(dep[OcamlNsLibraryMarker], "module_links"):
                    merged_module_links_depsets.append(dep[OcamlNsLibraryMarker].module_links)
                if hasattr(dep[OcamlNsLibraryMarker], "paths"):
                    merged_paths_depsets.append(dep[OcamlNsLibraryMarker].paths)
                if hasattr(dep[OcamlNsLibraryMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[OcamlNsLibraryMarker].depgraph)
                if hasattr(dep[OcamlNsLibraryMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[OcamlNsLibraryMarker].archived_modules)

            if PpxNsLibraryMarker in dep:
                if hasattr(dep[PpxNsLibraryMarker], "archive_links"):
                    merged_archive_links_depsets.append(dep[PpxNsLibraryMarker].archive_links)
                if hasattr(dep[PpxNsLibraryMarker], "module_links"):
                    merged_module_links_depsets.append(dep[PpxNsLibraryMarker].module_links)
                if hasattr(dep[PpxNsLibraryMarker], "paths"):
                    merged_paths_depsets.append(dep[PpxNsLibraryMarker].paths)
                if hasattr(dep[PpxNsLibraryMarker], "depgraph"):
                    merged_depgraph_depsets.append(dep[PpxNsLibraryMarker].depgraph)
                if hasattr(dep[PpxNsLibraryMarker], "archived_modules"):
                    merged_archived_modules_depsets.append(dep[PpxNsLibraryMarker].archived_modules)

            if OcamlNsResolverProvider in dep:
                merged_module_links_depsets.append(dep[DefaultInfo].files)
                if hasattr(dep[OcamlNsResolverProvider], "paths"):
                    merged_paths_depsets.append(dep[OcamlNsResolverProvider].paths)
                if hasattr(dep[OcamlNsResolverProvider], "files"):
                    merged_depgraph_depsets.append(dep[OcamlNsResolverProvider].files)

            if AdjunctDepsMarker in dep:
                # print(dep[AdjunctDepsMarker])
                indirect_adjunct_depsets.append(dep[AdjunctDepsMarker].nopam)
                indirect_adjunct_path_depsets.append(dep[AdjunctDepsMarker].nopam_paths)
                # indirect_adjunct_opam_depsets.append(dep[AdjunctDepsMarker].opam)

            # if OpamDepsMarker in dep:
            #     indirect_opam_depsets.append(dep[OpamDepsMarker].pkgs)

            if CcDepsProvider in dep:
                # if str(dep.label) == "//kernel:_Names":
                #     print("CC DEPS DEP: %s" % dep.label)
                #     print("CCDEPSPROVIDER: %s" % dep[CcDepsProvider])
                #     print("  CCDEPS: %s" % ccdeps)
                for [dep, linkmode] in dep[CcDepsProvider].libs.items():  ## ccdict.items():
                    # print("Processing dep {d}, linkmode {l}".format(d=dep, l=linkmode))
                    if dep.label in ccdeps_labels.keys():
                        if linkmode != ccdeps_labels[dep.label]:
                            fail("CCDEP: same key {k}, different vals: {v1}, {v2}".format(
                                k = dep,
                                v1 = ccdeps_labels[dep.label], v2 = linkmode
                            ))
                        # else:
                        #     print("Removing DUP ccdep: {k}: {v}".format(
                        #         k = dep, v = linkmode
                        #     ))
                    else:
                        # print("UPDATING %s" % dep.label)
                        ccdeps_labels.update({dep.label: linkmode})
                        ccdeps.update({dep: linkmode})
                        # print("UPDATED CCDEPS_LABELS: %s" % ccdeps_labels)
                        # print("UPDATED CCDEPS: %s" % ccdeps)

    indirect_cc_deps.update(ccdeps)
    # print("UPDATED INDIRECT_CC_DEPS: %s" % indirect_cc_deps)
