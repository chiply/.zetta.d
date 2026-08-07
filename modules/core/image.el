;;; image.el --- Image viewing helpers -*- lexical-binding: t; -*-

;; Shared machinery for popping document images out into an image-mode
;; window (used by the markdown and org modules) and for toggling the
;; fit axis inside any image buffer.

(declare-function image-toggle-display-image "image-mode")
(declare-function image-get-display-property "image-mode")
(defvar image-transform-resize)

(defvar zetta-image-inline-height-fraction 0.33
  "Max height of inline document images, as a fraction of the frame height.")

(defvar zetta-image--remote-cache (make-hash-table :test 'equal)
  "URL -> downloaded temp file, for popping out remote images.")

(defun zetta-image--remote-file (url)
  "Download URL once and return a local cached copy."
  (let ((cached (gethash url zetta-image--remote-cache)))
    (if (and cached (file-exists-p cached))
        cached
      (let ((file (make-temp-file "zetta-image-")))
        (url-copy-file url file t)
        (puthash url file zetta-image--remote-cache)
        file))))

(defun zetta-image-pop-out-file (file &optional fit-width)
  "Display image FILE in another window, fit to the window.
The fit is orientation-aware: the whole image is scaled to be fully
visible whichever way it is oriented.  With FIT-WIDTH non-nil, fit
to the window width instead.  In the image buffer, t toggles
fit-width/fit-height, H / W set them directly, q quits."
  (unless (or (image-supported-file-p file)
              (image-type-from-file-header file))
    (user-error "Not a displayable image (broken link?): %s" file))
  (find-file-other-window file)
  (setq image-transform-resize (if fit-width 'fit-width 'fit-window))
  (image-toggle-display-image))

(defun zetta-image-toggle-fit ()
  "Toggle the displayed image between fit-to-width and fit-to-height.
From any other fit state (e.g. the fit-window default), switch to
whichever axis the image is not already filling: a wide image goes
to fit-height so it can be scrolled, a tall one to fit-width."
  (interactive)
  (setq image-transform-resize
        (pcase image-transform-resize
          ('fit-height 'fit-width)
          ('fit-width 'fit-height)
          (_ (let* ((size (image-size (image-get-display-property) t))
                    (edges (window-inside-pixel-edges))
                    (window-wide-p (> (/ (float (- (nth 2 edges) (nth 0 edges)))
                                         (max 1 (- (nth 3 edges) (nth 1 edges))))
                                      (/ (float (car size)) (max 1 (cdr size))))))
               ;; Window proportionally wider than image: fit-window
               ;; was height-constrained, so the toggle is fit-width.
               (if window-wide-p 'fit-width 'fit-height)))))
  (image-toggle-display-image)
  (message "Fit to %s"
           (if (eq image-transform-resize 'fit-width) "width" "height")))

(defun zetta-image--clean-display ()
  "Drop text-editing chrome in image buffers.
Line numbers render a giant number beside the image, hl-line draws
a stripe straight through it, and any visible cursor paints ON the
image — an hbar's width is the glyph's width, i.e. the whole image."
  (setq-local display-line-numbers nil)
  (setq-local global-hl-line-mode nil)
  (when (fboundp 'global-hl-line-unhighlight) (global-hl-line-unhighlight))
  (setq-local cursor-type nil))
(add-hook 'image-mode-hook #'zetta-image--clean-display)
(add-hook 'doc-view-mode-hook #'zetta-image--clean-display)

;; Evil and meow both re-stamp `cursor-type' on every state refresh,
;; and both reset a nil spec to their state default — all their
;; writes funnel through these two functions, so make them leave
;; image-ish buffers alone and the nil above sticks.
(defun zetta-image--suppress-cursor-stamp (&rest _)
  (derived-mode-p 'image-mode 'doc-view-mode 'pdf-view-mode))
(with-eval-after-load 'evil
  (advice-add 'evil-refresh-cursor :before-until
              #'zetta-image--suppress-cursor-stamp))
(with-eval-after-load 'meow
  (advice-add 'meow--set-cursor-type :before-until
              #'zetta-image--suppress-cursor-stamp))

;; global-display-line-numbers-mode re-enables numbers AFTER mode
;; hooks run (global minor modes fire in after-change-major-mode-hook),
;; so the hook's setq-local alone doesn't stick — exempt these modes
;; at the turn-on function.
(define-advice display-line-numbers--turn-on
    (:before-until () zetta-image-exempt)
  (derived-mode-p 'image-mode 'doc-view-mode 'pdf-view-mode))

(with-eval-after-load 'image-mode
  ;; Emacs state / non-evil.
  (define-key image-mode-map "t" #'zetta-image-toggle-fit)
  ;; Evil normal state (shadows evil-find-char-to, useless here).
  (with-eval-after-load 'evil
    (general-define-key
     :states 'normal
     :keymaps 'image-mode-map
     "t" #'zetta-image-toggle-fit)))
;;; image.el ends here
