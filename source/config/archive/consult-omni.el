(use-package browser-hist
  :commands browser-hist-search
  :config
  (setq browser-hist-default-browser 'chrome))

(use-package consult-omni
  :ensure (consult-omni
           :host github
           :repo "armindarvish/consult-omni"
           :branch "main"
           :files (:defaults "sources/*.el"))
  :demand t
  :after (consult embark)

  :config
  (setq consult-omni-default-count 5)
  (setq consult-omni-dynamic-input-debounce 0.5)

  ;; Load core - these should work
  (require 'consult-omni-sources)
  (consult-omni-sources-load-modules)

  ;; Load only basic sources that don't need external APIs
  ;;(require 'consult-omni-buffer nil t)
  ;;(require 'consult-omni-man nil t)
  ;;(require 'consult-omni-grep nil t)
  ;;(require 'consult-omni-find nil t)
  ;;(require 'consult-omni-fd nil t)
  ;;(require 'consult-omni-ripgrep nil t)

  ;; Sources that need API keys - only load if key is set
  ;;(when (bound-and-true-p consult-omni-brave-api-key)
    ;;(require 'consult-omni-brave nil t)
    ;;(require 'consult-omni-brave-autosuggest nil t))
  ;;(when (bound-and-true-p consult-omni-google-customsearch-key)
    ;;(require 'consult-omni-google nil t))
  ;;(require 'consult-omni-wikipedia nil t)

  ;; Browser history - only if browser-hist is available
  ;;(when (featurep 'browser-hist)
    ;;(require 'consult-omni-browser-history nil t))

  ;; Set sources based on what's loaded
  (setq consult-omni-multi-sources '("Buffer" "man" "Wikipedia"))
  (when (bound-and-true-p consult-omni-brave-api-key)
    (add-to-list 'consult-omni-multi-sources "Brave" t))
  (when (bound-and-true-p consult-omni-google-customsearch-key)
    (add-to-list 'consult-omni-multi-sources "Google" t))

  (setq consult-omni-finder-sources '("Buffer" "fd" "ripgrep"))

  (defun consult-omni-multi* (&optional initial prompt sources no-callback &rest args)
    (interactive "P")
    (let ((sources (or sources consult-omni-multi-sources)))
      (consult-omni-multi initial prompt sources no-callback args)))

  ;; prevents white background that doesn't show up well in flat mode
  (when (facep 'consult-omni-default-face)
    (set-face-attribute 'consult-omni-default-face nil :inherit nil))

  :general
  (:keymaps 'override "S-s-SPC" #'consult-omni-multi*)
  )
