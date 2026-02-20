(use-package indent-guide
  :config
  (setq indent-guide-recursive nil)
  (add-to-list 'indent-guide-inhibit-modes 'vterm-mode)
  ;; NOTE this doesn't work properly, interferes with scrolling, and
  ;;recenter-top-bottom... sad because this was super fast compared to other solutions i've tried
  ;; (indent-guide-global-mode)
  )

