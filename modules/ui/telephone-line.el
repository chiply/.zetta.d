;;; telephone-line.el --- Configure telephone-line -*- lexical-binding: t; -*-

(defun zetta-telephone-line-evil-tag-faces ()
  "Put the evil state tag on the brushup ink ladder.

telephone-line ships the tag as a stoplight (red normal, green insert,
orange visual...).  Here the colour says how far the state is from rest:
normal is the page, insert is the loudest thing on the mode line (ink pill,
page text), the transient states sit between.  On a tty frame this tag is
the one state indicator the terminal cannot strip -- mosh drops the cursor
shape (see `zetta-evil-tty-cursor') -- so it has to be readable without
being read.  Prominence only; no hue names a state."
  (when (facep 'telephone-line-evil)
    (set-face-attribute 'telephone-line-evil nil
                        :inherit 'mode-line :weight 'bold
                        :foreground brushup-fg :background brushup-bg)
    (dolist (spec `((telephone-line-evil-normal   ,brushup-fg   ,brushup-bg)
                    (telephone-line-evil-motion   ,brushup-fg-3 ,brushup-bg)
                    (telephone-line-evil-operator ,brushup-fg   ,brushup-bg-2)
                    (telephone-line-evil-visual   ,brushup-fg   ,brushup-bg-3)
                    (telephone-line-evil-replace  ,brushup-bg   ,brushup-fg-3)
                    (telephone-line-evil-emacs    ,brushup-bg   ,brushup-fg-3)
                    (telephone-line-evil-god      ,brushup-bg   ,brushup-fg-3)
                    (telephone-line-evil-insert   ,brushup-bg   ,brushup-fg)))
      (when (facep (car spec))
        (set-face-attribute (car spec) nil
                            :foreground (nth 1 spec)
                            :background (nth 2 spec))))))

