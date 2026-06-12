;;; tab-line-svg.el --- Wrapping SVG tab line (svg-line config) -*- lexical-binding: t; -*-

;; The complete tab-line module.  It owns BOTH the tab-line system (the
;; `use-package tab-line' block below: global-tab-line-mode, the buffer
;; selector + scopes, close commands, g1-g9 / C-tab keybindings, faces,
;; built-in tab labels) AND the SVG renderer that draws the per-window
;; tab line as a single SVG image using the `wrap' layout (tabs flow
;; left-to-right and WRAP overflow onto new rows instead of truncating or
;; scrolling).  The rendering itself lives in the `svg-line' engine.
;;
;; Tab data comes from `tab-line-tabs-function'.  Labels are "N name",
;; where N is the 1-based index matching the g1..g9 jump keys.  The
;; current tab is drawn bold, in `current-foreground', over a
;; `current-background' box.  A buffer with unsaved changes is drawn in
;; `modified-foreground' with a trailing marker, and the whole tab line
;; dims to an inactive palette when its window is not selected (the same
;; active/inactive distinction the SVG mode line makes).
;;
;; Switch at runtime:
;;   M-x zetta-tab-line-use-svg       ; activate the wrapping SVG tab line
;;   M-x zetta-tab-line-use-default   ; restore the built-in tab line
;;   M-x zetta-tab-line-toggle        ; flip
;;
;; CAVEATS: single-font SVG text (the all-the-icons file icon is dropped;
;; the number prefix carries the useful info), and KEYBOARD interaction
;; only (as one image there are no per-tab mouse click / close targets).

(require 'svg-line)

;;; ==================================================================
;;; Tab-line SYSTEM (merged from the former tab-line.el): enables
;;; global-tab-line-mode, the buffer selector + scopes, close commands,
;;; g1-g9 / C-tab keybindings, faces, and the built-in tab labels.  The
;;; SVG renderer further below overrides only the rendering.
;;; ==================================================================
(use-package tab-line
  :ensure nil
  :hook (elpaca-after-init . global-tab-line-mode)

  :config

  (setq tab-line-switch-cycling t tab-line-close-button-show t)
  (setq tab-line-exclude-modes '(minibuffer-mode minibuffer-inactive-mode))

  (defun tab-line-close-tab-1 ()
    "Close the selected tab.
If the tab is presented in another window, close the tab by using the `bury-buffer` function.
If the tab is unique to all existing windows, kill the buffer with the `kill-buffer` function.
Lastly, if no tabs are left in the window, it is deleted with the `delete-window` function."
    (interactive)
    (let* ((window (selected-window))
           (buffer (current-buffer)))
      (with-selected-window window
        (let ((tab-list (tab-line-tabs-window-buffers))
              (buffer-list (flatten-list
                            (seq-reduce (lambda (list window)
                                          (select-window window t)
                                          (cons (tab-line-tabs-window-buffers) list))
                                        (window-list) nil))))
          (select-window window)
          (if (> (seq-count (lambda (b) (eq b buffer)) buffer-list) 1)
              (progn
                (if (eq buffer (current-buffer))
                    (bury-buffer)
                  (set-window-prev-buffers window (assq-delete-all buffer (window-prev-buffers)))
                  (set-window-next-buffers window (delq buffer (window-next-buffers))))
                (unless (cdr tab-list)
                  (ignore-errors (delete-window window))))
            (and (kill-buffer buffer)
                 (unless (cdr tab-list)
                   (ignore-errors (delete-window window)))))))
      (force-mode-line-update)))

  (defun ct/circle-number (n)
    "Return a Nerd Font circled-number glyph for tab index N (1-based).
1-9 use `nf-md-numeric_N_circle'; 10 uses `nf-md-numeric_10_circle';
anything higher falls back to `nf-md-numeric_9_plus_circle'.  The glyph is
re-faced to \"Terminess Nerd Font Mono\" (installed) rather than nerd-icons'
default \"Symbols Nerd Font Mono\" (NOT installed here) so it renders in the
plain-text tab line instead of tofu.  Trailing space keeps it off the icon."
    (when (require 'nerd-icons nil t)
      (let ((glyph (cond ((<= 1 n 9)
                          (nerd-icons-mdicon (format "nf-md-numeric_%d_circle" n)))
                         ((= n 10) (nerd-icons-mdicon "nf-md-numeric_10_circle"))
                         (t (nerd-icons-mdicon "nf-md-numeric_9_plus_circle")))))
        (when glyph
          (concat (propertize (substring-no-properties glyph)
                              'face '(:family "Terminess Nerd Font Mono"))
                  " ")))))

  (defun zetta-tab-line-tab-name-buffer (buffer &optional _buffers)
    (let* ((buffer-name (buffer-name buffer))
           (bufnm buffer-name)
           (bufnm (string-replace "helpful function" "H" bufnm))
           (bufnm (string-replace "helpful command" "H" bufnm))
           (bufnm (string-replace "helpful variable" "H" bufnm))
           (bufnm (string-replace "Embark Export" "EE" bufnm))
           (bufnm (string-replace "Embark Collect" "EC" bufnm))
           (bufnm (string-replace "Embark Export Grep" "EE G" bufnm))
           (bufnm (string-replace "Embark Export Occur" "EE O" bufnm))
           (bufnm (string-replace "Embark Export Dired" "EE D" bufnm))
           (fname (buffer-file-name buffer))
           (icon (cond (fname (all-the-icons-icon-for-file fname))
                       (t (all-the-icons-icon-for-mode (with-current-buffer buffer major-mode))))))
      (concat
       (ct/circle-number (+ 1 (cl-position buffer (funcall tab-line-tabs-function))))
       icon
       (propertize (if fname
                       ;; the file name including the suffix
                          (concat (file-name-nondirectory fname))
                       ;;(file-name-base fname)
                     bufnm)
                   'face '(:height 1.0)))))

  (setq tab-line-tab-name-function 'zetta-tab-line-tab-name-buffer)

  (setq tab-line-tabs-function 'tab-line-tabs-window-buffers)

  (add-to-list
   'brushup-styles
   '(progn
      (set-face-attribute 'tab-line-tab-current nil :box nil :inherit nil :background brushup-bg-1_0 :foreground brushup-fg :overline nil :weight 'bold :underline brushup-bg-6 :box nil)
      (set-face-attribute 'tab-line-tab-modified nil :box nil :inherit nil :background brushup-fg-4 :foreground brushup-bg :overline nil)
      ;; NOTE this applies to active tabs in other windows, counter intuitive
      (set-face-attribute 'tab-line-tab nil :box nil :inherit nil :background brushup-bg :foreground brushup-bg-5 :underline brushup-bg-6)
      (set-face-attribute 'tab-line-tab-inactive nil :box nil :inherit nil :background brushup-bg :foreground brushup-bg-5)
      (set-face-attribute 'tab-line nil :box nil :inherit nil :background brushup-bg :foreground brushup-bg-3 :overline nil)
      ))

  :general
  (
   :keymaps 'override
   "C-<tab>" 'tab-line-switch-to-next-tab
   "C-S-<tab>" 'tab-line-switch-to-prev-tab
   )

  ;; NOTE needs to be same as tab-line-tabs-function
  (
   :states '(normal visual)
   :keymaps 'override
   "g1" '(lambda () (interactive) (switch-to-buffer (nth 0 (tab-line-tabs-window-buffers))))
   "g2" '(lambda () (interactive) (switch-to-buffer (nth 1 (tab-line-tabs-window-buffers))))
   "g3" '(lambda () (interactive) (switch-to-buffer (nth 2 (tab-line-tabs-window-buffers))))
   "g4" '(lambda () (interactive) (switch-to-buffer (nth 3 (tab-line-tabs-window-buffers))))
   "g5" '(lambda () (interactive) (switch-to-buffer (nth 4 (tab-line-tabs-window-buffers))))
   "g6" '(lambda () (interactive) (switch-to-buffer (nth 5 (tab-line-tabs-window-buffers))))
   "g7" '(lambda () (interactive) (switch-to-buffer (nth 6 (tab-line-tabs-window-buffers))))
   "g8" '(lambda () (interactive) (switch-to-buffer (nth 7 (tab-line-tabs-window-buffers))))
   "g9" '(lambda () (interactive) (switch-to-buffer (nth 8 (tab-line-tabs-window-buffers))))
   )

  (
   :keymaps 'override
   "s-w" 'tab-line-close-tab-1
   )

  :hook ((fundamental-mode . tab-line-mode))
  )

;;; ------------------------------------------------------------------
;;; Customization
;;; ------------------------------------------------------------------
(defcustom zetta-tab-line-svg-font-size 15
  "Font size (px) for SVG tab-line text." :type 'integer :group 'zetta)
(defcustom zetta-tab-line-svg-line-pad 4
  "Extra vertical padding (px) per wrapped tab-line row." :type 'integer :group 'zetta)
(defcustom zetta-tab-line-svg-char-advance 8
  "Per-character advance (px) used to size tabs and wrap rows.
Match it to the SVG font's real glyph width as Emacs renders it -- 8 for
the bitmap Terminess Nerd Font Mono at 15px (a scalable font would be ~9).
Too high leaves whitespace inside tab boxes; too low overlaps tabs."
  :type 'number :group 'zetta)
(defcustom zetta-tab-line-svg-tab-gap 1.0
  "Gap between tabs, in character widths." :type 'number :group 'zetta)
(defcustom zetta-tab-line-svg-max-name 30
  "Truncate an individual tab name to this many characters (then …)."
  :type 'integer :group 'zetta)
(defcustom zetta-tab-line-svg-center t
  "When non-nil, centre the tabs while they all fit on one row.
Once there are enough tabs to wrap onto a second row they revert to the
normal flush-left flow."
  :type 'boolean :group 'zetta)

(defcustom zetta-tab-line-svg-background "#ece4f6"
  "Light purple background for the SVG tab line (selected window).
Distinguishes the tab line from the tab-bar and header-line.  nil = transparent."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

(defcustom zetta-tab-line-svg-current-background "#4b2e83"
  "Dark-purple highlight drawn behind the current (active) tab.  nil = none.
Chosen to sit in the same purple family as the lavender tab-line background
while staying dark enough for the white current-tab label to read."
  :type '(choice (const :tag "None" nil) color) :group 'zetta)

(defcustom zetta-tab-line-svg-current-foreground "#ffffff"
  "Foreground for the current tab's label (light, to read on the dark box)."
  :type 'color :group 'zetta)

(defcustom zetta-tab-line-svg-modified-foreground "#c1641e"
  "Foreground for a tab whose buffer has unsaved changes.
A warm amber that stands out from the neutral tab text without shouting,
echoing the built-in `tab-line-tab-modified' distinction."
  :type 'color :group 'zetta)

