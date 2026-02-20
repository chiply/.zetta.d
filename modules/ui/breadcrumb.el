(use-package breadcrumb
  :config
  ;; proportional width of the breadcrumb, if set smaller, breadcrumb
  ;; will start abbreviating the imenu path
  (setq breadcrumb-imenu-max-length 1000000)
  (setq breadcrumb-project-max-length 1000000)
  ;; NOTE still cuts magit off not sure why
  )

