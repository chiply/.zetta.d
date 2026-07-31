;;; app/llm-convo.el --- ChatGPT conversations -> kb -*- lexical-binding: t; -*-

;;; Commentary:
;; Mac-side entry to the llm-convo pipeline: converts a ChatGPT share
;; link into ~/kb/llm-convo/<title>.org immediately by running the hub's
;; converter script locally (it lives in the dotfiles repo, so this
;; machine has it too).  The phone path is the share-sheet shortcut that
;; appends to llm-convo/queue.txt, drained by the hub every 15 minutes.

;;; Code:

(defun zetta-kb-save-llm-convo (url)
  "Convert the ChatGPT share URL into ~/kb/llm-convo/ right now."
  (interactive (list (read-string "ChatGPT share URL: ")))
  (async-shell-command
   (format "python3 %s %s"
           (shell-quote-argument
            (expand-file-name "~/.files/hub/bin/llm_convo_sync.py"))
           (shell-quote-argument url))
   "*kb llm-convo*"))

;;; app/llm-convo.el ends here
