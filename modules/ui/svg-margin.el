;;; svg-margin.el --- svg-margin gutter configuration -*- lexical-binding: t; -*-

;; Loads the in-tree `svg-margin' package (source/zettapkg/svg-margin) and
;; wires up MY providers in the window margins instead of the fringe: VC
;; (via git-gutter), flycheck, TODO/FIXME, bookmarks, evil marks, an Org
;; heading rail, long-line and trailing-whitespace hygiene, and live
;; symbol-at-point occurrences.
;;
;; This is the config-level analogue of the package's examples/ gallery --
;; the gallery stays in zettapkg as published reference; this file is my own
;; setup, so it survives a restart.  Providers read the source packages'
;; data and guard on their availability at runtime, so this loads cleanly
;; even before evil/git-gutter/flycheck/bookmark are loaded; the activation
;; (disabling the fringe drawers it replaces, enabling the mode) runs from
;; `emacs-startup-hook', and refresh triggers are deferred per package.

(use-package svg-margin
  :ensure nil
  :load-path "source/zettapkg/svg-margin")

(require 'svg-margin)
(require 'svg)
(require 'cl-lib)

;; External symbols (declared so this byte-compiles without those packages).
(defvar evil-markers-alist)
(defvar git-gutter:diffinfos)
(defvar bookmark-alist)
(defvar flycheck-current-errors)
(declare-function git-gutter-hunk-start-line "git-gutter")
(declare-function git-gutter-hunk-end-line "git-gutter")
(declare-function git-gutter-hunk-type "git-gutter")
(declare-function global-git-gutter-mode "git-gutter")
(declare-function global-evil-fringe-mark-mode "evil-fringe-mark")
(declare-function bookmark-get-filename "bookmark")
(declare-function bookmark-get-position "bookmark")
(declare-function bookmark-jump "bookmark")
(declare-function flycheck-error-line "flycheck")
(declare-function flycheck-error-level "flycheck")
(declare-function flycheck-error-message "flycheck")

(defcustom zetta-svg-margin-long-line-column 80
  "Column past which `zetta-svg-margin-long-lines' flags a line."
  :type 'integer :group 'zetta)

;; A bookmark-ribbon shape (the package ships only geometric primitives).
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

;;;; Providers
;; ----------------------------------------------------------------
;; Each returns a list of indicator plists; :side and :priority are set at
;; registration (below), so the providers only describe what/where to draw.

(defun zetta-svg-margin-todo (buffer)
  "Dots for TODO/FIXME/HACK keywords in BUFFER."
  (with-current-buffer buffer
    (let (out)
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "\\_<\\(TODO\\|FIXME\\|HACK\\)\\_>" nil t)
          (push (list :pos (match-beginning 0) :shape 'dot
                      :color (pcase (match-string 1)
                               ("TODO" "#d29922") ("FIXME" "#f85149") (_ "#a371f7"))
                      :help (match-string 1))
                out)))
      out)))

(defun zetta-svg-margin-git-gutter (buffer)
  "VC bars/triangles for git-gutter hunks in BUFFER (git-gutter does not draw)."
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
                        (push (list :line ln :shape 'bar
                                    :color (if (eq type 'added) "#3fb950" "#d29922")
                                    :help (symbol-name type))
                              out)))
              ('deleted
               (push (list :line start :shape 'triangle :color "#f85149" :help "deleted")
                     out)))))
        out))))

(defun zetta-svg-margin-bookmarks (buffer)
  "Ribbons for bookmarks pointing into BUFFER's file."
  (with-current-buffer buffer
    (when (and buffer-file-name (bound-and-true-p bookmark-alist))
      (let ((file (file-truename buffer-file-name)) out)
        (dolist (bm bookmark-alist)
          (let ((bmfile (ignore-errors (bookmark-get-filename bm)))
                (pos (ignore-errors (bookmark-get-position bm))))
            (when (and bmfile pos (string= (file-truename bmfile) file))
              (let ((name (car bm)))
                (push (list :pos pos :shape 'bookmark :color "#7d5bed"
                            :help (format "bookmark: %s (click to jump)" name)
                            :action (lambda () (interactive) (bookmark-jump name)))
                      out)))))
        out))))

