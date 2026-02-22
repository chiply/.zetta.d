;;; -*- lexical-binding: t; -*-

(require 'json)
(require 'url)

(require 'spot-var)

;; sync
(defun spot-retrieve-url-to-alist-synchronously (url)
  "Return alist representation of json response from URL."
  (with-current-buffer (url-retrieve-synchronously url nil nil spot--request-timeout)
    (let ((json (decode-coding-region (+ 1 url-http-end-of-headers)
                                      (point-max) 'utf-8 t)))
      (when (not (string= json ""))
        (json-read-from-string json)))))

(cl-defun spot-request (&key method url q-params parse-json extra-headers data)
  "Function to handle spot requests.
METHOD is the request method, URL is the URL, Q-PARAMS is the
query parameters, PARSE-JSON is a boolean for whether to parse
and return the json response as an alist, EXTRA-HEADERS is an
alist of headers, and DATA is request body data as JSON."
  (let ((url-request-method method)
        (url-request-data data)
        (url-request-extra-headers extra-headers))
    (if parse-json
        (spot-retrieve-url-to-alist-synchronously
         (concat url q-params))
      (url-retrieve-synchronously
       (concat url q-params) nil nil spot--request-timeout))))

;; async
(defun spot-retrieve-url-to-alist-asynchronously (url callback)
  "Async version that calls CALLBACK with alist from URL's JSON response."
  (url-retrieve
   url
   (lambda (status)
     (let ((json (decode-coding-region (+ 1 url-http-end-of-headers)
                                       (point-max) 'utf-8 t)))
       (funcall callback json)))
   nil t t))

(defun spot--message-request-complete (&rest args)
  (message "spot request complete"))

(cl-defun spot-request-async (&key
                              method url q-params callback
                              extra-headers data)
  "Async version. CALLBACK receives the response."
  (let ((url-request-method method)
        (url-request-data data)
        (url-request-extra-headers extra-headers))
    (spot-retrieve-url-to-alist-asynchronously
     (concat url q-params)
     (or callback #'spot--message-request-complete))))

;; currently playing
(defun spot--currently-playing ()
  (spot-request
   :method "GET"
   :url spot-player-url
   :q-params (spot--base-q-params)
   :parse-json t))

(provide 'spot-generic-query)
