;;; svg-perf.el --- measure SVG rendering performance in Emacs -*- lexical-binding: t; -*-

;; A self-contained, dependency-free benchmark for Emacs's SVG pipeline
;; (svg.el -> create-image -> librsvg -> redisplay).  No packages, no I/O, no
;; svg-line -- it measures Emacs SVG performance in general.
;;
;; USAGE (live demo):
;;   emacs -Q svg-perf/svg-perf.el
;;   M-x eval-buffer
;;   M-x svg-perf-animate        ; a live animated SVG with a running fps counter
;;   M-x svg-perf-report         ; the SVG benchmark table, in a buffer
;;   M-x svg-perf-vs-modeline    ; SVG mode line vs the native text mode line
;;
;; All three need a GRAPHICAL frame (raster/fps are meaningless in -nw / --batch).

;;; Code:

(require 'svg)
(require 'cl-lib)

;;;; ---------------------------------------------------------------------------
;;;; SVG benchmark
;;;; ---------------------------------------------------------------------------

(defun svg-perf--make (n w h seed)
  "Build an in-memory SVG W by H: a background, N coloured bars and a label.
SEED varies the colours and text so each frame is a distinct image (a cache
miss), forcing librsvg to actually rasterise."
  (let ((svg (svg-create w h)))
    (svg-rectangle svg 0 0 w h :fill "#0d1117")
    (dotimes (i n)
      (let ((x (mod (* (1+ i) 13 (1+ seed)) (max 1 (- w 8))))
            (col (format "#%06x" (logand (* (1+ i) (1+ seed) 2654435761) #xffffff))))
        (svg-rectangle svg x 2 6 (max 1 (- h 4)) :rx 1 :fill col)))
    (svg-text svg (format "svg perf -- frame %d" seed)
              :x 8 :y (- h 6) :font-size (max 6 (- h 8))
              :font-family "Monospace" :fill "#e8e8e8")
    svg))

(defun svg-perf--image (n w h seed)
  "Image descriptor for `svg-perf--make' (builds the DOM and serialises it)."
  (svg-image (svg-perf--make n w h seed) :scale 1.0 :ascent 'center))

(defun svg-perf--gen (n w h reps)
  "(A) Generation only: build the DOM and serialise to the image data string.
Does NOT rasterise (that happens at redisplay).  Returns (:us US :conses N)."
  (garbage-collect)
  (let* ((m0 (memory-use-counts))
         (r (let ((gc-cons-threshold most-positive-fixnum))
              (benchmark-run reps (svg-perf--image n w h (random 1000000)))))
         (m1 (memory-use-counts)))
    (list :us (/ (* 1e6 (nth 0 r)) reps)
          :conses (/ (- (nth 0 m1) (nth 0 m0)) reps))))

(defvar svg-perf--n 8) (defvar svg-perf--w 800)
(defvar svg-perf--h 22) (defvar svg-perf--seed 0)

(defun svg-perf--frame-ms (reps dynamic)
  "(B) End-to-end frame time: show the image in a header line, force redisplay.
DYNAMIC bumps the seed each frame (new image -> cache miss -> rasterise); else
the image repeats (cache hit -> composite only).  Reads the svg-perf--* globals."
  (let ((gc-cons-threshold most-positive-fixnum)
        (buf (get-buffer-create "*svg-perf-frame*")))
    (with-current-buffer buf
      (setq header-line-format
            '(:eval (propertize
                     " " 'display (svg-perf--image svg-perf--n svg-perf--w
                                                   svg-perf--h svg-perf--seed))))
      (switch-to-buffer buf))
    (force-mode-line-update t) (redisplay t)        ; realise frame + warm up
    (let ((t0 (float-time)))
      (dotimes (_ reps)
        (when dynamic (cl-incf svg-perf--seed))
        (force-mode-line-update t)
        (redisplay t))
      (/ (* 1e3 (- (float-time) t0)) reps))))

(defcustom svg-perf-configs
  '((8 800 22) (32 800 22) (128 800 22) (512 800 22)
    (32 1600 22) (256 1600 44) (32 3000 44))
  "List of (N-ELEMENTS WIDTH HEIGHT) image configurations to benchmark."
  :type '(repeat (list integer integer integer)) :group 'svg-perf)

;;;###autoload
(defun svg-perf-report ()
  "Benchmark Emacs's SVG pipeline and show the results in a buffer.
For each configuration in `svg-perf-configs' it reports generation time and
allocation, the per-frame time with content changing (cache miss, rasterised)
vs static (cache hit), the isolated rasterisation cost (dynamic - static), and
the resulting frames-per-second."
  (interactive)
  (unless (display-graphic-p)
    (user-error "svg-perf needs a graphical frame (raster/fps are meaningless in -nw)"))
  (let ((buf (get-buffer-create "*svg-perf*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t)) (erase-buffer))
      (insert (format "Emacs %s | native-comp=%s | svg=%s | frame=%dx%d px\n\n"
                      emacs-version (and (featurep 'native-compile) t)
                      (image-type-available-p 'svg)
                      (frame-pixel-width) (frame-pixel-height)))
      (insert (format "%-16s | %8s | %8s | %8s | %10s | %12s | %6s\n"
                      "elems@WxH" "gen us" "conses" "dyn ms" "static ms"
                      "raster ms" "fps"))
      (insert (make-string 84 ?-) "\n")
      (redisplay t))
    (pop-to-buffer buf)
    (dolist (cfg svg-perf-configs)
      (cl-destructuring-bind (n w h) cfg
        (setq svg-perf--n n svg-perf--w w svg-perf--h h)
        (let* ((g  (svg-perf--gen n w h 3000))
               (fd (svg-perf--frame-ms 300 t))
               (fs (svg-perf--frame-ms 300 nil))
               ;; raster = dynamic - static: generation and composite are paid
               ;; in BOTH loops and cancel; only rasterisation differs.
               (raster (max 0.0 (- fd fs))))
          (with-current-buffer buf
            (goto-char (point-max))
            (insert (format "%-16s | %8.0f | %8d | %8.2f | %10.2f | %12.2f | %6.0f\n"
                            (format "%d@%dx%d" n w h)
                            (plist-get g :us) (plist-get g :conses)
                            fd fs raster (/ 1000.0 (max 1e-6 fd))))
            (redisplay t)))))
    (with-current-buffer buf
      (goto-char (point-max))
      (insert "\nraster = dynamic - static (the cost of rasterising fresh content);\n"
              "a STATIC bar is a cache hit, so steady-state cost is the `static' column.\n")
      (goto-char (point-min)))
    (switch-to-buffer buf)            ; end on the results table (for recording)
    (message "svg-perf-report done")))

;;;; ---------------------------------------------------------------------------
;;;; Comparison: SVG mode line vs the native (text) mode line
;;;; ---------------------------------------------------------------------------

(defvar svg-perf--ml-seed 0)
(defvar svg-perf--ml-segs 16)

(defun svg-perf--ml-string ()
  "A mode-line string of `svg-perf--ml-segs' segments that changes each frame."
  (let (parts)
    (dotimes (i svg-perf--ml-segs)
      (push (format " s%d:%d " i svg-perf--ml-seed) parts))
    (apply #'concat (nreverse parts))))

(defun svg-perf--ml-svg-image ()
  "The SAME text as `svg-perf--ml-string', drawn into a mode-line-sized SVG."
  (let* ((s (svg-perf--ml-string))
         (w (max 100 (frame-pixel-width)))
         (h (+ 4 (default-line-height)))
         (svg (svg-create w h)))
    (svg-rectangle svg 0 0 w h :fill "#0d1117")
    (svg-text svg s :x 4 :y (- h 6) :font-size (max 8 (- h 8))
              :font-family "Monospace" :fill "#e8e8e8")
    (svg-image svg :ascent 'center)))

(defun svg-perf--ml-frame-ms (reps mode)
  "Per-frame time for the mode line in MODE: `text' (native) or `svg'.
Content changes every frame; returns ms/frame."
  (let ((gc-cons-threshold most-positive-fixnum)
        (buf (get-buffer-create "*svg-perf-ml*")))
    (with-current-buffer buf
      (setq mode-line-format
            (if (eq mode 'svg)
                '(:eval (propertize " " 'display (svg-perf--ml-svg-image)))
              '(:eval (svg-perf--ml-string))))
      (switch-to-buffer buf))
    (force-mode-line-update t) (redisplay t)
    (let ((t0 (float-time)))
      (dotimes (_ reps)
        (cl-incf svg-perf--ml-seed)
        (force-mode-line-update t)
        (redisplay t))
      (/ (* 1e3 (- (float-time) t0)) reps))))

;;;###autoload
(defun svg-perf-vs-modeline ()
  "Compare the native text mode line with an SVG mode line of the SAME text.
Both show the same changing text every frame; one is laid out by Emacs's text
engine, the other rasterised by librsvg.  Reports ms/frame and fps for each."
  (interactive)
  (unless (display-graphic-p)
    (user-error "svg-perf needs a graphical frame"))
  (let ((buf (get-buffer-create "*svg-perf*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t)) (erase-buffer))
      (insert (format "Native text mode line vs SVG mode line (same text, changing every frame)\n"))
      (insert (format "Emacs %s | frame=%dx%d px\n\n"
                      emacs-version (frame-pixel-width) (frame-pixel-height)))
      (insert (format "%-6s | %10s | %10s | %9s | %9s | %s\n"
                      "segs" "text ms" "svg ms" "text fps" "svg fps" "svg/text"))
      (insert (make-string 72 ?-) "\n")
      (redisplay t))
    (pop-to-buffer buf)
    (dolist (segs '(4 16 48))
      (setq svg-perf--ml-segs segs)
      (let* ((tx (svg-perf--ml-frame-ms 400 'text))
             (sv (svg-perf--ml-frame-ms 400 'svg)))
        (with-current-buffer buf
          (goto-char (point-max))
          (insert (format "%-6d | %10.3f | %10.3f | %9.0f | %9.0f | %.1fx\n"
                          segs tx sv
                          (/ 1000.0 (max 1e-6 tx)) (/ 1000.0 (max 1e-6 sv))
                          (/ sv (max 1e-6 tx))))
          (redisplay t))))
    (with-current-buffer buf
      (goto-char (point-max))
      (insert "\nBoth repaint the WHOLE bar every frame -- a worst case neither engine\n"
              "does in practice (a real bar only repaints on content change).\n"))
    (message "svg-perf-vs-modeline done")))

;;;; ---------------------------------------------------------------------------
;;;; Three-way: SVG glyphs vs SVG text vs the native text mode line
;;;; ---------------------------------------------------------------------------

(defvar svg-perf--3w-seed 0)
(defvar svg-perf--3w-n 72
  "Number of character CELLS (ASCII chars / icon glyphs) drawn in the three-way
bench.  The text and glyph variants draw the same count, so the comparison
isolates per-glyph rasterisation cost, not how many cells each draws.")
(defvar svg-perf--3w-kind 'svg-text)
(defvar svg-perf--3w-width 1280
  "Fixed SVG bar width in pixels.  Pinned (rather than the live window width) so
the three-way numbers are reproducible no matter how the window is sized — SVG
raster cost scales with bar area, so a maximized window would otherwise inflate
them.  A representative full-width mode line; raise/lower to model a wider or
narrower bar.")
(defvar svg-perf--3w-height 28
  "Fixed SVG bar height in pixels (see `svg-perf--3w-width').")

(defconst svg-perf--3w-icons
  '(#xf017 #xf0e7 #xf02d #xf015 #xf121 #xf188 #xf073 #xf02b)
  "A handful of Nerd-Font (Font-Awesome range) icon codepoints.")

(defun svg-perf--3w-glyph-font ()
  "A Nerd Font librsvg can use for icon glyphs, or nil if none is found."
  (cl-find-if (lambda (f) (find-font (font-spec :family f)))
              '("Symbols Nerd Font Mono" "Symbols Nerd Font"
                "Terminess Nerd Font Mono" "Terminess Nerd Font")))

(defun svg-perf--3w-text-string ()
  "An ASCII string of exactly `svg-perf--3w-n' chars that changes each frame."
  (let ((s (format "frame %d status ok branch main plus3 utf8 line42 col7 "
                   svg-perf--3w-seed)))
    (while (< (length s) svg-perf--3w-n) (setq s (concat s s)))
    (substring s 0 svg-perf--3w-n)))

(defun svg-perf--3w-glyph-string ()
  "A string of `svg-perf--3w-n' Nerd-Font icon glyphs."
  (apply #'string
         (cl-loop for i below svg-perf--3w-n
                  collect (nth (mod i (length svg-perf--3w-icons))
                               svg-perf--3w-icons))))

(defun svg-perf--3w-color (kind)
  "Bright accent colour for KIND (the bar fill and the on-screen label)."
  (pcase kind ('native "#2f8f4f") ('svg-text "#2f6fd0") ('glyph "#8a5cf0")))

(defun svg-perf--3w-dim (kind)
  "Dim full-window tint for KIND."
  (pcase kind ('native "#13261a") ('svg-text "#121d33") ('glyph "#1d1433")))

(defun svg-perf--3w-label (kind)
  "On-screen banner text naming the engine under test for KIND."
  (pcase kind
    ('native   "BUILT-IN  /  native text mode line")
    ('svg-text "SVG  /  text")
    ('glyph    "SVG  /  icon glyphs")))

(defun svg-perf--3w-image ()
  "Mode-line-sized SVG for `svg-perf--3w-kind' (`svg-text' or `glyph')."
  (let* ((w svg-perf--3w-width) (h svg-perf--3w-height)
         (svg (svg-create w h)))
    (svg-rectangle svg 0 0 w h :fill (svg-perf--3w-color svg-perf--3w-kind))
    (if (eq svg-perf--3w-kind 'glyph)
        ;; vary the fill by the seed so each frame is a cache miss (full raster);
        ;; force the high bit of each channel so glyphs stay light on the tint
        (svg-text svg (svg-perf--3w-glyph-string)
                  :x 4 :y (- h 6) :font-size (max 8 (- h 8))
                  :font-family (or (svg-perf--3w-glyph-font) "Monospace")
                  :fill (format "#%06x"
                                (logior (logand (* (1+ svg-perf--3w-seed) 2654435761)
                                                #xffffff)
                                        #x808080)))
      (svg-text svg (svg-perf--3w-text-string)
                :x 4 :y (- h 6) :font-size (max 8 (- h 8))
                :font-family "Monospace" :fill "#e8e8e8"))
    (svg-image svg :ascent 'center)))

(defun svg-perf--3w-frame-ms (kind reps)
  "Per-frame ms for KIND (`native', `svg-text' or `glyph'), content changing.
Colour-codes the window (a labelled banner, a dim background tint, and a
matching bar colour) so the engine under test is unmistakable on screen."
  (setq svg-perf--3w-kind kind)
  (let ((gc-cons-threshold most-positive-fixnum)
        (buf (get-buffer-create "*svg-perf-3w*"))
        (col (svg-perf--3w-color kind)))
    (with-current-buffer buf
      ;; tint the whole window, and for the native bar tint its mode-line face
      ;; (the SVG bars carry their own colour in the image)
      (setq-local face-remapping-alist
                  (cons (list 'default :background (svg-perf--3w-dim kind)
                              :foreground "white")
                        (when (eq kind 'native)
                          (list (list 'mode-line-active :background col :foreground "white")
                                (list 'mode-line :background col :foreground "white")))))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "\n\n\n   "
                (propertize (concat "  " (svg-perf--3w-label kind) "  ")
                            'face (list :background col :foreground "white"
                                        :weight 'bold :height 2.6))
                "\n\n\n   "
                (propertize "the bar below is what's being benchmarked"
                            'face (list :foreground "gray70" :height 1.2))))
      (setq-local mode-line-format
                  (if (eq kind 'native)
                      '(:eval (svg-perf--3w-text-string))
                    '(:eval (propertize " " 'display (svg-perf--3w-image)))))
      (switch-to-buffer buf))
    (force-mode-line-update t) (redisplay t)
    (let ((t0 (float-time)))
      (dotimes (_ reps)
        (cl-incf svg-perf--3w-seed)
        (force-mode-line-update t)
        (redisplay t))
      (/ (* 1e3 (- (float-time) t0)) reps))))

(defun svg-perf--mean (xs) (/ (apply #'+ xs) (float (length xs))))

(defun svg-perf--ms-fps (ms)
  "Format MS as \"ms (fps)\" with fps = 1000/ms."
  (format "%7.3f (%5.0f)" ms (/ 1000.0 (max 1e-6 ms))))

;;;###autoload
(defun svg-perf-three-way (&optional trials reps)
  "Benchmark SVG-glyphs vs SVG-text vs the native text mode line, TRIALS times.
Each renders `svg-perf--3w-n' items into the mode line, repainting the whole
bar every frame.  Runs TRIALS (default 10) trials of REPS (default 200) frames
each, printing every trial's ms/frame and the averages."
  (interactive)
  (unless (display-graphic-p) (user-error "svg-perf needs a graphical frame"))
  (let* ((trials (or trials 10)) (reps (or reps 200))
         (gfont (svg-perf--3w-glyph-font))
         (buf (get-buffer-create "*svg-perf*"))
         (nat '()) (txt '()) (gly '()))
    (with-current-buffer buf
      (let ((inhibit-read-only t)) (erase-buffer))
      (insert "Three-way: native text mode line vs SVG text vs SVG icon glyphs\n")
      (insert (format "Emacs %s | bar=%dx%d px (fixed) | cells=%d (matched) | reps/trial=%d\n"
                      emacs-version svg-perf--3w-width svg-perf--3w-height
                      svg-perf--3w-n reps))
      (insert (format "glyph font: %s\n\n"
                      (or gfont "NONE FOUND -- glyphs fall back to Monospace!")))
      (insert (format "%-7s | %15s | %15s | %15s   (cells: ms (fps))\n"
                      "trial" "native" "svg-text" "svg-glyph"))
      (insert (make-string 64 ?-) "\n")
      (redisplay t))
    (pop-to-buffer buf)
    (dotimes (tr trials)
      (let ((n  (svg-perf--3w-frame-ms 'native reps))
            (t1 (svg-perf--3w-frame-ms 'svg-text reps))
            (g  (svg-perf--3w-frame-ms 'glyph reps)))
        (push n nat) (push t1 txt) (push g gly)
        (with-current-buffer buf
          (goto-char (point-max))
          (insert (format "%-7d | %15s | %15s | %15s\n" (1+ tr)
                          (svg-perf--ms-fps n) (svg-perf--ms-fps t1)
                          (svg-perf--ms-fps g)))
          (redisplay t))))
    (let ((mn (svg-perf--mean nat)) (mt (svg-perf--mean txt)) (mg (svg-perf--mean gly)))
      (with-current-buffer buf
        (goto-char (point-max))
        (insert (make-string 64 ?-) "\n")
        (insert (format "%-7s | %15s | %15s | %15s\n" "AVG"
                        (svg-perf--ms-fps mn) (svg-perf--ms-fps mt)
                        (svg-perf--ms-fps mg)))
        (insert (format "\nsvg-text/native = %.1fx   svg-glyph/native = %.1fx   svg-glyph/svg-text = %.2fx\n"
                        (/ mt mn) (/ mg mn) (/ mg mt)))
        (switch-to-buffer buf) (goto-char (point-min))))  ; end on the table
    (message "svg-perf-three-way done")))

;;;; ---------------------------------------------------------------------------
;;;; Live visual demo
;;;; ---------------------------------------------------------------------------

;;;###autoload
(defun svg-perf-animate (&optional seconds)
  "Animate a large SVG for SECONDS (default 8) with a live fps counter.
A purely visual demo: each frame builds and rasterises a fresh ~900x420 SVG.
Press any key to stop early."
  (interactive)
  (unless (display-graphic-p)
    (user-error "svg-perf-animate needs a graphical frame"))
  (let* ((secs (or seconds 8)) (w 900) (h 420)
         (buf (get-buffer-create "*svg-anim*"))
         (frames 0) (t0 (float-time)) (fps 0.0) (end (+ (float-time) secs)))
    (switch-to-buffer buf)
    (buffer-disable-undo) (setq-local cursor-type nil)
    (while (and (< (float-time) end) (not (input-pending-p)))
      (let ((svg (svg-create w h)))
        (svg-rectangle svg 0 0 w h :fill "#0d1117")
        (dotimes (i 48)
          (let* ((phase (* 0.13 (+ i (/ frames 3.0))))
                 (x (+ (/ w 2) (round (* (- (/ w 2) 40) (sin phase)))))
                 (hue (logand (* (1+ i) 2654435761) #xffffff)))
            (svg-rectangle svg x (+ 200 (round (* 150 (sin (* 0.05 (+ i frames))))))
                           44 8 :rx 4 :fill (format "#%06x" hue))))
        (svg-text svg (format "%.0f fps" fps) :x 36 :y 120
                  :font-size 96 :font-family "Monospace" :font-weight "bold"
                  :fill "#58a6ff")
        (svg-text svg "SVG rendered live in Emacs" :x 38 :y 168
                  :font-size 28 :font-family "Monospace" :fill "#8b949e")
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert-image (svg-image svg :scale 1.0))))
      (cl-incf frames)
      (redisplay t)
      (when (>= frames 8) (setq fps (/ frames (- (float-time) t0)))))
    (message "svg-perf-animate: %d frames in %.1fs = %.0f fps"
             frames (- (float-time) t0) fps)))

(provide 'svg-perf)
;;; svg-perf.el ends here
