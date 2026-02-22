;;; display.el --- Configure display-buffer rules -*- lexical-binding: t; -*-

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
;;; display.el ends here
