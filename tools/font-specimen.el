;;; font-specimen.el --- Render a font specimen buffer -*- lexical-binding: t; -*-

;; Renders every family x weight x slant of a font superfamily in one
;; buffer, so they can be compared at a glance rather than by cycling
;; presets.  Written for Monaspace (five metrically-compatible families)
;; but the family list is a plain variable.
;;
;;   M-x zetta-font-specimen
;;   C-u M-x zetta-font-specimen   prompt for the point size
;;
;; The ligature and texture sections below DO compose: this build has no
;; HARFBUZZ, but `mac-ct' shapes through Core Text, which applies a font's
;; default `calt'/`liga' anyway.  See FONTS.org.  Judge them by eye here,
;; not by glyph count -- these fonts substitute in place, so a ligature
;; keeps one glyph per character.  Monaspace's arrows are the one gap: they
;; live in stylistic set `ss03', which Emacs has no way to request.

;;; Code:

(require 'cl-lib)

(defvar zetta-font-specimen-families
  '(("Monaspace Neon NF"    . "neo-grotesque -- the default code face")
    ("Monaspace Argon NF"   . "humanist -- softer, good for prose")
    ("Monaspace Xenon NF"   . "slab serif -- headings, emphasis")
    ("Monaspace Krypton NF" . "mechanical -- chrome, mode line")
    ("Monaspace Radon NF"   . "handwriting -- comments, annotation"))
  "Families to render, as (FAMILY . DESCRIPTION).")

(defvar zetta-font-specimen-baseline "Terminus (TTF)"
  "Family rendered at the end for comparison.  nil to omit.")

(defvar zetta-font-specimen-weights
  '(extra-light light regular medium semi-bold bold extra-bold)
  "Weights to render for each family.")

(defvar zetta-font-specimen-pangram
  "The quick brown fox jumps over the lazy dog 0123456789"
  "Sample text for each weight row.")

(defun zetta-font-specimen--available-p (family)
  "Return non-nil when FAMILY is installed."
  (member family (font-family-list)))

(defun zetta-font-specimen--ins (text family &optional weight slant height)
  "Insert TEXT in FAMILY, optionally at WEIGHT/SLANT/HEIGHT."
  (insert (propertize text 'face
                      (append (list :family family)
                              (when weight (list :weight weight))
                              (when slant  (list :slant slant))
                              (when height (list :height height))))))

(defun zetta-font-specimen--rule (label sub height)
  "Insert a section rule for LABEL with subtitle SUB at HEIGHT."
  (insert "\n")
  (insert (propertize (format "%s  " label)
                      'face (list :height height :weight 'bold)))
  (insert (propertize (format "%s\n" sub) 'face (list :height (round (* height 0.85))
                                                     :slant 'italic)))
  (insert (propertize (make-string 78 ?─) 'face (list :height height)) "\n"))

(defun zetta-font-specimen--family (family desc height)
  "Render one FAMILY block described by DESC at HEIGHT."
  (zetta-font-specimen--rule family desc height)
  (if (not (zetta-font-specimen--available-p family))
      (insert (propertize "  NOT INSTALLED\n" 'face 'error))
    (dolist (weight zetta-font-specimen-weights)
      (dolist (slant '(normal italic))
        (let ((label (format "  %-11s %-7s "
                             weight (if (eq slant 'italic) "italic" ""))))
          (insert (propertize label 'face (list :height (round (* height 0.8))
                                                :family zetta-font-specimen-baseline)))
          (zetta-font-specimen--ins zetta-font-specimen-pangram
                                    family weight slant height)
          (insert "\n"))))
    ;; a line of real code, which is what actually matters
    (insert (propertize "  code        " 'face (list :height (round (* height 0.8))
                                                     :family zetta-font-specimen-baseline)))
    (zetta-font-specimen--ins
     "(let ((x 0)) (if (>= x 10) 'big \"small\")) ; l1 O0 |I"
     family 'regular 'normal height)
    (insert "\n")))

;;;###autoload
(defun zetta-font-specimen (&optional arg)
  "Show a specimen of `zetta-font-specimen-families'.
