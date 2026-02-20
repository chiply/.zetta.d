;; NOTE: design note, could make the macro insert 'menu' and 'keymap'.
;; Could also eliminate the keymap argument. That would make the calls
;; as simple as possible (defmenu window "w").  While this would lead
;; to nice syntax, I like the current setup because the _SYMBOLS_ in
;; the macro become the of the function and keymap that will be used
;; in *-define-key forms.  This is a very deliberate design choice and
;; should not be changed...

;; TODO experiment with a continue function that quits if something
;; not in keymap is pressed TODO make this configuration

;; TODO versatile C-h can trigger menu, but menu cannot trigger
;; versatile C-h, otherwise you could get into a recursion loop
;; verstaile C-h helpers, its okay for these helper functions to
;; depend on menu stuff because they are re-used by the menu
;; functions... maybe decouple at some point but for now this is fine
