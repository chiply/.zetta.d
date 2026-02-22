;;; say.el --- Configure text-to-speech -*- lexical-binding: t; -*-

(defun my/async-shell-command (cmd)
  (let ((bufnm "*tts*")
        (process-connection-type nil)
        (zmc-async-shell-command-spinners-enable t))
    ;; if the buffer exists, kill it
    (when (get-buffer bufnm)
      (kill-buffer bufnm))
    (async-shell-command cmd bufnm)))

;; write function that writes the text in region to a file
;; ~/.dictation-data
(defun my/async-shell-command-say (start end)
  "Write the region from START to END to a file in ~/.dictation-data."
  (interactive "r")
  (let* ((text (buffer-substring-no-properties start end))
         (file-path (expand-file-name "~/.say-file")))
    (with-temp-file file-path
      (insert text)
      (my/async-shell-command
       (concat "say"
               " --interactive"
               " --quality=127"
               " --rate 190"
               " --voice \"Jamie (Premium)\""
               " --input-file " file-path)))))

(general-define-key :keymaps 'override "s-:" 'my/async-shell-command-say)
;;; say.el ends here
