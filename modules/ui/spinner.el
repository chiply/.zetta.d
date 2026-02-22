;;; spinner.el --- Configure spinner -*- lexical-binding: t; -*-

;; Left off, was able to get this working the issues that some of the
;; spinner types actually change the height of the line as they're
;; spinning, and I couldn't figure out a way to do this even with
;; trying to use the font and also the header line height. It just
;; always seems that certain cliffs actually don't even know what they
;; are but certain clips take up more space vertical space than
;; others. Another less severe as she is that the current set of
;; spinners are actually different heights and so if you switch
;; between them, you'd notice some change, however, since I only
;; really intend to use these in compile buffers, It doesn't matter
;; that it changes the height. It really shouldn't be noticeable, but
;; ideally, I'll fix this and then I'll be able to use these little
;; animations everywhere. They're bringing in the spinners from the
;; rust code was useful in terms of mining, a library in spinners, but
;; also teaching me what the possibilities are e.g. you can just paste
;; emoji's in and get animations that way, but also at some of the
;; Limite Shinzo, e.g., some emojis actually custom such as the party
;; pirate thing, and also emoji simply rendered a different size in
;; the max, and it's not necessary easy to control.

;; Update, figured out how to decrease the size of emojis, but some of
;; the non-emoji unicode characters are still too large -- commenting
;; thos out for now as so I can use spinners everywhere .  keeping for
;; now as I don't want to overcomplicate things -- simply prefer
;; emojis for non compile spinners or ones that we know will fit

;; update - abandoning custom emojis as these are implenented as
;; emojis, the rendering also doesn't really work

