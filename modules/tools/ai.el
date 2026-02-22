;;; ai.el --- Configure AI tools -*- lexical-binding: t; -*-

;;(use-package copilot
  ;;:straight (:host github :repo "copilot-emacs/copilot.el" :files ("dist" "*.el"))
  ;;:demand t
  ;;:config
  ;;;;(setq copilot-server-executable (concat "node " (expand-file-name "~/node_modules/@github/copilot-language-server/dist/language-server.js ") "--stdio "))
  ;;;; modes
;;
  ;;(add-hook 'prog-mode-hook 'copilot-mode)
  ;;(add-hook 'markdown-mode-hook 'copilot-mode)
  ;;(add-hook 'org-mode-hook 'copilot-mode)
  ;;(add-hook 'sql-mode-hook 'copilot-mode)
  ;;(add-hook 'mermaid-mode-hook 'copilot-mode)
  ;;(add-hook 'emacs-lisp-mode 'copilot-mode)
  ;;(add-hook 'lisp-interaction-mode 'copilot-mode)
  ;;(add-hook 'yaml-mode-hook 'copilot-mode)
  ;;(add-hook 'dockerfile-mode 'copilot-mode)
;;
  ;;;; face
  ;;(set-face-attribute 'copilot-overlay-face nil :foreground brushup-bg-5 :inherit nil)
  ;;(setq copilot-indent-offset-warning-disable t)
 ;;
  ;;:general (:keymaps '(copilot-completion-map)
                     ;;"C-<return>" 'copilot-accept-completion
                     ;;"C-S-f" 'copilot-accept-completion-by-word
                     ;;"C-S-M-f" 'copilot-accept-completion-by-line
                     ;;;;"C-S-M-f" 'copilot-accept-completion-by-paragraph
                     ;;"C-n" 'copilot-next-completion
                     ;;"C-p" 'copilot-previous-completion))

;; TODO authenticate
(use-package copilot-chat
  :config
  (setq copilot-chat-model "claude-3.5-sonnet"))

(use-package mcp
  :ensure (mcp :type git :host github :repo "lizqwerscott/mcp.el")
  :demand t
  :config
  ;; NOTE prepend mcp
  (setq zetta-mcp-cautious-tools '("mcp-bash-mcp"))

  (require 'mcp-hub)
  (setq
   mcp-hub-servers
   `(("fetch" . (:command "uvx" :args ("mcp-server-fetch")))
     ("git" . (:command "uvx" :args ("mcp-server-git")))
     ;; NOTE this doesn't capture starting the server, but I could
     ;; probably get it to do that with the stdio option, it's just a
     ;; matter of gettting the corrrect directoyr... but instead
     ;; should lean towards a pattern that defines the servers in
     ;; .files, installs them automatically in bootstrap (not sure if
     ;; pipx would be the thing to use)... or could dockerize? not
     ;; sure, but could probably have a better pattern... maybe each
     ;; server defines a command that becomes available when the
     ;; package is installed with pipx, can prompt an ai for this
     ("fastmcp_demo" . (:url "http://127.0.0.1:8000/mcp"))
     ("fastmcp_docs" . (:url "https://gofastmcp.com/mcp"))
     ("playwright" . (:command "npx" :args ("@playwright/mcp@latest")))
     ("Demo" . (:command "poetry" :args ("run" "fastmcp"
                                                   "run" "/Users/charles.baker/.files/mcp_servers/servers/src/servers/server1.py:mcp"
                                                   )))
     ("memory" . (
                  :command "npx"
                  :args ("-y"
                         "@modelcontextprotocol/server-memory")))
     ("mcp-compass" . (:command "npx" :args ("-y" "@liuyoshio/mcp-compass")))
     ;; NOTE unable to make this confirm only, see below.  same
     ;; goes for any tool I define outside of gptel-make-tool, at
     ;; least for now, should make a TODO to resolve this
     ;;("bash-mcp" .
     ;;(
     ;;:command "npx"
     ;;:args ("bash-mcp"))
     ;;)
     ("mcp-run-python" .
      (
       :command "deno"
       :args (
              "run"
              "-N"
              "-R=node_modules"
              "-W=node_modules"
              "--node-modules-dir=auto"
              "jsr:@pydantic/mcp-run-python"
              "stdio"
              ))
      )
     ("filesystem" .
      (
       :command "npx"
       :args ("-y" "@modelcontextprotocol/server-filesystem"
              ,(expand-file-name "~/") ;; more dirs
              )))
     ("sequentialthinking" .
      (
       :command "docker"
       :args ("run" "--rm" "-i" "mcp/sequentialthinking")))))

  (defun gptel-mcp-register-tool ()
    (interactive)
    (let ((tools (mcp-hub-get-all-tool :asyncp t :categoryp t)))
      (mapcar #'(lambda (tool)
                  (when (member (plist-get tool :category) zetta-mcp-cautious-tools)
                    ;; NOTE this doesn't seem to work... not sure
                    ;; why... for now, preferring not to use bash-mcp
                    ;; as I can't make it promp-only
                    (plist-put tool :comfirm t))
                  (apply #'gptel-make-tool tool))
              tools)))

  (defun gptel-mcp-use-tool ()
    (interactive)
    (let ((tools (mcp-hub-get-all-tool :asyncp t :categoryp t)))
      (mapcar #'(lambda (tool)
                  (let ((path (list (plist-get tool :category)
                                    (plist-get tool :name))))
                    (push (gptel-get-tool path)
                          gptel-tools)))
              tools)))

  ;; Deactivate all MCP tools
  (defun gptel-mcp-close-use-tool ()
    (interactive)
    (let ((tools (mcp-hub-get-all-tool :asyncp t :categoryp t)))
      (mapcar #'(lambda (tool)
                  (let ((path (list (plist-get tool :category)
                                    (plist-get tool :name))))
                    (setq gptel-tools
                          (cl-remove-if #'(lambda (tool)
                                            (equal path
                                                   (list (gptel-tool-category tool)
                                                         (gptel-tool-name tool))))
                                        gptel-tools))))
              tools)))

  (defun zetta-mcp-setup-gptel ()
    (interactive)
    ;; TODO comment out
    ;;(setq gptel-tools nil)
    (gptel-mcp-register-tool)
    (gptel-mcp-use-tool)))

(use-package gptel
  :demand t
  :after mcp
  :config
  (gptel-make-anthropic "Claude" :stream t :key gptel-api-key)
  (require 'gptel-integrations) ;; required for mcp stuff
  (setq gptel-confirm-tool-calls nil)
  ;; NOTE messes up chat when using vscode-cp-proxy.  I think it
  ;; basically creates a syntax issue... probably something I can
  ;; figure out but won't spent too much time on it
  (setq gptel-include-tool-results nil)
  (setq gptel-include-reasoning t)
  (setq gptel-default-mode 'org-mode)
  (setq gptel-expert-commands t)

  (add-to-list
   'gptel-tools
   (gptel-make-tool
    :function (lambda (command &optional working_dir)
                (with-temp-message (format "Executing command: `%s`" command)
                  (let ((default-directory (if (and working_dir (not (string= working_dir "")))
                                               (expand-file-name working_dir)
                                             default-directory)))
                    (shell-command-to-string command))))
    :name "run_command"
    :description "Executes a shell command and returns the output as a string. IMPORTANT: This tool allows execution of arbitrary code; user confirmation will be required before any command is run."
    :args (list
           '(:name "command"
                   :type string
                   :description "The complete shell command to execute.")
           '(:name "working_dir"
                   :type string
                   :description "Optional: The directory in which to run the command. Defaults to the current directory if not specified."))
    :category "command"
    :confirm t
    :include t))

  (zetta-mcp-setup-gptel)

  :general
  (
   :keymaps 'override
   "s-p p" 'gptel-send
   "s-p P" 'gptel
   "s-p r" 'gptel-rewrite))

;; NOTE this is my solution for a generic claude.md solution, just use
;; system messages
;; NOTE another solution is including a header block at the beginning
;; of the chat with all the infromation, not sure if the system prompt
;; gets handled diffreently
(use-package gptel-prompts
  :after (gptel)
  :ensure (gptel-prompts :type git :host github :repo "jwiegley/gptel-prompts")
  :config
  (setq gptel-prompts-directory (concat (expand-file-name user-emacs-directory ) "prompts"))
  (gptel-prompts-update)
  (gptel-prompts-add-update-watchers))

(use-package gptel-quick
  :ensure (gptel-quick :type git :host github :repo "karthink/gptel-quick")
  :demand t
  :after (gptel embark)
  :config
  (keymap-set embark-general-map "?" #'gptel-quick)
  (setq gptel-quick-timeout 10000))

(use-package elysium)

;; NOTE keeping this in but wont use it.  not as smooth of an
;; experience, lots of bugs. text doesn't appear
(use-package gptel-autocomplete
  :ensure (gptel-autocomplete :type git :host github :repo "JDNdeveloper/gptel-autocomplete")
  :config
  ;;(setq gptel-autocomplete-before-context-lines 100)
  ;;(setq gptel-autocomplete-after-context-lines 20)
  ;;(setq gptel-autocomplete-temperature 0.1)
  (setq gptel-autocomplete-debug t)
  ;;(setq gptel-autocomplete-use-context t)
  ;;(setq gptel-autocomplete-use-context nil)
  )

;; necessary to use chatgpt chat like claude or cursor using copilot
;;(use-package vscode-cp-proxy
  ;;:ensure (vscode-cp-proxy :type git :host github :repo "utsahi/vscode-cp-proxy")
  ;;)
;;; ai.el ends here
