(use-package eca
  :ensure (eca :host github :repo "editor-code-assistant/eca-emacs" :files ("*.el"))
  :config

  (setq exec-path-from-shell-variables
        '("ANTHROPIC_API_KEY"
          "OPENAI_API_KEY"
          "OLLAMA_API_BASE"
          "OPENAI_API_URL"
          "ANTHROPIC_API_URL"
          "ECA_CONFIG"
          "XDG_CONFIG_HOME"
          "PATH"
          "MANPATH"))
  ;; For macOS and Linux GUI environments
  (when (memq window-system '(mac ns x))
    (exec-path-from-shell-initialize))

  ;;(setq eca-extra-args '("--verbose" "--log-level" "debug"))
  (setq eca-extra-args nil)
  )


