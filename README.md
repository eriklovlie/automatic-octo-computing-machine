# linter-ocaml

This is a linter for OCaml using [merlin] for the actual linting. It builds on
[atom-linter], like many of the other linter packages. It also uses
merlin to show types of expressions. More merlin functionality will hopefully
be exposed as atom commands in the future.

Since it is [atom-linter] that takes care of the decorations I may as well
steal a screenshot. Imagine the following is OCaml instead of JavaScript:

![Preview](https://camo.githubusercontent.com/70b6e697c9d793642414b4ea6d08dbb9678877b3/687474703a2f2f672e7265636f726469742e636f2f313352666d6972507a322e676966)

[merlin]: https://github.com/the-lambda-church/merlin
[atom-linter]: https://github.com/atom-community/linter

# Usage

Linting is performed when you save the file.

With [hyperclick] installed you can also cmd-click on a word to activate the
`linter-ocaml:type-of` command.

Keyboard activated commands:

|Command|Description|Keybinding (Linux)|Keybinding (OS X)|
|-------|-----------|------------------|-----------------|--------------------|
|`linter-ocaml:type-of`|Show type of expression at cursor|<kbd>ctrl-alt-?</kbd>|<kbd>cmd-alt-?</kbd>|
|`linter-ocaml:type-of-widen`|Show type of expression one level up|<kbd>ctrl-alt-.</kbd>|<kbd>cmd-alt-.</kbd>|
|`linter-ocaml:type-of-narrow`|Show type of expression one level down|<kbd>ctrl-alt-,</kbd>|<kbd>cmd-alt-,</kbd>|

## Caveat Emptor

I've now used this myself for some time on a program of a couple of thousand
LOC, and it seems to work well. However it still has only been tested on
fairly small programs so YMMV. Bug reports are welcomed.

You should ensure that you are on the latest released merlin version.

Tested on OS X and Linux. Not tested at all on Windows, but if you can get
merlin to work I suppose it should work.

## Other packages

Other packages you probably want:

* [language-ocaml] to get syntax highlighting.
* [minimap] to see errors/warnings in a nice minimappy thing.
* [hyperclick] to get clicky functionality (cmd-click on symbols).

[language-ocaml]: https://atom.io/packages/language-ocaml
[minimap]: https://atom.io/packages/minimap
[hyperclick]: https://atom.io/packages/hyperclick

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
ocamlbuild -package core_extended -I src yo.byte
```

The above assumes you have your sources in `src` (and your main program is
`yo.ml`). The globbing in `.merlin` is needed because `ocamlbuild` makes
subdirectories inside `_build` and merlin needs to see all the cmi files to
find symbols and whatnot.

I recommend also installing ocp-indent (also using opam) and run this on source
files before compilation. Personally I have a simple makefile that runs it
before running ocamlbuild. Atom refreshes the indented files automatically.
