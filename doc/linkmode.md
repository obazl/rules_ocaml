# linkmode

NOTE: The terminology `C/C++ library` does not necessarily imply that
the source code that produced the library was C/C++. Rather it refers
to the standard file format for object files, archives, etc., which is
historically is closely associated with C. Many other languages
(including OCaml) are capable of producing such files, so OBazl uses
e.g. `cc_deps` to refer to such files no matter what language was used
to produce them.

A library is a collection of code units. C/C++ libraries come in
several flavors:

* _static_: code units are assembled into an _archive_ file, whose extension (by convention) is `.a`.

* _dynamic shared_: code units are assembled into a _dynamic shared
  object_ (DSO) file. Yes, the terminology conflates two distinct
  concepts. On Linux, these are `.so` files; on MacOS, they are
  `.dylib` files (but MacOS also supports `.so` files).

Rules producing C/C++ libs commonly produce both a '.a' file and one
or more '.so' (or '.dylib') files. In Obazl rules, link _mode_
determines which type of library is used for linking. Possible values:

* 'static': statically link to `.a` file.
* 'dynamic': depending on the OS, link to '.dylib' file (MacOS) or '.so' file (Linux or MacOS).
* 'default': equivalent to 'static' on Linux, 'dynamic' on MacOS.
