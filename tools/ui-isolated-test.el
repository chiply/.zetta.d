;;; ui-isolated-test.el --- Stubbed harness for tab-bar / header-line UI -*- lexical-binding: t; -*-

;; Loaded by `emacs -Q' inside a THROWAWAY daemon (see ui-test.sh) so
;; experimental tab-bar / header-line renderers can be exercised without
;; touching the real Emacs session.  It stubs the segment functions and
;; theming vars that the real modules expect, then loads the module under
;; test and activates it.  If the renderer deadlocks redisplay, only this
;; throwaway daemon freezes -- kill it and the real session is untouched.

(require 'svg)
(require 'cl-lib)

;; --- theming / font stubs ---------------------------------------------
(setq zetta-font "Terminus (TTF)")
(defvar brushup-fg-3 "#88cc88")
(defvar brushup-bg "#1d1f21")
(defvar brushup-dark-p t)

;; --- stub the tab-bar segment functions with plain, recognizable text --
;; (Real ones live in tab-bar.el and pull in the whole config; here we
;;  only need representative strings to test LAYOUT + redisplay safety.)
(dolist (pair '((zetta-buffer-name . "~/src/project/some/long/file-name.el")
                (zmc-modeline-indicator . " M ")
                (zetta-pyvenv-activate-poetry-modeline . "{venv:proj}")
                (zetta-tab-bar-spot-mode-line-string . "♪ Some Artist - A Track Title")
                (zetta-tab-bar-modal . "evil")
                (zetta-gptel-processes . " ai:1 ")
                (blinker-tab-bar . " . ")
                (tab-bar-keycast . "C-x C-s  save-buffer")
                (zetta-tab-bar-current-thing . "[defun] ")
                (zetta-tab-bar-recursion-level . "[R:0] ")
                (recursion-indicator--string . "")
                (tab-bar-format-global . "11:24 ")
                (zetta-current-prefix . "C-c")
                (space-tree-modeline-lighter . " ST ")))
  (let ((fn (car pair)) (val (cdr pair)))
    (unless (fboundp fn) (fset fn `(lambda (&rest _) ,val)))))

;; --- load the module under test ---------------------------------------
(load (expand-file-name "modules/core/tab-bar-svg.el"
                        (file-name-directory
                         (directory-file-name
                          (file-name-directory load-file-name))))
      nil t)

;; --- activate -----------------------------------------------------------
(tab-bar-mode 1)
(setq tab-bar-show t)
(when (fboundp 'zetta-tab-bar-use-svg)
  (zetta-tab-bar-use-svg))

(message "ui-isolated-test loaded; tab-bar-format=%S" tab-bar-format)
;;; ui-isolated-test.el ends here
