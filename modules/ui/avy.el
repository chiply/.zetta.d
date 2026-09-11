;;; avy.el --- Configure avy -*- lexical-binding: t; -*-

;; Avy's own defaults are a red, a blue and a pink chosen to be loud rather
;; than to belong anywhere -- and whichever theme is loaded then paints over
;; them with something arbitrary of its own.  Taken off the palette instead.
;;
;; An avy key has to POP: it is competing with the text it is drawn on top
;; of.  So it is INVERTED -- the ink ladder as the ground, the page colour as
;; the text -- which is the strongest contrast a theme offers without
;; introducing a hue from outside it, and which inverts correctly whether the
;; theme is light or dark.
;;
;; The four faces are not decoration; avy uses them to say where you are in a
;; multi-key sequence (`avy-lead-faces' cycles through them).  So they take
;; successive rungs, and the one you are about to press is the brightest:
;;
;;   avy-lead-face    the terminating char        brushup-fg   (loudest)
;;   avy-lead-face-0  first non-terminating       brushup-fg-3
;;   avy-lead-face-2  further leading chars       brushup-fg-5
;;   avy-lead-face-1  already matched             recedes, not inverted --
;;                    it is spent, and reads as history rather than target

(defun zetta-avy-apply-palette ()
  "Paint avy's lead faces from the current theme's ladder."
  (when (boundp 'brushup-bg)
    (dolist (spec `((avy-lead-face   ,brushup-fg   ,brushup-bg bold)
                    (avy-lead-face-0 ,brushup-fg-3 ,brushup-bg bold)
                    (avy-lead-face-2 ,brushup-fg-5 ,brushup-bg normal)
                    (avy-lead-face-1 ,brushup-bg-3 ,brushup-fg-5 normal)))
      (when (facep (nth 0 spec))
        (set-face-attribute (nth 0 spec) nil
                            :background (nth 1 spec)
                            :foreground (nth 2 spec)
                            :weight (nth 3 spec))))
    ;; Unused while `avy-background' is nil, but wrong if it is ever turned
    ;; on: this one dims everything that is NOT a target.
    (when (facep 'avy-background-face)
      (set-face-attribute 'avy-background-face nil
                          :foreground brushup-fg-6
                          :background brushup-bg))))

(use-package avy
  :ensure t
  :commands (avy-goto-char-timer evil-avy-goto-char-timer)
  :config
  (setq avy-ignored-modes
        '(image-mode doc-view-mode pdf-view-mode))

  (general-define-key :keymaps 'override
                      "C-s-o" 'evil-avy-goto-char-timer)

  ;; "Avy can do anything" -- press `.' during any avy session to run
  ;; `embark-act' on the landed target.  After embark exits, returns
  ;; to the originating window via `avy-ring' so the prompt feels
  ;; like a handoff rather than a navigation.
  ;; https://karthinks.com/software/avy-can-do-anything/
  (defun avy-action-embark (pt)
    "Dispatch `embark-act' on PT after avy lands."
    (unwind-protect
        (save-excursion
          (goto-char pt)
          (embark-act))
      (select-window
       (cdr (ring-ref avy-ring 0))))
    t)

  (with-eval-after-load 'embark
    (setf (alist-get ?. avy-dispatch-alist) #'avy-action-embark))

  (zetta-avy-apply-palette)

  :brushup
  (add-to-list 'brushup-styles '(zetta-avy-apply-palette))

  :hook (use-package--avy--post-config . brushup))
;;; avy.el ends here
