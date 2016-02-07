# linter-ocaml

This is a linter for OCaml using [merlin] for the actual linting. It builds on [atom-linter], like many of the other linter packages.

Since it is [atom-linter] that takes care of the decorations I may as well
steal a screenshot. Imagine the following is OCaml instead of JavaScript:

![Preview](https://camo.githubusercontent.com/70b6e697c9d793642414b4ea6d08dbb9678877b3/687474703a2f2f672e7265636f726469742e636f2f313352666d6972507a322e676966)

[merlin]: https://github.com/the-lambda-church/merlin
[atom-linter]: https://github.com/atom-community/linter

## Caveat Emptor

This package is not amazingly well tested, since the author is still unfamiliar
with most of the technologies involved (OCaml, Node.js, CoffeeScript, Atom,
etc).

That said it does appear to work in my (tiny) OCaml projects.

## Features

It's a linter so it shows errors and warnings when you save a file. That's it.

You probably want to install [language-ocaml] to get syntax highlighting.

[language-ocaml]: https://atom.io/packages/language-ocaml

## Installation

The [package] itself can be installed the normal way (from the Atom package
installer).

[package]: https://atom.io/packages/linter-ocaml

It depends on `ocamlmerlin` being in `PATH`. The simple way to do this is
to install [opam] and then install merlin:

`opam install merlin`

[opam]: https://opam.ocaml.org/doc/Install.html

Additionally you must have a working merlin setup for you project. IOW you must
have a `.merlin` file in your project root directory.

If you are an experienced OCaml person you may stop reading now (or continue
reading and then report any mistakes or bad advice).

I'm not experienced in OCaml so YMMV, however my projects are set up as follows.

A `.merlin` file which looks something like this (add all the packages you need):

```
S src/**
B _build/**
PKG core_kernel
PKG core
PKG core_extended
```

I then have a small build script:

```
#!/usr/bin/env bash
corebuild -package core_extended -I src yo.byte
```

The above assumes you have your sources in `src` (and your main program is
`yo.ml`). The globbing in `.merlin` is needed because `ocamlbuild` makes
subdirectories inside `_build` and merlin needs to see all the cmi files to
find symbols and whatnot.
