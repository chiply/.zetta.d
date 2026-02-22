;;; tap.el --- Configure tap -*- lexical-binding: t; -*-

;; focus is a package that allows us to easily and constantly visualize things at point
;; it is a useful UI boost for focused programming, but is also a great development tool
;; in the context of working with tap




;; All the things
(setq zetta-tap--things '("block" "brick" "symbol" "list" "sexp"
                      "defun" "filename" "url"
                      "email" "uuid" "word"
                      "sentence" "whitespace" "line"
                      "page" "orgtree" "paragraph" "button"))


(defun zetta-intern-maybe (thing)
  (if (symbolp thing) thing (intern thing)))

(defun zetta-set-local-thing (&optional thing)
  "This is run as a hook on each relevant major-mode and can also be
used to override thing at point for whatever reason"
  (interactive)
  (setq-local focus-current-thing
              (zetta-intern-maybe
               (or thing (completing-read "What thing? " zetta-tap--things)))))


(defun zetta-locate-thing (&optional thing)
  (interactive)
  (let* ((bnds (bounds-of-thing-at-point
                (zetta-intern-maybe (or thing focus-current-thing))))
         (beg (if (string= thing "buf") (point-min) (car bnds)))
         (end (if (string= thing "buf") (point-max) (- (cdr bnds) 1))))
    (cons beg `(,end))))

(defun zetta-locate-thing-beg (&optional thing)
  (interactive)
  (let ((bnds (zetta-locate-thing thing))) (car bnds)))

(defun zetta-locate-thing-end (&optional thing)
  (interactive)
  (let ((bnds (zetta-locate-thing thing))) (cadr bnds)))



(defun zetta-get-thing (&optional thing)
  (interactive)
  (if (use-region-p)
      (buffer-substring-no-properties (region-beginning) (region-end)) 
    (buffer-substring-no-properties (zetta-locate-thing-beg thing) (zetta-locate-thing-end thing))))

(defun zetta-pulse (&optional thing)
  (interactive)
  ;; available things: generic + mode
  (let* ((bnds (zetta-locate-thing thing)))
    (pulse-momentary-highlight-region
     (car bnds) (cadr bnds)
     '(:background "black" :foreground "gray"))))

(defun zetta-select (&optional thing)
  (interactive)
  (let ((bnds (zetta-locate-thing thing)))
    (set-mark (car bnds))
    (goto-char (cadr bnds))))

(defun zetta-comment (&optional thing)
  (interactive)
  (save-excursion
    (zetta-select)
    (call-interactively 'comment-or-uncomment-region)
    )
  )




(general-define-key
 :keymaps '(
            sql-mode-map lisp-mode-map lisp-interaction-mode-map
            emacs-lisp-mode-map elisp python-ts-mode-map
            yaml-mode-map sh-mode-map shell-command-mode-map
            lark-mode-map)
 "s-j" '(lambda () (interactive)
          (if (buffer-narrowed-p)
              (progn (call-interactively 'zetta-narrow-or-widen)
                     (focus-next-thing 1)
                     (call-interactively 'zetta-narrow-or-widen)
                     )
            (focus-next-thing 1))
          )
 "s-k" '(lambda () (interactive)
          (if (buffer-narrowed-p)
              (progn (call-interactively 'zetta-narrow-or-widen)
                     (focus-prev-thing 1)
                     (call-interactively 'zetta-narrow-or-widen)
                     )
            (focus-prev-thing 1))
          )
 "s-h" '(lambda () (interactive)
          (beginning-of-thing focus-current-thing))
 "s-l" '(lambda () (interactive)
          (end-of-thing focus-current-thing)
          ;; to take care of skipping whitespace, not sure why this
          ;; happens
          (re-search-backward "[^[:space:]\n]")
          (evil-end-of-line)
          )
 "s-x v" 'zetta-pulse
 "s-x V" 'zetta-select
 "s-x t" 'zetta-set-local-thing
 "s-/" 'zetta-comment
 )

(use-package expand-region
  :general
  (
   :states '(normal visual)
   :keymaps '(
              ;; TODO delete unnecessary modes since including prog
              ;; mode
              ;; TODO doesn't work in funamental modek
              org-mode-map org-agenda-mode-map sql-mode-map
              python-ts-mode-map lisp-interaction-mode-map
              emacs-lisp-mode-map lisp-mode-map dired-mode-map
              snippet-mode-map shell-command-mode-map vterm-mode-map
              embark-collect-mode-map wgrep-mode-map csv-mode-map
              help-mode-map helpful-mode-map text-mode-map
              pubmed-show-mode-map json-mode-map eww-mode-map
              jmespath-mode-map jsonian-mode-map js2-mode-map
              compilation-mode-map lark-mode-map css-mode-map
              fundamental-mode-map lisp-data-mode-map prog-mode-map
              )
   "C-e" 'er/expand-region))


(defun zetta-thing-at-bobp ()
  (interactive)
  (eq 1 (save-excursion
          (beginning-of-thing focus-current-thing)
          (point))))


(defun zetta-thing-at-eobp ()
  (interactive)
  (save-excursion
    (end-of-thing focus-current-thing)
    (eobp)))




;; Brick
(defun brick-next-brick ()
  (interactive)
  (let ((delim "^ *$"))
    (re-search-forward delim)
    (forward-to-word 1)
    (evil-first-non-blank)
    )
  )

(defun brick-backward-brick (&optional skip)
  (interactive)
  (let* (
         (delim "^ *$")
         (bol (move-beginning-of-line 1))
         (blank-line-pt (re-search-backward delim nil t))
         )
    (cond (
           ;; no blank line prior to point
           (not blank-line-pt)
           (progn
             (beginning-of-buffer)
             ;; need point here bc beginning of buffer returns nil
             (point)))
          ;; already at beginning of brick or in whitespace above brick
          ((and
            (or
             (= 1 (- bol blank-line-pt))
             (= 0 (- bol blank-line-pt)))
            skip
            )
           (progn
             (backward-to-word 1)
             (if (re-search-backward delim nil t)
                 (evil-forward-word-begin)
               (progn (beginning-of-buffer) (point))
               ) 
             )
           )
          (t (progn
               (re-search-backward delim nil t)
               (evil-forward-word-begin)
               ))
          )
    )
  )



(defun brick-forward-brick (&optional arg)
  (interactive "p")
  (setq arg (or arg 1)) 
  (while (and (> arg 0)
              (not (eobp))
              (brick-next-brick))
    (setq arg (1- arg)))
  (while (and (< arg 0)
              (not (bobp))
              (brick-backward-brick t))
    (setq arg (1+ arg)))
  )

(put 'brick 'forward-op 'brick-forward-brick)




(defun current-line-empty-p ()
  (interactive)
  (save-excursion
    (beginning-of-line)
    (looking-at-p "[[:space:]]*$")))

(defun brick-bounds-of-brick-at-point ()
  (interactive)
  (save-excursion
    (if (not (current-line-empty-p))
        (let* (
               (beg (if (not (bobp))
                        (progn
                          (brick-backward-brick) (point))
                      (point)))
               (end (if (not (eobp))
                        (progn (end-of-thing 'paragraph) (+ 1 (point)))
                      (point)))
               )
          (cons beg end)
          )
      nil
      ))
  )

(put 'brick 'bounds-of-thing-at-point 'brick-bounds-of-brick-at-point)





(defun zetta-contiguous-chars-at-point ()
  (save-excursion
    (let* ((beg (progn (evil-backward-WORD-begin) (point)))
           (end (1+ (progn (evil-forward-WORD-end) (point))))
           (str (buffer-substring beg end))
           )
      (buffer-substring beg end)
      )
    )
  )
;;; tap.el ends here
