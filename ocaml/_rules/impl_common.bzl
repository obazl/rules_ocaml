## ocaml/_rules/impl_common.bzl

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CcDepsProvider",
     "OcamlArchiveProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsArchiveProvider",
     "OcamlNsLibraryProvider",
     "OcamlNsResolverProvider",
     "OcamlSignatureProvider",
     "OpamDepsProvider",
     "PpxArchiveProvider",
     "PpxLibraryProvider",
     "PpxModuleProvider",
     "PpxNsArchiveProvider",
     "PpxNsLibraryProvider"
     )

tmpdir = "__obazl/"

####################
def merge_deps(deps,
               merged_module_links_depsets,
               merged_archive_links_depsets,
               merged_paths_depsets,
               merged_depgraph_depsets,
               merged_archived_modules_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps):

    ccdeps_labels = {}
    ccdeps = {}

    for dep in deps:

        if OcamlModuleProvider in dep:
            if hasattr(dep[OcamlModuleProvider], "module_links"):
                merged_module_links_depsets.append(dep[OcamlModuleProvider].module_links)
            if hasattr(dep[OcamlModuleProvider], "archive_links"):
                merged_archive_links_depsets.append(dep[OcamlModuleProvider].archive_links)
            if hasattr(dep[OcamlModuleProvider], "paths"):
                merged_paths_depsets.append(dep[OcamlModuleProvider].paths)
            if hasattr(dep[OcamlModuleProvider], "depgraph"):
                merged_depgraph_depsets.append(dep[OcamlModuleProvider].depgraph)
            if hasattr(dep[OcamlModuleProvider], "archived_modules"):
                merged_archived_modules_depsets.append(dep[OcamlModuleProvider].archived_modules)

        if PpxModuleProvider in dep:
            if hasattr(dep[PpxModuleProvider], "module_links"):
                merged_module_links_depsets.append(dep[PpxModuleProvider].module_links)
            if hasattr(dep[PpxModuleProvider], "archive_links"):
                merged_archive_links_depsets.append(dep[PpxModuleProvider].archive_links)
            if hasattr(dep[PpxModuleProvider], "paths"):
                merged_paths_depsets.append(dep[PpxModuleProvider].paths)
            if hasattr(dep[PpxModuleProvider], "depgraph"):
                merged_depgraph_depsets.append(dep[PpxModuleProvider].depgraph)
            if hasattr(dep[PpxModuleProvider], "archived_modules"):
                merged_archived_modules_depsets.append(dep[PpxModuleProvider].archived_modules)

        if OcamlArchiveProvider in dep:
            if hasattr(dep[OcamlArchiveProvider], "archive_links"):
                merged_archive_links_depsets.append(dep[OcamlArchiveProvider].archive_links)
            if hasattr(dep[OcamlArchiveProvider], "module_links"):
                merged_module_links_depsets.append(dep[OcamlArchiveProvider].module_links)
            if hasattr(dep[OcamlArchiveProvider], "paths"):
                merged_paths_depsets.append(dep[OcamlArchiveProvider].paths)
            if hasattr(dep[OcamlArchiveProvider], "depgraph"):
                merged_depgraph_depsets.append(dep[OcamlArchiveProvider].depgraph)
            if hasattr(dep[OcamlArchiveProvider], "archived_modules"):
                merged_archived_modules_depsets.append(dep[OcamlArchiveProvider].archived_modules)

        if PpxArchiveProvider in dep:
            if hasattr(dep[PpxArchiveProvider], "archive_links"):
                merged_archive_links_depsets.append(dep[PpxArchiveProvider].archive_links)
            if hasattr(dep[PpxArchiveProvider], "module_links"):
                merged_module_links_depsets.append(dep[PpxArchiveProvider].module_links)
            if hasattr(dep[PpxArchiveProvider], "paths"):
                merged_paths_depsets.append(dep[PpxArchiveProvider].paths)
            if hasattr(dep[PpxArchiveProvider], "depgraph"):
                merged_depgraph_depsets.append(dep[PpxArchiveProvider].depgraph)
            if hasattr(dep[PpxArchiveProvider], "archived_modules"):
                merged_archived_modules_depsets.append(dep[PpxArchiveProvider].archived_modules)

        if OcamlLibraryProvider in dep:
            if hasattr(dep[OcamlLibraryProvider], "archive_links"):
                merged_archive_links_depsets.append(dep[OcamlLibraryProvider].archive_links)
            if hasattr(dep[OcamlLibraryProvider], "module_links"):
                merged_module_links_depsets.append(dep[OcamlLibraryProvider].module_links)
            if hasattr(dep[OcamlLibraryProvider], "paths"):
                merged_paths_depsets.append(dep[OcamlLibraryProvider].paths)
            if hasattr(dep[OcamlLibraryProvider], "depgraph"):
                merged_depgraph_depsets.append(dep[OcamlLibraryProvider].depgraph)
            if hasattr(dep[OcamlLibraryProvider], "archived_modules"):
                merged_archived_modules_depsets.append(dep[OcamlLibraryProvider].archived_modules)

        if PpxLibraryProvider in dep:
            if hasattr(dep[PpxLibraryProvider], "archive_links"):
                merged_archive_links_depsets.append(dep[PpxLibraryProvider].archive_links)
            if hasattr(dep[PpxLibraryProvider], "module_links"):
                merged_module_links_depsets.append(dep[PpxLibraryProvider].module_links)
            if hasattr(dep[PpxLibraryProvider], "paths"):
                merged_paths_depsets.append(dep[PpxLibraryProvider].paths)
            if hasattr(dep[PpxLibraryProvider], "depgraph"):
                merged_depgraph_depsets.append(dep[PpxLibraryProvider].depgraph)
            if hasattr(dep[PpxLibraryProvider], "archived_modules"):
                merged_archived_modules_depsets.append(dep[PpxLibraryProvider].archived_modules)

        if OcamlNsArchiveProvider in dep:
            if hasattr(dep[OcamlNsArchiveProvider], "archive_links"):
                merged_archive_links_depsets.append(dep[OcamlNsArchiveProvider].archive_links)
            if hasattr(dep[OcamlNsArchiveProvider], "module_links"):
                merged_module_links_depsets.append(dep[OcamlNsArchiveProvider].module_links)
            if hasattr(dep[OcamlNsArchiveProvider], "paths"):
                merged_paths_depsets.append(dep[OcamlNsArchiveProvider].paths)
            if hasattr(dep[OcamlNsArchiveProvider], "depgraph"):
                merged_depgraph_depsets.append(dep[OcamlNsArchiveProvider].depgraph)
            if hasattr(dep[OcamlNsArchiveProvider], "archived_modules"):
                merged_archived_modules_depsets.append(dep[OcamlNsArchiveProvider].archived_modules)

        if PpxNsArchiveProvider in dep:
            if hasattr(dep[PpxNsArchiveProvider], "archive_links"):
                merged_archive_links_depsets.append(dep[PpxNsArchiveProvider].archive_links)
            if hasattr(dep[PpxNsArchiveProvider], "module_links"):
                merged_module_links_depsets.append(dep[PpxNsArchiveProvider].module_links)
            if hasattr(dep[PpxNsArchiveProvider], "paths"):
                merged_paths_depsets.append(dep[PpxNsArchiveProvider].paths)
            if hasattr(dep[PpxNsArchiveProvider], "depgraph"):
                merged_depgraph_depsets.append(dep[PpxNsArchiveProvider].depgraph)
            if hasattr(dep[PpxNsArchiveProvider], "archived_modules"):
                merged_archived_modules_depsets.append(dep[PpxNsArchiveProvider].archived_modules)

        if OcamlNsLibraryProvider in dep:
            if hasattr(dep[OcamlNsLibraryProvider], "archive_links"):
                merged_archive_links_depsets.append(dep[OcamlNsLibraryProvider].archive_links)
            if hasattr(dep[OcamlNsLibraryProvider], "module_links"):
                merged_module_links_depsets.append(dep[OcamlNsLibraryProvider].module_links)
            if hasattr(dep[OcamlNsLibraryProvider], "paths"):
                merged_paths_depsets.append(dep[OcamlNsLibraryProvider].paths)
            if hasattr(dep[OcamlNsLibraryProvider], "depgraph"):
                merged_depgraph_depsets.append(dep[OcamlNsLibraryProvider].depgraph)
            if hasattr(dep[OcamlNsLibraryProvider], "archived_modules"):
                merged_archived_modules_depsets.append(dep[OcamlNsLibraryProvider].archived_modules)

        if PpxNsLibraryProvider in dep:
            if hasattr(dep[PpxNsLibraryProvider], "archive_links"):
                merged_archive_links_depsets.append(dep[PpxNsLibraryProvider].archive_links)
            if hasattr(dep[PpxNsLibraryProvider], "module_links"):
                merged_module_links_depsets.append(dep[PpxNsLibraryProvider].module_links)
            if hasattr(dep[PpxNsLibraryProvider], "paths"):
                merged_paths_depsets.append(dep[PpxNsLibraryProvider].paths)
            if hasattr(dep[PpxNsLibraryProvider], "depgraph"):
                merged_depgraph_depsets.append(dep[PpxNsLibraryProvider].depgraph)
            if hasattr(dep[PpxNsLibraryProvider], "archived_modules"):
                merged_archived_modules_depsets.append(dep[PpxNsLibraryProvider].archived_modules)

        if OcamlNsResolverProvider in dep:
            merged_module_links_depsets.append(dep[DefaultInfo].files)
            if hasattr(dep[OcamlNsResolverProvider], "paths"):
                merged_paths_depsets.append(dep[OcamlNsResolverProvider].paths)
            if hasattr(dep[OcamlNsResolverProvider], "files"):
                merged_depgraph_depsets.append(dep[OcamlNsResolverProvider].files)

        if OcamlSignatureProvider in dep:
            if hasattr(dep[OcamlSignatureProvider], "archive_links"):
                merged_archive_links_depsets.append(dep[OcamlSignatureProvider].archive_links)
            if hasattr(dep[OcamlSignatureProvider], "module_links"):
                merged_module_links_depsets.append(dep[OcamlSignatureProvider].module_links)
            if hasattr(dep[OcamlSignatureProvider], "paths"):
                merged_paths_depsets.append(dep[OcamlSignatureProvider].paths)
            if hasattr(dep[OcamlSignatureProvider], "depgraph"):
                merged_depgraph_depsets.append(dep[OcamlSignatureProvider].depgraph)
            if hasattr(dep[OcamlSignatureProvider], "archived_modules"):
                merged_archived_modules_depsets.append(dep[OcamlSignatureProvider].archived_modules)

        if AdjunctDepsProvider in dep:
            indirect_adjunct_depsets.append(dep[AdjunctDepsProvider].nopam)
            indirect_adjunct_path_depsets.append(dep[AdjunctDepsProvider].nopam_paths)
            indirect_adjunct_opam_depsets.append(dep[AdjunctDepsProvider].opam)

        if OpamDepsProvider in dep:
            indirect_opam_depsets.append(dep[OpamDepsProvider].pkgs)

        if CcDepsProvider in dep:
            for [dep, linkmode] in dep[CcDepsProvider].libs.items():  ## ccdict.items():
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
                    ccdeps_labels.update({dep.label: linkmode})
                    ccdeps.update({dep: linkmode})
            indirect_cc_deps.update(ccdeps)
