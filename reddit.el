;;; reddit.el --- reddit API wrapper library

;; This is free and unencumbered software released into the public domain.

;; Author: Christopher Wellons <wellons@nullprogram.com>
;; Version: 1.0.0
;; Package-Requires: ((cl-lib "0.3"))

;;; Commentary:

;; This library is intended to make it easy to operate reddit's API
;; from Emacs. Use `reddit-login' to create a session, stored in
;; `reddit-session', then use `reddit-get' and `reddit-post' to send
;; p-lists and receive JSON from reddit.

;; For example, to login and subscribe to my sandbox subreddit:

;;     (reddit-login "your-username" "your-password")
;;     (reddit-post "/api/subscribe" '(:sr "t5_2s49f" :action sub))

;; API documentation: http://www.reddit.com/dev/api

;;; Code:

(require 'url)
(require 'json)
(require 'cl-lib)

(defvar reddit-user-agent "emacs-reddit")
(defvar reddit-user-agent-version "1.0.0")

(defvar reddit-base-url "http://www.reddit.com"
  "Base URL for API requests.")

(defvar reddit-session nil
  "Holds the current reddit session information. This variable is
designed to be dynamically rebound.")

(cl-defstruct (reddit-session (:constructor reddit-session--create))
  "Session state for a logged in reddit user."
  cookie modhash)

(defun reddit-session-create (cookie modhash)
  "Create a reddit-session from COOKIE and MODHASH."
  (reddit-session--create :cookie cookie :modhash modhash))

(cl-defun reddit-session-valid-p (&optional (session reddit-session))
  "Return non-nil if SESSION (default `reddit-session') is valid."
  (and (reddit-session-p session))) ;; XXX check date

(cl-defun reddit-auth-headers (&optional (session reddit-session))
  (when (reddit-session-valid-p)
    (let ((cookie (reddit-session-cookie session))
          (modhash (reddit-session-modhash session)))
      `(("Cookie"    . ,(concat "reddit_session=" (url-hexify-string cookie)))
        ("X-Modhash" . ,modhash)))))

(defun reddit-symbol-name (symbol)
  "Like `symbol-name' but handle keywords and dashes properly."
  (if (keywordp symbol)
      (substring (symbol-name symbol) 1)
    (symbol-name symbol)))

(defun reddit-form-encode (plist)
  "Encode PLIST into application/x-www-form-urlencoded."
  (let ((allowed (url--allowed-chars (cons ?\s url-unreserved-chars))))
    (cl-flet ((encode (s)
                (replace-regexp-in-string
                 " " "+" (url-hexify-string s allowed))))
      (cl-loop for (key value) on plist by #'cddr
               for key-name = (reddit-symbol-name key)
               collect (concat (encode key-name) "="
                               (encode (format "%s" value)))
               into pairs
               finally (return (mapconcat #'identity pairs "&"))))))

(defun reddit-form-decode (string)
  "Decode STRING in application/x-www-form-urlencoded into a plist."
  (cl-flet ((decode (s)
              (url-unhex-string (replace-regexp-in-string "+" " " s) t)))
    (cl-loop with split = (split-string string "[&=]")
             for (key value) on split by #'cddr
             collect (intern (decode (concat ":" key)))
             collect (decode value))))

(defun reddit-url-encode (plist)
  "Encode PLIST for a GET request."
  (cl-loop for (key value) on plist by #'cddr
           collect (concat (url-hexify-string (reddit-symbol-name key))
                           "=" (url-hexify-string value))
           into pairs
           finally (return (mapconcat #'identity pairs "&"))))

(defun reddit-url-decode (string)
  "Decode STRING from a GET request."
  (cl-loop for (key value) on (split-string string "[=&]") by #'cddr
           collect (intern (concat ":" (url-unhex-string key)))
           collect (url-unhex-string value)))

(defun reddit-handle-errors (json)
  "Signal any errors appearing in JSON."
  (let ((errors (cdr (assoc 'errors (cdr (assoc 'json json))))))
    (cl-loop for error across errors
             for (name . message) = (coerce error 'list)
             for signal = (downcase (replace-regexp-in-string "_" "-" name))
             do (signal (intern signal) message)
             finally (return json))))

(defun reddit-post (api plist &optional no-auth)
  "Send PLIST to API as a POST request.
The :api_type is automatically set to \"json\"."
  (let ((url-package-name reddit-user-agent)
        (url-package-version reddit-user-agent-version)
        (url-use-cookies nil)
        (url-request-method "POST")
        (url-request-extra-headers
         `(("Content-Type" . "application/x-www-form-urlencoded") .
           ,(unless no-auth (reddit-auth-headers))))
        (url-request-data (reddit-form-encode
                           (append (list :api_type "json") plist))))
    (with-current-buffer
        (url-retrieve-synchronously (format "%s%s" reddit-base-url api))
      (goto-char (1+ url-http-end-of-headers))
      (unless (= url-http-response-status 200)
        (signal 'reddit-error (list "reddit request failed"
                                    url-http-response-status)))
      (prog1 (reddit-handle-errors (json-read))
        (kill-buffer)))))

(defun reddit-get (api plist &optional no-auth)
  "Send PLIST to API as a GET request.
The :api_type is automatically set to \"json\"."
  (let ((url-package-name reddit-user-agent)
        (url-package-version reddit-user-agent-version)
        (url-use-cookies nil)
        (url-request-extra-headers (unless no-auth (reddit-auth-headers))))
    (with-current-buffer
        (url-retrieve-synchronously (format "%s%s" reddit-base-url api))
      (goto-char (1+ url-http-end-of-headers))
      (unless (= url-http-response-status 200)
        (signal 'reddit-error (list "reddit request failed"
                                    url-http-response-status)))
      (prog1 (reddit-handle-errors (json-read))
        (kill-buffer)))))

(defun reddit-login (user passwd)
  "Return a session for USER and PASSWD, signaling an error on auth failure.
This function sets `reddit-session'."
  (let* ((json (reddit-post "/api/login" `(:user ,user :passwd ,passwd)))
         (data (cdr (assoc 'data (cdr (assoc 'json json)))))
         (cookie (cdr (assoc 'cookie data)))
         (modhash (cdr (assoc 'modhash data))))
    (setf reddit-session (reddit-session-create cookie modhash))))

(provide 'reddit)

;;; reddit.el ends here
