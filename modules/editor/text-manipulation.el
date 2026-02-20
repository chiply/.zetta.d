(defun split-region-by-periods (start end)
  "Replace periods and any trailing whitespace in the region with period followed by two newlines."
  (interactive "r")
  (save-restriction
    (narrow-to-region start end)
    (goto-char (point-min))
    (while (re-search-forward "\\. *" nil t)
      (replace-match ".\n\n"))))


(general-define-key :states 'visual :keymaps 'override "s-/" 'split-region-by-periods)
