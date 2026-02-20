(use-package org-roam
  :init
  (setq org-roam-directory (file-truename "~/.files/org-roam"))
  (setq org-roam-db-location (expand-file-name ".data/org-roam/org-roam.db" user-emacs-directory))
  (setq org-roam-v2-ack t)

  :config
  (org-roam-db-autosync-mode)
  (setq org-roam-completion-everywhere t)

  (defun zetta-org-roam-node-find ()
    (interactive)
    (setq zetta-captured-from-win (selected-window))
    (org-roam-node-find))

  (setq org-roam-capture-templates
        '(
          ("d" "default" plain "%?" :target
           (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n")
           :unnarrowed t)
          ("D" "default" plain "%?\n%a\n%F" :target
           (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n")
           :unnarrowed t)
          )
        )

  (defun zetta-org-roam-capture () (interactive)
         (setq zetta-captured-from-win (selected-window))
         (org-roam-capture))


  (defun zetta-get-header-from-link (s)
    (interactive)
    (nth 0 (split-string
            (nth 3 (split-string s "\\["))
            "]"
            )))
  (defun ndk/link-fast-copy ()
    (interactive)
    (let* ((context (org-element-context))
           (type (org-element-type context))
           (beg (org-element-property :begin context))
           (end (org-element-property :end context)))
      (when (eq type 'link)

        (zetta-get-header-from-link
         (buffer-substring beg end)
         )

        )))

  (defun zetta-jump-to-agenda-entry (&optional noselect)
    (interactive)
    ;; agenda command (from lambda)
    (let ((buf (current-buffer))
          (re (concat (ndk/link-fast-copy) "$"))
          )

      (progn
        (zetta-org-agenda "1" org-super-agenda-groups-main)
        (org-agenda-redo)
        )

      ;; insert from ndk
      (or
       (search-forward-regexp re nil t)
       (search-backward-regexp re nil t)
       )
      ;;(zetta-agenda-org-goto)

      (if noselect
          (select-window (get-buffer-window buf))
        (progn
          (zetta-org-agenda "1" org-super-agenda-groups-main)
          (org-agenda-redo)
          )
        )


      )
    )

  (defun zetta-org-roam-list-node-titles ()
    (interactive)
    (-map (lambda (x) `(,(org-roam-node-title x))) (org-roam-node-list))
    )

  (defun zetta-org-roam-agenda-set-tag ()
    (interactive)
    (org-agenda-set-tags (replace-regexp-in-string
                          "-" "_"
                          (replace-regexp-in-string
                           " " "_"
                           (completing-read "org-roam " (zetta-org-roam-list-node-titles)))))
    (org-agenda-redo)
    )

  :general 
  (
   :keymaps 'override
   "s-o" 'zetta-org-roam-node-find
   "s-O" 'zetta-org-roam-capture
   "s-i" 'org-roam-node-insert
   )
  )
