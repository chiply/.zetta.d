;;; org-ql.el --- Configure org-ql -*- lexical-binding: t; -*-

;; `:wait t': elpaca processes the queue up to this order before the next
;; module loads, so org-ql is on the load-path when the local zettapkg
;; modules that follow (org-queue, org-daylog, org-decorate, org-chain;
;; `:ensure nil', their bodies run at load) `(require 'org-ql)'.  Without
;; it org-decorate's :init -- which requires its package as soon as
;; org-capture is up -- failed at startup with "Cannot open load file:
;; org-ql" (measured 2026-09-13, ci-test on dev at 422f10d; the eager
;; require arrived in b14463b, 2026-09-12).
(use-package org-ql
  :ensure (:wait t)
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
;;; org-ql.el ends here