(defun zetta-svg-margin-evil-marks (buffer)
  "Letter glyphs for buffer-local evil marks a-z in BUFFER."
  (with-current-buffer buffer
    (when (boundp 'evil-markers-alist)
      (let (out)
        (dolist (cell evil-markers-alist)
          (let ((char (car cell)) (val (cdr cell)))
            (when (and (markerp val) (eq (marker-buffer val) buffer)
                       (>= char ?a) (<= char ?z))
              (push (list :pos (marker-position val) :text (char-to-string char)
                          :face 'warning :help (format "evil mark `%c'" char))
                    out))))
        out))))

(defun zetta-svg-margin-flycheck (buffer)
  "Severity dots for flycheck diagnostics in BUFFER."
  (with-current-buffer buffer
    (when (bound-and-true-p flycheck-mode)
      (let (out)
        (dolist (err flycheck-current-errors)
          (let ((line (flycheck-error-line err))
                (level (flycheck-error-level err)))
            (when line
              (push (list :line line :shape 'dot
                          :color (pcase level
                                   ('error "#f85149") ('warning "#d29922") (_ "#3fb950"))
                          :help (ignore-errors (flycheck-error-message err)))
                    out))))
        out))))

(defun zetta-svg-margin-long-lines (buffer)
  "Bars for over-long lines in prog-mode BUFFER."
  (with-current-buffer buffer
    (when (derived-mode-p 'prog-mode)
      (let ((col zetta-svg-margin-long-line-column) out)
        (save-excursion
          (goto-char (point-min))
          (while (not (eobp))
            (end-of-line)
            (when (> (current-column) col)
              (push (list :pos (line-beginning-position) :shape 'bar :color "#b08800"
                          :help (format "line exceeds %d columns" col))
                    out))
            (forward-line 1)))
        out))))

(defun zetta-svg-margin-trailing-ws (buffer)
  "Marks for lines with trailing whitespace in BUFFER."
  (with-current-buffer buffer
    (let (out)
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "[ \t]+$" nil t)
          (push (list :pos (line-beginning-position) :shape 'dot :color "#8b949e"
                      :help "trailing whitespace")
                out)
          (forward-line 1)))
      out)))

(defun zetta-svg-margin-org-headings (buffer)
  "A left rail bar per Org heading, sized and coloured by depth."
  (with-current-buffer buffer
    (when (derived-mode-p 'org-mode)
      (let (out)
        (save-excursion
          (goto-char (point-min))
          (while (re-search-forward "^\\(\\*+\\) " nil t)
            (let* ((level (length (match-string 1)))
                   (face (intern (format "org-level-%d" (1+ (mod (1- level) 8)))))
                   (color (or (face-foreground face nil 'default) "#888888")))
              (push (list :pos (line-beginning-position) :color color
                          :help (format "heading level %d" level)
                          :draw (lambda (svg x y w h c)
                                  (let* ((frac (/ (max 1 (- 7 level)) 6.0))
                                         (bh (max 3 (round (* h frac))))
                                         (yy (+ y (/ (- h bh) 2))))
                                    (svg-rectangle svg x yy (max 2 (round (* w 0.4))) bh
                                                   :rx 1 :fill c))))
                    out))))
        out))))

(defvar zetta-svg-margin--last-symbol nil
  "Last symbol at point, to refresh only when it changes.")

(defun zetta-svg-margin-symbol (buffer)
  "Dots on lines where the symbol at point also appears in BUFFER."
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
                  (push (list :pos bol :shape 'dot :color "#58a6ff"
                              :help (format "occurrence of `%s'" sym))
                        out)))))
          out)))))

;;;; Refresh triggers
;; ----------------------------------------------------------------

(defun zetta-svg-margin--refresh (&rest _)
  "Refresh the current buffer's svg-margin."
  (svg-margin-refresh))

(defun zetta-svg-margin--refresh-all (&rest _)
  "Refresh every svg-margin buffer."
  (svg-margin-refresh-all))

(defvar-local zetta-svg-margin--gg-last 'none
  "Last git-gutter diffinfos svg-margin rendered, to break a refresh loop.")

