# Claude Code Instructions

## Commit style

- Do NOT include `Co-Authored-By` lines in commit messages
- Keep commit messages concise and descriptive

## Project structure

- `mlx-mode.el` -- the main (and only) Emacs Lisp source file
- `test/sample.mlx` -- example MLX file for manual testing
- This is a single-file Emacs package; keep it that way

## Development

- Byte-compile with: `emacs --batch -L . -L /path/to/tuareg/ -f batch-byte-compile mlx-mode.el`
- The mode derives from `tuareg-mode`; always test that tuareg loads correctly
- Font-lock keywords must use simple regexps, NOT function matchers with scanning loops (they hang on broken syntax)
