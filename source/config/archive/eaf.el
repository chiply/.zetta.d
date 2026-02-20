;; this is incidentally a great example of using a striaght recipe
(use-package eaf
  :ensure (eaf
           :type git
           :host github
           :repo "emacs-eaf/emacs-application-framework"           
           :files ("*.el" "*.py" "core" "app" "*.json")
           ;; Straight won't try to search for these packages when we
           ;; make further use-package invocations for them
           :includes (eaf-pdf-viewer
                      eaf-browser
                      eaf-image-viewer
                      eaf-terminal
                      eaf-org-previewer
                      eaf-markdown-previewer
                      )
           :pre-build ("python3"
                       "install-eaf.py"
                       "--install"
                       "pdf-viewer"
                       "browser"
                       "image-viewer"
                       "terminal"
                       "org-previewer"
                       "markdown-previewer"
                       "--ignore-sys-deps")
           )

  :commands (eaf-open eaf-open-browser)

  ;; Evil mode doesn't work well with eaf keybindings.
  :init (evil-set-initial-state 'eaf-mode 'emacs)

  :config
  (defun zetta-eaf-switch-to-eww ()
    (interactive)
    (eww-browse-url (eaf-get-path-or-url))
    )

  (defun zetta-eaf-org-agenda ()
    (interactive)
    (zetta-org-agenda "1" org-super-agenda-groups-main)
    (org-agenda-redo) 
    )
  (require 'eaf-browser)
  (require 'eaf-pdf-viewer)
  ) 


;; note: started up with super weird display settings
(use-package eaf-browser
  :ensure nil
  :custom
  (eaf-browser-continue-where-left-off t)
  (eaf-browser-enable-adblocker t)
  :config
  (eaf-bind-key zetta-eaf-switch-to-eww "C-&" eaf-browser-keybinding)
  (eaf-bind-key nil "," eaf-browser-keybinding)

  (eaf-bind-key consult-buffer ",b" eaf-browser-keybinding)
  (eaf-bind-key consult-buffer ",B" eaf-browser-keybinding)
  (eaf-bind-key execute-extended-command ",x" eaf-browser-keybinding)
  (eaf-bind-key project-find-file ",p" eaf-browser-keybinding)
  (eaf-bind-key find-file ",f" eaf-browser-keybinding)
  (eaf-bind-key kill-current-buffer ",b" eaf-browser-keybinding)
  (eaf-bind-key zetta-eaf-org-agenda ",a" eaf-browser-keybinding)
  )

;; note pymupdf is a dependency!!!
;; (use-package eaf-pdf-viewer
;;   :ensure nil
;;   :config
;;   (eaf-bind-key nil "," eaf-pdf-viewer-keybinding)
;;   )

(use-package eaf-image-viewer
  :ensure nil
  :config
  (eaf-bind-key nil "," eaf-image-viewer-keybinding)
  )

(use-package eaf-markdown-previewer
  :ensure nil
  :config
  (eaf-bind-key nil "," eaf-markdown-previewer-keybinding)
  )

(use-package eaf-org-previewer
  :ensure nil
  :config
  (eaf-bind-key nil "," eaf-org-previewer-keybinding)
  )

(setq eaf-python-command "~/.pyenv/shims/python3")