(defun zetta-svg-margin--gg-feed (&rest _)
  "Override of `git-gutter:view-diff-infos': refresh svg-margin, draw nothing.
Refresh only when the hunks actually changed.  svg-margin's render changes the
margin, which fires `window-configuration-change-hook', which makes git-gutter
recompute and call this again -- so an unconditional refresh would loop.  When
the recompute yields the same hunks we skip, breaking the cycle."
  (unless (equal git-gutter:diffinfos zetta-svg-margin--gg-last)
    (setq zetta-svg-margin--gg-last git-gutter:diffinfos)
    (svg-margin-refresh)))

(defun zetta-svg-margin--symbol-watch ()
  "Refresh when the symbol at point changes (for `post-command-hook')."
  (let ((sym (and (derived-mode-p 'prog-mode)
                  (ignore-errors (thing-at-point 'symbol t)))))
    (unless (equal sym zetta-svg-margin--last-symbol)
      (setq zetta-svg-margin--last-symbol sym)
      (svg-margin-refresh))))

;;;; Configuration + registration
;; ----------------------------------------------------------------

;; Reclaim only the left fringe (evil-fringe-mark's old home); the right
;; fringe stays for yascroll.  Margins are independent of fringes, so the
;; right-margin providers below still show.
(setq svg-margin-disable-fringe 'left)

;; Reserve a baseline margin width so buffer text doesn't shift as indicators
;; come and go (the margin still grows past this when a line needs more).
(setq svg-margin-min-left-columns 4
      svg-margin-min-right-columns 2)

;; Provider -> (side . priority).  Side/priority set here, not in the
;; providers, so moving one between margins is a one-line edit.
(svg-margin-register-provider 'git-gutter   #'zetta-svg-margin-git-gutter   :side 'left  :priority 9)
(svg-margin-register-provider 'flycheck     #'zetta-svg-margin-flycheck     :side 'left  :priority 8)
(svg-margin-register-provider 'todo         #'zetta-svg-margin-todo         :side 'right :priority 7)
(svg-margin-register-provider 'bookmarks    #'zetta-svg-margin-bookmarks    :side 'right :priority 6)
(svg-margin-register-provider 'evil-marks   #'zetta-svg-margin-evil-marks   :side 'left  :priority 5)
(svg-margin-register-provider 'org-headings #'zetta-svg-margin-org-headings :side 'left  :priority 4)
(svg-margin-register-provider 'long-lines   #'zetta-svg-margin-long-lines   :side 'right :priority 3)
(svg-margin-register-provider 'symbol       #'zetta-svg-margin-symbol       :side 'left  :priority 2)
(svg-margin-register-provider 'trailing-ws  #'zetta-svg-margin-trailing-ws  :side 'right :priority 1)

;; Refresh triggers, deferred until each source package loads.
(with-eval-after-load 'evil
  (advice-add 'evil-set-marker :after #'zetta-svg-margin--refresh))
(with-eval-after-load 'bookmark
  (advice-add 'bookmark-set :after #'zetta-svg-margin--refresh-all)
  (advice-add 'bookmark-delete :after #'zetta-svg-margin--refresh-all))
(with-eval-after-load 'flycheck
  (add-hook 'flycheck-after-syntax-check-hook #'zetta-svg-margin--refresh))
(add-hook 'post-command-hook #'zetta-svg-margin--symbol-watch)

;;;; Activation
;; ----------------------------------------------------------------
;; Runs after init, when the packages svg-margin replaces are loaded: turn
;; off their fringe drawing, then enable the gutter everywhere.

(defun zetta-svg-margin-activate ()
  "Disable the fringe drawers svg-margin replaces and enable the gutter."
  ;; evil marks now come from the margin provider, not the fringe.
  (when (fboundp 'global-evil-fringe-mark-mode)
    (global-evil-fringe-mark-mode -1))
  ;; Let git-gutter keep computing hunks, but stop it drawing (svg-margin draws).
  (when (and (fboundp 'git-gutter:view-diff-infos)
             (not (advice-member-p #'zetta-svg-margin--gg-feed 'git-gutter:view-diff-infos)))
    (advice-add 'git-gutter:view-diff-infos :override #'zetta-svg-margin--gg-feed))
  (global-svg-margin-mode 1)
  (svg-margin-refresh-all))

(if after-init-time
    (zetta-svg-margin-activate)             ; loaded interactively, init already done
  (add-hook 'emacs-startup-hook #'zetta-svg-margin-activate))

;;; svg-margin.el ends here
