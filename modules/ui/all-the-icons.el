;;; all-the-icons.el --- Configure all-the-icons -*- lexical-binding: t; -*-

;; all-the-icons uses (setf (image-property ...)) without requiring
;; 'image.  An Emacs whose build doesn't preload image.el (headless CI
;; runners byte-compiling the prebuilt store) compiles that into a call
;; to the named setter function (setf image-property), which no
;; released Emacs defines -- every icon render then fails with
;; void-function, prebuilt stores shipped that bytecode to every
;; platform (measured 2026-07-25: 30.2- and 31.0.90-built stores
;; alike), and the vertico UI surfaced it as "Vertico detected an
;; error".  Define the setter so such bytecode works no matter which
;; Emacs compiled it.  Harmless when unneeded; skipped if some future
;; Emacs defines it natively.
(unless (fboundp (intern "(setf image-property)"))
  (defalias (intern "(setf image-property)")
    (lambda (value image property)
      (require 'image)
      (image--set-property image property value))
    "Named setter for `image-property', for bytecode compiled without image.el."))

(use-package all-the-icons
  :ensure (all-the-icons
           :host github
           :repo "domtronn/all-the-icons.el"
           :branch "svg"
           :files (:defaults "svg"))
  ;; NO `:if (display-graphic-p)' here.  Under a daemon the startup frame is
  ;; a terminal one, so that test is nil at init and use-package skips this
  ;; whole `:config' -- including the `currentColor' fill advice below, which
  ;; is the ONLY thing giving these SVGs a colour.  Every icon then renders
  ;; at the SVG default, black, in the graphical frames the daemon opens
  ;; later.  Nothing here needs a display: it is advice, alist edits and face
  ;; colours, all of which are fine to set up in a tty and are waiting,
  ;; correct, whenever a graphical frame does arrive.
  :config
  ;;(use-package octicons)
  (setq all-the-icons-color-icons t)

  ;; fixing themes
  ;; TODO mayybe more efficient way to just add a face to this
  ;; Somehow this gets around the size problem
  (setq all-the-icons-mode-icon-alist
        (-remove
         (lambda (x)
           (or (eq (car x) 'vterm-mode)
               (eq (car x) 'copilot-mode)
               (eq (car x) 'lsp-mode)
               (eq (car x) 'evil-state)
               (eq (car x) 'meow-state)
               (eq (car x) 'emacs-state)
               (eq (car x) 'insert-state)
               (eq (car x) 'non-insert-state)))
         all-the-icons-mode-icon-alist))
  (add-to-list 'all-the-icons-mode-icon-alist '(nov-mode octicons "book"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(md4rd-mode fontawesome-4 "reddit-alien"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(wombag-search-mode material-icons "article"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(wombag-show-mode material-icons "article"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(vterm-mode octicons "terminal"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(copilot-mode octicons "copilot"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(lsp-mode fileicon "vscode"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(evil-state devopicons "vim"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(meow-state fluentui-system-icons "animal_cat"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(emacs-state fileicon "emacs"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(insert-state fluentui-system-icons "pen"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(non-insert-state fluentui-system-icons "pen_off"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))

  ;;; ----------------------------------------------------------------
  ;;; Icon size
  ;;; ----------------------------------------------------------------
  ;; An icon is drawn at the pixel height of `(font-info (face-font
  ;; FACE))' -- the GLOBAL face, which knows nothing about
  ;; `text-scale-mode', since that remaps `default' buffer-locally.  And
  ;; the five entry points are memoized on their arguments alone
  ;; (`all-the-icons-cache'), so even a global zoom hands back the string
  ;; that was built at the old size.  Between them the icons kept
  ;; whatever height they were first drawn at, and a zoomed-out line
  ;; could not get any shorter than that.
  ;;
  ;; An explicit `:size' fixes both at once.  The icon macro prefers it
  ;; over its own font lookup, and being an argument it lands in the memo
  ;; key, so each size gets a cache entry of its own instead of the first
  ;; one winning for the rest of the session.
  (defun zetta-all-the-icons--sized (args)
    "Advice: size the icon in ARGS to the line it is going into.
A caller that asked for a size of its own keeps it."
    (if (or (plist-member (cdr args) :size)
            (not (fboundp 'zetta-icon-line-height)))
        args
      (append args (list :size (zetta-icon-line-height)))))

  (dolist (fn '(all-the-icons-icon-for-file
                all-the-icons-icon-for-dir
                all-the-icons-icon-for-dir-with-chevron
                all-the-icons-icon-for-mode
                all-the-icons-icon-for-weather))
    (advice-add fn :filter-args #'zetta-all-the-icons--sized))

  ;; An explicit `:width' is not the last word on how big the image ends
  ;; up: `compute_image_size' (src/image.c) multiplies it by the scaling
  ;; factor, and the `auto' default scales up whenever a character is
  ;; wider than 10 pixels.  So the size computed above would be doubled
  ;; again on a zoomed-IN frame.  Pinning the scale makes the pixel size
  ;; asked for the pixel size drawn, both ways.
  (defun zetta-all-the-icons--unscaled (image)
    "Advice: draw IMAGE at exactly the size it was built for."
    (when (eq 'image (car-safe image))
      (setf (image-property image :scale) 1))
    image)
  (advice-add 'all-the-icons--normalize-svg-doc :filter-return
              #'zetta-all-the-icons--unscaled)

  ;; Sizing an icon correctly when it is built is only half of it.  An
  ;; icon is an IMAGE, and an image already sitting in a buffer keeps the
  ;; pixel size it was created at -- zooming resizes the text around it
  ;; and leaves it alone, which is why the icons appeared to stop
  ;; shrinking partway.  The buffers that draw icons have to be asked to
  ;; build theirs again.
  ;;
  ;; `after-setting-font-hook' is the global signal:
  ;; `default-text-scale-increment' runs it explicitly for exactly this
  ;; reason (see modules/ui/default-text-scale.el).  `text-scale-mode-hook'
  ;; is the buffer-local one.
  (defun zetta-icons-redraw ()
    "Rebuild the icons in every buffer that draws them, at the new size.
Only the buffers wearing IMAGE icons need this.  Treemacs is not among
them: it is built out of nerd-icons glyphs (see modules/ui/treemacs.el),
and text resizes itself."
    (dolist (buffer (buffer-list))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          ;; `bound-and-true-p': all-the-icons-dired is a separate package
          ;; and may not have loaded at all
          (when (bound-and-true-p all-the-icons-dired-mode)
            ;; the icons are put on by the fontify function, so a flush is
            ;; enough -- jit-lock rebuilds them on the next redisplay
            (font-lock-flush))))))

  (add-hook 'after-setting-font-hook #'zetta-icons-redraw)
  (add-hook 'text-scale-mode-hook #'zetta-icons-redraw)

  ;;; ----------------------------------------------------------------
  ;;; Icon colours
  ;;; ----------------------------------------------------------------
  ;; The icons in this fork are SVG IMAGES, and the icon SVGs carry no
  ;; `fill' at all -- so every path took the SVG default, black, and on a
  ;; dark theme the whole set was black on near-black.  The `:face' the
  ;; package puts on the icon string could not help: an image is not
  ;; text, and a face foreground does not reach one.
  ;;
  ;; Emacs wraps every SVG it renders in an outer <svg style="color: ...">
  ;; taken from the face the image is displayed with (`svg_load_image',
  ;; src/image.c), so `currentColor' inside an icon resolves to that
  ;; face's foreground.  Setting the root fill to the WORD `currentColor'
  ;; rather than to a colour is what keeps the icons live: the icon
  ;; strings are memoized (`all-the-icons-cache'), so a colour baked into
  ;; the SVG would outlive a theme switch inside that cache, where
  ;; `currentColor' is re-resolved from the face on every render.
  (require 'dom)                        ;`dom-set-attribute', below
  (defun zetta-all-the-icons--currentcolor (args)
    "Advice: let the icon SVG in ARGS take the colour of its display face."
    (when (car args)
      (dom-set-attribute (car args) 'fill "currentColor"))
    args)
  (advice-add 'all-the-icons--normalize-svg-doc :filter-args
              #'zetta-all-the-icons--currentcolor)

  ;; With that, the ~75 colour faces the two icon packages ship are what
  ;; the icons actually wear -- and those are fixed hexes (a Base16
  ;; palette in all-the-icons' case) chosen against no theme in
  ;; particular.  `zetta-icon-color' remaps each to the nearest hue among
  ;; the theme's own strongest colours; see the Icon palette commentary
  ;; in modules/core/line-utils.el for why icons keep their variety where
  ;; the rest of this config drops hue.
  (defvar zetta-icon-color-names
    '("red" "green" "yellow" "blue" "maroon" "purple" "orange" "cyan"
      "pink" "grey" "gray" "silver")
    "The colour words the icon packages name their faces after.
Both vocabularies spell a shade as an optional `l' or `d' in front of one
of these (`all-the-icons-lblue', `nerd-icons-dsilver'), and nerd-icons
adds an `-alt' suffix for a second take on a few of them.")

  (defun zetta-icon--variant (face)
    "Which shade of its colour FACE names: `light', `dark' or `medium'.
Nil when FACE is not one of the icon colour-vocabulary faces at all --
which is how the likes of `all-the-icons-dired-dir-face' and the ibuffer
faces are left alone, along with the `auto-' faces, which inherit their
colour from a sibling and so follow it without being touched."
    (let* ((n (symbol-name face))
           (base (cond ((string-prefix-p "all-the-icons-" n) (substring n 14))
                       ((string-prefix-p "nerd-icons-" n) (substring n 11))))
           (base (and base (replace-regexp-in-string "-alt\\'" "" base))))
      (when base
        (cond ((member base zetta-icon-color-names) 'medium)
              ((and (> (length base) 1)
                    (member (substring base 1) zetta-icon-color-names))
               (pcase (aref base 0) (?l 'light) (?d 'dark)))))))

  (defun zetta-icons-refresh-colors ()
    "Re-tint both icon colour vocabularies from the current theme.

The stock colour is read from each face's own `face-defface-spec' rather
than from the face as it currently stands.  Two reasons: a theme may have
flattened the whole vocabulary already (doric-water paints every icon
face one muted lilac), and this function would otherwise be remapping its
own output on the second run and drifting a little further each time.

A monochrome theme yields no palette to borrow -- `zetta-icon-color'
returns nil -- and the icons fall back to the ink ladder, where the
vocabulary's light and dark shades at least stay a rung apart."
    (when (fboundp 'zetta-icon-color)
      (dolist (face (face-list))
        (when-let* ((variant (zetta-icon--variant face))
                    (stock (plist-get (face-spec-choose
                                       (get face 'face-defface-spec))
                                      :foreground)))
          (set-face-attribute
           face nil
           :foreground
           (or (zetta-icon-color stock (and (memq variant '(light dark)) variant))
               (pcase variant
                 ('light (bound-and-true-p brushup-fg-1))
                 ('dark  (bound-and-true-p brushup-fg-4))
                 (_      (bound-and-true-p brushup-fg-2)))
               stock))))))

  ;; APPENDED for the same reason as the org-remark pens: `brushup-init'
  ;; sits near the end of `brushup-styles', and the ink-ladder fallback
  ;; above reads the gradient it recomputes.
  (add-to-list 'brushup-styles '(zetta-icons-refresh-colors) t)
  (zetta-icons-refresh-colors)
  ;; nerd-icons is pulled in as a dependency and may well load after this
  ;; module; its faces do not exist yet on the run above.
  (with-eval-after-load 'nerd-icons (zetta-icons-refresh-colors))
  )
;;; all-the-icons.el ends here
