;;; tab-line.el --- The tab-line system: mode, selector, keys, faces -*- lexical-binding: t; -*-

;; The tab-line SYSTEM, and nothing about how it is drawn: the
;; `use-package tab-line' block below owns `global-tab-line-mode', the
;; buffer selector and scopes, `tab-line-close-tab-1', the g1-g9 / C-tab /
;; s-w keys, the faces (`zetta-tab-line-faces' on `brushup-styles'), the
;; built-in labels (`zetta-tab-line-tab-name-buffer', `ct/circle-number')
;; and the `zetta-tab-line-ensure' sweep.
;;
;; Split out of tab-line-svg.el on 2026-09-11.  That file had been "the
;; complete tab-line module" since commit 184958c merged the two, and the
;; capability predicate in `zetta-module-conditions' skips it wherever the
;; build cannot render SVG -- so a headless box lost the whole system with
;; the renderer: no tab line, no g1-g9, no C-tab.  This half loads on
;; every profile; tab-line-svg.el keeps the wrapping SVG renderer and the
;; switch commands and overrides only the rendering.
;;
;; Load order: this file is listed in `zetta--default-file-order' (ui)
;; so it precedes tab-line-svg.el, which the alphabetical tail would put
;; FIRST ("tab-line-svg.el" sorts before "tab-line.el").

(defcustom zetta-tab-line-name-space-ok t
  "When non-nil, a DISPLAYED buffer gets a tab line even if its name starts
with a space.

That prefix is the convention for buffers the user is not meant to see, and
`tab-line-mode--turn-on' skips them on that basis.  The convention breaks
down for a buffer that is on screen anyway: treemacs names its sidebar
\" *Treemacs-Buffer-#<frame 0x...>\", and the tab line is the one piece of
chrome that would say so.  Consulted only by `zetta-tab-line-ensure', which
runs when a buffer lands in a window, so a hidden buffer stays untouched."
  :type 'boolean :group 'zetta)

;; `ct/circle-number' (defined in the `tab-line' use-package :config below)
;; wraps `zetta-circle-number' (line-utils) -- the shared source of the
;; numbered-circle glyphs also used by svg-margin's org rail.
(declare-function zetta-circle-number "line-utils")

(use-package tab-line
  :ensure nil
  :hook (elpaca-after-init . global-tab-line-mode)

  :config

  (setq tab-line-switch-cycling t tab-line-close-button-show t)
  (setq tab-line-exclude-modes '(minibuffer-mode minibuffer-inactive-mode))

  (defun zetta-tab-line-ensure (&optional _frame)
    "Give newly displayed buffers a tab line when the globalized mode missed them.

`global-tab-line-mode' turns the mode on from `after-change-major-mode-hook',
plus one sweep of `buffer-list' when it is first enabled.  A buffer created
with `get-buffer-create' and left in `fundamental-mode' never SETS a major
mode, so the hook never fires -- and if it was created after startup the
sweep has already run.  That is the shape most process and log buffers take
\(`*copilot-language-server-log*' is the one that turned up here), and they
end up as the odd buffer with no tab line for no visible reason.  The
`fundamental-mode' hook below does not cover it: that fires when
`fundamental-mode' is CALLED, not when a buffer is merely born in it.

Runs from `window-buffer-change-functions', i.e. exactly when a buffer lands
in a window -- the moment you would notice.  Eligibility is left to
`tab-line-mode--turn-on', so the exclusion rules stay in one place, with the
one exception described in `zetta-tab-line-name-space-ok'."
    (when (bound-and-true-p global-tab-line-mode)
      (dolist (w (window-list nil 'no-minibuf))
        (with-current-buffer (window-buffer w)
          (unless (bound-and-true-p tab-line-mode)
            (ignore-errors (tab-line-mode--turn-on))
            ;; `tab-line-mode--turn-on' exempts any buffer whose name begins
            ;; with a space, the convention for buffers the user is not
            ;; supposed to see.  A buffer that is ON SCREEN plainly is not
            ;; one of those, whatever it called itself -- treemacs names its
            ;; sidebar \" *Treemacs-Buffer-#<frame 0x...>\" and so has never
            ;; had a tab line, which is the one place the name is worth
            ;; showing.  Every OTHER exclusion is still honoured; only the
            ;; leading space is overridden.
            (when (and (not (bound-and-true-p tab-line-mode))
                       zetta-tab-line-name-space-ok
                       (string-match-p "\\` " (buffer-name))
                       (not (minibufferp))
                       (not (memq major-mode tab-line-exclude-modes))
                       (not (buffer-match-p tab-line-exclude-buffers (buffer-name)))
                       (not (get major-mode 'tab-line-exclude))
                       (not (buffer-local-value 'tab-line-exclude (current-buffer))))
              (tab-line-mode 1)))))))

  (add-hook 'window-buffer-change-functions #'zetta-tab-line-ensure)

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
    "Circled-number glyph for tab index N (1-based), or nil.
A thin wrapper over `zetta-circle-number' (the shared glyph source).  No
trailing space -- the number sits flush against the file/mode glyph that
follows; callers add their own separator before the buffer name."
    (zetta-circle-number n))

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
           ;; The file/mode icon wants all-the-icons, a keep-out on the
           ;; headless profile (it needs a GUI font); the number prefix
           ;; carries the useful information without it.
           (icon (cond ((not (fboundp 'all-the-icons-icon-for-mode)) nil)
                       (fname (all-the-icons-icon-for-file fname))
                       (t (all-the-icons-icon-for-mode (with-current-buffer buffer major-mode))))))
      (concat
       (ct/circle-number (+ 1 (cl-position buffer (funcall tab-line-tabs-function))))
       (or icon "")
       (propertize (if fname
                       ;; the file name including the suffix
                          (concat (file-name-nondirectory fname))
                       ;;(file-name-base fname)
                     bufnm)
                   'face '(:height 1.0)))))

  (setq tab-line-tab-name-function 'zetta-tab-line-tab-name-buffer)

  (setq tab-line-tabs-function 'tab-line-tabs-window-buffers)

  (defun zetta-tab-line-faces ()
    "Style the built-in tab-line faces and the face the SVG image sits on."
    (set-face-attribute 'tab-line-tab-current nil :box nil :inherit nil :background brushup-bg-1_0 :foreground brushup-fg :overline nil :weight 'bold :underline brushup-bg-6)
    (set-face-attribute 'tab-line-tab-modified nil :box nil :inherit nil :background brushup-fg-4 :foreground brushup-bg :overline nil)
    ;; NOTE this applies to active tabs in other windows, counter intuitive
    (set-face-attribute 'tab-line-tab nil :box nil :inherit nil :background brushup-bg :foreground brushup-bg-5 :underline brushup-bg-6)
    (set-face-attribute 'tab-line-tab-inactive nil :box nil :inherit nil :background brushup-bg :foreground brushup-bg-5)
    ;; The `tab-line' face is what the SVG image sits on: its background is
    ;; what shows through the image's transparent margin, and its OVERLINE is
    ;; a single-sided rule along the top of the tab line -- which, the tab
    ;; line being per-window, is a rule along the top of each WINDOW.
    ;; The overline here is the FALLBACK.  A face attribute is painted
    ;; across the face's whole extent, so on a window-width image it is a
    ;; window-width rule and cannot be inset; svg-line draws an inset one
    ;; itself (`:rule' in tab-line-svg.el) wherever the engine is new
    ;; enough to know the key.  Both would show as two rules, so this one
    ;; stands down when the other is available.  The two knobs it reads
    ;; belong to the SVG half and are unbound where that half is skipped
    ;; (no SVG on the build), which also means no rule: a tty cannot draw
    ;; an overline anyway.
    (set-face-attribute 'tab-line nil :box nil :inherit nil
                        :background brushup-bg :foreground brushup-bg-3
                        :overline (and (bound-and-true-p zetta-tab-line-svg-overline)
                                       (boundp 'zetta-tab-line-svg-overline-strength)
                                       (not (bound-and-true-p svg-line-rule-supported))
                                       (zetta-line-blend brushup-bg brushup-fg
                                                         zetta-tab-line-svg-overline-strength))))

  ;; Appended: `brushup-init' recomputes the palette near the END of
  ;; `brushup-styles', so a prepended entry reads the PREVIOUS theme's
  ;; colours and lands one theme change behind -- the same bug that made the
  ;; window dividers reappear on every theme switch.
  (add-to-list 'brushup-styles '(zetta-tab-line-faces) t)

  ;; tab-line's switching commands wrap their work in
  ;; `with-selected-window', which restores the CURRENT BUFFER on exit --
  ;; but the window's buffer has already changed underneath it.  So the
  ;; command returns with `current-buffer' still the buffer you left while
  ;; the window shows the one you arrived at, and `post-command-hook' then
  ;; runs against the wrong buffer.  Two symptoms, one cause:
  ;;
  ;;   global-hl-line moves its overlay in the buffer you LEFT, so the new
  ;;   one has no highlight until the next command;
  ;;
  ;;   beacon's buffer-change trigger compares against the current buffer,
  ;;   sees nothing changed, and never blinks.
  ;;
  ;; Resync after the command and before the hook.  Upstream's own bug --
  ;; reproduced in `emacs -Q' -- so this rides on the commands rather than
  ;; being worked around in hl-line or beacon, which are only two of the
  ;; things a wrong `current-buffer' can mislead.
  (defun zetta-tab-line--resync-current-buffer (&rest _)
    "Make the selected window's buffer current after a tab-line switch."
    (let ((buf (window-buffer (selected-window))))
      (when (and (buffer-live-p buf) (not (eq buf (current-buffer))))
        (set-buffer buf))))

  (dolist (cmd '(tab-line-switch-to-next-tab
                 tab-line-switch-to-prev-tab
                 tab-line-select-tab
                 tab-line-select-tab-buffer
                 tab-line-close-tab))
    (advice-add cmd :after #'zetta-tab-line--resync-current-buffer))

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

(provide 'zetta-tab-line)
;;; tab-line.el ends here
