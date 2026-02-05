# mlx-mode

Emacs major mode for editing [MLX](https://github.com/ocaml-mlx/mlx) files — OCaml with JSX syntax.

## Features

- Syntax highlighting for JSX tags, components, attributes, and delimiters
- Full OCaml highlighting via [tuareg-mode](https://github.com/ocaml/tuareg)
- JSX-aware indentation
- LSP support via [eglot](https://www.gnu.org/software/emacs/manual/html_mono/eglot.html) + [ocamllsp](https://github.com/ocaml/ocaml-lsp)

## Prerequisites

```
opam install mlx ocamlmerlin-mlx ocamlformat-mlx
```

Your `dune-project` must declare the MLX dialect with the merlin reader:

```lisp
(dialect
 (name mlx)
 (implementation
  (extension mlx)
  (merlin_reader mlx)
  (preprocess
   (run mlx-pp %{input-file}))))
```

## Installation

### Doom Emacs

In `~/.config/doom/packages.el`:

```elisp
(package! mlx-mode
  :recipe (:host github :repo "finalclass/emacs-mlx"))
```

In `~/.config/doom/config.el`:

```elisp
(use-package! mlx-mode
  :defer t
  :mode "\\.mlx\\'"
  :init
  (add-to-list 'auto-mode-alist '("\\.mlx\\'" . mlx-mode)))
```

Then run `doom sync` and restart Emacs.

### use-package (straight.el)

```elisp
(use-package mlx-mode
  :straight (:host github :repo "finalclass/emacs-mlx")
  :mode "\\.mlx\\'"
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(mlx-mode . ("ocamllsp")))))
```

### Manual

Clone this repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/emacs-mlx")
(require 'mlx-mode)

;; LSP via eglot
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(mlx-mode . ("ocamllsp"))))

;; Auto-start eglot for .mlx files (optional)
(add-hook 'mlx-mode-hook #'eglot-ensure)
```

### lsp-mode (alternative to eglot)

If you use `lsp-mode` instead of eglot, `mlx-mode` registers itself automatically. Just ensure `ocamllsp` is in your `PATH` and add:

```elisp
(add-hook 'mlx-mode-hook #'lsp)
```

## Customization

| Variable                | Default | Description                  |
|-------------------------|---------|------------------------------|
| `mlx-jsx-indent-offset` | `2`     | Indentation for JSX children |

### Faces

- `mlx-jsx-tag-face` — lowercase tags (`div`, `span`)
- `mlx-jsx-component-face` — uppercase components (`App`, `Module.View`)
- `mlx-jsx-attribute-face` — attribute names (`className`, `onClick`)
- `mlx-jsx-delimiter-face` — delimiters (`<`, `</`, `/>`)

## Related projects

- [mlx](https://github.com/ocaml-mlx/mlx) — the MLX preprocessor
- [ocaml_mlx.nvim](https://github.com/ocaml-mlx/ocaml_mlx.nvim) — Neovim plugin for MLX
- [tree-sitter-mlx](https://github.com/ocaml-mlx/tree-sitter-mlx) — Tree-sitter grammar for MLX
- [tuareg](https://github.com/ocaml/tuareg) — OCaml mode for Emacs

## License

MIT
