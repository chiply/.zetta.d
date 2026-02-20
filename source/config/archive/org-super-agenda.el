(use-package org-super-agenda
  :init
  (setq zetta-org-super-agenda-auto-show-groups
        '("Inbox"
          "In Mind"
          "Sync"
          "Today"
          "Async"
          "Ready to Run"
          "Open"
          "Upcoming Events"
          "Recurring Meetings"
          "Knowledge Debt"
          "Recurring Tasks"
          "Block"
          "No State"
          "Holding")
        )

  (setq org-super-agenda-groups-main
        '(
          (:name "In Mind" :todo ("REMINDER")) ;; wordplay for 'keep in mind'
          (:name "Sync" :todo ("CODING"
                               "IDEATING"
                               "IN-REVIEW"
                               "ATTENDING"
                               "LEARNING"
                               "DEBRIEF"))
          (:name "Async" :todo ("RUNNING" "TESTING"))
          (:name "Today" :todo ("TODAY"))
          (:name "Block" :todo ("INFO-BLOCK" "WORK-BLOCK" "SCHEDULE-BLOCK"))
          (:name "Ready to Run" :todo ("TO-RUN"))
          (:name "Upcoming Events" :todo ("SCHEDULED"))
          (:name "Open" :todo ("OPEN"))
          (:name "Noted" :todo ("NOTED"))
          (:name "Recurring Tasks" :todo ("REPETETIVE-TASK"))
          (:name "Recurring Meetings" :todo ("RECURRING:MEETING"))
          (:name "Knowledge Debt" :todo ("TO-LEARN"))
          (:name "Assigned" :todo ("ASSIGNED"))
          (:name "Inbox" :todo ("INBOX"))
          (:name "Holding" :todo ("HOLDING"))
          (:name "To Archive" :todo ("CLOSED"))
          ))

  (defun zetta-org-super-agenda-origami-fold-default ()
    "Fold certain groups by default in Org Super Agenda buffer."
    (when org-super-agenda-groups
      (progn
        (forward-line 2)
        (cl-loop do (origami-forward-toggle-node (current-buffer) (point))
                 while (origami-forward-fold-same-level (current-buffer) (point)))
        (--each zetta-org-super-agenda-auto-show-groups
          (goto-char (point-min))
          (when (re-search-forward (rx-to-string `(seq bol " " ,it)) nil t)
            (origami-show-node (current-buffer) (point))))
        )
      )
    )

  (defun zetta-org-agenda (cmd grp)
    "Run org-agenda with the given CMD.  Use groups specified by
GRP.  Note grouping is performed by org-super-agenda if grouping
is provided."
    (if grp
        (let ((org-super-agenda-groups grp)) (org-agenda nil cmd))
      (let ((org-super-agenda-groups nil)) (org-agenda nil cmd))
      )
    ;; set text scale
    ;;(unless (equal text-scale-mode-amount -2) (text-scale-set -2))
    )

  ;; common enough that I'm making it's own function
  (defun zetta-org-agenda-main ()
    (interactive)
    (zetta-org-agenda "1" org-super-agenda-groups-main))

  (defun zetta-refresh-agenda ()
    "Activates the agenda, refreshes it.  Cursor should remain
where is was when zetta-refresh-agenda was called"
    (interactive)
    (save-selected-window
      (zetta-org-agenda-main)
      (org-agenda-redo)
      )
    (message "AGENDA REFRESHED")
    )

  (defun zetta-hide-agenda ()
    (interactive)
    (zetta-org-agenda-main)
    (org-agenda-quit)
    ;; this restores the point to where it was when the function was called
    )

  (defun zetta-highlight-agenda ()
    (interactive)
    ;; web link
    (highlight-regexp "\\[\\[https.*?\\]\\]" 'modus-themes-nuanced-blue)
    ;; roam / org link (unfortunately there is no distinction here)
    (highlight-regexp "\\[\\[id.*?\\]\\]" 'modus-themes-nuanced-green)
    ;; file link
    (highlight-regexp "\\[\\[file.*?\\]\\]" 'modus-themes-nuanced-red)

    ;; headers
    (highlight-regexp "Block" 'modus-themes-nuanced-red)
    (highlight-regexp "Sync" 'modus-themes-refine-green)
    (highlight-regexp "Async" 'modus-themes-nuanced-green)

    ;; tracebacks
    (highlight-regexp "-->" 'modus-themes-refine-red)
    )

  (general-define-key
   :keymaps 'menu-run-map
   "a" (** zetta-org-agenda-main))


  (org-super-agenda-mode)

  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'org-super-agenda-header nil
                                      :underline nil
                                      :overline nil
                                      :extend t
                                      :box nil
                                      :foreground brushup-fg-3
                                      :weight 'bold
                                      )
                  )
               )


  ;;:hydra
  ;;(defhydra+ hydra-run ()
    ;;("a" zetta-org-agenda-main "Org Agenda")
    ;;)


  :general
  (
   :keymaps '(org-super-agenda-header-map)
   "j"  nil
   "k"  nil
   "g" nil
   "G" nil
   "," nil
   "/" nil
   "C" nil
   "c" nil
   "<tab>" nil
   )
  (
   :keymaps '( org-agenda-mode-map org-super-agenda-header-map  )
   "vt" '(lambda () (interactive)
           (zetta-org-agenda "1" org-super-agenda-groups-main))
   "vT" '(lambda () (interactive)
           (zetta-org-agenda "2" nil))
   "va" '(lambda () (interactive)
           (zetta-org-agenda "3" nil))
   )
  (
   :keymaps '(org-super-agenda-header-map)
   "<tab>" 'origami-toggle-node
   )

  :hook ((org-agenda-mode . origami-mode)
         (org-agenda-finalize . zetta-org-super-agenda-origami-fold-default)
         (org-agenda-finalize . zetta-highlight-agenda)
         )
  )
