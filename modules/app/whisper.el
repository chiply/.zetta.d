;;; whisper.el --- Configure whisper -*- lexical-binding: t; -*-

(use-package whisper
  :ensure (whisper :type git :host github :repo "natrys/whisper.el")
  :config

  (defun rk/get-ffmpeg-device ()
    "Gets the list of devices available to ffmpeg.
The output of the ffmpeg command is pretty messy, e.g.
  [AVFoundation indev @ 0x7f867f004580] AVFoundation video devices:
  [AVFoundation indev @ 0x7f867f004580] [0] FaceTime HD Camera (Built-in)
  [AVFoundation indev @ 0x7f867f004580] AVFoundation audio devices:
  [AVFoundation indev @ 0x7f867f004580] [0] Cam Link 4K
  [AVFoundation indev @ 0x7f867f004580] [1] MacBook Pro Microphone
so we need to parse it to get the list of devices.
The return value contains two lists, one for video devices and one for audio devices.
Each list contains a list of cons cells, where the car is the device number and the cdr is the device name."
    (unless (string-equal system-type "darwin")
      (error "This function is currently only supported on macOS"))

    (let ((lines (string-split (shell-command-to-string "ffmpeg -list_devices true -f avfoundation -i dummy || true") "\n")))
      (cl-loop with at-video-devices = nil
               with at-audio-devices = nil
               with video-devices = nil
               with audio-devices = nil
               for line in lines
               when (string-match "AVFoundation video devices:" line)
               do (setq at-video-devices t
                        at-audio-devices nil)
               when (string-match "AVFoundation audio devices:" line)
               do (setq at-audio-devices t
                        at-video-devices nil)
               when (and at-video-devices
                         (string-match "\\[\\([0-9]+\\)\\] \\(.+\\)" line))
               do (push (cons (string-to-number (match-string 1 line)) (match-string 2 line)) video-devices)
               when (and at-audio-devices
                         (string-match "\\[\\([0-9]+\\)\\] \\(.+\\)" line))
               do (push (cons (string-to-number (match-string 1 line)) (match-string 2 line)) audio-devices)
               finally return (list (nreverse video-devices) (nreverse audio-devices)))))

  (defun rk/find-device-matching (string type)
    "Get the devices from `rk/get-ffmpeg-device' and look for a device
matching `STRING'. `TYPE' can be :video or :audio."
    (let* ((devices (rk/get-ffmpeg-device))
           (device-list (if (eq type :video)
                            (car devices)
                          (cadr devices))))
      (cl-loop for device in device-list
               when (string-match-p string (cdr device))
               return (car device))))

  (defcustom rk/default-audio-device nil
    "The default audio device to use for whisper.el and outher audio processes."
    :type 'string)

  (defun rk/select-default-audio-device (&optional device-name)
    "Interactively select an audio device to use for whisper.el and other audio processes.
If `DEVICE-NAME' is provided, it will be used instead of prompting the user."
    (interactive)
    (let* ((audio-devices (cadr (rk/get-ffmpeg-device)))
           (indexes (mapcar #'car audio-devices))
           (names (mapcar #'cdr audio-devices))
           (name (or device-name (completing-read "Select audio device: " names nil t))))
      (setq rk/default-audio-device (rk/find-device-matching name :audio))
      (when (boundp 'whisper--ffmpeg-input-device)
        (setq whisper--ffmpeg-input-device (format ":%s" rk/default-audio-device)))))

  (defun rk/select-best-audio-device (&rest preferred)
    "Try each device name in PREFERRED order, selecting the first available one."
    (let ((available (mapcar #'cdr (cadr (rk/get-ffmpeg-device)))))
      (cl-loop for name in preferred
               for match = (cl-find-if (lambda (dev) (string-match-p name dev)) available)
               when match
               return (rk/select-default-audio-device match))))

  (rk/select-best-audio-device "fifine Microphone" "MacBook Pro Microphone")

  ;; NOTE using openai to prevent the need for a local whisper model
  ;; and the need to maintain / upgrade that on my own
  ;; NOTE there is cost, but at the time of this writing it is very
  ;; cheap: https://platform.openai.com/docs/pricing. $0.006 / minute.
  ;; So if I do 3 hours of transcription per day (unlikely), then I
  ;; will incur roughly $1 in cost
  (setq whisper-server-mode 'openai
        whisper-openai-api-key openai-api-key
        whisper--ffmpeg-input-format "avfoundation")

  :general
  (
   :keymaps 'override
   "s-;" 'whisper-run
   )
  )
;;; whisper.el ends here
