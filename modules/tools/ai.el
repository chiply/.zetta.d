;;; ai.el --- Configure AI tools -*- lexical-binding: t; -*-

(when (>= emacs-major-version 30)
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
    (gptel-mcp-register-tool)
    (gptel-mcp-use-tool))))

(use-package gptel
  :demand t
  :config
  (gptel-make-anthropic "Claude" :stream t :key gptel-api-key)
  (gptel-make-openai "OpenAI" :stream t :key openai-api-key)

  ;; ── OpenRouter ────────────────────────────────────────────────────
  (defvar zetta-openrouter-models-cache-file
    (expand-file-name "openrouter-models-cache.eld" user-emacs-directory)
    "Last fetched OpenRouter catalog, so the full list survives restarts.")

  (defvar zetta-openrouter-seed-models
    '(anthropic/claude-sonnet-5
      openai/gpt-5.6-luna
      deepseek/deepseek-v4-pro
      deepseek/deepseek-v4-flash
      z-ai/glm-5.3
      qwen/qwen3.8-max
      meta/muse-glimmer-30b
      meta/muse-spark-1.2)
    "Fallback model list until `zetta-openrouter-refresh-models' has run once.")

  (defun zetta-openrouter-api-key ()
    "OpenRouter key from the 1Password cache, else ~/source_code/my-ai/.env.
The op-secrets template has no OPENROUTER_API_KEY entry yet; adding one
there makes the 1Password path win automatically."
    (or (and (boundp 'zetta-op--cache)
             (gethash "OPENROUTER_API_KEY" zetta-op--cache))
        (let ((env (expand-file-name "~/source_code/my-ai/.env")))
          (when (file-readable-p env)
            (with-temp-buffer
              (insert-file-contents env)
              (when (re-search-forward
                     "^OPENROUTER_API_KEY=\"?\\([^\"\n]+?\\)\"?$" nil t)
                (match-string 1)))))
        (user-error "No OpenRouter key in 1Password cache or my-ai/.env")))

  (defvar zetta-openrouter-backend
    (gptel-make-openai "OpenRouter"
      :host "openrouter.ai"
      :endpoint "/api/v1/chat/completions"
      :stream t
      :key #'zetta-openrouter-api-key
      :models (or (and (file-readable-p zetta-openrouter-models-cache-file)
                       (with-temp-buffer
                         (insert-file-contents zetta-openrouter-models-cache-file)
                         (ignore-errors (read (current-buffer)))))
                  zetta-openrouter-seed-models)))

  (defvar url-http-end-of-headers)
  (defun zetta-openrouter-refresh-models ()
    "Fetch the full OpenRouter model catalog into the OpenRouter backend."
    (interactive)
    (url-retrieve
     "https://openrouter.ai/api/v1/models"
     (lambda (status)
       (unwind-protect
           (if (plist-get status :error)
               (message "OpenRouter: catalog fetch failed: %s"
                        (plist-get status :error))
             (goto-char url-http-end-of-headers)
             (let ((models (sort (mapcar (lambda (m) (intern (gethash "id" m)))
                                         (gethash "data" (json-parse-buffer)))
                                 #'string-lessp)))
               (when models
                 (setf (gptel-backend-models zetta-openrouter-backend) models)
                 (with-temp-file zetta-openrouter-models-cache-file
                   (prin1 models (current-buffer)))
                 (message "OpenRouter: %d models available" (length models)))))
         (kill-buffer (current-buffer))))
     nil t))
  ;; async + idle so a dead network can't slow startup
  (run-with-idle-timer 10 nil #'zetta-openrouter-refresh-models)

  ;; my-ai router proxy (~/source_code/my-ai): classifies difficulty
  ;; locally via Ollama, then forwards to the cheapest OpenRouter model
  ;; clearing the quality floor.  The key is a placeholder the proxy
  ;; ignores; gptel requires it non-empty.
  (gptel-make-openai "LLM-Router"
    :host "localhost:8765"
    :protocol "http"
    :endpoint "/v1/chat/completions"
    :stream t
    :key "sk-llm-router-local-proxy-no-auth-needed"
    :models '(llm-router))

  (setq gptel-backend zetta-openrouter-backend
        gptel-model   'deepseek/deepseek-v4-pro)
  (when (featurep 'mcp)
    (require 'gptel-integrations))
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

  (when (featurep 'mcp)
    (zetta-mcp-setup-gptel))

  ;; ── Response notifications ────────────────────────────────────────
  ;; Routed through `zetta-notify' (tools/alert.el), the same entry
  ;; point Claude Code's hooks call over emacsclient, so both agents
  ;; share one notification stack -- and the same "tell me about
  ;; everything" policy, so the duration gate is open by default.

  (defvar zetta-gptel-notify-min-seconds 0
    "Only notify for gptel responses that took at least this many seconds.
0 notifies for every response; raise it to hear only about slow ones.")

  (defvar zetta-gptel--request-start nil
    "`float-time' when the most recent gptel request was sent.
Set buffer-locally for the common case where a request and its response
share a buffer, and globally to cover the ones where they do not
(rewrites, `gptel-quick').  A buffer-local value shadows the global, so
reading the variable picks the right start time either way.")

  (defun zetta-gptel-mark-request ()
    "Record when a gptel request went out."
    (setq-local zetta-gptel--request-start (float-time))
    (setq-default zetta-gptel--request-start (float-time)))

  (defun zetta-gptel-notify-response (beg end)
    "Notify when a slow gptel response lands in the current buffer.
BEG and END bound the inserted text.  gptel passes them equal when the
request failed, which is worth hearing about however long it took."
    (let ((started zetta-gptel--request-start))
      (setq-local zetta-gptel--request-start nil)
      (setq-default zetta-gptel--request-start nil)
      (cond
       ((= beg end)
        (zetta-notify (format "Request failed in %s" (buffer-name))
                      "gptel" 'high))
       ((and started
             (>= (- (float-time) started) zetta-gptel-notify-min-seconds))
        (zetta-notify (format "%s — %.0fs, %d chars"
                              (buffer-name) (- (float-time) started)
                              (- end beg))
                      "gptel")))))

  (add-hook 'gptel-post-request-hook #'zetta-gptel-mark-request)
  (add-hook 'gptel-post-response-functions #'zetta-gptel-notify-response)

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

(use-package copilot
  :ensure t
  :bind (:map copilot-completion-map
              ("C-<return>" . copilot-accept-completion)
              ("C-f" . copilot-accept-completion-by-word)
              ("C-n" . copilot-next-completion)
              ("C-p" . copilot-previous-completion)
              )
  :init
  (defun zetta-copilot-maybe-enable ()
    "Enable `copilot-mode' only when actually editing a code buffer.
Copilot is restricted to file-visiting buffers whose major mode derives
from `prog-mode' (so Org, Markdown and other text modes are skipped) and
oversized files are left alone.  This keeps Copilot from activating -- or
tripping its `copilot-max-char' warning -- in the transient buffers that
tools like HyRolo or consult-grep open in the background to scan files."
    (require 'copilot)
    (when (and buffer-file-name
               (derived-mode-p 'prog-mode)
               (not (bound-and-true-p copilot-mode))
               (or (< copilot-max-char 0)
                   (<= (buffer-size) copilot-max-char)))
      (copilot-mode 1)))
  (add-hook 'prog-mode-hook #'zetta-copilot-maybe-enable)

  :config
  ;; -32800 "Request was canceled" is routine — it means we typed past
  ;; an in-flight inlineCompletion request; don't echo it
  (define-advice copilot--log (:around (fn level format &rest args) zetta-silence-cancelled)
    (unless (string-match-p "Request was canceled\\|-32800"
                            (apply #'format format args))
      (apply fn level format args))))

;;; ai.el ends here
