(defun zetta-indirect-buffer (&optional buffer)
  (interactive)
  (let* ((cbuf-name (buffer-name buffer))
         (ibuf-name (format "*indirect--%s*" cbuf-name))
         (mmode (with-current-buffer cbuf-name (intern (format "%s" major-mode)))))
    (if (gnus-buffer-exists-p ibuf-name)
        (progn
          (display-buffer ibuf-name)
          (select-window (get-buffer-window ibuf-name))
          )
      (progn
        (make-indirect-buffer cbuf-name ibuf-name t)
        (display-buffer ibuf-name)
        (select-window (get-buffer-window ibuf-name))
        ;;(unless (equal text-scale-mode-amount -2) (text-scale-set -2))
        )
      )
    )
  )


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; display
;;(zetta-side "^\\*indirect*" 'right)
