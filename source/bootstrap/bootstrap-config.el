;; -*- lexical-binding: t; -*-

(defvar bootstrap-version)

(setq straight-base-dir (expand-file-name "source" user-emacs-directory))

(let ((bootstrap-file
       (expand-file-name
        "source/straight/repos/straight.el/bootstrap.el"
        user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))



(provide 'bootstrap-config)
