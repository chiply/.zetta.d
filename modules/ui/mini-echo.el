;;; mini-echo.el --- Persistent echo-area segments -*- lexical-binding: t; -*-

;; mini-echo shows small, persistent "mode-line-like" segments in the
;; echo area, and (unlike writing there directly) it cooperates with the
;; active minibuffer and completion UIs like vertico.
;;
;; Sparse + CONTEXTUAL by design: these segments surface info only when
;; it's relevant, so the echo area stays clean otherwise.  We deliberately
;; avoid data already shown in the tab-bar / mode line (major-mode, vcs,
;; buffer position, flycheck, clock, ...).
;;
;;   selection-info — size of the active region while marking
;;   macro          — keyboard-macro recording indicator
;;   process        — running async processes (compiles, greps, ...)
;;
;; Switch off anytime with `M-x mini-echo-mode'.  Add an always-visible
;; anchor (e.g. "battery" or "time") to the :long/:short lists below if
;; you want something shown even when idle.

(use-package mini-echo
  :hook (elpaca-after-init . mini-echo-mode)
  :config
  ;; IMPORTANT: `mini-echo-mode' hides the mode line by default (it
  ;; expects to *replace* the mode line, calling `global-hide-mode-line-mode').
  ;; We keep our SVG mode line and use mini-echo only for sparse echo-area
  ;; extras, so neutralize its hide/show of the mode line entirely.  The
  ;; advice is installed here (at load) before the elpaca-after-init hook
  ;; enables the mode, so the mode line is never hidden.
  (advice-add 'mini-echo-hide-mode-line :override #'ignore)

  ;; "battery" is an always-visible anchor (its :setup enables
  ;; `display-battery-mode'); the rest are contextual and surface only
  ;; when active.
  (setq mini-echo-persistent-rule
        '(:long  ("battery" "selection-info" "macro" "process")
          :short ("battery" "selection-info" "macro"))))
;;; mini-echo.el ends here
