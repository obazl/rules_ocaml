

def config():

    native.new_local_repository(
        name = "ocaml.compiler-libs",
        path = "%workspace%/.opam/4.10/lib/ocaml/compiler-libs",
        build_file = "@//.opam/ocaml:BUILD.bazel"
        # build_files = {
        #     ##  build_file: path
        #     "@//.opam/ocaml:BUILD.bazel": "/Users/gar/.opam/4.10/bin",
        #     "@rules_ocaml//ocaml/_templates/BUILD.ocaml.archive": "/Users/gar/.opam/4.10/archive"
        # }
    )
