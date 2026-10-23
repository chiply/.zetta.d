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

  ;; `mini-echo-update' runs every `mini-echo-update-interval' (0.3 s) and
  ;; `mini-echo-update-overlays' ends in an `overlay-put' of a freshly built
  ;; string.  `overlay-put' decides "changed" with `eq' (buffer.c), so a
  ;; string that is `equal' to the last one still invalidates the overlay
  ;; and redisplays the echo area -- 3.3 times a second, and an echo-area
  ;; redisplay re-evaluates every mode line (the mechanism behind the 2026-07
  ;; consult stall, see OPTIMIZATIONS.org round 2).  Skip the put when the
  ;; message, the info and the width it was laid out for are unchanged.
  (defvar zetta-mini-echo--last nil
    "(MSG INFO WIDTH ACTIVE-MINIBUFFER) of the last overlay update.")
  (defun zetta-mini-echo--reset-last (&rest _)
    (setq zetta-mini-echo--last nil))
  (defun zetta-mini-echo--update-overlays-if-changed (orig &optional msg)
    (let ((key (list (or msg (current-message) "")
                     (mini-echo-build-info)
                     (mini-echo-minibuffer-width)
                     (and (active-minibuffer-window) t))))
      (unless (equal key zetta-mini-echo--last)
        (setq zetta-mini-echo--last key)
        (funcall orig msg))))
  (advice-add 'mini-echo-update-overlays :around
              #'zetta-mini-echo--update-overlays-if-changed)
  ;; The overlays are rebuilt when the mode toggles; forget the key with them.
  (add-hook 'mini-echo-mode-hook #'zetta-mini-echo--reset-last)

  ;; "battery" is an always-visible anchor (its :setup enables
  ;; `display-battery-mode'); the rest are contextual and surface only
  ;; when active.
  (setq mini-echo-persistent-rule
        '(:long  ("battery" "selection-info" "macro" "process")
          :short ("battery" "selection-info" "macro"))))
;;; mini-echo.el ends here
