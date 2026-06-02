;;; copilot-isr.el --- Generative ISR: pick a Copilot completion via consult -*- lexical-binding: t; -*-

;;; Commentary:
;; Incremental Suggesting Read, generative flavor.  GitHub Copilot's panel API
;; (getPanelCompletions, via `copilot-panel-complete') synthesizes several
;; candidate completions for the current point; this collects them and surfaces
;; them through consult -- preview each as ghost text where it would be
;; inserted, choose with RET.  The candidates are *generated* by a model, not
;; matched against any corpus, yet the picker is the same ICR substrate
;; (consult) used everywhere else.
;;
;; Why panel and not inline: inline completion (`copilot-complete' /
;; `copilot-next-completion') returns however many items the server chose --
;; often exactly one, hence "Only one completion is available".  The panel API
;; deliberately produces several.  How many DISTINCT solutions you get still
;; depends on the context: an unambiguous spot yields few, an open-ended one
;; yields more.

;;; Code:

(declare-function consult--read "consult")
(declare-function copilot-panel-complete "copilot")
(declare-function copilot-clear-overlay "copilot")
(declare-function general-define-key "general")
(defvar copilot--notification-handlers)

(defgroup copilot-isr nil
  "Pick a generated Copilot completion through consult."
  :group 'completion :prefix "copilot-isr-")

(defcustom copilot-isr-timeout 20
  "Seconds to wait for Copilot to finish synthesizing before giving up."
  :type 'number)

(defcustom copilot-isr-suppress-panel-buffer t
  "When non-nil, keep Copilot's *copilot-panel* window from popping up.
This module reads the panel solutions and shows them through consult
instead, so the raw panel buffer is just noise.  Set to nil to get
Copilot's native panel window back."
  :type 'boolean)

(defcustom copilot-isr-newline-indicator " ↵ "
  "String marking a line break in the one-line minibuffer candidate.
Each candidate carries the WHOLE body (collapsed to one line, since
vertico shows one line per candidate), so you can filter by any code in
it.  The real multi-line text still previews as ghost text and inserts
intact.  Use e.g. \" / \" if your font lacks the arrow glyph."
  :type 'string)

(defvar copilot-isr--collecting nil)
(defvar copilot-isr--solutions nil
  "Alist of (SCORE . TEXT) collected from the current panel request.")
(defvar copilot-isr--done-fn nil)
(defvar copilot-isr--timeout-timer nil)

(defun copilot-isr--on-solution (msg)
  "Collect one PanelSolution MSG (deduplicated by text) while collecting."
  (when copilot-isr--collecting
    (let ((text  (plist-get msg :completionText))
          (score (or (plist-get msg :score) 0)))
      (when (and text (not (rassoc text copilot-isr--solutions)))
        (push (cons score text) copilot-isr--solutions)))))

(defun copilot-isr--on-done (_msg)
  "Finish collection when Copilot signals PanelSolutionsDone."
  (copilot-isr--finish))

(defun copilot-isr--ensure-handler (method fn)
  "Add FN to Copilot's notification handler list for METHOD if absent.
Uses named functions + `memq', so it is robust across module reloads and
sits alongside Copilot's own handlers (which still fill *copilot-panel*)."
  (let ((handlers (gethash method copilot--notification-handlers)))
    (unless (memq fn handlers)
      (puthash method (cons fn handlers) copilot--notification-handlers))))

(defun copilot-isr--install-handlers ()
  "Ensure our PanelSolution/PanelSolutionsDone collectors are registered."
  (copilot-isr--ensure-handler 'PanelSolution #'copilot-isr--on-solution)
  (copilot-isr--ensure-handler 'PanelSolutionsDone #'copilot-isr--on-done))

(defun copilot-isr--finish ()
  "Stop collecting and hand the solutions to the continuation (deferred)."
  (when copilot-isr--collecting
    (setq copilot-isr--collecting nil)
    (when (timerp copilot-isr--timeout-timer) (cancel-timer copilot-isr--timeout-timer))
    (setq copilot-isr--timeout-timer nil)
    (let ((fn copilot-isr--done-fn))
      (setq copilot-isr--done-fn nil)
      ;; Defer out of the jsonrpc/process-filter context before opening a
      ;; blocking minibuffer.
      (when fn (run-at-time 0 nil fn)))))

