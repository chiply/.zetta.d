;;; typst-ts-mode.el --- Configure typst-ts-mode -*- lexical-binding: t; -*-

;; Tree-sitter major mode for Typst (.typ) markup with a fully in-Emacs live
;; preview workflow: `typst-ts-watch-start' hot-compiles on every save and the
;; output PDF is shown in a side window via pdf-tools with auto-revert, so the
;; preview updates ~instantly as you edit.
;;
;; Requires the `typst' CLI (brew install typst).  The typst tree-sitter grammar
;; is auto-installed on first visit because `treesit-auto-install-grammar' is t
;; (set in modules/lang/treesit.el, Emacs 31); we register its source below.

;; typst-ts-mode's generated autoloads execute a `define-compilation-mode'
;; form at load time, so compile.el must be resident BEFORE elpaca activates
;; the package or the load dies void-function.  Whether it was resident was
;; a race decided by elpaca's async build interleaving — any declaration
;; added ahead of this module shifts every queue boundary and re-rolls it
;; (measured 2026-07-23: the snapshot CI job flipped red on an unrelated
;; ordering PR).  Requiring it here is deterministic: this top-level form
;; runs before the order below is declared, and activation follows it.
(require 'compile)

(defun zetta-typst-preview-in-emacs (pdf)
  "Open PDF in a right-hand side window and keep it live via auto-revert.
Used as `typst-ts-preview-function' so the package's compile/watch
pipeline renders straight into a pdf-tools buffer that reloads itself
whenever `typst watch' rewrites the file."
  (let ((win (display-buffer
              (find-file-noselect pdf)
              '(display-buffer-in-side-window
                (side . right) (window-width . 0.5)))))
    (when win
      (with-selected-window win
        (when (derived-mode-p 'pdf-view-mode)
          (auto-revert-mode 1))))))

(defun zetta-typst-live ()
  "Start hot-compile watch and open the live PDF preview side-by-side.
This is the one-shot \"start editing\" command: it begins `typst watch'
and renders the first compile into the live preview window."
  (interactive)
  (typst-ts-watch-start)
  (typst-ts-compile-and-preview))

(use-package typst-ts-mode
  :if (executable-find "typst")
  :mode ("\\.typ\\'" . typst-ts-mode)
  :init
  ;; Register the grammar source so Emacs 31 auto-installs it on first visit
  ;; (`treesit-auto-install-grammar' is t — see modules/lang/treesit.el).
  (require 'treesit)
  (add-to-list 'treesit-language-source-alist
               '(typst "https://github.com/Ziqi-Yang/tree-sitter-typst"))
  :config
  ;; Render previews inside Emacs (pdf-tools + auto-revert) instead of the
  ;; default `browse-url' (which would shell out to Preview.app).
  (setq typst-ts-preview-function #'zetta-typst-preview-in-emacs)
  :general
  (:keymaps 'typst-ts-mode-map
   "C-c C-c" 'typst-ts-compile
   "C-c C-p" 'typst-ts-preview
   "C-c C-w" 'typst-ts-watch-start
   "C-c C-k" 'typst-ts-watch-stop
   "C-c C-l" 'zetta-typst-live))

;;; typst-ts-mode.el ends here
