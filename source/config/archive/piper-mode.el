(use-package piper-mode
  :ensure (piper-mode
           :type git
           :host github
           :repo "snowy-0wl/piper-mode"
           :files ("*.el" "bin" "models" "setup-piper.sh"))
  :config
  ;; use pipe-select-model fn to download models not present
  ;; NOTE to download another model, you need to change setup-piper.sh
  ;;(setq my/piper-model "en_US-joe-medium.onnx")
  ;; NOTE severe issues with memory usage... not sure what the problem is, but I can really only get it to speak sentences that are a few words long
  (setq piper-debug nil)
  (setq my/piper-model "en_GB-northern_english_male-medium.onnx")
  (when (not (file-exists-p (expand-file-name (concat "models/" my/piper-model)
                                              (file-name-directory (locate-library "piper-mode")))))
    (let ((default-directory (file-name-directory (locate-library "piper-mode"))))
      (shell-command "chmod +x setup-piper.sh")
      (shell-command "./setup-piper.sh .")))
  (setq piper-voice-model (expand-file-name (concat "models/" my/piper-model)
                                            (file-name-directory (locate-library "piper-mode"))))
  (setq piper-playback-speed 1.5)
  (piper-mode))
