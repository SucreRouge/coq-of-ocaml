# ![Logo](https://raw.githubusercontent.com/clarus/icons/master/abc-48.png) CoqOfOCaml
Compiler of OCaml to Coq. Still experimental. For more information look at the [Wiki](https://github.com/clarus/coq-of-ocaml/wiki).

## Install
### Using Docker
Just run the `Dockerfile` with:

    docker build .

It will install all dependencies (can take time), compile CoqOfOCaml and run the tests. The resulting files will be in `/root/coq-of-ocaml/` in your [Docker](https://www.docker.io/) image.

### Manually
This compiler needs a working installation of OCaml 4.02 and Coq 8.4, plus the following packages (can be installed using [OPAM](http://opam.ocaml.org/)):
* [SmartPrint](https://github.com/clarus/smart-print)
* [YoJson](http://mjambon.com/yojson.html)

You have two parts to compile in order:

#### The Coq library
Go to `OCaml/` and run:

    ./configure.sh
    make
    make install

#### The compiler
Go to the root folder and run:

    make

## Play with the tests
To run the tests of the folder `tests/` (needs Ruby):

    make test

## Usage
CoqOfOCaml compiles the `.cmt` files (generated by the OCaml compiler using the option `-bin-annot`) to Coq definitions and print it on the standard output:

    ./coqOfOCaml.native -mode coq file.cmt

You can start to experiment with the test files in `tests/`.