(defcustom zetta-tab-line-svg-modified-marker ""
  "Marker appended to a modified tab's label (in addition to the colour).
Empty by default -- the modified colour alone marks unsaved tabs."
  :type 'string :group 'zetta)

;;; Inactive palette -- used when the tab line's window is NOT selected,
;;; the way the mode line dims in unfocused windows.  Each falls back to
;;; its active counterpart when nil.
(defcustom zetta-tab-line-svg-inactive-background "#f5f1fb"
  "SVG tab-line background in NON-selected windows (lighter purple than active)."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

(defcustom zetta-tab-line-svg-inactive-foreground "#aab2bd"
  "Foreground for ordinary tabs in NON-selected windows (dimmed)."
  :type 'color :group 'zetta)

(defcustom zetta-tab-line-svg-inactive-current-background "#b0a3cf"
  "Highlight behind the current tab in NON-selected windows (muted purple)."
  :type '(choice (const :tag "None" nil) color) :group 'zetta)

(defcustom zetta-tab-line-svg-inactive-current-foreground "#ffffff"
  "Current tab's label colour in NON-selected windows."
  :type 'color :group 'zetta)

(defcustom zetta-tab-line-svg-inactive-modified-foreground "#d8a06a"
  "Modified tab's label colour in NON-selected windows (dimmed amber)."
  :type 'color :group 'zetta)

;;; ------------------------------------------------------------------
;;; Content -- a list of (LABEL . STATE) for the `wrap' layout, where
;;; STATE is a plist of `:current' / `:modified' flags.
;;; ------------------------------------------------------------------
(defun zetta-tab-line-svg-tabs ()
  "Return a list of (LABEL . STATE) for the window's tab-line tabs.
LABEL is \"N GLYPH name\" -- the 1-based index (matching g1..g9), a
nerd-font file-type glyph, and the buffer name, with
`zetta-tab-line-svg-modified-marker' appended when the buffer has unsaved
changes.  STATE is a plist: `:current' marks the tab for the buffer shown
in this window; `:modified' marks a file-visiting buffer with changes.
Because the glyph is part of the label text it needs no separate icon."
  (let ((tabs (ignore-errors (funcall tab-line-tabs-function)))
        (cur  (current-buffer)))
    (cl-loop for buf in tabs
             for i from 1
             for real = (if (bufferp buf) buf cur)
             for name = (buffer-name real)
             for currentp = (eq buf cur)
             for modifiedp = (and (buffer-live-p real)
                                  (buffer-modified-p real)
                                  (buffer-file-name real)
                                  t)
             for glyph = (zetta-line-buffer-glyph real)
             for short = (if (> (length name) zetta-tab-line-svg-max-name)
                             (concat (substring name 0 (1- zetta-tab-line-svg-max-name)) "…")
                           name)
             ;; capture the buffer in a fresh binding -- cl-loop reuses one
             ;; binding for `real', so action/menu closures must not close over
             ;; it directly (they would all see the last tab's buffer).
             collect (let ((b real) (nm name))
                       (cons (format "%d %s%s%s"
                                     i
                                     (if glyph (concat glyph " ") "")
                                     short
                                     (if modifiedp zetta-tab-line-svg-modified-marker ""))
                             (list :current currentp :modified modifiedp
                                   :id b
                                   :help (format "buffer: %s" nm)
                                   :action-help "switch to this buffer"
                                   :action (lambda () (interactive)
                                             (when (buffer-live-p b) (switch-to-buffer b)))
                                   :menu
                                   (delq nil
                                         (list (cons "Switch to buffer"
                                                     (lambda () (interactive)
                                                       (when (buffer-live-p b) (switch-to-buffer b))))
                                               (and (buffer-file-name b)
                                                    (cons "Save buffer"
                                                          (lambda () (interactive)
                                                            (when (buffer-live-p b)
                                                              (with-current-buffer b (save-buffer))))))
                                               (cons "Kill buffer"
                                                     (lambda () (interactive)
                                                       (when (buffer-live-p b) (kill-buffer b))))
                                               (cons "Copy buffer name"
                                                     (lambda () (interactive)
                                                       (kill-new (buffer-name b))))))))))))

