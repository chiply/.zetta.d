;;; prose.el --- Configure prose editing -*- lexical-binding: t; -*-

(global-set-key (kbd "C-c q") 'auto-fill-mode)

;; Single-space sentence endings as the default. The `nil' regex is
;; strictly more permissive than `t': it matches period + ONE OR MORE
;; spaces, so single-space (modern convention) AND double-space (old
;; typewriter convention) both detect as sentence boundaries.
;;
;; With the default `sentence-end-double-space = t', forward-sentence
;; and `bounds-of-thing-at-point 'sentence' REQUIRE two spaces, which
;; treats whole paragraphs as one sentence in any modern prose.
;;
;; Affects every mode where `sentence-end-double-space' isn't set
;; buffer-locally to t. Override per-buffer / per-mode if you really
;; want double-space-only somewhere.
(setq-default sentence-end-double-space nil)
;;; prose.el ends here