(defun copilot-isr--oneline (text)
  "Collapse TEXT to one line for the minibuffer candidate.
Line breaks and their surrounding indentation become
`copilot-isr-newline-indicator', leaving the whole body matchable on a
single line."
  (string-trim
   (replace-regexp-in-string "[ \t]*\n[ \t]*"
                             copilot-isr-newline-indicator
                             (string-trim text))))

(defun copilot-isr--candidates (solutions)
  "Return (CANDS . MAP) from SOLUTIONS (alist (SCORE . TEXT)).
CANDS is a list of unique display STRINGS -- each the WHOLE body collapsed
to one line, so completing-read matches on any code in it (plain strings,
so prescient/vertico filter them happily).  MAP is DISPLAY -> full TEXT."
  (let ((map (make-hash-table :test 'equal))
        (cands nil) (i 0))
    (dolist (s solutions)
      (setq i (1+ i))
      (let* ((text (cdr s))
             (disp (format "%2d. %s" i (copilot-isr--oneline text))))
        ;; Guarantee uniqueness even if two collapsed bodies collide.
        (while (gethash disp map) (setq disp (concat disp " ")))
        (puthash disp text map)
        (push disp cands)))
    (cons (nreverse cands) map)))

(defun copilot-isr--fit (text prefix)
  "Drop PREFIX from TEXT when point already sits in that leading whitespace.
Avoids double-indentation when inserting at an indented point."
  (if (and text (string-match-p "\\`[ \t]*\\'" prefix) (string-prefix-p prefix text))
      (substring text (length prefix))
    (or text "")))

(defun copilot-isr--state (prefix ov)
  "Return a consult state fn previewing the candidate as ghost text via OV.
With `consult--lookup-cdr' the CAND passed here is the completion TEXT."
  (lambda (action cand)
    (pcase action
      ('preview
       (when (overlayp ov)
         (overlay-put ov 'after-string
                      (and (stringp cand)
                           (propertize (copilot-isr--fit cand prefix) 'face 'shadow)))))
      ((or 'return 'exit)
       (when (overlayp ov) (delete-overlay ov))))))

(defun copilot-isr--choose (buf pt)
  "Pick one collected solution for BUF and insert it at PT."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      ;; Clear any inline ghost that re-appeared during the async wait, so the
      ;; preview starts on a clean buffer.
      (when (fboundp 'copilot-clear-overlay) (copilot-clear-overlay))
      (let ((sols (sort (copy-sequence copilot-isr--solutions)
                        (lambda (a b) (> (car a) (car b))))))
        (if (null sols)
            (message "Copilot: no solutions synthesized (try a richer context)")
          (let* ((cm (copilot-isr--candidates sols))
                 (cands (car cm))
                 (map (cdr cm))
                 (table (lambda (&rest _) cands))   ; consult calls (table nil) -> string list
                 (prefix (buffer-substring-no-properties
                          (save-excursion (goto-char pt) (line-beginning-position)) pt))
                 (ov (make-overlay pt pt buf))
                 (choice nil))
            (unwind-protect
                (setq choice
                      (consult--read
                       table
                       :prompt (format "Copilot suggestion (%d): " (length cands))
                       ;; selected DISPLAY string -> TEXT, so both the preview
                       ;; cand and the return value are the completion text.
                       :lookup (lambda (sel &rest _) (gethash sel map))
                       :category 'copilot-isr
                       :sort nil
                       :require-match t
                       :preview-key 'any            ; preview as you cycle
                       :state (copilot-isr--state prefix ov)))
              (when (overlayp ov) (delete-overlay ov)))
            ;; Clear any lingering Copilot inline ghost so it does not paint
            ;; over the inserted text (otherwise it shows until you hit escape).
            (when (fboundp 'copilot-clear-overlay) (copilot-clear-overlay))
            (when (stringp choice)
              (goto-char pt)
              (insert (copilot-isr--fit choice prefix)))))))))

;;;###autoload
(defun copilot-isr-panel-read ()
  "Synthesize several Copilot completions and pick one via consult.
Run with point where the completion should go (e.g. an empty function
body).  Each candidate previews as ghost text at point; RET inserts it."
  (interactive)
  (require 'consult)
  (require 'copilot)
  (copilot-isr--install-handlers)
  ;; Drop the inline ghost showing now, so it does not compete with the
  ;; consult preview that takes over.
  (when (fboundp 'copilot-clear-overlay) (copilot-clear-overlay))
  (let ((buf (current-buffer))
        (pt (point)))
    (setq copilot-isr--solutions nil
          copilot-isr--collecting t
          copilot-isr--done-fn (lambda () (copilot-isr--choose buf pt)))
    (when (timerp copilot-isr--timeout-timer) (cancel-timer copilot-isr--timeout-timer))
    (setq copilot-isr--timeout-timer
          (run-at-time copilot-isr-timeout nil #'copilot-isr--finish))
    (message "Copilot: synthesizing solutions... (consult opens when ready)")
    (copilot-panel-complete)))

;; Keep Copilot's panel buffer from stealing a window -- we show the solutions
;; through consult instead.  (The buffer is still populated, just not displayed.)
(when copilot-isr-suppress-panel-buffer
  (add-to-list 'display-buffer-alist
               '("\\`\\*copilot-panel\\*\\'"
                 (display-buffer-no-window)
                 (allow-no-window . t))))

(with-eval-after-load 'general
  (when (boundp 'menu-lookup-map)
    (general-define-key :keymaps 'menu-lookup-map "c" 'copilot-isr-panel-read)))

(provide 'copilot-isr)
;;; copilot-isr.el ends here
