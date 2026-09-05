;;; ligature.el --- Operator ligatures and texture healing -*- lexical-binding: t; -*-

;; This build has no HARFBUZZ and never will -- `configure.ac' gates
;; HAVE_HARFBUZZ on X11+FreeType, pgtk, w32, Android or Haiku, and NS is in
;; none of those branches.  That is a real constraint, but it is NOT the
;; reason ligatures were missing, which is what FONTS.org used to claim.
;;
;; The `mac-ct' backend shapes through Core Text, and Core Text applies a
;; font's default `calt'/`liga' features perfectly well.  Measured on this
;; machine with `font-shape-gstring' -- i.e. Emacs's own shaper, not an
;; external harness:
;;
;;   JetBrainsMono NF   "->"   -> 12137 11919   (solo: - 17, > 34)
;;                      "==="  -> 12137 12137 12020
;;   Monaspace Neon NF  "mil"  -> 869 838 491   (solo: m 504, i 464, l 491)
;;
;; Both of those are the feature working.  Note the glyph COUNT is unchanged
;; in each case: these fonts implement ligatures as same-count contextual
;; substitutions -- leading cells become a spacer glyph and the final cell
;; carries a wide glyph with negative bearing.  Counting glyphs to test for
;; ligature support therefore reports a false negative every time; compare
;; glyph CODES against the solo baselines instead.  `zetta-font-shape-report'
;; does that, so this stays checkable rather than becoming folklore again.
;;
;; What was actually missing is the trigger.  Emacs only calls the shaper
;; across a run of characters where `composition-function-table' has a rule,
;; and nothing here installed any.  Hence two halves, same mechanism:
;;
;;   operators  ligature.el installs rules for punctuation sequences.
;;   letters    `zetta-texture-healing-mode' installs rules for letter runs.
;;
;; The letter half is the expensive one -- it composes ordinary prose and
;; identifiers on every redisplay -- so it turns itself on only for fonts
;; that measurably heal, and re-checks on every fontaine preset change.
;;
;; One thing genuinely out of reach: Monaspace keeps its arrow ligatures in
;; stylistic set `ss03' (verified by enumerating ss01-ss09; only ss03 moves
;; "->" off its plain glyphs), and `macfont.m' has no OpenType feature
;; plumbing at all -- no `kCTFontFeatureSettingsAttribute', no `:otf'.  So
;; under Monaspace you get texture healing plus its default-`calt' ligatures
;; ("!=" and friends) but not the arrows.  Fonts that ship ligatures in
;; default `calt' -- JetBrains Mono, Fira Code -- ligate in full.

;;; ------------------------------------------------------------------
;;; Shaping probe
;;; ------------------------------------------------------------------

