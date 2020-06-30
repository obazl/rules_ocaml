# linking

From the manual Chapter 12, Native-code compilation (ocamlopt):

* "Arguments ending in .cmx are taken to be compiled object code. These files are linked together, along with the object files obtained by compiling .ml arguments (if any), and the OCaml standard library, to produce a native-code executable program. The order in which .cmx and .ml arguments are presented on the command line is relevant: compilation units are initialized in that order at run-time, and it is a link-time error to use a component of a unit before having initialized it. Hence, a given x.cmx file must come before all .cmx files that refer to the unit x.

* "Arguments ending in .cmxa are taken to be libraries of object code. Such a library packs in two files (lib.cmxa and lib.a/.lib) a set of object files (.cmx and .o/.obj files). Libraries are build with ocamlopt -a (see the description of the -a option below). The object files contained in the library are linked as regular .cmx files (see above), in the order specified when the library was built. The only difference is that if an object file contained in a library is not referenced anywhere in the program, then it is not linked in."

* "-a
Build a library(.cmxa and .a/.lib files) with the object files (.cmx and .o/.obj files) given on the command line, instead of linking them into an executable file. The name of the library must be set with the -o option."

* "-c
Compile only. Suppress the linking phase of the compilation. Source code files are turned into compiled files, but no executable file is produced. This option is useful to compile modules separately."

* "-linkall
Force all modules contained in libraries to be linked in. If this flag is not given, unreferenced modules are not linked in. When building a library (option -a), setting the -linkall option forces all subsequent links of programs involving that library to link all the modules contained in the library. When compiling a module (option -c), setting the -linkall option ensures that this module will always be linked if it is put in a library and this library is linked."

English translation (draft):

* "Linking" here seems to mean "combining", without regard to whether
  any actual linking (i.e. resolving references) is involved.
* BUT it also seems to mean "producing an executable" when it says the
  -c option means "suppress the linking phase" so that "[s]ource code
  files are turned into compiled files, but no executable file is
  prduced."
* If you pass .cmx and .ml files to the compiler, they will all be
  "linked" (i.e. included/combined) in the resulting executable, _even
  if they are not used_ (referenced).
* If you pass an archive file (.cmxa), only the modules referenced by
  "the program" will be included.  (Since there is no "main" in OCaml,
  it is not clear what the writer means by "the program", let alone
  "referenced anywhere in the program".  Does that mean "referenced by
  any of the modules"?
  * The implication here is that the compiler/linker will not optimize
    out modules passed directly but not referenced; it will only do
    this for modules listed in archives.

* Evidently `-linkall` means something like "sticky".
