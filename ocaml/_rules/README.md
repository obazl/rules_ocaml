# pack libs

Evidently only direct deps should be compiled with `-for-pack`. If
there are sibling deps, the dependency must be compiled normally, even
if it is in the component list?

Otherwise we get e.g.

```
File "bazel-out/darwin-fastbuild/bin/plugins/ltac/__obazl/Tacenv.ml", line 1:
Error: File bazel-out/darwin-fastbuild/bin/plugins/ltac/__obazl/Tacenv.cmx
       was compiled without access to the .cmx file for module Tacsubst,
       which was produced by `ocamlopt -for-pack'.
       Please recompile bazel-out/darwin-fastbuild/bin/plugins/ltac/__obazl/Tacenv.cmx
       with the correct `-I' option so that Tacsubst.cmx is found.
```

In this case, both Tacenv and Tacsubst are listed in
ltac_plugin.mlpack, but the former depends on the latter.