(defun zetta-ligature--frame (&optional frame)
  "Return FRAME if it can display fonts, else the frame to measure against.

Not simply the first graphical frame: under the daemon that is regularly a
corfu child frame, which is both dedicated and carries a different default
family, so probing it answers for the wrong font entirely.
`zetta-font--measurement-frame' in core/interface.el already picks the
largest real frame for exactly this reason; fall back to an equivalent
filter when core is not loaded."
  (or (and frame (display-graphic-p frame) frame)
      (and (fboundp 'zetta-font--measurement-frame)
           (zetta-font--measurement-frame))
      (car (sort (seq-filter (lambda (f)
                               (and (display-graphic-p f)
                                    (window-live-p (frame-selected-window f))))
                             (frame-list))
                 (lambda (a b) (> (* (frame-width a) (frame-height a))
                                  (* (frame-width b) (frame-height b))))))))

(defun zetta-font-shape-glyphs (string &optional family frame)
  "Return the glyph codes FAMILY shapes STRING into, as a list.

Returns nil when there is no graphical frame, FAMILY is not installed, or
the shaper declines the run.

The gstring is built by hand rather than taken from
`composition-get-gstring' for two reasons.  `font-shape-gstring' returns
early when LGSTRING_ID is already set, so a cached gstring comes back
unshaped and looks like a failure.  And `macfont_shape' reads its
characters out of the GLYPH slots -- LGLYPH_CHAR of each -- not out of the
header, so a gstring with the header filled in and the glyph slots left nil
shapes an empty string and returns nil for everything.  Both mistakes look
exactly like \"this build cannot do ligatures\"."
  (let* ((frame (zetta-ligature--frame frame))
         (family (or family (and frame (face-attribute 'default :family frame))))
         ;; `face-attribute' answers `unspecified' for an unset family, and a
         ;; remapped `default' can hand back a whole attribute plist.  Either
         ;; reaches `font-spec' as "invalid font property" -- from a hook on
         ;; a redisplay path, thousands of times.
         (family (and (stringp family) (not (string-empty-p family)) family))
         (entity (and frame family
                      (ignore-errors (find-font (font-spec :family family) frame))))
         (font (and entity (open-font entity 14 frame))))
    (when font
      (let* ((chars (string-to-list string))
             (n (length chars))
             ;; Room to spare: shaping may want more glyph slots than
             ;; characters, and the C side stops at the first nil slot.
             (gstring (make-vector (+ 2 (* 4 n)) nil))
             shaped)
        (aset gstring 0 (vconcat (vector font) (vconcat chars)))
        (aset gstring 1 nil)
        (dotimes (k n)
          ;; [from to char code width lbearing rbearing ascent descent adjust]
          (aset gstring (+ 2 k)
                (vector k k (nth k chars) nil nil nil nil nil nil nil)))
        (setq shaped (ignore-errors (font-shape-gstring gstring nil)))
        (when shaped
          (let ((k 0) (codes nil))
            (while (and (< k (lgstring-glyph-len shaped))
                        (lgstring-glyph shaped k))
              (push (lglyph-code (lgstring-glyph shaped k)) codes)
              (setq k (1+ k)))
            (nreverse codes)))))))

(defun zetta-font-shape-solo-glyphs (string &optional family frame)
  "Return the glyph codes of STRING's characters shaped one at a time."
  (apply #'append
         (mapcar (lambda (char)
                   (zetta-font-shape-glyphs (string char) family frame))
                 (string-to-list string))))

(defun zetta-font-shapes-p (string &optional family frame)
  "Return non-nil when FAMILY shapes STRING differently than char-by-char.
That difference is the whole test: it means the font substituted glyphs
for context, which is what both ligatures and texture healing are."
  (let ((together (zetta-font-shape-glyphs string family frame))
        (apart (zetta-font-shape-solo-glyphs string family frame)))
    (and together apart (not (equal together apart)))))

