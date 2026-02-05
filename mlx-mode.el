;;; mlx-mode.el --- Major mode for MLX (OCaml with JSX) -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Szymon Wygnanski
;; Author: Szymon Wygnanski
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (tuareg "3.0.0"))
;; Keywords: languages, ocaml, jsx, mlx
;; URL: https://github.com/finalclass/emacs-mlx

;;; Commentary:

;; Major mode for editing MLX files (OCaml with JSX syntax).
;; Extends tuareg-mode with JSX syntax highlighting and indentation.
;;
;; MLX is an OCaml syntax dialect that integrates JSX expressions
;; directly into OCaml.  See https://github.com/ocaml-mlx/mlx
;;
;; Prerequisites:
;;   opam install mlx ocamlmerlin-mlx
;;
;; Usage:
;;   (require 'mlx-mode)
;;   ;; .mlx files will automatically use mlx-mode

;;; Code:

(require 'tuareg)
(require 'cl-lib)
(require 'smie)

;;; ============================================================
;;; Customization
;;; ============================================================

(defgroup mlx nil
  "Support for the MLX language (OCaml with JSX)."
  :group 'languages
  :prefix "mlx-")

(defcustom mlx-jsx-indent-offset 2
  "Indentation offset for JSX children and multi-line tag attributes."
  :type 'integer
  :group 'mlx
  :safe #'integerp)

;;; ============================================================
;;; Faces
;;; ============================================================

(defface mlx-jsx-tag-face
  '((t :inherit font-lock-function-name-face))
  "Face for lowercase JSX tag names (e.g., div, span)."
  :group 'mlx)

(defface mlx-jsx-component-face
  '((t :inherit font-lock-type-face))
  "Face for uppercase JSX component names (e.g., Component, Module.View)."
  :group 'mlx)

(defface mlx-jsx-attribute-face
  '((t :inherit font-lock-constant-face))
  "Face for JSX attribute names."
  :group 'mlx)

(defface mlx-jsx-delimiter-face
  '((((background dark))
     :foreground "#888888")
    (((background light))
     :foreground "#666666"))
  "Face for JSX delimiters: < > </ />."
  :group 'mlx)

;;; ============================================================
;;; Internal constants
;;; ============================================================

(defconst mlx--ident-re
  "[a-z_][a-zA-Z0-9_']*"
  "Regexp matching OCaml lowercase identifiers.")

(defconst mlx--component-re
  "[A-Z][a-zA-Z0-9_]*"
  "Regexp matching uppercase component/module names.")

(defconst mlx--tag-name-re
  (concat "\\(?:" mlx--component-re "\\.\\)*"
          "\\(?:" mlx--component-re "\\|" mlx--ident-re "\\)")
  "Regexp matching JSX tag names including module paths.
Matches: div, Component, Module.Component, Module.sub_tag.")

;;; ============================================================
;;; Scanning utilities
;;; ============================================================

(defun mlx--in-string-or-comment-p (&optional pos)
  "Return non-nil if POS (default: point) is inside a string or comment."
  (let ((state (syntax-ppss (or pos (point)))))
    (or (nth 3 state) (nth 4 state))))

;;; ============================================================
;;; Font-lock helper functions
;;; ============================================================

(defun mlx--tag-face ()
  "Return the appropriate face for the matched JSX tag (group 1)."
  (let ((name (match-string-no-properties 1)))
    (if (and name (let ((case-fold-search nil))
                    (string-match-p "\\`[A-Z]" name)))
        'mlx-jsx-component-face
      'mlx-jsx-tag-face)))

;;; ============================================================
;;; Font-lock keywords
;;; ============================================================

(defvar mlx-font-lock-keywords
  `(;; Closing tags: </tagname>
    (,(concat "</\\(" mlx--tag-name-re "\\)\\s-*>")
     (0 'mlx-jsx-delimiter-face t)
     (1 (mlx--tag-face) t))

    ;; Self-closing tags: <tagname ... />
    (,(concat "<\\(" mlx--tag-name-re "\\)[^>]*/>" )
     (0 'mlx-jsx-delimiter-face t)
     (1 (mlx--tag-face) t))

    ;; Opening tags: <tagname (not followed by /)
    (,(concat "<\\(" mlx--tag-name-re "\\)\\_>")
     (0 'mlx-jsx-delimiter-face t)
     (1 (mlx--tag-face) t))

    ;; JSX attributes: name= or ?name= inside angle brackets
    ;; Simple regex approach - may miss some edge cases but won't hang
    (,(concat "\\_<\\(" mlx--ident-re "\\)=")
     (1 'mlx-jsx-attribute-face t))

    ;; Optional attributes: ?name
    (,(concat "\\?\\(" mlx--ident-re "\\)\\_>")
     (1 'mlx-jsx-attribute-face t)))
  "Font-lock keywords for JSX syntax in MLX mode.")

;;; ============================================================
;;; Multi-line font-lock support
;;; ============================================================

;; We rely on `font-lock-multiline' being t.  Once a multi-line JSX
;; tag has been fontified, Emacs records the span via the
;; `font-lock-multiline' text property and will automatically extend
;; the refontification region on subsequent edits.

;;; ============================================================
;;; Indentation
;;; ============================================================

(defun mlx--find-matching-open-tag (tag-name)
  "Search backward for the opening tag matching TAG-NAME.
Handles nested tags of the same name.
Returns the opening tag's column, or nil."
  (save-excursion
    (let ((depth 1)
          (search-limit (max (point-min) (- (point) 10000)))
          (open-re (concat "<" (regexp-quote tag-name) "\\_>"))
          (close-re (concat "</" (regexp-quote tag-name) "\\s-*>")))
      (while (and (> depth 0)
                  (re-search-backward
                   (concat "\\(?:" open-re "\\)\\|\\(?:" close-re "\\)")
                   search-limit t))
        (unless (mlx--in-string-or-comment-p)
          (if (looking-at "</")
              (cl-incf depth)
            (cl-decf depth))))
      (when (= depth 0)
        (current-column)))))

(defun mlx--looking-back-jsx-open-tag-end-p ()
  "Check if the previous non-blank line ends a JSX opening tag with `>'.
Returns the column of the `<' that started the tag, or nil."
  (save-excursion
    (forward-line 0)
    ;; Go to previous non-blank line
    (forward-line -1)
    (while (and (not (bobp)) (looking-at-p "^[ \t]*$"))
      (forward-line -1))
    (end-of-line)
    (skip-chars-backward " \t")
    (when (and (eq (char-before) ?>)
               ;; Not />
               (not (and (>= (- (point) 2) (point-min))
                         (eq (char-before (1- (point))) ?/)))
               ;; Not a closing tag </...>
               (not (save-excursion
                      (beginning-of-line)
                      (looking-at-p
                       (concat "[ \t]*</" mlx--tag-name-re)))))
      ;; Check if this line has a JSX opening tag
      (beginning-of-line)
      (when (re-search-forward
             (concat "<\\(" mlx--tag-name-re "\\)\\_>")
             (line-end-position) t)
        (unless (mlx--in-string-or-comment-p (match-beginning 0))
          (goto-char (match-beginning 0))
          (current-column))))))

(defun mlx--compute-jsx-indent ()
  "Compute JSX indentation for the current line, or nil.
Returns an integer column if in JSX context, nil otherwise."
  (save-excursion
    (forward-line 0)
    (skip-chars-forward " \t")
    (cond
     ;; Line starts with closing tag </tagname>
     ((looking-at (concat "</\\(" mlx--tag-name-re "\\)"))
      (let ((tag (match-string 1)))
        (mlx--find-matching-open-tag tag)))

     ;; Line starts with self-closing end />
     ((looking-at "/>")
      (save-excursion
        (when (re-search-backward
               (concat "<\\(" mlx--tag-name-re "\\)\\_>")
               nil t)
          (unless (mlx--in-string-or-comment-p)
            (current-column)))))

     ;; Check if previous line ended a JSX opening tag with >
     (t
      (let ((col (mlx--looking-back-jsx-open-tag-end-p)))
        (when col
          (+ col mlx-jsx-indent-offset)))))))

(defun mlx--indent-line (orig-fun &rest args)
  "Advice around `indent-line-function' for JSX indentation.
Falls back to ORIG-FUN (tuareg indentation) for non-JSX lines."
  (let ((jsx-indent (mlx--compute-jsx-indent)))
    (if jsx-indent
        (let ((offset (- (current-column) (current-indentation))))
          (indent-line-to jsx-indent)
          (when (> offset 0)
            (forward-char offset)))
      (apply orig-fun args))))

;;; ============================================================
;;; Syntax propertization
;;; ============================================================

;; We inherit tuareg's `syntax-propertize-function' without changes.
;; In tuareg's syntax table, `<' and `>' are already punctuation,
;; so no additional syntax properties are needed for JSX delimiters.

;;; ============================================================
;;; LSP integration
;;; ============================================================

;; Eglot support
(with-eval-after-load 'eglot
  (defvar eglot-server-programs)
  (add-to-list 'eglot-server-programs
               '(mlx-mode . ("ocamllsp"))))

;; lsp-mode support
(with-eval-after-load 'lsp-mode
  (defvar lsp-language-id-configuration)
  (add-to-list 'lsp-language-id-configuration
               '(mlx-mode . "ocaml")))

;;; ============================================================
;;; Mode definition
;;; ============================================================

;;;###autoload
(define-derived-mode mlx-mode tuareg-mode "MLX"
  "Major mode for editing MLX files (OCaml with JSX).

MLX extends OCaml with JSX syntax for writing UI markup.
This mode provides:
  - Syntax highlighting for both OCaml and JSX constructs
  - JSX-aware indentation
  - LSP integration via eglot or lsp-mode (using ocamllsp)

\\{mlx-mode-map}"
  :group 'mlx

  ;; JSX font-lock keywords on top of tuareg's
  (font-lock-add-keywords nil mlx-font-lock-keywords 'append)

  ;; Enable multi-line font-lock so JSX tags spanning multiple
  ;; lines are refontified correctly on edits.
  (setq-local font-lock-multiline t)

  ;; JSX indentation wrapping tuareg's SMIE indentation
  (add-function :around (local 'indent-line-function)
                #'mlx--indent-line))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.mlx\\'" . mlx-mode))

(provide 'mlx-mode)

;;; mlx-mode.el ends here
