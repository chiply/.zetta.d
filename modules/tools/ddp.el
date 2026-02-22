;;; ddp.el --- Configure ddp -*- lexical-binding: t; -*-

(use-package ddp
  :ensure (ddp :type git
               :host github
               :repo "eki3z/ddp.el"
               :branch "master"
               :files ("*.el"))

  :config
  (defun split-string-with-quotes (str)
    "Split STR into a list of words, treating quoted sections as single elements."
    (let ((words '())
          (current-word "")
          (in-quotes nil))
      (dotimes (i (length str))
        (let ((char (aref str i)))
          (cond
           ((eq char ?\s) ; space
            (if in-quotes
                (setq current-word (concat current-word " "))
              (when (not (string= current-word ""))
                (push current-word words)
                (setq current-word ""))))
           ((eq char ?\') ; single quote
            (setq in-quotes (not in-quotes)))
           (t ; any other character
            (setq current-word (concat current-word (char-to-string char)))))))
      (when in-quotes
        (error "Unmatched single quote in string"))
      (when (not (string= current-word ""))
        (push current-word words))
      (nreverse words)))

  (defun my-ddp--dasel-read-pred (mmajor-mode)
    (cond
     ((or (eq mmajor-mode 'json-mode)
          (eq mmajor-mode 'jsonian-mode))
      "json")
     ((or (eq mmajor-mode 'yaml-mode))
      "yaml")))

  (defun ddp--build-cmd (&optional header)
    (ddp-bind (exec cmd temp file query cache-query buffer)
      (let* ((spec `(("exec" . ,exec)
                     ("temp" . ,temp)
                     ("file" . ,file)
                     ("query" . ,query)
                     ("cache-query" . ,cache-query)
                     ("dasel_read" . ,(my-ddp--dasel-read-pred
                                       (with-current-buffer buffer
                                         major-mode)))))
             (cmd (templatel-render-string cmd spec)))
        (split-string-with-quotes cmd))))

  ;; TODO still need to see if this works on temp and region
  (ddp-define-command "jq"
    "Parse json using jq."
    :url "https://github.com/jqlang/jq"
    :exec "jq"
    :cmd "{{ exec }} -C '{{ query }}' {{ temp or file }}"
    :ansi t)

  (ddp-define-command "dasel"
    "Parse data using dasel."
    :url "https://github.com/TomWright/dasel"
    :ansi t
    :exec "dasel"
    :cmd "{{ exec }} --colour -f {{ file }} -r {{ dasel_read }} -s {{ query }}"
    :support ("yaml" "json" "toml" "csv" "xml"))
  )
;;; ddp.el ends here