(svg-line-define 'zetta-tab-line
  :target 'tab-line
  :layout 'wrap
  :width 'window
  :content #'zetta-tab-line-svg-tabs
  ;; dim the whole tab line when its window is not the selected one,
  ;; the same way the SVG mode line distinguishes active/inactive.
  :active #'mode-line-window-selected-p
  :font (lambda () zetta-svg-line-font)
  :font-size (lambda () zetta-tab-line-svg-font-size)
  :line-pad (lambda () zetta-tab-line-svg-line-pad)
  :char-advance (lambda () zetta-tab-line-svg-char-advance)
  :gap (lambda () zetta-tab-line-svg-tab-gap)
  :center (lambda () zetta-tab-line-svg-center)
  :background (lambda () zetta-tab-line-svg-background)
  :foreground (lambda () (or (bound-and-true-p brushup-bg-5)
                             (face-foreground 'shadow nil t) "#888888"))
  :current-foreground (lambda () zetta-tab-line-svg-current-foreground)
  :current-background (lambda () zetta-tab-line-svg-current-background)
  :modified-foreground (lambda () zetta-tab-line-svg-modified-foreground)
  ;; inactive (unfocused-window) palette
  :inactive-background (lambda () zetta-tab-line-svg-inactive-background)
  :inactive-foreground (lambda () zetta-tab-line-svg-inactive-foreground)
  :inactive-current-foreground (lambda () zetta-tab-line-svg-inactive-current-foreground)
  :inactive-current-background (lambda () zetta-tab-line-svg-inactive-current-background)
  :inactive-modified-foreground (lambda () zetta-tab-line-svg-inactive-modified-foreground))

;;; ------------------------------------------------------------------
;;; Switching.  svg-line installs the tab line by advising the
;;; `tab-line-format' FUNCTION (so it catches buffers whose
;;; `tab-line-format' variable is buffer-local), and removes the advice
;;; on deactivate.
;;; ------------------------------------------------------------------
(defun zetta-tab-line-using-svg-p ()
  "Non-nil if the wrapping SVG tab line is currently active."
  (svg-line-active-p 'zetta-tab-line))

;;;###autoload
(defun zetta-tab-line-use-svg ()
  "Switch the tab line to the wrapping SVG renderer."
  (interactive)
  (setq svg-line-hover-highlight t)   ; highlight the tab under the mouse
  (svg-line-activate 'zetta-tab-line)
  (message "tab-line: wrapping SVG renderer active (M-x zetta-tab-line-use-default to revert)"))

;;;###autoload
(defun zetta-tab-line-use-default ()
  "Restore the built-in tab line."
  (interactive)
  (svg-line-deactivate 'zetta-tab-line)
  (message "tab-line: built-in renderer active"))

;;;###autoload
(defun zetta-tab-line-toggle ()
  "Toggle between the SVG and built-in tab line."
  (interactive)
  (if (zetta-tab-line-using-svg-p)
      (zetta-tab-line-use-default)
    (zetta-tab-line-use-svg)))

;;; ------------------------------------------------------------------
;;; Startup default (opt-out).  The tab line is per-window and installs
;;; by advising `tab-line-format', so it is safe to activate from the
;;; startup hook (sets up advice only; no rendering at hook time).
;;; ------------------------------------------------------------------
(defcustom zetta-tab-line-svg-default t
  "When non-nil, activate the wrapping SVG tab line at startup.
Set to nil (and restart) to keep the built-in tab line; either way you
can switch at runtime with `zetta-tab-line-toggle'."
  :type 'boolean :group 'zetta)

(when zetta-tab-line-svg-default
  (add-hook 'emacs-startup-hook #'zetta-tab-line-use-svg))

(provide 'tab-line-svg)
;;; tab-line-svg.el ends here
