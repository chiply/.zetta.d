;;; svg-bench.el --- SVG vs native rendering benchmark + demos -*- lexical-binding: t; -*-

;; A self-contained benchmark for the cost of rendering a status bar in Emacs
;; two ways -- as an SVG image (svg.el -> create-image -> librsvg -> redisplay)
;; versus the native text engine.  No packages, no I/O.  It backs a blog post,
;; so it has both live, recordable DEMOS and headless DATA gatherers.
;;
;; The thesis: SVG raster cost scales with image PIXEL AREA.  A status bar is
;; short, so even a very wide (ultrawide-monitor) SVG bar stays well above the
;; 60 fps that high-frame-rate apps target; only a large 2-D image (the circle
;; animation) pushes past it.
;;
;; Everything needs a GRAPHICAL frame -- raster and fps are meaningless under
;; --batch or -nw.
;;
;; USAGE
;;   emacs -Q svg-bench/svg-bench.el ; then M-x eval-buffer
;;   Demos (record these):  M-x svg-perf-text / svg-perf-icons /
;;                          builtin-perf-text / svg-perf-animation
;;   Data tables:           M-x svg-perf-benchmark
;;                          M-x svg-perf-animation-benchmark

;;; Code:

(require 'svg)
(require 'cl-lib)

;;;; --------------------------------------------------------------------------
;;;; Configuration
;;;; --------------------------------------------------------------------------

(defvar svg-bench-bar-height 30
  "Height in pixels of the benchmarked status bar (short, like a mode line).")

(defvar svg-bench-bar-widths '(("narrow" . 800) ("medium" . 1800) ("large" . 3000))
  "Alist of (NAME . WIDTH-PX) status-bar widths for `svg-perf-benchmark'.
Width is the axis of size variance: SVG raster scales with it, and the native
engine scales with the glyph count it implies.")

(defvar svg-bench-anim-widths '(("small" . 300) ("medium" . 700) ("large" . 1400))
  "Alist of (NAME . WIDTH-PX) for the line animation, `svg-perf-animation'.
The animation is a thin mode-line-sized bar (height `svg-bench-anim-height')
with circles bouncing horizontally -- representative of an inline SVG animation
you might actually put in a status line -- so its cost scales with width like
the status-bar benchmarks.")
(defvar svg-bench-anim-height 40 "Height in px of the line animation bar.")
(defvar svg-bench-anim-speed 1.2
  "Angular speed of the bouncing circles, in radians/second (wall-clock).
A full there-and-back bounce takes 2*pi / this many seconds (~5.2s at 1.2);
lower is slower and smoother.")

(defvar svg-bench-trials 20 "Trials per (benchmark, size) cell.")
(defvar svg-bench-reps 100 "Forced-redisplay frames timed per trial.")

(defvar svg-bench-icons
  '(#xf017 #xf0e7 #xf02d #xf015 #xf121 #xf188 #xf073 #xf02b #xf0e0 #xf02c)
  "Nerd-Font (Font-Awesome range) icon codepoints for the glyph benchmark.")

(defconst svg-bench--alphabet
  "abcdefghijklmnopqrstuvwxyz 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ .,;:-+=/ "
  "Pool the text content is drawn from; rotated per frame so every cell changes.")

(defun svg-bench--color (kind)
  "Accent colour for KIND."
  (pcase kind ('svg-text "#2f6fd0") ('svg-icons "#8a5cf0") ('builtin-text "#2f8f4f")))

(defun svg-bench--glyph-font ()
  "A Nerd Font librsvg can resolve for icon glyphs, or nil."
  (cl-find-if (lambda (f) (find-font (font-spec :family f)))
              '("Symbols Nerd Font Mono" "Symbols Nerd Font"
                "Terminess Nerd Font Mono" "Terminess Nerd Font")))

;;;; --------------------------------------------------------------------------
;;;; Content (fully changes every frame, so the native engine can't reuse glyphs)
;;;; --------------------------------------------------------------------------

(defun svg-bench--ncells (width)
  "Number of character cells that fill WIDTH px in the benchmark's SVG font."
  (max 1 (floor (/ (- width 12) (* (- svg-bench-bar-height 10) 0.6)))))

(defun svg-bench--cells (n seed)
  "An N-character ASCII string, rotated by SEED so every position differs frame
to frame (forcing a full re-render in both engines)."
  (let* ((a svg-bench--alphabet) (la (length a)) (off (mod seed la)))
    (apply #'string (cl-loop for i below n collect (aref a (mod (+ i off) la))))))

(defun svg-bench--icon-cells (n seed)
  "An N-glyph Nerd-Font icon string, rotated by SEED for per-frame variation."
  (apply #'string (cl-loop for i below n
                           collect (nth (mod (+ i seed) (length svg-bench-icons))
                                        svg-bench-icons))))

;;;; --------------------------------------------------------------------------
;;;; Images
;;;; --------------------------------------------------------------------------

(defun svg-bench--bar-image (kind width height seed)
  "SVG status bar WIDTH x HEIGHT for KIND (`svg-text' or `svg-icons'), per SEED.
The whole canvas is filled, so raster cost tracks WIDTH x HEIGHT; the content
changes each frame (text rotates; icon fill cycles) so every frame is a cache
miss and is rasterised afresh."
  (let* ((svg (svg-create width height))
         (fs (max 8 (- height 10)))
         (n (svg-bench--ncells width))
         (y (- height (max 4 (round (/ height 4.0))))))
    (svg-rectangle svg 0 0 width height :fill (svg-bench--color kind))
    (if (eq kind 'svg-icons)
        (svg-text svg (svg-bench--icon-cells n seed)
                  :x 6 :y y :font-size fs
                  :font-family (or (svg-bench--glyph-font) "Monospace")
                  :fill "#ffffff")
      (svg-text svg (svg-bench--cells n seed)
                :x 6 :y y :font-size fs :font-family "Monospace" :fill "#ffffff"))
    ;; A 2px seed-coloured marker at the right edge makes every frame a UNIQUE
    ;; image -> always an Emacs image-cache MISS, genuinely re-rasterised.  We
    ;; vary this marker rather than the glyph colour, so glyph colour stays
    ;; fixed: cost reflects a realistic re-render (canvas raster + reused
    ;; glyphs), and the cache cannot serve a repeated frame.
    (svg-rectangle svg (- width 2) 0 2 height
                   :fill (format "#%06x" (logand (* (1+ seed) 2654435761) #xffffff)))
    (svg-image svg :scale 1.0 :ascent 'center)))

(defun svg-bench--anim-image (width frame)
  "Thin WIDTH x `svg-bench-anim-height' bar with circles bouncing left-right.
Representative of an inline status-line animation; cost scales with WIDTH."
  (let* ((h svg-bench-anim-height)
         (svg (svg-create width h))
         (r (max 4 (round (/ h 3.0))))
         (cy (/ h 2))
         (span (max 1 (- width (* 2 (+ r 4))))))
    (svg-rectangle svg 0 0 width h :fill "#0d1117")
    ;; Position from wall-clock (not the frame index) so the motion is the same
    ;; smooth, slow speed regardless of how many fps we render at.
    (let ((t* (* (float-time) svg-bench-anim-speed)))
      (dolist (c (list (cons 0.0 "#f25c54") (cons 1.9 "#58a6ff") (cons 3.8 "#3fb950")))
        (let* ((ph (+ (car c) t*))
               ;; sine oscillation -> smooth back-and-forth across the bar
               (x (+ r 4 (round (* (/ span 2.0) (1+ (sin ph)))))))
          (svg-circle svg x cy r :fill (cdr c)))))
    ;; per-frame marker so each frame is a unique image (no cache hits)
    (svg-rectangle svg (- width 2) 0 2 2
                   :fill (format "#%06x" (logand (* (1+ frame) 2654435761) #xffffff)))
    (svg-image svg :scale 1.0 :ascent 'center)))

;;;; --------------------------------------------------------------------------
;;;; Measurement core
;;;; --------------------------------------------------------------------------

(defun svg-bench--time (render-fn reps)
  "Call RENDER-FN with frame indices and time forced redisplay, ms/frame.
RENDER-FN updates the current (displayed) buffer for a given frame index.  GC is
pinned and the cache cleared so each trial starts clean; the first frame is a
warm-up and is not timed."
  (let ((gc-cons-threshold most-positive-fixnum))
    (clear-image-cache)
    (funcall render-fn 0) (redisplay t)            ; warm up (untimed)
    (let ((t0 (float-time)))
      (dotimes (i reps) (funcall render-fn (1+ i)) (redisplay t))
      (/ (* 1e3 (- (float-time) t0)) reps))))

(defun svg-bench--bar-render-fn (kind width)
  "A render function drawing KIND at WIDTH into the current buffer."
  (let ((n (svg-bench--ncells width)) (h svg-bench-bar-height))
    (if (eq kind 'builtin-text)
        (lambda (f) (let ((inhibit-read-only t))
                      (erase-buffer) (insert (svg-bench--cells n f))))
      (lambda (f) (let ((inhibit-read-only t))
                    (erase-buffer)
                    (insert-image (svg-bench--bar-image kind width h f)))))))

(defun svg-bench--anim-render-fn (width)
  "A render function drawing the line animation at WIDTH into the current buffer."
  (lambda (f) (let ((inhibit-read-only t))
                (erase-buffer) (insert-image (svg-bench--anim-image width f)))))

;;;; --------------------------------------------------------------------------
;;;; Statistics + table formatting
;;;; --------------------------------------------------------------------------

(defun svg-bench--stats (xs)
  "Summary statistics for the list of ms samples XS."
  (let* ((n (length xs)) (s (sort (copy-sequence xs) #'<))
         (mean (/ (apply #'+ xs) n))
         (median (if (cl-oddp n) (nth (/ n 2) s)
                   (/ (+ (nth (1- (/ n 2)) s) (nth (/ n 2) s)) 2.0)))
         (mn (car s)) (mx (car (last s)))
         (sd (sqrt (/ (apply #'+ (mapcar (lambda (x) (* (- x mean) (- x mean))) xs)) n))))
    (list :n n :mean mean :median median :min mn :max mx :sd sd)))

(defun svg-bench--table-header (title)
  (concat (format "%-22s | %3s | %7s | %7s | %6s | %6s | %6s | %8s | %7s\n"
                  title "n" "mean ms" "med ms" "sd ms" "min ms" "max ms"
                  "mean fps" "min fps")
          (make-string 92 ?-) "\n"))

(defun svg-bench--table-row (label st)
  ;; mean fps = 1000/mean ; min fps = 1000/max (the worst trial)
  (format "%-22s | %3d | %7.2f | %7.2f | %6.2f | %6.2f | %6.2f | %8.0f | %7.0f\n"
          label (plist-get st :n) (plist-get st :mean) (plist-get st :median)
          (plist-get st :sd) (plist-get st :min) (plist-get st :max)
          (/ 1000.0 (plist-get st :mean)) (/ 1000.0 (plist-get st :max))))

;;;; --------------------------------------------------------------------------
;;;; Data gatherers
;;;; --------------------------------------------------------------------------

;;;###autoload
(defun svg-perf-benchmark (&optional trials reps)
  "Benchmark svg-text vs svg-icons vs builtin-text across the three bar widths.
TRIALS (default `svg-bench-trials') trials of REPS (default `svg-bench-reps')
frames each.  Emits three tables (one per render kind), each row a width, with
full statistics; fps is the headline (mean fps, and min fps = the worst trial)."
  (interactive)
  (unless (display-graphic-p) (user-error "svg-bench needs a graphical frame"))
  (let* ((trials (or trials svg-bench-trials)) (reps (or reps svg-bench-reps))
         (work (get-buffer-create "*svg-bench-work*"))
         (out (get-buffer-create "*svg-bench*")))
    (with-current-buffer out (let ((inhibit-read-only t)) (erase-buffer))
      (insert (format "Status-bar rendering: SVG vs native text engine\n"))
      (insert (format "Emacs %s | bar height %dpx | %d trials x %d frames | glyph font: %s\n\n"
                      emacs-version svg-bench-bar-height trials reps
                      (or (svg-bench--glyph-font) "none"))))
    (with-current-buffer work (setq truncate-lines nil) (buffer-disable-undo))
    (switch-to-buffer work) (delete-other-windows)
    (dolist (kind '(svg-text svg-icons builtin-text))
      (with-current-buffer out (goto-char (point-max))
        (insert (svg-bench--table-header
                 (pcase kind ('svg-text "SVG / text")
                             ('svg-icons "SVG / icons")
                             ('builtin-text "BUILT-IN / text")))))
      (dolist (wspec svg-bench-bar-widths)
        (let* ((wname (car wspec)) (w (cdr wspec)) (n (svg-bench--ncells w))
               (rf (svg-bench--bar-render-fn kind w))
               (samples (with-current-buffer work
                          (cl-loop repeat trials collect (svg-bench--time rf reps))))
               (st (svg-bench--stats samples)))
          (with-current-buffer out (goto-char (point-max))
            (insert (svg-bench--table-row (format "%-7s %dpx, %dc" wname w n) st))
            (redisplay t))))
      (with-current-buffer out (goto-char (point-max)) (insert "\n")))
    (switch-to-buffer out) (delete-other-windows) (goto-char (point-min))
    (message "svg-perf-benchmark done")))

;;;###autoload
(defun svg-perf-animation-benchmark (&optional trials reps)
  "Benchmark the line animation across the three bar widths.
One table, a row per width, same statistics as `svg-perf-benchmark'."
  (interactive)
  (unless (display-graphic-p) (user-error "svg-bench needs a graphical frame"))
  (let* ((trials (or trials svg-bench-trials)) (reps (or reps svg-bench-reps))
         (work (get-buffer-create "*svg-bench-work*"))
         (out (get-buffer-create "*svg-bench*")))
    (with-current-buffer out (let ((inhibit-read-only t)) (erase-buffer))
      (insert (format "Line animation (3 circles bouncing in a bar): SVG width vs fps\n"))
      (insert (format "Emacs %s | bar height %dpx | %d trials x %d frames\n\n"
                      emacs-version svg-bench-anim-height trials reps))
      (insert (svg-bench--table-header "animation width")))
    (with-current-buffer work (buffer-disable-undo))
    (switch-to-buffer work) (delete-other-windows)
    (dolist (wspec svg-bench-anim-widths)
      (let* ((wname (car wspec)) (w (cdr wspec))
             (rf (svg-bench--anim-render-fn w))
             (samples (with-current-buffer work
                        (cl-loop repeat trials collect (svg-bench--time rf reps))))
             (st (svg-bench--stats samples)))
        (with-current-buffer out (goto-char (point-max))
          (insert (svg-bench--table-row (format "%-7s %dx%dpx" wname w svg-bench-anim-height) st))
          (redisplay t))))
    (switch-to-buffer out) (delete-other-windows) (goto-char (point-min))
    (message "svg-perf-animation-benchmark done")))

;;;; --------------------------------------------------------------------------
;;;; Live visual demos (record these)
;;;; --------------------------------------------------------------------------

(defvar svg-bench-demo-seconds 12 "Default demo duration; any key stops early.")
(defun svg-bench--demo (kind label)
  "Run a live, labelled demo of KIND with a running fps counter.
Renders at the benchmark's `narrow' bar size, so the live fps matches the
narrow row of the data table; LABEL names the engine and data on screen."
  (unless (display-graphic-p) (user-error "svg-bench needs a graphical frame"))
  (let* ((buf (get-buffer-create "*svg-bench-demo*"))
         (col (svg-bench--color kind))
         (w (cdr (assoc "narrow" svg-bench-bar-widths)))   ; match the table's narrow row
         (h svg-bench-bar-height)
         (n (svg-bench--ncells w))
         (frames 0) (t0 (float-time)) (fps 0) (endt (+ (float-time) svg-bench-demo-seconds)))
    (switch-to-buffer buf) (delete-other-windows)
    (buffer-disable-undo) (setq-local cursor-type nil)
    (setq-local face-remapping-alist (list (list 'default :background "white" :foreground "black")))
    (while (and (< (float-time) endt) (not (input-pending-p)))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "\n\n  "
                (propertize label
                            'face (list :foreground col :weight 'bold :height 2.4))
                "    "
                (propertize (format "%d fps" fps)
                            'face (list :foreground "gray40" :height 1.8))
                "\n\n\n  ")
        (if (eq kind 'builtin-text)
            ;; the changing text IS the benchmarked thing -> colour its background
            (insert (propertize (svg-bench--cells n frames)
                                'face (list :background col :foreground "white")))
          (insert-image (svg-bench--bar-image kind w h frames))))
      (cl-incf frames) (redisplay t)
      (when (>= frames 6) (setq fps (round (/ frames (- (float-time) t0))))))
    (message "%s: %d frames, %.0f fps" label frames
             (/ frames (max 1e-6 (- (float-time) t0))))))

;;;###autoload
(defun svg-perf-text () "Live demo: SVG rendering text." (interactive)
  (svg-bench--demo 'svg-text "SVG  /  text"))

;;;###autoload
(defun svg-perf-icons () "Live demo: SVG rendering icon glyphs." (interactive)
  (svg-bench--demo 'svg-icons "SVG  /  icons"))

;;;###autoload
(defun builtin-perf-text () "Live demo: the native text engine rendering text."
  (interactive)
  (svg-bench--demo 'builtin-text "BUILT-IN  /  text"))

;;;###autoload
(defun svg-perf-animation (&optional width)
  "Live demo: three circles bouncing in a thin SVG bar of WIDTH (default 460).
Representative of an inline status-line animation; shows a running fps counter;
any key stops it."
  (interactive)
  (unless (display-graphic-p) (user-error "svg-bench needs a graphical frame"))
  (let* ((width (or width 460)) (h svg-bench-anim-height)
         (buf (get-buffer-create "*svg-bench-demo*"))
         (frames 0) (t0 (float-time)) (fps 0) (endt (+ (float-time) svg-bench-demo-seconds)))
    (switch-to-buffer buf) (delete-other-windows)
    (buffer-disable-undo) (setq-local cursor-type nil)
    (setq-local face-remapping-alist (list (list 'default :background "white" :foreground "black")))
    (while (and (< (float-time) endt) (not (input-pending-p)))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "\n\n  " (propertize "SVG  /  line animation"
                                     'face (list :foreground "#1f6feb"
                                                 :weight 'bold :height 2.4))
                "    " (propertize (format "%d fps" fps)
                                   'face (list :foreground "gray40" :height 1.8))
                "\n\n\n  ")
        (insert-image (svg-bench--anim-image width frames)))
      (cl-incf frames) (redisplay t)
      (when (>= frames 6) (setq fps (round (/ frames (- (float-time) t0))))))
    (message "line animation %dx%d: %d frames, %.0f fps" width h frames
             (/ frames (max 1e-6 (- (float-time) t0))))))

(provide 'svg-bench)
;;; svg-bench.el ends here
