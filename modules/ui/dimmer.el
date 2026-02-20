(use-package dimmer
  :demand
  :init
  (defun advise-dimmer-config-change-handler ()
    "Advise to only force process if no predicate is truthy."
    (let ((ignore (cl-some (lambda (f) (and (fboundp f) (funcall f)))
                           dimmer-prevent-dimming-predicates)))
      (unless ignore
        (when (fboundp 'dimmer-process-all)
          (dimmer-process-all t)))))

  (defun lsp-doc-frame-p ()
    "Check if the buffer is a lsp-doc frame buffer."
    (string-match-p "\\` \\*lsp-ui-doc" (buffer-name)))

  (defun dimmer-configure-lsp-doc ()
    "Convenience settings for lsp-doc users."
    (add-to-list
     'dimmer-prevent-dimming-predicates
     #'lsp-doc-frame-p))

  (defun corfu-frame-p ()
    "Check if the buffer is a corfu frame buffer."
    (string-match-p "\\` \\*corfu" (buffer-name)))

  (defun dimmer-configure-corfu ()
    "Convenience settings for corfu users."
    (add-to-list
     'dimmer-prevent-dimming-predicates
     #'corfu-frame-p))

  (defun minimap-frame-p ()
    "Check if the buffer is a minimap frame buffer."
    (string-match-p "\\` \\*MINIMAP" (buffer-name)))

  (defun dimmer-configure-minimap ()
    "Convenience settings for minimap users."
    (add-to-list
     'dimmer-prevent-dimming-predicates
     #'minimap-frame-p))

  :config
  (dimmer-configure-posframe)
  (dimmer-configure-which-key)
  (dimmer-configure-magit) ;; transient
  (dimmer-configure-org) ;; org select and agenda
  (advice-add
   'dimmer-config-change-handler
   :override 'advise-dimmer-config-change-handler)
  (dimmer-configure-corfu)
  (dimmer-configure-lsp-doc)
  (dimmer-configure-minimap)
  (setq dimmer-fraction 0.4)
  (setq dimmer-watch-frame-focus-events nil)
  (dimmer-mode t)
  )