(defconst zetta-font-texture-healing-probes '("mil" "milk" "illum")
  "Letter runs used to detect texture healing.

Bare doubles like \"mm\" are not enough -- Monaspace heals on surrounding
context and leaves them alone, so a two-character probe reports no support
for a font that plainly has it.")

(defvar zetta-font--healing-cache (make-hash-table :test 'equal)
  "Family name -> whether it heals.  A font's feature table never changes.")

(defun zetta-font-texture-healing-p (&optional family frame)
  "Return non-nil when FAMILY performs texture healing on letter runs.
Cached per family: this runs on every preset switch and window change."
  (let* ((family (or family
                     (face-attribute 'default :family
                                     (zetta-ligature--frame frame))))
         (cached (if family
                     (gethash family zetta-font--healing-cache 'miss)
                   nil)))
    (if (eq cached 'miss)
        (puthash family
                 (and (seq-some (lambda (probe)
                                  (zetta-font-shapes-p probe family frame))
                                zetta-font-texture-healing-probes)
                      t)
                 zetta-font--healing-cache)
      cached)))

(defun zetta-font-family-at-point (&optional pos)
  "The family actually used to draw the character at POS.
Not `face-attribute' of `default': a buffer carrying its own preset through
`face-remapping-alist' draws in a family the frame knows nothing about."
  (let* ((font (ignore-errors (font-at (or pos (point)))))
         (family (and font (font-get font :family))))
    (if (symbolp family) (and family (symbol-name family)) family)))

;;;###autoload
(defun zetta-font-shape-report (&optional family)
  "Report what FAMILY does to a spread of ligature and healing probes."
  (interactive
   (list (completing-read "Family: " (font-family-list) nil t nil nil
                          (or (zetta-font-family-at-point)
                              (face-attribute 'default :family)))))
  (let ((family (or family
                    (zetta-font-family-at-point)
                    (face-attribute 'default :family))))
    (with-current-buffer (get-buffer-create "*font shape report*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "%s\n%s\n\n" family (make-string (length family) ?=)))
        (insert (format "%-10s %-26s %-26s %s\n" "probe" "shaped" "solo" ""))
        ;; Monaspace's default-calt set is narrow -- "||" "!=" "://" "..."
        ;; "//" ";;" and friends -- so probe those alongside the arrows it
        ;; keeps in ss03, or the report looks like nothing works.
        (dolist (probe '("->" "=>" "===" "<!--" "x->y"
                         "||" "!=" "://" "..." "//" ";;" "!!"
                         "mil" "milk" "illum" "mm"))
          (let ((together (zetta-font-shape-glyphs probe family))
                (apart (zetta-font-shape-solo-glyphs probe family)))
            (insert (format "%-10s %-26s %-26s %s\n"
                            probe
                            (if together (format "%s" together) "-")
                            (if apart (format "%s" apart) "-")
                            (if (and together apart (not (equal together apart)))
                                "substituted" "")))))
        (insert (format "\ntexture healing: %s\nbackend: %s\n"
                        (if (zetta-font-texture-healing-p family) "yes" "no")
                        (frame-parameter (zetta-ligature--frame)
                                         'font-backend))))
      (goto-char (point-min))
      (special-mode)
      (display-buffer (current-buffer)))))

;;; ------------------------------------------------------------------
;;; Texture healing
;;; ------------------------------------------------------------------

(defcustom zetta-texture-healing-max-run 32
  "Longest run of letters composed as a single unit.

Healing only ever looks at nearby neighbours, so chunking a very long
identifier costs nothing visible while bounding the worst case handed to
the shaper."
  :type 'integer
  :group 'zetta)

(defcustom zetta-texture-healing-auto t
  "When non-nil, follow the font: enable healing only where it does something.
Re-evaluated on every fontaine preset change."
  :type 'boolean
  :group 'zetta)

(defvar zetta-texture-healing--saved nil
  "Alist of (CHAR . PREVIOUS-RULE) captured before rules were installed.")

(defvar zetta-texture-healing--auto nil
  "Bound to t while the mode is being toggled automatically.
Suppresses the redraw a manual toggle needs.")

(defun zetta-texture-healing--chars ()
  "The characters that should trigger a letter-run composition."
  (append (number-sequence ?a ?z) (number-sequence ?A ?Z)))

(defun zetta-texture-healing--rule ()
  "The `composition-function-table' entry for a letter run.
Anchored at the triggering character, so the pattern must match from it."
  `([,(format "[a-zA-Z]\\{2,%d\\}" zetta-texture-healing-max-run)
     0 font-shape-gstring]))

(defun zetta-texture-healing--install ()
  "Install letter-run composition rules in the global table.

Deliberately the DEFAULT value: `ligature-mode' rebinds
`composition-function-table' buffer-locally, so writing to the current
binding would land in ligature.el's child table and vanish with it.  Its
child sets the global table as its parent, and char-table lookup falls
through on nil, so rules installed here stay visible inside ligature-mode
buffers -- provided the two never claim the same character.  That is why
the ligature set below drops \"www\", the only stock entry triggered by a
letter."
  (unless zetta-texture-healing--saved
    (let ((table (default-value 'composition-function-table))
          (rule (zetta-texture-healing--rule))
          (chars (zetta-texture-healing--chars)))
      (setq zetta-texture-healing--saved
            (mapcar (lambda (char) (cons char (aref table char))) chars))
      (dolist (char chars)
        (set-char-table-range table char rule)))))

(defun zetta-texture-healing--remove ()
  "Restore whatever the letter characters mapped to before."
  (when zetta-texture-healing--saved
    (let ((table (default-value 'composition-function-table)))
      (pcase-dolist (`(,char . ,rule) zetta-texture-healing--saved)
        (set-char-table-range table char rule)))
    (setq zetta-texture-healing--saved nil)))

