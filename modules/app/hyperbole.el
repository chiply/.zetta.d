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

;; --- Fix HyRolo's consult-grep handoff for directory search paths ---
;; When `hyrolo-file-list' contains a directory, the interactive grep
;; commands (`hyrolo-grep'/`hyrolo-fgrep') read input through consult, which
;; runs ripgrep *inside* that directory and so reports bare file names
;; relative to it.  `hyrolo-grep-input' hands those names back, and HyRolo
;; then re-expands them against the invocation `default-directory' (not the
;; search dir), producing non-existent paths -- so the assembled *HyRolo*
;; buffer shows "No matching entries" even though consult found matches.
;; Re-root the names against `hyrolo-file-list' so only the matched files are
;; assembled (fast) and the consult front-end is left untouched.

(defun zetta-hyrolo--search-roots ()
  "Directory roots to resolve consult-relative HyRolo file names against.
Each entry of `hyrolo-file-list' contributes its own directory (a
directory entry contributes itself; a file or wildcard entry contributes
its parent directory)."
  (delq nil
        (mapcar (lambda (p)
                  (let ((ep (hpath:expand p)))
                    (if (file-directory-p ep)
                        (file-name-as-directory ep)
                      (file-name-directory ep))))
                hyrolo-file-list)))

(defun zetta-hyrolo--reroot (files roots)
  "Resolve each name in FILES to an existing path under one of ROOTS.
Absolute names are kept if they exist; search-relative names (as returned
by `consult-grep', which runs inside the search directory) are expanded
against ROOTS.  Unresolvable names are dropped."
  (delq nil
        (mapcar (lambda (f)
                  (if (file-name-absolute-p f)
                      (and (file-exists-p f) f)
                    (seq-some (lambda (root)
                                (let ((cand (expand-file-name f root)))
                                  (and (file-exists-p cand) cand)))
                              roots)))
                files)))

(defun zetta-hyrolo-fix-consult-handoff (result)
  "Re-root consult-grep's relative file names in RESULT for HyRolo's assembler.
`hyrolo-grep-input' returns (PATTERN MATCHING-FILES) when driven through
consult.  consult runs ripgrep inside the search directory, so
MATCHING-FILES are bare names relative to it; HyRolo would otherwise
re-expand them against the wrong `default-directory' and find nothing.
Resolve them against `hyrolo-file-list' so only the matched files are
assembled, leaving the consult front-end untouched.  If nothing resolves,
return RESULT unchanged so the assembler does not fall back to scanning
every file."
  (if (and (consp result) (consp (cdr result)) (cadr result))
      (let ((rerooted (zetta-hyrolo--reroot (cadr result)
                                            (zetta-hyrolo--search-roots))))
        (if rerooted
            (list (car result) rerooted)
          result))
    result))

(use-package hyperbole
  :defer 1
  :init
  ;; Keep Hyperbole's default key initialization; we relocate two keys below.
  (setq hkey-init t)
  :config
  (hyperbole-mode 1)

  ;; --- HyWiki: highlight/buttonize WikiWords (pages live in ~/hywiki/) ---
  ;; `hyperbole-mode' alone does NOT highlight WikiWords; the global
  ;; `hywiki-mode' does.  `hywiki-directory' defaults to ~/hywiki/, which is
  ;; where the generated chiply.dev WikiWord pages live.  Follow a WikiWord
  ;; with the Action Key {s-H} (relocated from {M-RET} below).
  (require 'hywiki)
  (hywiki-mode 1)

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
  (hkey-set-key (kbd "s-H") #'hkey-either)

  ;; --- HyRolo: search the Logseq pages as the rolo source ---
  (setq hyrolo-file-list '("~/logseq/pages/"))
  ;; Make the consult-driven grep commands resolve their matched files
  ;; correctly (see `zetta-hyrolo-fix-consult-handoff' above).
  (advice-add 'hyrolo-grep-input :filter-return
              #'zetta-hyrolo-fix-consult-handoff))

;;; hyperbole.el ends here