With prefix ARG, prompt for the point size (in 1/10 pt, e.g. 160)."
  (interactive "P")
  (let* ((height (if arg (read-number "Height (1/10 pt): " 160) 160))
         (buf (get-buffer-create "*font specimen*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (setq-local truncate-lines t)
        (insert (propertize "MONASPACE SPECIMEN\n" 'face (list :height (round (* height 1.4))
                                                               :weight 'bold)))
        (insert (format "current default: %s at %s   |   rendered here at %s\n"
                        (face-attribute 'default :family)
                        (face-attribute 'default :height)
                        height))
        (insert "shaping: mac-ct via Core Text -- ligatures and texture healing DO apply\n")

        (dolist (entry zetta-font-specimen-families)
          (zetta-font-specimen--family (car entry) (cdr entry) height))

        ;; --- what shaping would change -------------------------------
        (zetta-font-specimen--rule "Ligature candidates"
                                   "compose in a shaping-capable build; separate glyphs here" height)
        (dolist (entry zetta-font-specimen-families)
          (when (zetta-font-specimen--available-p (car entry))
            (insert (propertize (format "  %-22s " (car entry))
                                'face (list :height (round (* height 0.8))
                                            :family zetta-font-specimen-baseline)))
            (zetta-font-specimen--ins "-> => != === <= >= <> |> ::= ++ // /* */ ... <!--"
                                      (car entry) 'regular 'normal height)
            (insert "\n")))

        (zetta-font-specimen--rule "Texture healing"
                                   "narrow/wide pairs calt would even out" height)
        (dolist (entry zetta-font-specimen-families)
          (when (zetta-font-specimen--available-p (car entry))
            (insert (propertize (format "  %-22s " (car entry))
                                'face (list :height (round (* height 0.8))
                                            :family zetta-font-specimen-baseline)))
            (zetta-font-specimen--ins "illuminating mmm iii rn rm lil www MWM"
                                      (car entry) 'regular 'normal height)
            (insert "\n")))

        (zetta-font-specimen--rule "Nerd Font + box drawing"
                                   "what the terminal and mode line actually need" height)
        (dolist (entry zetta-font-specimen-families)
          (when (zetta-font-specimen--available-p (car entry))
            (insert (propertize (format "  %-22s " (car entry))
                                'face (list :height (round (* height 0.8))
                                            :family zetta-font-specimen-baseline)))
            (zetta-font-specimen--ins "─│┌┐└┘├┤┬┴┼ ━┃ ░▒▓█ ⏺ ❯ ✳    "
                                      (car entry) 'regular 'normal height)
            (insert "\n")))

        (when zetta-font-specimen-baseline
          (zetta-font-specimen--rule zetta-font-specimen-baseline
                                     "current default, for comparison" height)
          (dolist (weight '(regular bold))
            (dolist (slant '(normal italic))
              (insert (propertize (format "  %-11s %-7s " weight
                                          (if (eq slant 'italic) "italic" ""))
                                  'face (list :height (round (* height 0.8))
                                              :family zetta-font-specimen-baseline)))
              (zetta-font-specimen--ins zetta-font-specimen-pangram
                                        zetta-font-specimen-baseline weight slant height)
              (insert "\n"))))
        (goto-char (point-min))
        (view-mode 1)))
    (pop-to-buffer buf)))

(provide 'font-specimen)
;;; font-specimen.el ends here

;;; ------------------------------------------------------------------
;;; Browsing everything that is installed
;;; ------------------------------------------------------------------

(defun zetta-font--nerd-capable-p (family)
  "Non-nil when FAMILY carries Nerd Font private-use glyphs."
  (ignore-errors
    (when-let* ((spec (find-font (font-spec :family family :size 15)))
                (obj (open-font spec)))
      (font-has-char-p obj #xF0614))))

;;;###autoload
(defun zetta-font-list-installed (&optional filter)
  "List every installed font family, each name rendered in its own font.

Columns: the family name (in itself), a fixed sample, its per-character
advance at 15pt, and -- for families carrying Nerd glyphs -- whether text
and icons advance identically.  That last column is the one that decides
whether a family can serve as the SVG chrome font; see FONTS.org.

With a prefix argument, prompt for a regexp to filter families."
  (interactive (list (when current-prefix-arg (read-string "Filter (regexp): "))))
  (let* ((families (sort (seq-filter (lambda (f)
                                       (or (null filter) (string-match-p filter f)))
                                     (font-family-list))
                         #'string<))
         (buf (get-buffer-create "*installed fonts*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (setq-local truncate-lines t)
        (insert (propertize (format "%d installed font families%s\n"
                                    (length families)
                                    (if filter (format " matching %S" filter) ""))
                            'face '(:height 1.3 :weight bold)))
        (insert "advance is px/char at 15pt; uniform = icons advance like text "
                "(required for the SVG chrome)\n\n")
        (dolist (family families)
          (let* ((adv (zetta-font-specimen--px-per-char family))
                 (nerd (zetta-font--nerd-capable-p family))
                 (icon (and nerd (zetta-font-specimen--px-per-char family #xF0614)))
                 (uniform (and icon (= (round adv) (round icon)))))
            (insert (propertize (format "%-34s" (truncate-string-to-width family 33))
                                'face (list :family family)))
            (insert (propertize " AaBbGg 0O1lI |-+  " 'face (list :family family)))
            (insert (propertize (format "  %4.1f" adv) 'face 'shadow))
            (insert (cond ((not nerd) "")
                          (uniform (propertize "  nerd:uniform" 'face 'success))
                          (t (propertize (format "  nerd:%.1f MISMATCH" icon)
                                         'face 'warning))))
            (insert "\n")))
        (goto-char (point-min))
        (view-mode 1)))
    (pop-to-buffer buf)))

(defun zetta-font-specimen--px-per-char (family &optional char)
  "Advance of CHAR (default ?M) in FAMILY at 15pt, in pixels."
  (let ((s (make-string 10 (or char ?M))))
    (/ (float (string-pixel-width (propertize s 'face (list :family family :height 150))))
       10)))
