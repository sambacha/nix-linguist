# [nix-linguist](https://nixos.org/)

> **Warning** <br />
> As of July 2023, GitHub Linguist has began adopting tree-sitter based grammars. <br />
> [The Nix Community now maintains the relevant language grammar](https://github.com/nix-community/tree-sitter-nix) <br />
> https://github.com/github-linguist/linguist/commit/e855ef2b6f90c34074061a2e17acbe853e61b483


> **Note** <br />
> The _Legacy_ GitHub Linguist Grammar for Nix


- [nix-linguist](https://nixos.org/)
  * [Overview](#overview)
- [Nix](#nix)
  * [Language constructs](#language-constructs)
  * [Primitives / literals](#primitives---literals)
  * [Operators](#operators)
      - [Canonical Nix Grammar](#canonical-nix-grammar)
      - [Nix BNF Grammar](#nix-bnf-grammar)
      

## Overview

This repo provide's GitHub's Linguist with a grammar file to enhance syntax highlighting when viewed on `github.com`. 

> **Warning** <br />
> As such, for other parsing usages, this syntax file should not be used as it is lax (not strict).

# Nix

> **Note** <br />
> [source, nixery 1pager](https://nixery.dev/nix-1p.html)

-   **purely functional**. It has no concept of sequential steps being executed, any dependency between operations is established by depending on _data_ from previous operations.
    
    Everything in Nix is an expression, meaning that every directive returns some kind of data.
    
    Evaluating a Nix expression _yields a single data structure_, it does not execute a sequence of operations.
    
    Every Nix file evaluates to a _single expression_.
    
-   **lazy**. It will only evaluate expressions when their result is actually requested.
    
    For example, the builtin function `throw` causes evaluation to stop. Entering the following expression works fine however, because we never actually ask for the part of the structure that causes the `throw`.
    
    ```nix
    let attrs = { a = 15; b = builtins.throw "Oh no!"; };
    in "The value of 'a' is ${toString attrs.a}"
    ```
    
-   **purpose-built**. Nix only exists to be the language for Nix, the package manager. While people have occasionally used it for other use-cases, it is explicitly not a general-purpose language.
    

## [Language constructs](#)

This section describes the language constructs in Nix. It is a small language and most of these should be self-explanatory.

## [Primitives / literals](#)

Nix has a handful of data types which can be represented literally in source code, similar to many other languages.

```nix
# numbers
42
1.72394

# strings & paths
"hello"
./some-file.json

# strings support interpolation
"Hello ${name}"

# multi-line strings (common prefix whitespace is dropped)
''
first line
second line
''

# lists (note: no commas!)
[ 1 2 3 ]

# attribute sets (field access with dot syntax)
{ a = 15; b = "something else"; }

# recursive attribute sets (fields can reference each other)
rec { a = 15; b = a * 2; }
```

## [Operators](#)

Nix has several operators, most of which are unsurprising:

| Syntax | Description |
| --- | --- |
| `+`, `-`, `*`, `/` | Numerical operations |
| `+` | String concatenation |
| `++` | List concatenation |
| `==` | Equality |
| `>`, `>=`, `<`, `<=` | Ordering comparators |
| `&&` | Logical `AND` |
| `||` | Logical `OR` |
| `e1 -> e2` | Logical implication (i.e. `!e1 || e2`) |
| `!` | Boolean negation |
| `set.attr` | Access attribute `attr` in attribute set `set` |
| `set ? attribute` | Test whether attribute set contains an attribute |
| `left // right` | Merge `left` & `right` attribute sets, with the right set taking precedence |

Make sure to understand the `//`\-operator, as it is used quite a lot and is probably the least familiar one.


#### Canonical Nix Grammar
[canonical grammar for `nix` can be sourced via NixOS/nix/blob/master/src/libexpr/lexer.l](https://github.com/NixOS/nix/blob/master/src/libexpr/lexer.l#L27-#L314)

#### Nix BNF Grammar

[Another grammar spec format is available in BNF format, here is the grammar file.](https://github.com/NixOS/nix-idea/blob/4d710f3c2a33f70e0057a35b2bab9917cffbdb57/src/main/lang/Nix.bnf)


---

[![built with nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)

[via the MIT License](LICENSE.txt)
