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

(defvar evil-markers-alist)
(declare-function diff-hl-changes "diff-hl")

;;;; Provider: TODO/FIXME/HACK keywords -> coloured dots

(defun svg-margin-example-todo (buffer)
  "Return dot indicators for TODO/FIXME/HACK keywords in BUFFER."
  (with-current-buffer buffer
    (let (out)
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "\\_<\\(TODO\\|FIXME\\|HACK\\)\\_>" nil t)
          (push (list :pos (match-beginning 0)
                      :shape 'dot
                      :priority 7
                      :color (pcase (match-string 1)
                               ("TODO" "#d29922") ("FIXME" "#f85149") (_ "#a371f7"))
                      :help (match-string 1))
                out)))
      out)))

;;;; Provider: VC hunks (diverted from the diff-hl/git-gutter fringe)

(defun svg-margin-example-vc (buffer)
  "Return vertical-bar indicators for VC hunks in BUFFER (via `diff-hl-changes').
Drawn at the inner column (priority 9) so it hugs the text like a gutter."
  (with-current-buffer buffer
    (when (fboundp 'diff-hl-changes)
      (let (out)
        (dolist (hunk (ignore-errors (diff-hl-changes)))
          (cl-destructuring-bind (line len type) hunk
            (dotimes (i (max 1 len))
              (push (list :line (+ line i)
                          :shape 'bar
                          :priority 9
                          :color (pcase type
                                   ('insert "#3fb950") ('delete "#f85149") (_ "#d29922"))
                          :help (symbol-name type))
                    out))))
        out))))

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
                          :text (char-to-string char)
                          :priority 5
                          :face 'warning
                          :help (format "evil mark `%c'" char))
                    out))))
        out))))

(defun svg-margin-example--mark-refresh (&rest _)
  "Refresh svg-margin after an evil mark changes."
  (svg-margin-refresh))

;;;; Wiring

;;;###autoload
(defun svg-margin-example-setup ()
  "Register the example providers, divert the left fringe, and enable the mode.
Demonstrates several sources stacking columns on one line: a VC bar nearest
the text, a TODO dot, and an evil-mark letter, all in the left margin."
  (interactive)
  (svg-margin-register-provider 'todo #'svg-margin-example-todo)
  (when (fboundp 'diff-hl-changes)
    (svg-margin-register-provider 'vc #'svg-margin-example-vc))
  (when (boundp 'evil-markers-alist)
    (svg-margin-register-provider 'evil-marks #'svg-margin-example-evil-marks)
    (advice-add 'evil-set-marker :after #'svg-margin-example--mark-refresh))
  (setq svg-margin-disable-fringe 'left)
  (svg-margin-mode 1)
  (message "svg-margin example active: VC + TODO + evil marks in the left margin"))

(defun svg-margin-example-teardown ()
  "Undo `svg-margin-example-setup' in the current buffer."
  (interactive)
  (svg-margin-mode -1)
  (svg-margin-unregister-provider 'todo)
  (svg-margin-unregister-provider 'vc)
  (svg-margin-unregister-provider 'evil-marks)
  (advice-remove 'evil-set-marker #'svg-margin-example--mark-refresh))

(provide 'svg-margin-examples)
;;; svg-margin-examples.el ends here
