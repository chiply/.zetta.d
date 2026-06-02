;;; hyperbole.el --- Configure GNU Hyperbole -*- lexical-binding: t; -*-

;; GNU Hyperbole: hypertextual information management — implicit buttons,
;; the Koutliner, HyRolo, smart keys, etc.  Installed from GNU ELPA via elpaca.
;;
;; We keep Hyperbole's FULL default key setup (`hkey-init' = t: shift-mouse
;; Smart Keys, the C-c bindings, etc.) but relocate the two bindings that
;; would clash with this distro:
;;
;;   * The minibuffer menu, default {C-h h}, is moved to {C-h H} so the stock
;;     {C-h h} (view-hello-file) and the which-key/embark `C-h' prefix help are
;;     left untouched.
;;   * The keyboard Action Key, default {M-RET} (which org-mode wants for
;;     `org-meta-return'), is moved to {s-H}.  The Assist Key is the prefixed
;;     variant {C-u s-H}.  The shift-mouse Smart Keys keep their defaults.

(use-package hyperbole
  :defer 1
  :init
  ;; Keep Hyperbole's default key initialization; we relocate two keys below.
  (setq hkey-init t)
  :config
  (hyperbole-mode 1)

  ;; --- Relocate the minibuffer menu: {C-h h} -> {C-h H} ---
  ;; Hyperbole binds `hyperbole' to {C-h h} globally; undo that and rebind.
  (when (eq (lookup-key (current-global-map) (kbd "C-h h")) 'hyperbole)
    (global-set-key (kbd "C-h h") #'view-hello-file))
  (global-set-key (kbd "C-h H") #'hyperbole)

  ;; --- Relocate the keyboard Action/Assist Key: {M-RET} -> {s-H} ---
  ;; Free the default M-RET variants from `hyperbole-mode-map' (so org-mode's
  ;; M-RET is no longer shadowed), then bind the Action Key on s-H via the
  ;; supported `hkey-set-key' helper.  Assist Key = {C-u s-H}.
  (dolist (k '("M-RET" "M-<return>" "ESC RET" "ESC <return>"))
    (define-key hyperbole-mode-map (kbd k) nil))
  (hkey-set-key (kbd "s-H") #'hkey-either))

;;; hyperbole.el ends here
