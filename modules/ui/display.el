(zetta-side :regex "^\\*blacken-error*" :side 'top :slot 1)
(zetta-side :regex "^\\*compilation*" :side 'top :slot 1)
;; note this can't have the backslashes...
(zetta-side :regex "compilation-mode" :side 'top :slot 1) 
(zetta-side :regex "^\\*Async*" :side 'top :slot 1)
(zetta-side :regex "shell-command-mode" :side 'top :slot 1)
(zetta-side :regex "^\\*Shell*" :side 'top :slot 3)
(zetta-side :regex "\\magit-process-mode" :side 'top :slot 1)
(zetta-side :regex "^\\*Messages*" :side 'bottom :slot 3)


(setq visual-line-fringe-indicators '(nil top-right-angle))

;;;;(zetta-side "\\calendar-mode" 'top 1)
;;;;(zetta-side "\\occur-mode" 'right -1 0.2)
;;;;(zetta-side "\\grep-mode" 'right -1 0.25)
;;(add-to-list
 ;;'display-buffer-alist
 ;;`(,(zetta-soda-mode-name "\\org-mode")
   ;;(display-buffer-no-window)
   ;;)
 ;;nil
 ;;)
;;
;;
;;;;(zetta-side "\\xref--xref-buffer-mode" 'right -1 0.25)
;;
;;(add-hook 'grep-mode-hook '(lambda () (toggle-truncate-lines 1)))
;;(add-hook 'occur-mode-hook '(lambda () (text-scale-set -2)))
;;(add-hook 'grep-mode-hook '(lambda () (text-scale-set -2)))
;;
;;;;(zetta-side "^\\*Apropos*" 'right)
;;;;(zetta-side "^\\*Warnings*" 'top)
;;;;(zetta-side "^\\*Backtrace*" 'top)
;;;;(zetta-side "^\\*sqls results*" 'top)
;;;;(zetta-side "^\\*info*" 'bottom)
;;;;(zetta-side "^\\*Help*" 'right)
;;;;(zetta-side "^\\*helpful*" 'right)
;;
;;;; makes things less cluttered

