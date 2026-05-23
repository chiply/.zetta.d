;;; treesit-tap.el --- treesit-tap wrapper + zetta-specific extras -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `treesit-tap' package (under
;; `source/zettapkg/').  When the package is factored out to its own
;; repo, swap `:ensure nil' + `:load-path' for `:ensure t'.
;;
;; Adds zetta-specific bits the upstream package deliberately omits:
;; - `brick' thing-at-point provider (zetta-local extension).
;; - `brick' and `orgtree' added to `treesit-tap-things' (so
;;   `treesit-tap-set-local' offers them in the picker).
;; - Keybindings: s-j/s-k/s-h/s-l for nav, s-x t for set-local, &c.
;; - Loads the optional `treesit-tap-embark' integration after embark.

(use-package treesit-tap
  :ensure nil
  :load-path "source/zettapkg/treesit-tap"
  :config
  (treesit-tap-setup)

  ;; Zetta-specific things in the picker.  `brick' is defined below;
  ;; `orgtree' is defined in `modules/org/org.el'.
  (dolist (thing '("brick" "orgtree"))
    (add-to-list 'treesit-tap-things thing t))

  ;; Embark sub-extension: load once embark is available.
  (with-eval-after-load 'embark
    (require 'treesit-tap-embark)))


;;;; Zetta-local thing: `brick'
;; ----------------------------------------------------------------
;; A "brick" is a paragraph-shaped region delimited by blank lines.
;; Useful as a coarser navigation unit than `paragraph' for prose.

(defun zetta--current-line-empty-p ()
  (save-excursion
    (beginning-of-line)
    (looking-at-p "[[:space:]]*$")))

(defun brick-next-brick ()
  (interactive)
  (let ((delim "^ *$"))
    (re-search-forward delim)
    (forward-to-word 1)
    (evil-first-non-blank)))

(defun brick-backward-brick (&optional skip)
  (interactive)
  (let* ((delim "^ *$")
         (bol (move-beginning-of-line 1))
         (blank-line-pt (re-search-backward delim nil t)))
    (cond ((not blank-line-pt)
           (progn (beginning-of-buffer) (point)))
          ((and (or (= 1 (- bol blank-line-pt))
                    (= 0 (- bol blank-line-pt)))
                skip)
           (progn
             (backward-to-word 1)
             (if (re-search-backward delim nil t)
                 (evil-forward-word-begin)
               (progn (beginning-of-buffer) (point)))))
          (t (progn
               (re-search-backward delim nil t)
               (evil-forward-word-begin))))))

(defun brick-forward-brick (&optional arg)
  (interactive "p")
  (setq arg (or arg 1))
  (while (and (> arg 0) (not (eobp)) (brick-next-brick))
    (setq arg (1- arg)))
  (while (and (< arg 0) (not (bobp)) (brick-backward-brick t))
    (setq arg (1+ arg))))

(put 'brick 'forward-op 'brick-forward-brick)

(defun brick-bounds-of-brick-at-point ()
  (interactive)
  (save-excursion
    (if (not (zetta--current-line-empty-p))
        (let* ((beg (if (not (bobp))
                        (progn (brick-backward-brick) (point))
                      (point)))
               (end (if (not (eobp))
                        (progn (end-of-thing 'paragraph) (+ 1 (point)))
                      (point))))
          (cons beg end))
      nil)))

(put 'brick 'bounds-of-thing-at-point 'brick-bounds-of-brick-at-point)


;;;; Misc helpers used by other modules
;; ----------------------------------------------------------------

(defun zetta-contiguous-chars-at-point ()
  "Return the contiguous WORD around point (evil-WORD boundaries).
Used by `modules/tools/lsp.el'."
  (save-excursion
    (let* ((beg (progn (evil-backward-WORD-begin) (point)))
           (end (1+ (progn (evil-forward-WORD-end) (point)))))
      (buffer-substring beg end))))


;;;; Keybindings
;; ----------------------------------------------------------------

(general-define-key
 :keymaps '(sql-mode-map lisp-mode-map lisp-interaction-mode-map
            emacs-lisp-mode-map elisp python-ts-mode-map
            yaml-mode-map sh-mode-map shell-command-mode-map
            lark-mode-map org-mode-map)
 "s-j" 'treesit-tap-next
 "s-k" 'treesit-tap-prev
 "s-h" 'treesit-tap-beg
 "s-l" 'treesit-tap-end
 "s-x v" 'treesit-tap-pulse
 "s-x V" 'treesit-tap-select
 "s-x t" 'treesit-tap-set-local
 "s-x j" 'embark-scope-jump-to-type
 "s-x a" 'embark-scope-avy-jump-to-type
 "s-/" 'treesit-tap-comment)

;;; treesit-tap.el ends here