(use-package telephone-line
  :config

  ;; Every segment below that reaches for another module guards the
  ;; call, the way `zt-flycheck-segment' always has.  telephone-line
  ;; catches a segment's error so the mode line still draws, but on the
  ;; headless profile (no all-the-icons, no parrot, no nyan-mode) that
  ;; was three signals per redisplay on one core and a *Messages* buffer
  ;; full of "Error during redisplay" -- measured 2026-09-11 on the hub
  ;; daemon, 206 lines within minutes.  On the Mac every one of these is
  ;; loaded, so the guards change nothing there.

  (telephone-line-defsegment zt-ace-1 ()
    ;; `ace-window-path' is only set once `aw-update' has run for the
    ;; window; a fresh tty frame can be drawn before that.
    (when-let* ((path (window-parameter (selected-window) 'ace-window-path)))
      (propertize path 'face 'ef-themes-heading-0)))

  (telephone-line-defsegment zt-icon-file-or-buffer ()
    (when (fboundp 'all-the-icons-icon-for-mode)
      (let ((fname (buffer-file-name)))
        (if fname
            (all-the-icons-icon-for-file fname)
          (all-the-icons-icon-for-mode major-mode)))))

  (telephone-line-defsegment zt-icon-lsp ()
    (when (and (bound-and-true-p lsp-mode)
               (fboundp 'all-the-icons-icon-for-mode))
      (all-the-icons-icon-for-mode 'lsp-mode)))

  (telephone-line-defsegment zt-icon-copilot ()
    (when (and (bound-and-true-p copilot-mode)
               (fboundp 'all-the-icons-octicon))
      ;; `all-the-icons-icon-for-mode' only maps MAJOR modes, so for the
      ;; copilot-mode minor mode it returned the symbol instead of an icon.
      ;; Use the real Copilot octicon directly (SVG, like the siblings).
      (all-the-icons-octicon "copilot" :face 'success)))

  (telephone-line-defsegment zt-icon-side-window ()
    (when (zetta-side-window-p (selected-window)) " {S} "))

  (telephone-line-defsegment zt-flappy-fish ()
    (if (equal
         (current-buffer)
         (window-buffer (selected-window)))
        fish-mode-line-string
      ;; NOTE doesn't work, leaves behind an un-rendered animation frame
      "foo"))

  (telephone-line-defsegment zt-vc-segment-repo-icon ()
    (when (and (fboundp 'all-the-icons-icon-for-mode)
               (vc-git-root (or (buffer-file-name) default-directory)))
      (all-the-icons-icon-for-mode 'magit-status-mode)))

  (telephone-line-defsegment zt-vc-segment-repo ()
    (when (vc-git-root (or (buffer-file-name) default-directory))
      (nth 0 (zetta-get-repo-name))))

  (telephone-line-defsegment zt-vc-segment-branch ()
    (when (vc-git-root (or (buffer-file-name) default-directory))
      (vc-git--symbolic-ref (or (buffer-file-name) default-directory))))

  (telephone-line-defsegment zt-flycheck-segment ()
    (when (fboundp 'flycheck-indicator--mode-line)
      (let ((text (flycheck-indicator--mode-line)))
        (if (string= " not-checked" text) "" text))))

  (telephone-line-defsegment zt-zmc-segment ()
    (concat (or (if (boundp 'latest-transient) latest-transient) (if (boundp 'local-transient) local-transient)) " "))

  (telephone-line-defsegment zt-indicators-segment ()
    ;; note making letters now as there are still issues with
    ;; faces for SVG branch of all-the-icons
    ;; Not sure if actually the ones that change size are the
    ;; intende behavior.  Either way, I tihk it has to do with
    ;; scale attribute of the SVG and there must be a way to
    ;; change this
    ;; Actaulyl the scale attribute is not the culprit here as the
    ;; icons that do have fixed fonts actually have scale 1 as
    ;; well.  Didn't see a difference in the attributes between
    ;; the working and not working icons... will just table this
    ;; for now as I can hack around this by using one of the
    ;; icon-for commands
    ;; TODO separate this out
    (concat
     (when (bound-and-true-p repeat-in-progress) "R")
     (let ((icon (zetta-line-tramp-icon))) (when icon "T"))
     (let ((icon (zetta-line-docker-icon))) (when icon "D"))
     (let ((icon (zetta-line-narrowed-icon))) (when icon "N"))
     (let ((icon (zetta-line-hydra-indicator-icon))) (when icon "H"))
     ))

  (telephone-line-defsegment zt-anzu-segment ()
    (anzu--update-mode-line)
    )

  (telephone-line-defsegment zt-iedit-segment ()
    (let ((icon (zetta-line-iedit-icon)))
      (when icon
        ;; the car of iedit-mode-line unioned with the cdr of iedit-mode-line
        (cons (replace-regexp-in-string
               " " ""
               (car iedit-mode-line) )
              (cdr iedit-mode-line)))))

  (telephone-line-defsegment zt-nyan ()
    (when (and (eq major-mode 'magit-status-mode) (fboundp 'nyan-create))
      (nyan-create)))

  (telephone-line-defsegment zt-parrot ()
    (when (and (fboundp 'parrot-create)
               (boundp 'zetta-parrot-window)
               (boundp 'zetta-parrot-buffer)
               (equal zetta-parrot-window (selected-window))
               (equal zetta-parrot-buffer (current-buffer))
               (memq major-mode '(org-mode magit-status-mode)))
      (parrot-create)))

  (telephone-line-defsegment zt-popper-popup ()
    (if (and (bound-and-true-p popper-popup-status)
             (fboundp 'all-the-icons-vscode-codicons))
        (all-the-icons-vscode-codicons "layout-sidebar-left") ;; NOTE requires svg branch
      ""))

  (telephone-line-defsegment zt-doc-position ()
    (cond
     ((eq major-mode 'pdf-view-mode)
      (format " %d/%d " (pdf-view-current-page) (pdf-cache-number-of-pages)))
     ((eq major-mode 'reader-mode)
      (let ((page (reader-current-doc-pagenumber)))
        (when page (format " p%d " (1+ page)))))
     (t nil)))

  (setq telephone-line-primary-left-separator 'telephone-line-nil
        telephone-line-primary-right-separator 'telephone-line-nil
        telephone-line-secondary-left-separator 'telephone-line-nil
        telephone-line-secondary-right-separator 'telephone-line-nil)

  ;; NOTE My current implementation is overly simplistic relative to
  ;; what telephone line actually provides. I wanted to prioritize
  ;; getting color icons in the mode line, but I found that difficult
  ;; as when you're using something other than nil to define a
  ;; segment, basically the face gets overridden and it always comes
  ;; out with a dark foreground, which I don't like. But using nil for
  ;; everything means that you don't get visual separation between the
  ;; different segments, and because everything is defined with the
  ;; same face, the separator doesn't actually show up. I do want to
  ;; see if there's a way to fix that, but right now, basically, it's
  ;; just icons dumped out with no visual separation, but I think
  ;; that's okay for now. It's also space-saving.
  ;; NOTE The current solution I've landed on, which is not ideal, is
  ;; to use null anytime you have anything that needs to display
  ;; color, and then to use some other symbol, like foo, anytime it
  ;; doesn't matter, and then that allows you to have the
  ;; separation. It has to have something to do with applying the
  ;; separators.
  ;; NOTE currently styling is effectively disabled
  (defface telephone-line-face-active `((t (:background ,brushup-bg :foreground unspecified))) "foo")
  (defface telephone-line-face-inactive `((t (:background ,brushup-bg :foreground unspecified))) "bar")

  (setq telephone-line-faces
        '(
          (foo . (telephone-line-face-inactive . telephone-line-face-inactive))
          (nil . (telephone-line-face-inactive . telephone-line-face-inactive))
          ))

  (setq telephone-line-subseparator-faces '())

  (setq telephone-line-lhs
        '(
          (nil . (telephone-line-evil-tag-segment telephone-line-meow-tag-segment))
          (foo . (zt-ace-1))
          (nil . (zt-icon-file-or-buffer zt-doc-position zt-icon-copilot zt-icon-lsp zt-popper-popup zt-vc-segment-repo-icon))
          (foo . (zt-indicators-segment))
          (nil . (zt-iedit-segment))
          (foo . (zt-anzu-segment))
          (nil . (zt-flycheck-segment))
          (foo . (zt-nyan))
          (nil . (zt-parrot))
          ))

  (setq telephone-line-target 'mode-line)
  (setq telephone-line-rhs '())
  (setq telephone-line-evil-use-short-tag nil)
  (setq telephone-line-separator-extra-padding 0)
  (setq telephone-line-height 40)

  (telephone-line-mode -1) ;; helps when making edits (resets the mode-line)
  (telephone-line-mode 1)

  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'telephone-line-face-active nil
                                      :inherit nil
                                      :foreground 'unspecified
                                      :background brushup-bg)
                  (set-face-attribute 'telephone-line-face-inactive nil
                                      :inherit nil
                                      :foreground 'unspecified
                                      :background brushup-bg)
                  (zetta-telephone-line-evil-tag-faces))))

;;; telephone-line.el ends here
