;;; foreman.el --- Configure foreman -*- lexical-binding: t; -*-

;; NOTE foreman-as-a-feature is disabled (2026-08): its config, code
;; execution bindings, and detached.el dependency are preserved in
;; term/disabled/foreman-conf.el.  This module remains ONLY to load
;; the zettapkg as a library — vterm (soda), dired, and line-utils
;; depend on its 4mn-get-tramp-* context helpers.  :demand because
;; nothing else reliably loads it anymore.
;; TODO migrate the 4mn tramp helpers to core/utility, then disable
;; this module fully.
(use-package foreman
  :ensure nil
  :load-path "source/zettapkg/foreman"
  :demand t
  )
;;; foreman.el ends here
