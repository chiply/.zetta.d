(use-package llm-tool-collection
  :ensure (llm-tool-collection :type git :host github :repo "skissue/llm-tool-collection")
  :config

  (defun llm-tool-collection-register-with-gptel (tool-spec)
    "Register a tool defined by TOOL-SPEC with gptel.
TOOL-SPEC is a plist that can be passed to `gptel-make-tool'."
    (let ((tool (apply #'gptel-make-tool tool-spec)))
      (setq gptel-tools
            (cons tool (seq-remove
                        (lambda (existing)
                          (string= (gptel-tool-name existing)
                                   (gptel-tool-name tool)))
                        gptel-tools)))))

  ;;(setq gptel-tools (mapcar (apply-partially #'apply #'gptel-make-tool)
                            ;;(llm-tool-collection-get-all)))
  ;;(add-hook 'llm-tool-collection-post-define-functions
            ;;#'llm-tool-collection-register-with-gptel)
  )
