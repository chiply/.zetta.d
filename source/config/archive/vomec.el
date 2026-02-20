(defun my/demo-action-for-foo-type (input)
  (interactive)
  (message input))

(consult--read "foo" 'my/demo-action-for-foo-type)



