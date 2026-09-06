;;; canvas-demo.el --- Canvas animation demos -*- lexical-binding: t; -*-

;; Requires Emacs 32 (canvas landed on master 2026-08-16, commit d5f515e4a33).
;; Check with (image-type-available-p 'canvas).

;;; Commentary:

;; A canvas is an image with a writable ARGB32 pixel buffer that can be
;; redrawn without allocating a new Lisp object each frame.  That is the whole
;; point: ordinary Emacs images make you rebuild an image spec per frame, which
;; is why animation in Emacs has always been either a GIF or a slideshow.
;;
;; Two ways to get pixels in, and the difference is the whole performance
;; story:
;;
;;   :data + (canvas-refresh c 'reload-data)   Lisp writes a vector, Emacs
;;                                             copies the whole thing into the
;;                                             pixel buffer every frame.
;;   canvas_data() from a dynamic module       a uint32_t* straight into the
;;                                             pixel buffer.  No copy.
;;
;; This file is the first one only.  It exists to prove the pipeline and to
;; MEASURE it, so the numbers decide whether a native module is worth it
;; rather than a hunch.  `canvas-demo-benchmark' prints the real frame cost.

;;; Code:

(require 'cl-lib)

(defgroup canvas-demo nil
  "Canvas animation demos."
  :group 'multimedia)

(defcustom canvas-demo-width 200
  "Canvas width in pixels."
  :type 'natnum)

(defcustom canvas-demo-height 120
  "Canvas height in pixels."
  :type 'natnum)

(defcustom canvas-demo-fps 30
  "Target frames per second."
  :type 'number)

(defvar-local canvas-demo--timer nil
  "Animation timer for this buffer, so a second demo cannot orphan the first.")

;;;; Pixels

;; ARGB32, most significant byte first, identical on every platform -- the
;; manual is explicit about that, so no endianness dance is needed.
(defsubst canvas-demo--argb (a r g b)
  (logior (ash a 24) (ash r 16) (ash g 8) b))

;; Trig in the inner loop is the obvious cost, so it is table-driven: one
;; lookup and an integer AND instead of a float sin() per pixel per frame.
;; Size is a power of two to make the wrap a mask.
(defconst canvas-demo--sin-bits 8)
(defconst canvas-demo--sin-size (ash 1 canvas-demo--sin-bits))
(defconst canvas-demo--sin-mask (1- canvas-demo--sin-size))

(defconst canvas-demo--sin
  (let ((v (make-vector canvas-demo--sin-size 0)))
    (dotimes (i canvas-demo--sin-size)
      ;; scaled to 0..255 so the result can be used as a colour byte directly
      (aset v i (floor (* 127.5 (1+ (sin (/ (* 2 float-pi i)
                                            canvas-demo--sin-size)))))))
    v)
  "Sine lookup table, one period, values 0..255.")

(defsubst canvas-demo--sin-at (i)
  (aref canvas-demo--sin (logand i canvas-demo--sin-mask)))

(defun canvas-demo--plasma (vec width height phase)
  "Render one plasma frame into VEC at PHASE.
Classic two-axis interference pattern: cheap, and it writes every pixel,
so the frame cost measured here is the worst case rather than a flattering
one."
  (dotimes (y height)
    (let ((row (* y width))
          (ny (canvas-demo--sin-at (+ (* y 3) phase))))
      (dotimes (x width)
        (let* ((nx (canvas-demo--sin-at (+ (* x 2) phase)))
               (r (logand (+ nx ny) 255))
               (g (logand (+ nx (ash ny 1) phase) 255))
               (b (logand (- 255 nx) 255)))
          (aset vec (+ row x) (canvas-demo--argb 255 r g b)))))))

;;;; The demo

(defun canvas-demo--make (width height)
  "Return a fresh canvas image of WIDTH by HEIGHT, and its data vector."
  (let* ((vec (make-vector (* width height) (canvas-demo--argb 255 0 0 0)))
         ;; `create-image' with DATA-P non-nil takes the vector directly.
         ;; :id must be a symbol and unique per canvas -- two canvases sharing
         ;; an id share a pixel buffer, which is a confusing way to find out.
         (img (create-image vec 'canvas t
                            :data-width width
                            :data-height height
                            :id (gensym "canvas-demo-"))))
    (cons img vec)))

;;;###autoload
(defun canvas-demo-insert (&optional width height)
  "Insert an animated plasma canvas at point.
WIDTH and HEIGHT default to `canvas-demo-width' and `canvas-demo-height'.
Stop it with \\[canvas-demo-stop]."
  (interactive)
  (unless (image-type-available-p 'canvas)
    (user-error "This Emacs has no canvas support (needs Emacs 32+)"))
  (let* ((w (or width canvas-demo-width))
         (h (or height canvas-demo-height))
         (cell (canvas-demo--make w h))
         (img (car cell))
         (vec (cdr cell))
         (phase 0)
         (buf (current-buffer)))
    (insert (propertize "#" 'display img 'canvas-demo t))
    (insert "\n")
    (canvas-demo-stop)
    (setq canvas-demo--timer
          (run-at-time
           0 (/ 1.0 canvas-demo-fps)
           (lambda ()
             ;; The buffer can be killed out from under a live timer.
             (if (not (buffer-live-p buf))
                 (cancel-timer canvas-demo--timer)
               (with-current-buffer buf
                 (canvas-demo--plasma vec w h phase)
                 (setq phase (1+ phase))
                 ;; 'reload-data because Lisp wrote the :data vector, not the
                 ;; pixel buffer.  A module writing canvas_data passes nil.
                 ;; No explicit `redisplay': inside a timer Emacs does it.
                 (canvas-refresh img 'reload-data))))))
    (message "canvas-demo: %dx%d at %d fps target -- M-x canvas-demo-stop"
             w h canvas-demo-fps)))

;;;###autoload
(defun canvas-demo-stop ()
  "Stop the animation running in this buffer."
  (interactive)
  (when (timerp canvas-demo--timer)
    (cancel-timer canvas-demo--timer))
  (setq canvas-demo--timer nil))

;;;###autoload
(defun canvas-demo-benchmark (&optional width height frames)
  "Measure the real cost of a canvas frame, with no display in the way.

Splits the two halves that matter, because they scale differently and only
one of them a native module can remove:

  render   Lisp writing the :data vector
  refresh  Emacs copying that vector into the pixel buffer

A dynamic module writing `canvas_data' directly deletes both."
  (interactive)
  (let* ((w (or width canvas-demo-width))
         (h (or height canvas-demo-height))
         (n (or frames 60))
         (cell (canvas-demo--make w h))
         (img (car cell))
         (vec (cdr cell))
         (t0 (float-time)))
    (dotimes (i n) (canvas-demo--plasma vec w h i))
    (let* ((render (- (float-time) t0))
           (t1 (float-time)))
      (dotimes (_ n) (canvas-refresh img 'reload-data))
      (let* ((refresh (- (float-time) t1))
             (total (+ render refresh))
             (px (* w h)))
        (message
         (concat "canvas %dx%d (%d px), %d frames\n"
                 "  render   %6.1f ms/frame\n"
                 "  refresh  %6.1f ms/frame\n"
                 "  total    %6.1f ms/frame  ->  %.1f fps ceiling")
         w h px n
         (* 1000 (/ render n)) (* 1000 (/ refresh n))
         (* 1000 (/ total n)) (/ n total))))))

(provide 'canvas-demo)
;;; canvas-demo.el ends here