(use-package spinner

  :after (compile unicode-fonts)

  :config
  ;; set emoji font size to 11 -- I have found this is necessary to
  ;; prevent the spinner characters from being to big and causing the
  ;; height of the *-line to change.  this may not abstract when text
  ;; size increases or decreases...
  ;; NOTE not setting as when you set the size, they don't scale with font size.
  ;; drawback is that these are larger then the termius text, not a
  ;; big usse as I rarely if ever use these in buffers
  (set-fontset-font t 'unicode "Apple Color Emoji" nil 'prepend)
  (set-fontset-font t 'unicode "Arial Unicode MS 10" nil 'prepend)

  ;; Starting commenting out spinners that cause issues with the mode
  ;; or headerline
  ;;
  ;; copied from https://github.com/FGRibreau/spinners/blob/master/src/utils/spinners_data.rs

  ;; ideas for spinners -- fruit and veg, kind of like slot machine vibes
  ;; ability for certain processes to request a certain spinner.

  ;; For example, would be nice for something like monitoring CI to be different from running unit tests
  (setq spinner-types
        '(
          ;; TODO remove 2 comemnts to get old list, going simple for now
          ;;(Foo . ("-" "\\" "|" "/"))
          (Bar .
               ;;("o" "O" "@" "*")
               (
                  "o---o"
                  "O\\+/O"
                  "@|x|@"
                  "*/*\\*"
                  )
               )
          ;;;;(Line . ("-" "\\" "|" "/"))
          ;;;;(Pipe . ("┤" "┘" "┴" "└" "├" "┌" "┬" "┐"))
          ;;(SimpleDots . (".  " ".. " "..." "   "))
          ;;(SimpleDotsScrolling . (".  " ".. " "..." " .." "  ." "   "))
          ;;(Star . ("✶" "✸" "✹" "✺" "✹" "✷"))
          ;;(Star2 . ("+" "x" "*"))
          ;;(Flip . ("_" "_" "_" "-" "`" "`" "'" "´" "-" "_" "_" "_"))
          ;;(Hamburger . ("☱" "☲" "☴"))
          ;;(Balloon . (" " "." "o" "O" "@" "*" " "))
          ;;(Balloon2 . ("." "o" "O" "°" "O" "o" "."))
          ;;;;(Noise . ("▓" "▒" "░"))
          ;;(Bounce . ("⠁" "⠂" "⠄" "⠂"))
          ;;(BoxBounce . ("▖" "▘" "▝" "▗"))
          ;;;;(BoxBounce2 . ("▌" "▀" "▐" "▄"))
          ;;(Triangle . ("◢" "◣" "◤" "◥"))
          ;;(Arc . ("◜" "◠" "◝" "◞" "◡" "◟"))
          ;;(Circle . ("◡" "⊙" "◠"))
          ;;(SquareCorners . ("◰" "◳" "◲" "◱"))
          ;;(CircleQuarters . ("◴" "◷" "◶" "◵"))
          ;;(CircleHalves . ("◐" "◓" "◑" "◒"))
          ;;(Squish . ("╫" "╪"))
          ;;(Toggle . ("⊶" "⊷"))
          ;;(Toggle2 . ("▫" "▪"))
          ;;;;(Toggle3 . ("□" "■"))
          ;;;;(Toggle4 . ("■" "□" "▪" "▫"))
          ;;(Toggle5 . ("▮" "▯"))
          ;;(Toggle7 . ("⦾" "⦿"))
          ;;(Toggle8 . ("◍" "◌"))
          ;;;;(Toggle9 . ("◉" "◎"))
          ;;;;(Toggle10 . ("㊂" "㊀" "㊁"))
          ;;(Toggle11 . ("⧇" "⧆"))
          ;;(Toggle12 . ("☗" "☖"))
          ;;(Toggle13 . ("=" "*" "-"))
          ;;;;(Arrow . ("←" "↖" "↑" "↗" "→" "↘" "↓" "↙"))
          ;;(Arrow3 . ("▹▹▹▹▹" "▸▹▹▹▹" "▹▸▹▹▹" "▹▹▸▹▹" "▹▹▹▸▹" "▹▹▹▹▸"))
          ;;(Smiley . ("😄 " "😝 "))
          ;;(Monkey . ("🙈 " "🙈 " "🙉 " "🙊 "))
          ;;;;(Hearts . ("💛 " "💙 " "💜 " "💚 " "❤️ "))
          ;;(Clock . ("🕛 " "🕐 " "🕑 " "🕒 " "🕓 " "🕔 " "🕕 " "🕖 " "🕗 " "🕘 " "🕙 " "🕚 "))
          ;;(Earth . ("🌍 " "🌎 " "🌏 "))
         ;;
          ;;(Moon . ("🌑 " "🌒 " "🌓 " "🌔 " "🌕 " "🌖 " "🌗 " "🌘 "))
          ;;(Runner . ("🚶 " "🏃 "))
          ;;(Pong . ("▐⠂       ▌" "▐⠈       ▌" "▐ ⠂      ▌" "▐ ⠠      ▌"
                   ;;"▐  ⡀     ▌" "▐  ⠠     ▌" "▐   ⠂    ▌" "▐   ⠈    ▌"
                   ;;"▐    ⠂   ▌" "▐    ⠠   ▌" "▐     ⡀  ▌" "▐     ⠠  ▌"
                   ;;"▐      ⠂ ▌" "▐      ⠈ ▌" "▐       ⠂▌" "▐       ⠠▌"
                   ;;"▐       ⡀▌" "▐      ⠠ ▌" "▐      ⠂ ▌" "▐     ⠈  ▌"
                   ;;"▐     ⠂  ▌" "▐    ⠠   ▌" "▐    ⡀   ▌" "▐   ⠠    ▌"
                   ;;"▐   ⠂    ▌" "▐  ⠈     ▌" "▐  ⠂     ▌" "▐ ⠠      ▌"
                   ;;"▐ ⡀      ▌" "▐⠠       ▌"))
;;
          ;;;;(Shark . ("▐|\\____________▌" "▐_|\\___________▌"
                    ;;;;"▐__|\\__________▌" "▐___|\\_________▌" "▐____|\\________▌"
                    ;;;;"▐_____|\\_______▌" "▐______|\\______▌" "▐_______|\\_____▌"
                    ;;;;"▐________|\\____▌" "▐_________|\\___▌" "▐__________|\\__▌"
                    ;;;;"▐___________|\\_▌" "▐____________|\\▌" "▐____________/|▌"
                    ;;;;"▐___________/|_▌" "▐__________/|__▌" "▐_________/|___▌"
                    ;;;;"▐________/|____▌" "▐_______/|_____▌" "▐______/|______▌"
                    ;;;;"▐_____/|_______▌" "▐____/|________▌" "▐___/|_________▌"
                    ;;;;"▐__/|__________▌" "▐_/|___________▌" "▐/|____________▌"))
;;
          ;;(Dqpb . ("d" "q" "p" "b"))
          ;;(Weather . ("☀️ " "☀️ " "☀️ " "🌤 " "⛅️ " "🌥 " "☁️ " "🌧 "
                      ;;"🌨 " "🌧 " "🌨 " "🌧 " "🌨 " "🌨 " "🌧 " "🌨 "
                      ;;"☁️ " "🌥 " "⛅️ " "🌤 " "☀️ " "☀️ "))
          ;;(Christmas . ("🌲" "🎄"))
          ;;(Point . ("∙∙∙" "●∙∙" "∙●∙" "∙∙●" "∙∙∙"))
          ;;(Layer . ("-" "=" "≡"))
          ;;(BetaWave . ("ρββββββ" "βρβββββ" "ββρββββ" "βββρβββ"
                       ;;"ββββρββ" "βββββρβ" "ββββββρ"))
          ;;;;(FingerDance . ("🤘 " "🤟 " "🖖 " "✋ " "🤚 " "👆 "))
          ;;(FistBump . ("🤜　　　　🤛 " "🤜　　　　🤛 " "🤜　　　　🤛 "
                       ;;"　🤜　　🤛　 " "　　🤜🤛　　 " "　🤜✨🤛　　 "
                       ;;"🤜　✨　🤛 　 "))
          ;;(SoccerHeader . (" 🧑⚽️       🧑 " "🧑  ⚽️      🧑 "
                           ;;"🧑   ⚽️     🧑 " "🧑    ⚽️    🧑 "
                           ;;"🧑     ⚽️   🧑 " "🧑      ⚽️  🧑 "
                           ;;"🧑       ⚽️🧑  " "🧑      ⚽️  🧑 "
                           ;;"🧑     ⚽️   🧑 " "🧑    ⚽️    🧑 "
                           ;;"🧑   ⚽️     🧑 " "🧑  ⚽️      🧑 "))
          ;;(Mindblown . ("😐 " "😐 " "😮 " "😮 " "😦 " "😦 " "😧 " "😧"
                        ;;"😫 " "💥 " "🔥 " "🔥 " "🔥 " "✨ "))
          ;;(Speaker . ("🔈 " "🔉 " "🔊 " "🔉 "))
          ;;;;(OrangePulse . ("🔸 " "🔶 " "🟠 " "🟠 " "🔶 "))
          ;;(BluePulse . ("🔹 " "🔷 " "🔵 " "🔵 " "🔷 "))
          ;;;;(OrangeBluePulse . ("🔸 " "🔶 " "🟠 " "🟠 " "🔶 " "🔹 " "🔷 "
                              ;;;;"🔵 " "🔵 " "🔷 "))
          ;;(TimeTravel . ("🕛 " "🕚 " "🕙 " "🕘 " "🕗 " "🕖 " "🕕 " "🕔"
                         ;;"🕓 " "🕒 " "🕑 " "🕐 "))
          ;;;;(Aesthetic . ("▰▱▱▱▱▱▱" "▰▰▱▱▱▱▱" "▰▰▰▱▱▱▱" "▰▰▰▰▱▱▱"
                        ;;;;"▰▰▰▰▰▱▱" "▰▰▰▰▰▰▱" "▰▰▰▰▰▰▰" "▰▱▱▱▱▱▱"))
          ))

  (defun zetta-spinner-compile-spin (&optional _)
    (let* ((spinner (nth (random (length spinner-types)) spinner-types))
           (spinner-type-name (car spinner))
           (spinner-type-data (cdr spinner))
           (spinner-number-of-frames (length spinner-type-data)))
      ;; using N frames as the frames per second sets a logical
      ;; default of running through every element in the spinner vec
      ;; once per second.  I use the multipler (1.5 in this case) as a
      ;; fine-tuning of thiis default.  IMO this is a smotther
      ;; animation experience for most spinners. should tweak this
      ;; overtime.  For 'animation' looks like 24fps is the standard,
      ;; but this seems to cause issues with key-chord, not sure why
      (spinner-start
       spinner-type-name
       (* 1.25 spinner-number-of-frames)
       ;; having a delay prevents wasting compute on display for quick
       ;; commands
       ;;1
       )))

  (add-hook 'compilation-start-hook 'zetta-spinner-compile-spin)

  ;; Stop
  (defun zetta-compile-spin-stop (buffer result)
    "Executes spinner-stop strategy depending on compilation exit status."
    (cond ((string-match "^finished" result) (spinner-stop))
          ((string-match "^interrupt" result) (spinner-stop))
          ((string-match "^exited abnormally" result) (spinner-stop))))

  (add-to-list 'compilation-finish-functions 'zetta-compile-spin-stop)

  )
;;; spinner.el ends here
