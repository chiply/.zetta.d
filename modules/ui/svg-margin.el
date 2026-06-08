;;; svg-margin.el --- svg-margin gutter configuration -*- lexical-binding: t; -*-

;; Loads the `svg-margin' package (https://github.com/chiply/svg-margin)
;; and wires up MY providers in the window margins instead of the fringe:
;; VC (via git-gutter), flycheck, TODO/FIXME, bookmarks, evil marks, an Org
;; heading rail, long-line and trailing-whitespace hygiene, and live
;; symbol-at-point occurrences.
;;
;; This is the config-level analogue of the provider examples in the
;; package's README; this file is my own setup, so it survives a restart.
;; Providers read the source packages' data and guard on their availability
;; at runtime, so this loads cleanly even before evil/git-gutter/flycheck/
;; bookmark are loaded; the activation (disabling the fringe drawers it
;; replaces, enabling the mode) runs from `emacs-startup-hook', and refresh
;; triggers are deferred per package.  `:wait t' makes elpaca finish
;; installing svg-margin before the `(require 'svg-margin)' below runs.

(use-package svg-margin
  :ensure (:host github :repo "chiply/svg-margin" :wait t))

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
(declare-function bookmark-rename "bookmark")
(declare-function bookmark-delete "bookmark")
(declare-function evil-goto-mark "evil-commands")
(declare-function evil-delete-marks "evil-commands")
(declare-function git-gutter:next-hunk "git-gutter")
(declare-function git-gutter:previous-hunk "git-gutter")
(declare-function git-gutter:stage-hunk "git-gutter")
(declare-function git-gutter:revert-hunk "git-gutter")
(declare-function git-gutter:popup-hunk "git-gutter")
(declare-function flycheck-next-error "flycheck")
(declare-function flycheck-previous-error "flycheck")
(declare-function flycheck-list-errors "flycheck")
(declare-function flycheck-explain-error-at-point "flycheck")
(declare-function flycheck-display-error-at-point "flycheck")
(declare-function org-cycle "org")
(declare-function org-narrow-to-subtree "org")

(defun zetta-svg-margin--goto-line (n)
  "Move point to the start of line N (absolute) in the current buffer."
  (goto-char (point-min))
  (forward-line (1- n)))

(defun zetta-svg-margin--gg-action (line cmd)
  "Return a command that moves to LINE then runs git-gutter CMD on that hunk."
  (lambda () (interactive) (zetta-svg-margin--goto-line line) (call-interactively cmd)))

(defun zetta-svg-margin--gg-menu (line)
  "Return a context-menu alist for the git-gutter hunk at LINE."
  (list (cons "Show hunk diff" (zetta-svg-margin--gg-action line #'git-gutter:popup-hunk))
        (cons "Stage hunk"     (zetta-svg-margin--gg-action line #'git-gutter:stage-hunk))
        (cons "Revert hunk"    (zetta-svg-margin--gg-action line #'git-gutter:revert-hunk))
        (cons "Next hunk"      #'git-gutter:next-hunk)
        (cons "Previous hunk"  #'git-gutter:previous-hunk)))
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

(defvar zetta-svg-margin-icon-font
  (or (and (boundp 'zetta-svg-line-font) zetta-svg-line-font)
      "Symbols Nerd Font Mono")
  "Font family used to draw Nerd-Font icon glyphs in the margin.")

(defun zetta-svg-margin--glyph (name &optional collection)
  "Return the Nerd-Font glyph NAME (via COLLECTION fn, default mdicon), or nil."
  (and (featurep 'nerd-icons)
       (let ((g (ignore-errors (funcall (or collection #'nerd-icons-mdicon) name))))
         (and (stringp g) (> (length (string-trim g)) 0) (substring-no-properties g)))))

(defun zetta-svg-margin-todo (buffer)
  "Keyword icons for TODO/FIXME/HACK in BUFFER (checkbox / wrench / note)."
  (with-current-buffer buffer
    (let (out)
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "\\_<\\(TODO\\|FIXME\\|HACK\\)\\_>" nil t)
          (let ((p (match-beginning 0)) (kw (match-string 1)))
            (push (list :pos p :font zetta-svg-margin-icon-font :scale 1.1
                        :text (zetta-svg-margin--glyph
                               (pcase kw
                                 ("TODO" "nf-md-checkbox_blank_outline")
                                 ("FIXME" "nf-md-wrench")
                                 (_ "nf-md-note_outline")))
                        :color (pcase kw
                                 ("TODO" "#c7ab74") ("FIXME" "#cf9999") (_ "#a698c9"))
                        :help kw
                        :action-help "go to keyword"
                        :action (lambda () (interactive) (goto-char p))
                        :menu (list (cons "Go to keyword"
                                          (lambda () (interactive) (goto-char p)))
                                    (cons "List TODO/FIXME/HACK"
                                          (lambda () (interactive)
                                            (occur "\\_<\\(TODO\\|FIXME\\|HACK\\)\\_>")))))
                  out))))
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
                        (let ((l ln) (ty type))
                          (push (list :line l :shape 'bar
                                      :color (if (eq ty 'added) "#8fb39a" "#c7ab74")
                                      :help (format "git: %s hunk" ty)
                                      :action-help "show hunk diff"
                                      :action (zetta-svg-margin--gg-action l #'git-gutter:popup-hunk)
                                      :menu (zetta-svg-margin--gg-menu l))
                                out))))
              ('deleted
               (let ((l start))
                 (push (list :line l :shape 'triangle :color "#cf9999"
                             :help "git: deleted hunk"
                             :action-help "show hunk diff"
                             :action (zetta-svg-margin--gg-action l #'git-gutter:popup-hunk)

                             :menu (zetta-svg-margin--gg-menu l))
                       out))))))
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
                (push (list :pos pos :color "#9f90c7"
                            :font zetta-svg-margin-icon-font :scale 1.1
                            :text (zetta-svg-margin--glyph "nf-md-bookmark")
                            :help (format "bookmark: %s" name)
                            :action-help "jump to bookmark"
                            :action (lambda () (interactive) (bookmark-jump name))
                            :menu (list (cons "Jump to bookmark"
                                              (lambda () (interactive) (bookmark-jump name)))
                                        (cons "Rename bookmark…"
                                              (lambda () (interactive) (bookmark-rename name)))
                                        (cons "Delete bookmark"
                                              (lambda () (interactive) (bookmark-delete name)))))
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
                          :color "#a698c9"
                          :help (format "evil mark `%c'" char)
                          :action-help (format "jump to mark `%c'" char)
                          :action (lambda () (interactive) (evil-goto-mark char))
                          :menu (list (cons (format "Jump to mark `%c'" char)
                                            (lambda () (interactive) (evil-goto-mark char)))
                                      (cons (format "Delete mark `%c'" char)
                                            (lambda () (interactive)
                                              (evil-delete-marks (char-to-string char))))))
                    out))))
        out))))

(defun zetta-svg-margin-flycheck (buffer)
  "Severity icons for flycheck diagnostics in BUFFER (bug / alert / info)."
  (with-current-buffer buffer
    (when (bound-and-true-p flycheck-mode)
      (let (out)
        (dolist (err flycheck-current-errors)
          (let ((line (flycheck-error-line err))
                (level (flycheck-error-level err)))
            (when line
              (let ((l line))
                (push (list :line l :font zetta-svg-margin-icon-font :scale 1.1
                            :text (pcase level
                                    ('error (zetta-svg-margin--glyph "nf-cod-bug" #'nerd-icons-codicon))
                                    ('warning (zetta-svg-margin--glyph "nf-md-alert"))
                                    (_ (zetta-svg-margin--glyph "nf-md-information_outline")))
                            :color (pcase level
                                     ('error "#cf9999") ('warning "#c7ab74") (_ "#8fb39a"))
                            :help (ignore-errors (flycheck-error-message err))
                            :action-help "show error"
                            :action (lambda () (interactive)
                                      (zetta-svg-margin--goto-line l)
                                      (flycheck-display-error-at-point))
                            :menu (list (cons "Show error"
                                              (lambda () (interactive)
                                                (zetta-svg-margin--goto-line l)
                                                (flycheck-display-error-at-point)))
                                        (cons "Explain error"
                                              (lambda () (interactive)
                                                (zetta-svg-margin--goto-line l)
                                                (flycheck-explain-error-at-point)))
                                        (cons "List all errors" #'flycheck-list-errors)
                                        (cons "Next error" #'flycheck-next-error)
                                        (cons "Previous error" #'flycheck-previous-error)))
                      out)))))
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
              (let ((bol (line-beginning-position)))
                (push (list :pos bol :color "#bfae7e"
                            :font zetta-svg-margin-icon-font :scale 1.1
                            :text (zetta-svg-margin--glyph "nf-md-ruler")
                            :help (format "line exceeds %d columns" col)
                            :action-help "go to overflow"
                            :action (lambda () (interactive) (goto-char bol) (end-of-line)))
                      out)))
            (forward-line 1)))
        out))))

(defun zetta-svg-margin-trailing-ws (buffer)
  "Marks for lines with trailing whitespace in BUFFER."
  (with-current-buffer buffer
    (let (out)
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "[ \t]+$" nil t)
          (let ((bol (line-beginning-position)))
            (push (list :pos bol :color "#8a909a"
                        :font zetta-svg-margin-icon-font :scale 1.2
                        :text (zetta-svg-margin--glyph "nf-md-format_pilcrow")
                        :help "trailing whitespace"
                        :action-help "go to line"
                        :action (lambda () (interactive) (goto-char bol) (end-of-line))
                        :menu (list (cons "Clear on this line"
                                          (lambda () (interactive)
                                            (goto-char bol)
                                            (when (re-search-forward "[ \t]+$" (line-end-position) t)
                                              (replace-match ""))))
                                    (cons "Clear in whole buffer"
                                          #'delete-trailing-whitespace)))
                  out))
          (forward-line 1)))
      out)))

(defun zetta-svg-margin-org-headings (buffer)
  "A numbered-circle level marker per Org heading in the left margin.
This is the org-margin idea delivered through an svg-margin provider: each
heading gets a Nerd-Font numbered circle (level 1-9, cycling) coloured by the
heading's `org-level-N' face, while the stars stay in the buffer."
  (with-current-buffer buffer
    (when (derived-mode-p 'org-mode)
      (let ((font (and (boundp 'zetta-svg-line-font) zetta-svg-line-font))
            out)
        (save-excursion
          (goto-char (point-min))
          (while (re-search-forward "^\\(\\*+\\) " nil t)
            (let* ((level (length (match-string 1)))
                   (n     (1+ (mod (1- level) 9)))   ; numbered circles run 1..9
                   (face  (intern (format "org-level-%d" (1+ (mod (1- level) 8)))))
                   (color (or (face-foreground face nil 'default) "#9aa0a8"))
                   (glyph (and (featurep 'nerd-icons)
                               (ignore-errors
                                 (substring-no-properties
                                  (nerd-icons-mdicon (format "nf-md-numeric_%d_circle" n))))))
                   (p (line-beginning-position)))
              (when (and glyph (> (length (string-trim glyph)) 0))
                (push (list :pos p :text glyph :color color :font font :scale 1.2
                            :help (format "heading level %d" level)
                            :action-help "go to heading"
                            :action (lambda () (interactive) (goto-char p))
                            :menu (list (cons "Go to heading"
                                              (lambda () (interactive) (goto-char p)))
                                        (cons "Toggle fold"
                                              (lambda () (interactive) (goto-char p) (org-cycle)))
                                        (cons "Narrow to subtree"
                                              (lambda () (interactive)
                                                (goto-char p) (org-narrow-to-subtree)))))
                      out)))))
        out))))

(defun zetta-svg-margin-org-blocks (buffer)
  "Margin icons for Org block starts (the block-marker half of org-margin).
Marks `#+begin_src' (babel), `#+begin_quote', `#+begin_example',
`#+begin_export' and `#+begin_verse' lines with a Nerd-Font glyph; src blocks
edit/execute from the menu."
  (with-current-buffer buffer
    (when (derived-mode-p 'org-mode)
      (let ((font (and (boundp 'zetta-svg-line-font) zetta-svg-line-font))
            (case-fold-search t)
            ;; (KIND GLYPH COLOUR)
            (specs '(("src"     "nf-md-code_tags"          "#98accb")
                     ("quote"   "nf-md-format_quote_close" "#aeb4bb")
                     ("example" "nf-md-console"            "#aeb4bb")
                     ("export"  "nf-md-export"             "#aeb4bb")
                     ("verse"   "nf-md-script_text"        "#aeb4bb")))
            out)
        (save-excursion
          (dolist (spec specs)
            (let* ((kind (nth 0 spec))
                   (glyph (and (featurep 'nerd-icons)
                               (ignore-errors
                                 (substring-no-properties (nerd-icons-mdicon (nth 1 spec))))))
                   (color (nth 2 spec))
                   (srcp (string= kind "src"))
                   (re (format "^[ \t]*#\\+begin_%s\\b" kind)))
              (when (and glyph (> (length (string-trim glyph)) 0))
                (goto-char (point-min))
                (while (re-search-forward re nil t)
                  (let ((p (line-beginning-position)))
                    (push (list :pos p :text glyph :color color :font font :scale 1.1
                                :help (format "org %s block" kind)
                                :action-help (if srcp "edit block" "go to block")
                                :action (if srcp
                                            (lambda () (interactive)
                                              (goto-char p)
                                              (when (fboundp 'org-edit-special)
                                                (ignore-errors (org-edit-special))))
                                          (lambda () (interactive) (goto-char p)))
                                :menu (delq nil
                                            (list (cons "Go to block"
                                                        (lambda () (interactive) (goto-char p)))
                                                  (and srcp (fboundp 'org-edit-special)
                                                       (cons "Edit block"
                                                             (lambda () (interactive) (goto-char p) (org-edit-special))))
                                                  (and srcp (fboundp 'org-babel-execute-src-block)
                                                       (cons "Execute block"
                                                             (lambda () (interactive) (goto-char p) (org-babel-execute-src-block))))
                                                  (cons "Toggle fold"
                                                        (lambda () (interactive) (goto-char p) (org-cycle))))))
                          out)))))))
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
                  (let ((p bol) (s sym))
                    (push (list :pos p :color "#98accb"
                                :font zetta-svg-margin-icon-font :scale 1.1
                                :text (zetta-svg-margin--glyph "nf-cod-symbol_namespace"
                                                               #'nerd-icons-codicon)
                                :help (format "occurrence of `%s'" s)
                                :action-help "go to occurrence"
                                :action (lambda () (interactive) (goto-char p))
                                :menu (list (cons "Go to occurrence"
                                                  (lambda () (interactive) (goto-char p)))
                                            (cons (format "Occur `%s'" s)
                                                  (lambda () (interactive)
                                                    (occur (concat "\\_<" (regexp-quote s) "\\_>"))))))
                          out))))))
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
(svg-margin-register-provider 'org-blocks   #'zetta-svg-margin-org-blocks   :side 'left  :priority 4)
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

(defvar zetta-svg-margin--orig-show-help nil
  "The `show-help-function' in effect before svg-margin wrapped it.")

(defun zetta-svg-margin--show-help (help)
  "Track hover for svg-margin and svg-line, then show HELP as before.
Both note-help functions key off their own text property and hover custom, so
calling both is safe; this is the single `show-help-function' both hook into."
  (svg-margin--note-help help)
  (when (fboundp 'svg-line--note-help) (svg-line--note-help help))
  (when (functionp zetta-svg-margin--orig-show-help)
    (funcall zetta-svg-margin--orig-show-help help)))

(defun zetta-svg-margin-activate ()
  "Disable the fringe drawers svg-margin replaces and enable the gutter."
  ;; evil marks now come from the margin provider, not the fringe.
  (when (fboundp 'global-evil-fringe-mark-mode)
    (global-evil-fringe-mark-mode -1))
  ;; Let git-gutter keep computing hunks, but stop it drawing (svg-margin draws).
  (when (and (fboundp 'git-gutter:view-diff-infos)
             (not (advice-member-p #'zetta-svg-margin--gg-feed 'git-gutter:view-diff-infos)))
    (advice-add 'git-gutter:view-diff-infos :override #'zetta-svg-margin--gg-feed))
  ;; Hover background: route help display through `svg-margin--note-help' so the
  ;; hovered indicator gets a drawn background (works because show-help-function
  ;; fires on mouse enter, move AND leave).  Done here (after init) so it sits
  ;; on top of whatever tooltip.el left in `show-help-function'.
  (setq svg-margin-hover-highlight t)
  (unless (eq show-help-function #'zetta-svg-margin--show-help)
    (setq zetta-svg-margin--orig-show-help show-help-function
          show-help-function #'zetta-svg-margin--show-help))
  (global-svg-margin-mode 1)
  (svg-margin-refresh-all))

(if after-init-time
    (zetta-svg-margin-activate)             ; loaded interactively, init already done
  (add-hook 'emacs-startup-hook #'zetta-svg-margin-activate))

;;; svg-margin.el ends here
