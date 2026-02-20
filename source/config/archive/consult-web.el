(use-package consult-web
  :ensure (consult-web :host github :repo "armindarvish/consult-web" :branch "main"
                       :files (:defaults "sources/*.el"))
  :after consult
  :custom
  ;; General settings that apply to all sources
  (consult-web-show-preview t) ;;; show previews
  (consult-web-preview-key "C-o") ;;; set the preview key to C-o
  (consult-web-highlight-matches t) ;;; highlight matches in minibuffer
  (consult-web-default-count 5) ;;; set default count
  (consult-web-default-page 0) ;;; set the default page (default is 0 for the first page)

  ;;; optionally change the consult-web debounce, throttle and delay.
  ;;; Adjust these (e.g. increase to avoid hiting a source (e.g. an API) too frequently)
  (consult-web-dynamic-input-debounce 0.8)
  (consult-web-dynamic-input-throttle 1.6)
  (consult-web-dynamic-refresh-delay 0.8)

  :config
  ;; Add sources and configure them
  ;;; load the example sources provided by default
  ;;(require 'consult-web-sources)

  (require 'consult-web-brave-autosuggest)
  (require 'consult-web-brave)
  (require 'consult-web-google)
  (require 'consult-web-wikipedia)


  ;;; set multiple sources for consult-web-multi command. Change these lists as needed for different interactive commands. Keep in mind that each source has to be a key in `consult-web-sources-alist'.
  (setq consult-web-multi-sources '("Brave" "Google" "Wikipedia")) ;; consult-web-multi
  (setq consult-web-dynamic-sources '("Brave" "Google" "Wikipedia")) ;; consult-web-dynamic
  (setq consult-web-scholar-sources '("Brave" "Google" "Wikipedia")) ;; consult-web-scholar
  (setq consult-web-omni-sources (list  "Brave" "Google" "Wikipedia")) ;;consult-web-omni
  (setq consult-web-dynamic-omni-sources (list "Brave" "Google" "Wikipedia")) ;;consult-web-dynamic-omni

  ;; Per source customization
  ;;; Pick you favorite autosuggest command.
  (setq consult-web-default-autosuggest-command #'consult-web-dynamic-brave-autosuggest) ;;or any other autosuggest source you define


  (require 'consult-web-embark) ;;not loading for some reason
  )
