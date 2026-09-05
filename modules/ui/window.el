;;; window.el --- Configure window management -*- lexical-binding: t; -*-

(require 'window)

;; NOTE this makes them look almost invisible, better than disabling
;; the mode because when disabled there's still a black liine right
;; divider for some reason
(window-divider-mode -1)
(setq window-divider-default-places t)
;; A wide RIGHT divider is what separates side-by-side windows in the
;; `spacious-padding' look: the divider faces below are painted to the
;; background, so 30px reads as a gutter rather than as a rule.  The bottom
;; divider stays hairline -- Prot's package leaves it alone too, because its
;; vertical separation comes from the mode-line box; here that job is done by
;; `:pad-y' on the mode-line and header-line svg-line specs instead.
(defcustom zetta-window-divider-bottom-width 1
  "Height of the divider between vertically stacked windows.  Kept hairline.

Worth recording why, since the obvious tweak is a trap: a right divider
spans its window\='s FULL height and cannot be shortened or dashed, so two
windows stacked in one column share an unbroken vertical rule down their
left.  Raising this looks like the fix -- a bottom divider would interrupt
that run -- but the three divider faces are SHARED between the right and
bottom dividers, so whichever edge `zetta-window-divider-rule\=' colours gets
coloured on both, and you trade the continuous vertical rule for a
horizontal rule under every window.  Not worth it; left at 1."
  :type 'integer :group 'zetta)

(setq window-divider-default-bottom-width zetta-window-divider-bottom-width
      window-divider-default-right-width 30)
(window-divider-mode +1)

(defun zetta-window-divider-apply ()
  "Re-apply the divider widths to `default-frame-alist' and every frame.

`window-divider-mode' works by writing `right-divider-width' and
`bottom-divider-width' through `modify-all-frames-parameters', so ANY later
caller that re-applies the mode overwrites what was set here -- and the
widths landed back at 1 after a real startup even though the variables above
were correct, which means something during init does exactly that.  Running
once more after init settles wins that race whoever the other party is.
Cheap and idempotent, so it costs nothing if the clobber ever goes away."
  (window-divider-mode +1))

(add-hook (if (boundp 'elpaca-after-init-hook) 'elpaca-after-init-hook 'after-init-hook)
          #'zetta-window-divider-apply)
(add-hook 'emacs-startup-hook #'zetta-window-divider-apply)

(defcustom zetta-window-divider-rule nil
  "Which pixel column of the window divider is drawn as a visible rule.

A divider is drawn with THREE faces: the body plus a separate face for its
first and last pixel column.  At a 1px width all three coincide, which is
why painting only the body used to look fine; a wide divider pulls them
apart and each becomes independently styleable -- so a SINGLE-SIDED border
is just a matter of which one keeps a colour.

  nil     no rule; the divider is pure space (the default -- a vertical
          rule cannot be broken between stacked windows, see
          `zetta-window-divider-bottom-width\=', so the delineation is left
          to `zetta-tab-line-svg-overline\=' instead)
  `first' a rule at the LEFT edge of the gutter (a right border on the
          window to its left)
  `last'  a rule at the RIGHT edge, hugging the window to its right -- a
          left border on that window
  `both'  rules on both edges"
  :type '(choice (const :tag "None" nil) (const first) (const last) (const both))
  :group 'zetta)

(defcustom zetta-window-divider-rule-strength 0.22
  "How far the divider rule is blended from the page toward the ink.
Faint by intent: it delineates windows, it is not a frame around them."
  :type 'number :group 'zetta)

(defun zetta-window-divider-faces ()
  "Paint the divider faces: all to the background, bar the chosen rule.
See `zetta-window-divider-rule'."
  (let ((rule (zetta-line-blend brushup-bg brushup-fg
                                zetta-window-divider-rule-strength)))
    (dolist (face '(window-divider
                    window-divider-first-pixel
                    window-divider-last-pixel
                    ;; Also hide the built-in `vertical-border': on daemon
                    ;; frames `window-divider-mode' often isn't applied, so
                    ;; the unstyled border (a visible line) shows between
                    ;; side-by-side windows.  Paint it out either way.
                    vertical-border))
      (when (facep face)
        (set-face-attribute face nil
                            :background brushup-bg
                            :foreground brushup-bg)))
    (dolist (face (pcase zetta-window-divider-rule
                    ('first '(window-divider-first-pixel))
                    ('last  '(window-divider-last-pixel))
                    ('both  '(window-divider-first-pixel
                              window-divider-last-pixel))
                    (_ nil)))
      (when (facep face)
        (set-face-attribute face nil :foreground rule)))))

;; APPENDED, not prepended.  `brushup-init' -- which recomputes brushup-bg
;; and friends from the newly enabled theme -- sits near the END of
;; `brushup-styles', so a prepended entry reads the PREVIOUS theme's palette
;; and lands one theme change behind.  That is precisely what made the
;; dividers reappear on every theme switch: they were being painted to the
;; OLD background, which against the new one is a visible line.
(add-to-list 'brushup-styles '(zetta-window-divider-faces) t)

(defun zetta-window-divider-mode ()
  (interactive)
  (call-interactively 'window-divider-mode))

(defun zetta-scroll-bar-mode ()
  (interactive)
  (if (get-scroll-bar-mode) (set-scroll-bar-mode nil) (set-scroll-bar-mode 'left)))

(defun zetta-shrink-window-h-1 () (interactive) (shrink-window-horizontally 1))
(defun zetta-shrink-window-h-2 () (interactive) (shrink-window-horizontally 2))
(defun zetta-shrink-window-h-4 () (interactive) (shrink-window-horizontally 4))
(defun zetta-enlarge-window-h-1 () (interactive) (enlarge-window-horizontally 1))
(defun zetta-enlarge-window-h-2 () (interactive) (enlarge-window-horizontally 2))
(defun zetta-enlarge-window-h-4 () (interactive) (enlarge-window-horizontally 4))
(defun zetta-shrink-window-v-1 () (interactive) (shrink-window 1))
(defun zetta-shrink-window-v-2 () (interactive) (shrink-window 2))
(defun zetta-shrink-window-v-4 () (interactive) (shrink-window 4))
(defun zetta-enlarge-window-v-1 () (interactive) (enlarge-window 1))
(defun zetta-enlarge-window-v-2 () (interactive) (enlarge-window 2))
(defun zetta-enlarge-window-v-4 () (interactive) (enlarge-window 4))

(general-define-key
 :keymaps 'menu-window-map
 "D" (** delete-window)
 "C-S-d" (** delete-other-windows)
 "C-S-S" (** window-toggle-side-windows)
 "C-S-b h" (** horizontal-scroll-bar-mode)
 "mm" (** balance-windows)
 "mk" (** minimize-window)
 "mj" (** maximize-window)
 "C-v" (** visual-line-mode)
 "C-t" (** toggle-truncate-lines)
 "C-t" (** toggle-truncate-lines)
 "C-w" (** toggle-word-wrap)
 "s" (** zetta-state-hydra/body)
 "f" (** consult-project-extra-find)
 "F" (** find-file)
 "x" (** execute-extended-command)
 "u" (** winner-undo)
 "o" (** zetta-window-divider-mode)
 "C-S-b b" (** zetta-scroll-bar-mode)
 "r h" (** zetta-shrink-window-h-1)
 "r C-h" (** zetta-shrink-window-h-2)
 "r C-S-h" (** zetta-shrink-window-h-4)
 "r l" (** zetta-enlarge-window-h-1)
 "r C-l" (** zetta-enlarge-window-h-2)
 "r C-S-l" (** zetta-enlarge-window-h-4)
 "r j" (** zetta-shrink-window-v-1)
 "r C-j" (** zetta-shrink-window-v-2)
 "r C-S-j" (** zetta-shrink-window-v-4)
 "r k" (** zetta-enlarge-window-v-1)
 "r C-k" (** zetta-enlarge-window-v-2)
 "r C-S-k" (** zetta-enlarge-window-v-4)
 )

(add-to-list 'window-persistent-parameters '(window-side . writable))
(add-to-list 'window-persistent-parameters '(window-slot . writable))
(add-to-list 'window-persistent-parameters '(clone-of . writable))
(add-to-list 'window-persistent-parameters '(no-delete-other-windows . writable))
(add-to-list 'window-persistent-parameters '(split-window . writable))
(add-to-list 'window-persistent-parameters '(min-margins . writable))
(add-to-list 'window-persistent-parameters '(quit-restore . writable))

(general-define-key
 :keymaps 'menu-run-map
 "r" (** window-toggle-side-windows)
 )

(defun zetta-async-blowup ()
  (interactive)
  (when (or (eq (window-parameter (selected-window) 'window-side) 'top)
            (eq (window-parameter (selected-window) 'window-side) 'bottom))
    (if (< (window-total-height) 25)
        (enlarge-window 30)
      (shrink-window 30)))
  (when (eq (window-parameter (selected-window) 'window-side) 'left)
    (if (< (window-total-width) 30)
        (enlarge-window 30 t)
      (shrink-window 30 t)))
  (when (eq (window-parameter (selected-window) 'window-side) 'right)
    (if (< (window-total-width) 90)
        (enlarge-window 30 t)
      (shrink-window 30 t)))
  (unless (window-parameter (selected-window) 'window-side)
    (message "This is not a side window"))
  )

(general-define-key
 :keymaps '(treemacs-mode-map)
 "C-p" 'zetta-async-blowup)

(make-local-variable 'zetta-zen-disable)

(general-define-key
 :keymaps 'override
 "s-+" '(lambda () (interactive) (setq-local zetta-zen-disable t) (call-interactively 'text-scale-increase))
 "s-=" '(lambda () (interactive) (setq-local zetta-zen-disable t) (call-interactively 'text-scale-increase))

 "s--" '(lambda () (interactive) (setq-local zetta-zen-disable t) (call-interactively 'text-scale-decrease))

 "s-0" '(lambda () (interactive) (setq-local zetta-zen-disable t) (text-scale-adjust 0))
 "s-)" '(lambda () (interactive)
          ;; unlock
          (setq-local zetta-zen-disable nil)
          ;; and reset to (global) default size
          (text-scale-adjust 0))
 )
;;; window.el ends here
