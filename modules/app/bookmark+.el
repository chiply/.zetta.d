;;; bookmark+.el --- Configure bookmark+ -*- lexical-binding: t; -*-

(use-package bookmark+
  :ensure (bookmark+
           :fetcher github
           :repo "emacsmirror/bookmark-plus"
           :files (:defaults
                   "*.el")
           :main "bookmark+.el")
  :config
  (defun zetta-bookmark-create ()
    (interactive)
    (bookmark-set)
    (bmkp-set-lighting-for-this-buffer 'rfringe nil 'auto nil t)
    (bookmark-save))

  ;;;;;;;;;;;;;;;;;;;;;;;;;; HACK
  ;; https://takeonrules.com/2024/12/03/monkey-patch-fix-for-bookmark-for-emacs-30/
  (add-hook 'bmkp-write-bookmark-file-hook
            #'jf/bookmark+/remediate-bookmark-file)

  (defun jf/bookmark+/remediate-bookmark-file (&optional file)
    "Fix FILE format to conform to `bookmark+'.

In updating to Emacs 30.x, I encountered problems with saving the
bookmark file.  What was happening is that the read format is assumed to
have a line that is only \")\".  However the writing was not doing that.

This function remediates the observed written format to conform to the
expected read format."
    (with-current-buffer
        (find-file-noselect (or file bookmark-default-file))
      (save-excursion
        (goto-char (point-max))
        (if (re-search-backward "^)" nil t)
            (message "%s already well formatted" bookmark-default-file)
          (progn
            (goto-char (point-max))
            (re-search-backward ")")
            (insert "\n")
            (save-buffer))))))
  ;;;;;;;;;;;;;;;;;;;;;;;;;; END HACK

  :general
  (
   :keymaps 'override
   :prefix "s-b"
   "n" 'zetta-bookmark-create
   )
  :hook ((org-mode python-ts-mode emacs-lisp-mode)
         . (lambda ()
             (call-interactively 'bmkp-light-bookmarks))))
;;; bookmark+.el ends here
