;;; hl-todo.el --- Configure hl-todo -*- lexical-binding: t; -*-

;; Declared, not required: hl-todo may not be loaded when this file is
;; byte-compiled, and `zetta-hl-todo-refresh' clears this buffer-local cache.
(defvar hl-todo--regexp)

(use-package hl-todo
  :config
  ;; Keyword colours come from the theme rather than being fixed web
  ;; primaries.  The old list was #FF0000 / #0000FA / A020F0 etc -- saturated
  ;; sRGB corners that clash with any designed palette, and #0000FA is very
  ;; nearly unreadable on a dark background.
  ;;
  ;; Taking them from the theme's error/warning/success colours instead was
  ;; the first fix and only moved the problem: that is still the
  ;; red/green/yellow stoplight, just the theme's own version of it, and it
  ;; puts the loudest colour on the page on the single most common word in a
  ;; codebase.  The keyword is a WORD -- "TODO", "FIXME", "NOTE" -- so it
  ;; already says which one it is; what the colour is left to encode is how
  ;; much attention it deserves.  `zetta-keyword-tiers' says that in rungs of
  ;; the theme's ink ladder.
  ;;
  ;;   loud    FIXME GOTCHA              something is broken
  ;;   open    TODO STUB LEFTOFF PROMPT  work not done yet
  ;;   parked  NOTE EXPLANATION DEBUG    context, not a call to action
  ;;   closed  DONE                      over
  ;;
  ;; TODO and DONE sit on the same rungs org gives them (see
  ;; modules/org/org.el): hl-todo is hooked into `org-mode' and paints an org
  ;; heading's keyword over org's own face, so a heading would otherwise read
  ;; at one weight in an org file and another everywhere else.
  (defvar zetta-hl-todo-keyword-tiers
    '((loud   "FIXME" "GOTCHA")
      (open   "TODO" "STUB" "LEFTOFF" "PROMPT")
      (parked "NOTE" "EXPLANATION" "DEBUG")
      (closed "DONE"))
    "hl-todo keywords grouped by `zetta-keyword-tiers' prominence tier.")

  (defun zetta-hl-todo-refresh ()
    "Recompute `hl-todo-keyword-faces' from the current theme's ink ladder.

Also repaints live buffers.  `hl-todo--get-face' reads the alist at
FONTIFICATION time, so without a flush a theme change leaves every buffer
already open showing the previous theme's keywords until something edits
it.  `hl-todo--regexp' is a buffer-local cache built from the keyword
list; it only goes stale if the tier table gains or loses a keyword, but
clearing it here is a good deal cheaper than the confusion of not."
    (setq hl-todo-keyword-faces
          (mapcan (lambda (group)
                    (let ((color (if (fboundp 'zetta-tier-color)
                                     (zetta-tier-color (car group))
                                   (face-foreground 'default nil t))))
                      (mapcar (lambda (kw) (cons kw color)) (cdr group))))
                  zetta-hl-todo-keyword-tiers))
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (bound-and-true-p hl-todo-mode)
          (setq hl-todo--regexp nil)
          (font-lock-flush)))))
  (zetta-hl-todo-refresh)

  :brushup
  (add-to-list 'brushup-styles '(zetta-hl-todo-refresh) t)

  :hook ((prog-mode markdown-mode org-mode yaml-mode) . hl-todo-mode))
;;; hl-todo.el ends here
