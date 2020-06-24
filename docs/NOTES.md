# notes

Fine-grained dependencies: build specs often express deps in groups,
e.g. this group of sources depends on that lib (group of objects).
Whereas in fact particular files depend on particular objects.  Bazel
makes it easy to refine this, expressing the deps of single files.  I
suppose one could do the same in Dune or other systems, but it feels
natural in Bazel.  It's not necessary, but it's possible, and it can
make build structure more explicit.

For an example, see the build file for the c implementation of
digestif (digestif/src-c).  The dunefile says the lib to build depends
on some source files and some libs, that's it.  The OBazl build files
show exactly which files depend on which; for example, only the
`digestif_native.ml` file depends on the c lib `librakia` (Dune calls
it `rakia_stubs`), and that is explicitly stated in the build file.
The BUILD.bazel file might look more complex on the surface, but that
reflects the structure of the build.  The simplicity of the Dune file
is only apparent; it only hides complexity, it does not remove it.

IOW, build structure that is hidden by Dune is articulated in
OBazl. Or at least may be articulated; one could write Bazel rules to
hide stuff too.

A related virtue: intermediate targets are available.  You can build
the entire digestif c implementation, but you can just as easily build
its parts, e.g. librakia.

## misc

  ## IMPORTANT!  from the ocamlopt docs:
  ## -o exec-file   Specify the name of the output file produced by the linker.
  ## That covers both executables and library archives (-a).
  ## If you're just compiling (-c), no need to pass -o.
  ## By contrast, the output files must be listed in the action output arg
  ## in order to be registered in the action dependency graph.

