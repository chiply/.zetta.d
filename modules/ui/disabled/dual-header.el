;;; dual-header.el --- Configure dual header-line -*- lexical-binding: t; -*-

;; -------------------------------------------------------------------
;; A proof of concept for a multi header or mode line
;;
;; Multi line header or mode line is made possible by generating an
;; SVG image made of two small lines of text. It is certainly memory
;; hungry but it seems to be fast enough to display line/column while
;; typing text. It can probably be extended in a number of ways.
;;
;; Feel free to modify it for your own needs.
;; -------------------------------------------------------------------
(require 'svg)

(defun tag (line-1 font-size-1 font-family-1 foreground-1
                   line-2 font-size-2 font-family-2 foreground-2
                   left)
  (let* ((char-width-1  (* font-size-1 0.88))
         (char-height-1 (+ font-size-1 0.0))
         (width-1       (* char-width-1 (window-width)))
         (height-1      (+ (* char-height-1 2) 7))

         (char-width-2  (* font-size-2 0.88))
         (char-height-2 (+ font-size-2 0.0))
         (width-2       (* char-width-2 (window-width)))
         (height-2      (+ (* char-height-2 2) 7))

         (width         (max width-1 width-2))
         (height        (max height-1 height-2))

         (x1 (if left 0 (- width (* char-width-1 (+ (length line-1) .0)))))
         (x2 (if left 0 (- width (* char-width-2 (+ (length line-2) .0)))))

         (y1 char-height-1)
         (y2 (+ (* char-height-2 2) 1))

         (svg (svg-create width height)))
    ;; NOTE doesn't work well for bitmap font Cozetter, even using
    ;; :line-spacing and :line-height
    ;; Does work well with Terminus, haven't tried other bitmap fonts though
    (svg-text svg line-1
              :font-family font-family-1
              :font-size font-size-1 :fill foreground-1
              :x x1 :y y1)
    (svg-text svg line-2
              :font-family font-family-2
              :font-size font-size-2 :fill foreground-2
              :x x2 :y y2)
    svg))

(define-key mode-line-major-mode-keymap [header-line]
            (lookup-key mode-line-major-mode-keymap [mode-line]))

(defun mode-line-render (left)
  left)

(defun zetta-set-dual-header ()
 (setq-default
  header-line-format
  ;;header-line-format
  '((:eval
     (mode-line-render
      (format-mode-line
       (propertize
        (make-string (window-width) 1)
        'display
        (svg-image
         (tag
          (format-mode-line
           (zetta-get-line-format default-line-align-left-devel-1 "" "")
           )
          15 "Terminus (TTF)" brushup-fg-3
          (format-mode-line default-line-align-left-devel-2)
          15 "Terminus (TTF)" brushup-fg-3
          t)
         :ascent 100)))))))
 )

(zetta-set-dual-header)

(add-to-list 'brushup-styles '(zetta-set-dual-header))

(add-hook 'magit-status-mode-hook 'zetta-set-dual-header)
;;; dual-header.el ends here
