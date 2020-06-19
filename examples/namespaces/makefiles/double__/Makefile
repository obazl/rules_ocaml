
all: Amod__Bmod__Hello.cmo
	ocamlc *.cmo Driver.ml -o Driver.exe

Amod.cmo:
	ocamlc -w -49 -c -no-alias-deps Amod.ml

Amod__Bmod.cmo: Amod.cmo
	ocamlc -w -49 -c -no-alias-deps Amod__Bmod.ml

Amod__Bmod__Hello.cmo: Amod__Bmod.cmo
	ocamlc -c -no-alias-deps Amod__Bmod__Hello.ml

clean:
	rm *.cmo;
	rm *.cmi;
	rm *.exe;
