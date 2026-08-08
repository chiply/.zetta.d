;;; org-msg.el --- Configure org-msg -*- lexical-binding: t; -*-

;; Compose mail in org-mode, delivered as multipart text+HTML.
;; mu4e is set up in ~/.private.el (loaded eagerly before modules), so
;; :after mu4e fires here without further deferral.

(use-package org-msg
  :if (executable-find "mu")
  :ensure (org-msg :host github :repo "jeremy-compostella/org-msg")
  :after mu4e
  :config
  ;; org-msg picks its MUA integration from `mail-user-agent'; without
  ;; this it wires itself to gnus/message and mu4e compose buffers stay
  ;; plain mu4e-compose-mode.
  (setq mail-user-agent 'mu4e-user-agent
        read-mail-command 'mu4e)
  (setq org-msg-options "html-postamble:nil H:5 num:nil ^:{} toc:nil author:nil email:nil \\n:t"
        org-msg-startup "hidestars indent inlineimages"
        ;; no boilerplate greeting/signature; write those yourself
        org-msg-greeting-fmt nil
        ;; reply in kind: org/HTML compose for HTML mail, plain for plain
        org-msg-default-alternatives '((new . (text html))
                                       (reply-to-html . (text html))
                                       (reply-to-text . (text))))
  (org-msg-mode)

  ;; C-c C-c only sends when no org element at point claims it (org-msg
  ;; sends via org-ctrl-c-ctrl-c-final-hook), and it should keep doing
  ;; its org job anyway.  C-RET is the dedicated send key; the heading
  ;; command it shadows (org-insert-heading-respect-content) is unused,
  ;; and only in compose buffers.  C-u C-RET sends without exiting.
  (defun zetta-org-msg-send ()
    "Send the message, regardless of the org element at point."
    (interactive)
    (org-msg-ctrl-c-ctrl-c))
  (define-key org-msg-edit-mode-map (kbd "C-<return>") #'zetta-org-msg-send))

;;; org-msg.el ends here
