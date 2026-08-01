;;; org-msg.el --- Configure org-msg -*- lexical-binding: t; -*-

;; Compose mail in org-mode, delivered as multipart text+HTML.
;; mu4e is set up in ~/.private.el (loaded eagerly before modules), so
;; :after mu4e fires here without further deferral.

(use-package org-msg
  :if (executable-find "mu")
  :ensure (org-msg :host github :repo "jeremy-compostella/org-msg")
  :after mu4e
  :config
  (setq org-msg-options "html-postamble:nil H:5 num:nil ^:{} toc:nil author:nil email:nil \\n:t"
        org-msg-startup "hidestars indent inlineimages"
        ;; no boilerplate greeting/signature; write those yourself
        org-msg-greeting-fmt nil
        ;; reply in kind: org/HTML compose for HTML mail, plain for plain
        org-msg-default-alternatives '((new . (text html))
                                       (reply-to-html . (text html))
                                       (reply-to-text . (text))))
  (org-msg-mode))

;;; org-msg.el ends here