;;;###autoload
(define-minor-mode zetta-texture-healing-mode
  "Compose runs of ASCII letters so the font's contextual alternates apply.

Monaspace substitutes letterforms based on their neighbours -- its
\"texture healing\" -- but only for characters Emacs hands to the shaper
together.  Without a composition rule Emacs draws letters one at a time and
the feature never fires."
  :global t
  :lighter nil
  :group 'zetta
  (if zetta-texture-healing-mode
      (zetta-texture-healing--install)
    (zetta-texture-healing--remove))
  ;; Composition is decided during redisplay, so already-drawn text keeps its
  ;; old shaping until something repaints it.  A manual toggle needs that
  ;; push; an automatic one does not -- whatever changed the window is about
  ;; to repaint anyway, and redrawing on every window change is exactly the
  ;; kind of thing that put the mode line on a treadmill before.
  (unless zetta-texture-healing--auto (redraw-display)))

(defun zetta-texture-healing--remapped-family (spec)
  "Dig a :family out of SPEC, one `face-remapping-alist' entry's value.
Entries come in both shapes -- (default :family \"X\") and
\(default (:family \"X\") other-face) -- so walk rather than assume."
  (cond ((keywordp (car-safe spec)) (plist-get spec :family))
        ((consp spec) (seq-some #'zetta-texture-healing--remapped-family spec))))

(defun zetta-texture-healing--families ()
  "Families healing should be decided from.

The mode is global because `composition-function-table' is, but the family
is not: a per-buffer fontaine preset remaps `default' buffer-locally.
Deciding from the frame's default alone leaves healing off in exactly the
buffer that asked for a healing font -- a Monaspace SQL buffer under a
GohuFont global default, say."
  (delete-dups
   ;; Only real family names get out of here.  A remapped `default' carries
   ;; arbitrary attribute plists -- (default (:foreground "#aec7...") default)
   ;; is the common shape -- and anything but a string is a font-spec error
   ;; on a redisplay path.
   (seq-filter (lambda (family)
                 (and (stringp family) (not (string-empty-p family))))
               (append
                (list (face-attribute 'default :family (zetta-ligature--frame))
                      ;; current-buffer covers a hook that runs before display
                      (zetta-texture-healing--remapped-family
                       (cdr (assq 'default face-remapping-alist))))
                ;; ...and every buffer on screen, because `current-buffer'
                ;; during `window-buffer-change-functions' is not reliably
                ;; the window's.
                (mapcar (lambda (win)
                          (with-current-buffer (window-buffer win)
                            (zetta-texture-healing--remapped-family
                             (cdr (assq 'default face-remapping-alist)))))
                        (window-list-1 nil 'never t))))))

;;;###autoload
(defun zetta-texture-healing-refresh (&optional interactive)
  "Turn healing on or off to match the fonts actually in play.

Toggles only on a real change: this runs from
`window-buffer-change-functions', and re-running the mode body would
redraw the display on every window change."
  (interactive (list t))
  (when zetta-texture-healing-auto
    (let ((want (and (seq-some #'zetta-font-texture-healing-p
                               (zetta-texture-healing--families))
                     t))
          (zetta-texture-healing--auto (not interactive)))
      (unless (eq want (and zetta-texture-healing-mode t))
        (zetta-texture-healing-mode (if want 1 -1))))))

(defun zetta-texture-healing--on-window-change (&rest _)
  "Refresh from `window-buffer-change-functions'.

Swallows errors on purpose.  This runs on a redisplay path, where a signal
is caught by `safe_call' and re-logged on every single window change --
the failure mode is thousands of identical lines in *Messages*, not one
useful backtrace.  Nothing above should be able to signal now; this is the
backstop, and `\\[zetta-texture-healing-refresh]' still reports honestly
when run by hand."
  (ignore-errors (zetta-texture-healing-refresh)))

;;;###autoload
(defun zetta-font-composition-at-point (&optional pos)
  "Report the composition covering POS, if any, and whether it substituted.

The honest check that healing is happening HERE, in this buffer, in the
font this buffer actually draws with -- rather than that the font is
capable of it in principle."
  (interactive)
  (let* ((pos (or pos (point)))
         (comp (find-composition pos nil nil t))
         (family (zetta-font-family-at-point pos)))
    (if (not (and comp (nth 2 comp)))
        (message "no composition at point (font: %s, healing-mode: %s)"
                 (or family "?")
                 (if zetta-texture-healing-mode "on" "off"))
      (let* ((text (buffer-substring-no-properties (nth 0 comp) (nth 1 comp)))
             (gstring (nth 2 comp))
             (shaped (let ((k 0) (acc nil))
                       (while (and (< k (lgstring-glyph-len gstring))
                                   (lgstring-glyph gstring k))
                         (push (lglyph-code (lgstring-glyph gstring k)) acc)
                         (setq k (1+ k)))
                       (nreverse acc)))
             (solo (zetta-font-shape-solo-glyphs text family)))
        (message "%S in %s: %S%s"
                 text (or family "?") shaped
                 (cond ((null solo) "")
                       ((equal shaped solo)
                        (format "  == solo %S -- composed but NOT substituted" solo))
                       (t (format "  vs solo %S -- SUBSTITUTED" solo))))))))

;;; ------------------------------------------------------------------
;;; Operator ligatures
;;; ------------------------------------------------------------------

(use-package ligature
  :ensure (ligature :type git :host github :repo "mickeynp/ligature.el")
  :config
  ;; The stock programming set, minus "www": its trigger is a letter, and a
  ;; letter claimed here would shadow the healing rule for every word
  ;; starting with it.
  (ligature-set-ligatures
   'prog-mode
   '("|||>" "<|||" "<==>" "<!--" "####" "~~>" "***" "||=" "||>"
     ":::" "::=" "=:=" "===" "==>" "=!=" "=>>" "=<<" "=/=" "!=="
     "!!." ">=>" ">>=" ">>>" ">>-" ">->" "->>" "-->" "---" "-<<"
     "<~~" "<~>" "<*>" "<||" "<|>" "<$>" "<==" "<=>" "<=<" "<->"
     "<--" "<-<" "<<=" "<<-" "<<<" "<+>" "</>" "###" "#_(" "..<"
     "..." "+++" "/==" "///" "_|_" "&&" "^=" "~~" "~@" "~="
     "~>" "~-" "**" "*>" "*/" "||" "|}" "|]" "|=" "|>" "|-" "{|"
     "[|" "]#" "::" ":=" ":>" ":<" "$>" "==" "=>" "!=" "!!" ">:"
     ">=" ">>" ">-" "-~" "-|" "->" "--" "-<" "<~" "<*" "<|" "<:"
     "<$" "<=" "<>" "<-" "<<" "<+" "</" "#{" "#[" "#:" "#=" "#!"
     "##" "#(" "#?" "#_" "%%" ".=" ".-" ".." ".?" "+>" "++" "?:"
     "?=" "?." "??" ";;" "/*" "/=" "/>" "//" "__" "(*" "*)" "\\\\"
     "://"))
  (global-ligature-mode t)

  (zetta-texture-healing-refresh)
  ;; Presets change the family under us, and healing is per-font.
  (with-eval-after-load 'fontaine
    (add-hook 'fontaine-set-preset-hook #'zetta-texture-healing-refresh))
  ;; And a per-buffer preset changes it without any preset hook firing, so
  ;; follow the buffer too.  Cheap: the probe is cached per family.
  (add-hook 'window-buffer-change-functions
            #'zetta-texture-healing--on-window-change))
;;; ligature.el ends here
