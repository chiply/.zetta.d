;;; profile.el --- CPU-profile the SVG render path (for flamegraphs) -*- lexical-binding: t; -*-

;; Companion to svg-bench.el.  CPU-profiles the SVG rendering loop and writes
;; artifacts you can turn into a flamegraph.  Load AFTER svg-bench.el, in a
;; GRAPHICAL Emacs:
;;
;;   emacs -Q -l svg-bench/svg-bench.el -l svg-bench/profile.el
;;   M-x svg-bench-profile
;;
;; It writes:
;;   /tmp/svg-bench-cpu.profile     raw CPU profile  -> M-x flamegraph-find-profile
;;   /tmp/svg-bench-cpu-report.txt  the textual profiler-report (top of the tree)
;;
;; For a LIVE flamegraph (no saved file), skip this and do:
;;   M-x profiler-start RET cpu RET
;;   M-x svg-perf-benchmark          ; or use Emacs normally for a while
;;   M-x flamegraph-profiler-report  ; renders current profiler data as a flamegraph

(require 'profiler)
(require 'cl-lib)

(defvar svg-bench-profile-output "/tmp/svg-bench-cpu.profile"
  "Where `svg-bench-profile' writes the raw CPU profile (for flamegraph-find-profile).")
(defvar svg-bench-profile-report "/tmp/svg-bench-cpu-report.txt"
  "Where `svg-bench-profile' writes the textual profiler report.")

;;;###autoload
(defun svg-bench-profile (&optional width frames)
  "CPU-profile FRAMES (default 4000) of SVG-text rendering at WIDTH (default 1800).
Writes a raw profile to `svg-bench-profile-output' (open with
`flamegraph-find-profile') and a text report to `svg-bench-profile-report'.
GC is left at its normal threshold here (unlike the benchmark) so collection
shows up in the profile too."
  (interactive)
  (unless (display-graphic-p) (user-error "svg-bench-profile needs a graphical frame"))
  (unless (fboundp 'svg-bench--bar-render-fn)
    (user-error "Load svg-bench.el first"))
  (let* ((width (or width 1800))
         (frames (or frames 4000))
         (rf (svg-bench--bar-render-fn 'svg-text width))
         (buf (get-buffer-create "*svg-bench-profile*")))
    (switch-to-buffer buf) (delete-other-windows) (buffer-disable-undo)
    (clear-image-cache)
    (profiler-reset)
    (profiler-start 'cpu)
    (dotimes (i frames)
      (funcall rf (1+ i))
      (redisplay t))
    (profiler-stop)
    ;; Raw profile -> the file flamegraph-find-profile reads.
    (profiler-write-profile (profiler-cpu-profile) svg-bench-profile-output)
    ;; Text report -> human-readable top of the call tree.
    (profiler-report)
    (let ((rb (cl-find-if (lambda (b) (string-match-p "Profiler-Report" (buffer-name b)))
                          (buffer-list))))
      (when rb
        (with-current-buffer rb
          (write-region (point-min) (point-max) svg-bench-profile-report))))
    (message "Wrote %s + %s — visualise: M-x flamegraph-find-profile RET %s"
             svg-bench-profile-output svg-bench-profile-report svg-bench-profile-output)))

(provide 'svg-bench-profile)
;;; profile.el ends here
