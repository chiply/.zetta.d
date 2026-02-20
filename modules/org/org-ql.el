(use-package org-ql
  :config
  (setq org-ql-view-display-buffer-action
        `(
          (display-buffer-in-side-window)
          (side . top)
          (window-height . 0.20)
          (slot . 1)
          (window-parameters . ((no-delete-other-windows . 1)))
          )
        )
  )
