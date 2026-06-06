;;; svg-margin-examples.el --- Example svg-margin providers -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; NOT part of the svg-margin package -- example providers showing how to
;; feed the margin gutter from several independent sources, including
;; DIVERTING fringe data (evil marks, VC hunks) into the margin so they can
;; coexist column-by-column on the same line.
;;
;; Try it:  M-M-x load this file, then `M-x svg-margin-example-setup'.
;;
;; A provider is just (BUFFER -> list of indicator plists); see the
;; svg-margin Commentary for the indicator keys.

;;; Code:

(require 'svg-margin)
(require 'cl-lib)

(defvar evil-markers-alist)
(defvar git-gutter:diffinfos)
(defvar bookmark-alist)
(declare-function diff-hl-changes "diff-hl")
(declare-function git-gutter-hunk-start-line "git-gutter")
(declare-function git-gutter-hunk-end-line "git-gutter")
(declare-function git-gutter-hunk-type "git-gutter")
(declare-function global-git-gutter-mode "git-gutter")
(declare-function bookmark-get-filename "bookmark")
(declare-function bookmark-get-position "bookmark")
(defvar flycheck-current-errors)
(declare-function flycheck-error-line "flycheck")
(declare-function flycheck-error-level "flycheck")
(declare-function flycheck-error-message "flycheck")

(defcustom svg-margin-example-sides
  '((git-gutter   . left)
    (vc           . left)
    (evil-marks   . left)
    (flycheck     . left)
    (org-headings . left)
    (todo         . right)
    (bookmarks    . right)
    (long-lines   . right)
    (trailing-ws  . right)
    (symbol       . right))
  "Margin side (`left' or `right') for each example provider.
