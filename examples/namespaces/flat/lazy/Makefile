
LINK_LAZY=-no-alias-deps

# With lazy linking, we do not need to list the linkage deps in the compile command line.

all: Alpha__Gamma__Howdy.cmo Alpha__Beta_1__Gamma__Hello.cmo Alpha__Beta2.cmo
	ocamlc *.cmo Driver.ml -o Driver.exe

Alpha.cmo:
	ocamlc -w -49 -c ${LINK_LAZY} Alpha.ml

Alpha__Beta_1.cmo: Alpha.cmo
	ocamlc -w -49 -c ${LINK_LAZY} Alpha__Beta_1.ml

Alpha__Beta_1__Gamma.cmo: Alpha__Beta_1.cmo
	ocamlc -w -49 -c ${LINK_LAZY} Alpha__Beta_1__Gamma.ml

Alpha__Beta_1__Gamma__Hello.cmo: Alpha__Beta_1__Gamma.cmo
	ocamlc -w -49 -c ${LINK_LAZY} Alpha__Beta_1__Gamma__Hello.ml

Alpha__Beta2.cmo:
	ocamlc -w -49 -c ${LINK_LAZY} Alpha__Beta2.ml

Alpha__Gamma.cmo:
	ocamlc -w -49 -c ${LINK_LAZY} Alpha__Gamma.ml

Alpha__Gamma__Howdy.cmo:
	ocamlc -w -49 -c ${LINK_LAZY} Alpha__Gamma__Howdy.ml

clean:
	-rm *.exe 2>/dev/null || true;
	-rm *.cmi 2>/dev/null || true;
	-rm *.cmo 2>/dev/null || true;
	-rm *.cma 2>/dev/null || true;
	-rm *.cmx 2>/dev/null || true;
	-rm *.cmxa 2>/dev/null || true;