Providers stamp their indicators with the side looked up here, so moving a
source between margins is pure configuration -- the engine renders each
indicator on its `:side' and reserves both margins as needed."
  :type '(alist :key-type symbol :value-type (choice (const left) (const right)))
  :group 'svg-margin)

(defun svg-margin-example--side (provider)
  "Return the configured margin side for PROVIDER (see `svg-margin-example-sides')."
  (alist-get provider svg-margin-example-sides 'left))

;; A bookmark-ribbon shape, to show `svg-margin-define-shape'.
(svg-margin-define-shape 'bookmark
  (lambda (svg x y w h color)
    (let* ((bw (max 4 (round (* w 0.52))))
           (bx (+ x (/ (- w bw) 2)))
           (top (+ y (round (* h 0.16))))
           (bot (+ y (round (* h 0.84))))
           (notch (+ y (round (* h 0.6)))))
      (svg-polygon svg
                   (list (cons bx top) (cons (+ bx bw) top)
                         (cons (+ bx bw) bot) (cons (+ bx (/ bw 2)) notch)
                         (cons bx bot))
                   :fill color))))

;;;; Provider: TODO/FIXME/HACK keywords -> coloured dots

(defun svg-margin-example-todo (buffer)
  "Return dot indicators for TODO/FIXME/HACK keywords in BUFFER."
  (with-current-buffer buffer
    (let (out)
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "\\_<\\(TODO\\|FIXME\\|HACK\\)\\_>" nil t)
          (push (list :pos (match-beginning 0)
                      :side (svg-margin-example--side 'todo)
                      :shape 'dot
                      :priority 7
                      :color (pcase (match-string 1)
                               ("TODO" "#d29922") ("FIXME" "#f85149") (_ "#a371f7"))
                      :help (match-string 1))
                out)))
      out)))

;;;; Provider: VC hunks (diverted from the diff-hl/git-gutter fringe)

(defun svg-margin-example-vc (buffer)
  "Return vertical-bar indicators for VC hunks in BUFFER via `diff-hl-changes'.
An ALTERNATIVE VC source to `svg-margin-example-git-gutter' -- use one, not
both (both draw at priority 9 and would stack two bars per line).

`diff-hl-changes' returns an alist ((:working . CHANGES) ...) where each
change is (LINE INSERTS DELETES TYPE) and TYPE is `insert', `delete' or
`change'."
  (with-current-buffer buffer
    (when (fboundp 'diff-hl-changes)
      (let ((changes (ignore-errors (alist-get :working (diff-hl-changes))))
            out)
        (dolist (chg changes)
          (cl-destructuring-bind (line inserts _deletes type) chg
            (if (eq type 'delete)
                (push (list :line line :side (svg-margin-example--side 'vc)
                            :shape 'triangle :priority 9
                            :color "#f85149" :help "deleted")
                      out)
              (cl-loop for i from 0 below (max 1 inserts) do
                       (push (list :line (+ line i) :side (svg-margin-example--side 'vc)
                                   :shape 'bar :priority 9
                                   :color (if (eq type 'insert) "#3fb950" "#d29922")
                                   :help (symbol-name type))
                             out)))))
        out))))

;;;; Provider: VC hunks via git-gutter (data-only; git-gutter does not draw)

(defun svg-margin-example-git-gutter (buffer)
  "Return vertical-bar indicators for git-gutter's hunks in BUFFER.
Reads git-gutter's buffer-local `git-gutter:diffinfos'.  Use together with
`svg-margin-example-git-gutter-setup', which keeps git-gutter computing but
stops it drawing (so it does not duel with svg-margin over the margin)."
  (with-current-buffer buffer
    (when (and (bound-and-true-p git-gutter-mode) (boundp 'git-gutter:diffinfos))
      (let (out)
        (dolist (info git-gutter:diffinfos)
          (let* ((start (git-gutter-hunk-start-line info))
                 (end   (or (git-gutter-hunk-end-line info) start))
                 (type  (git-gutter-hunk-type info)))
            (pcase type
              ((or 'added 'modified)
               (cl-loop for ln from start to (min end (+ start 1000)) do
                        (push (list :line ln :side (svg-margin-example--side 'git-gutter)
                                    :shape 'bar :priority 9
                                    :color (if (eq type 'added) "#3fb950" "#d29922")
                                    :help (symbol-name type))
                              out)))
              ('deleted
               (push (list :line start :side (svg-margin-example--side 'git-gutter)
                           :shape 'triangle :priority 9
                           :color "#f85149" :help "deleted")
                     out)))))
        out))))

(defun svg-margin-example--gg-feed (&rest _)
  "Override of `git-gutter:view-diff-infos': refresh svg-margin, draw nothing.
git-gutter still computes `git-gutter:diffinfos'; svg-margin draws from them."
  (svg-margin-refresh))

;;;; Provider: bookmarks (diverted from the bookmark fringe)

(defun svg-margin-example-bookmarks (buffer)
  "Return ribbon indicators for bookmarks pointing into BUFFER's file.
Reads the global `bookmark-alist' and matches by file name."
  (with-current-buffer buffer
    (when (and buffer-file-name (bound-and-true-p bookmark-alist))
      (let ((file (file-truename buffer-file-name)) out)
        (dolist (bm bookmark-alist)
          (let ((bmfile (ignore-errors (bookmark-get-filename bm)))
                (pos (ignore-errors (bookmark-get-position bm))))
            (when (and bmfile pos (string= (file-truename bmfile) file))
              (push (list :pos pos :side (svg-margin-example--side 'bookmarks)
                          :shape 'bookmark :priority 6
                          :color "#7d5bed"
                          :help (format "bookmark: %s" (car bm)))
                    out))))
        out))))

(defun svg-margin-example--bookmark-refresh (&rest _)
  "Refresh svg-margin after a bookmark is set or deleted."
  (svg-margin-refresh-all))

;;;; Provider: evil marks (diverted from the evil-fringe-mark fringe)

(defun svg-margin-example-evil-marks (buffer)
  "Return letter indicators for buffer-local evil marks a-z in BUFFER.
Reads evil's own `evil-markers-alist', so it needs neither evil-fringe-mark
nor any fringe."
  (with-current-buffer buffer
    (when (boundp 'evil-markers-alist)
      (let (out)
        (dolist (cell evil-markers-alist)
          (let ((char (car cell)) (val (cdr cell)))
            (when (and (markerp val)
                       (eq (marker-buffer val) buffer)
                       (>= char ?a) (<= char ?z))
              (push (list :pos (marker-position val)
                          :side (svg-margin-example--side 'evil-marks)
                          :text (char-to-string char)
                          :priority 5
                          :face 'warning
                          :help (format "evil mark `%c'" char))
                    out))))
        out))))

(defun svg-margin-example--mark-refresh (&rest _)
  "Refresh svg-margin after an evil mark changes."
  (svg-margin-refresh))

;;;; Provider: flycheck/flymake-style diagnostics (external integration)

(defun svg-margin-example-flycheck (buffer)
  "Return severity-coloured dots for flycheck diagnostics in BUFFER."
  (with-current-buffer buffer
    (when (bound-and-true-p flycheck-mode)
      (let (out)
        (dolist (err flycheck-current-errors)
          (let ((line (flycheck-error-line err))
                (level (flycheck-error-level err)))
            (when line
              (push (list :line line :side (svg-margin-example--side 'flycheck)
                          :shape 'dot :priority 8
                          :color (pcase level
                                   ('error "#f85149") ('warning "#d29922") (_ "#3fb950"))
                          :help (ignore-errors (flycheck-error-message err)))
                    out))))
        out))))

(defun svg-margin-example--flycheck-refresh (&rest _)
  "Refresh svg-margin after a flycheck check finishes."
  (svg-margin-refresh))

;;;; Provider: long lines (pure buffer scan, no dependency)

(defcustom svg-margin-example-long-line-column 80
  "Column past which `svg-margin-example-long-lines' flags a line."
  :type 'integer :group 'svg-margin)

(defun svg-margin-example-long-lines (buffer)
  "Return bar indicators for over-long lines in prog-mode BUFFER."
  (with-current-buffer buffer
    (when (derived-mode-p 'prog-mode)
      (let ((col svg-margin-example-long-line-column) out)
        (save-excursion
          (goto-char (point-min))
          (while (not (eobp))
            (end-of-line)
            (when (> (current-column) col)
              (push (list :pos (line-beginning-position)
                          :side (svg-margin-example--side 'long-lines)
                          :shape 'bar :priority 3 :color "#b08800"
                          :help (format "line exceeds %d columns" col))
                    out))
            (forward-line 1)))
        out))))

;;;; Provider: trailing whitespace (pure buffer scan)

(defun svg-margin-example-trailing-ws (buffer)
  "Return small marks for lines with trailing whitespace in BUFFER."
  (with-current-buffer buffer
    (let (out)
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "[ \t]+$" nil t)
          (push (list :pos (line-beginning-position)
                      :side (svg-margin-example--side 'trailing-ws)
                      :shape 'dot :priority 1 :color "#8b949e"
                      :help "trailing whitespace")
                out)
          (forward-line 1)))
      out)))

;;;; Provider: org heading rail (mode-specific, variable-geometry :draw)

(defun svg-margin-example-org-headings (buffer)
  "Return a left rail bar per org heading, sized and coloured by depth."
  (with-current-buffer buffer
    (when (derived-mode-p 'org-mode)
      (let (out)
        (save-excursion
          (goto-char (point-min))
          (while (re-search-forward "^\\(\\*+\\) " nil t)
            (let* ((level (length (match-string 1)))
                   (face (intern (format "org-level-%d" (1+ (mod (1- level) 8)))))
                   (color (or (face-foreground face nil 'default) "#888888")))
              (push (list :pos (line-beginning-position)
                          :side (svg-margin-example--side 'org-headings)
                          :priority 4 :color color
                          :help (format "heading level %d" level)
                          ;; deeper headings draw a shorter, centred tick
                          :draw (lambda (svg x y w h c)
                                  (let* ((frac (/ (max 1 (- 7 level)) 6.0))
                                         (bh (max 3 (round (* h frac))))
                                         (yy (+ y (/ (- h bh) 2))))
                                    (svg-rectangle svg x yy (max 2 (round (* w 0.4))) bh
                                                   :rx 1 :fill c))))
                    out))))
        out))))

;;;; Provider: occurrences of the symbol at point (dynamic, point-driven)

(defvar svg-margin-example--last-symbol nil
  "Last symbol at point, to refresh svg-margin only when it changes.")

(defun svg-margin-example-symbol-occurrences (buffer)
  "Return dots on lines where the symbol at point also appears in BUFFER."
  (with-current-buffer buffer
    (let ((sym (and (derived-mode-p 'prog-mode)
                    (ignore-errors (thing-at-point 'symbol t)))))
      (when (and sym (>= (length sym) 3))
        (let ((re (concat "\\_<" (regexp-quote sym) "\\_>"))
              (seen (make-hash-table :test 'eql)) out)
          (save-excursion
            (goto-char (point-min))
            (while (re-search-forward re nil t)
              ;; one indicator per LINE, not per occurrence -- several matches
              ;; on the same line must not each claim a column.
              (let ((bol (line-beginning-position)))
                (unless (gethash bol seen)
                  (puthash bol t seen)
                  (push (list :pos bol
                              :side (svg-margin-example--side 'symbol)
                              :shape 'dot :priority 2 :color "#58a6ff"
                              :help (format "occurrence of `%s'" sym))
                        out)))))
          out)))))

(defun svg-margin-example--symbol-watch ()
  "Refresh svg-margin when the symbol at point changes (for `post-command-hook')."
  (let ((sym (and (derived-mode-p 'prog-mode)
                  (ignore-errors (thing-at-point 'symbol t)))))
    (unless (equal sym svg-margin-example--last-symbol)
      (setq svg-margin-example--last-symbol sym)
      (svg-margin-refresh))))

;;;; Wiring

;;;###autoload
(defun svg-margin-example-setup ()
  "Register the example providers, divert the left fringe, and enable the mode.
Demonstrates several sources stacking columns on one line: a VC bar nearest
the text, a TODO dot, a bookmark ribbon, and an evil-mark letter, all in the
left margin.  For VC it prefers git-gutter and falls back to diff-hl -- never
both, since they would draw two bars per line."
  (interactive)
  (svg-margin-register-provider 'todo #'svg-margin-example-todo)
  (when (boundp 'evil-markers-alist)
    (svg-margin-register-provider 'evil-marks #'svg-margin-example-evil-marks)
    (advice-add 'evil-set-marker :after #'svg-margin-example--mark-refresh))
  (when (fboundp 'bookmark-get-position)
    (svg-margin-example-bookmarks-setup))
  (cond ((fboundp 'global-git-gutter-mode) (svg-margin-example-git-gutter-setup))
        ((fboundp 'diff-hl-changes)
         (svg-margin-register-provider 'vc #'svg-margin-example-vc)))
  ;; Reclaim ONLY the left fringe -- evil-fringe-mark's old home, now migrated
  ;; into the margin.  Disabling a fringe is about migrating that fringe's
  ;; USERS, not about which margin side you draw in: margins are independent of
  ;; fringes, so right-margin indicators show fine while the right fringe stays
  ;; available for yascroll / flycheck / continuation arrows.  Only disable a
  ;; fringe once nothing else needs it.
  (setq svg-margin-disable-fringe 'left)
  (svg-margin-mode 1)
  (message "svg-margin example active: VC + TODO + bookmarks + evil marks in the left margin"))

;;;###autoload
(defun svg-margin-example-git-gutter-setup ()
  "Feed git-gutter's VC hunks into the svg-margin gutter.
Overrides git-gutter's own drawing (so it does not duel with svg-margin
over the margin), registers the git-gutter provider, and enables
`global-git-gutter-mode' for its computation."
  (interactive)
  (advice-add 'git-gutter:view-diff-infos :override #'svg-margin-example--gg-feed)
  (svg-margin-register-provider 'git-gutter #'svg-margin-example-git-gutter)
  (global-git-gutter-mode 1)
  (svg-margin-refresh-all)
  (message "svg-margin: git-gutter hunks now drawn in the margin"))

(defun svg-margin-example-git-gutter-teardown ()
  "Undo `svg-margin-example-git-gutter-setup'."
  (interactive)
  (advice-remove 'git-gutter:view-diff-infos #'svg-margin-example--gg-feed)
  (svg-margin-unregister-provider 'git-gutter))

;;;###autoload
(defun svg-margin-example-bookmarks-setup ()
  "Draw bookmarks in the svg-margin gutter and refresh when they change."
  (interactive)
  (svg-margin-register-provider 'bookmarks #'svg-margin-example-bookmarks)
  (advice-add 'bookmark-set :after #'svg-margin-example--bookmark-refresh)
  (advice-add 'bookmark-delete :after #'svg-margin-example--bookmark-refresh)
  (svg-margin-refresh-all)
  (message "svg-margin: bookmarks now drawn in the margin"))

(defun svg-margin-example-bookmarks-teardown ()
  "Undo `svg-margin-example-bookmarks-setup'."
  (interactive)
  (svg-margin-unregister-provider 'bookmarks)
  (advice-remove 'bookmark-set #'svg-margin-example--bookmark-refresh)
  (advice-remove 'bookmark-delete #'svg-margin-example--bookmark-refresh))

;;;###autoload
(defun svg-margin-example-extras-setup ()
  "Register the extra demo providers: flycheck, long-lines, trailing-ws,
org-headings, and symbol-at-point occurrences.  Showcases more techniques
\(external integration, pure scans, mode-specific variable-geometry drawing,
and dynamic point-driven refresh)."
  (interactive)
  (svg-margin-register-provider 'long-lines #'svg-margin-example-long-lines)
  (svg-margin-register-provider 'trailing-ws #'svg-margin-example-trailing-ws)
  (svg-margin-register-provider 'org-headings #'svg-margin-example-org-headings)
  (svg-margin-register-provider 'symbol #'svg-margin-example-symbol-occurrences)
  (add-hook 'post-command-hook #'svg-margin-example--symbol-watch)
  (when (boundp 'flycheck-current-errors)
    (svg-margin-register-provider 'flycheck #'svg-margin-example-flycheck)
    (add-hook 'flycheck-after-syntax-check-hook #'svg-margin-example--flycheck-refresh))
  (svg-margin-refresh-all)
  (message "svg-margin extras: flycheck, long-lines, trailing-ws, org-headings, symbol"))

(defun svg-margin-example-extras-teardown ()
  "Undo `svg-margin-example-extras-setup'."
  (interactive)
  (dolist (p '(long-lines trailing-ws org-headings symbol flycheck))
    (svg-margin-unregister-provider p))
  (remove-hook 'post-command-hook #'svg-margin-example--symbol-watch)
  (when (boundp 'flycheck-after-syntax-check-hook)
    (remove-hook 'flycheck-after-syntax-check-hook #'svg-margin-example--flycheck-refresh)))

(defun svg-margin-example-teardown ()
  "Undo `svg-margin-example-setup' in the current buffer."
  (interactive)
  (svg-margin-mode -1)
  (svg-margin-unregister-provider 'todo)
  (svg-margin-unregister-provider 'vc)
  (svg-margin-unregister-provider 'evil-marks)
  (advice-remove 'evil-set-marker #'svg-margin-example--mark-refresh)
  (svg-margin-example-bookmarks-teardown)
  (svg-margin-example-git-gutter-teardown)
  (svg-margin-example-extras-teardown))

(provide 'svg-margin-examples)
;;; svg-margin-examples.el ends here
