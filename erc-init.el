;;; erc-init.el --- Initialization file for erc -*- lexical-binding: t; -*-
;; ident
(setq
 ;; erc-nick "Oxon"
 ;; erc-server "irc.rizon.net"
 erc-prompt-for-password nil
 erc-prompt-for-nickserv-password nil)
;;(erc :server "irc.rizon.net" :port 6667 :nick "Oxon")
(require 'erc-track)
(add-hook 'erc-mode-hook 'erc-track-mode)

;; (defun start-irc()
;;   "Connect to IRC."
;;   (interactive)
;;   (erc-tls :server erc-server :port 6697
;; 	   :nick erc-nick))

(defvar my-erc-server-info nil
  "Info on how to connect and identify on a specific server.

This has a format of '((server-name
                        :server server-host
                        :nick user-name
                        :channels (\"channel1\" \"channel2\" ...))
                        :before-functions (my-function-name my-function-2)
                       (server-2-name
                        ...))

server-name - server name as in `erc-server-alist' (case-sensitive)
:server - i.e. \"irc.freenode.net\"
:nick - nick to use on the server
Optional:
:port - port to use for connection, if not specified - use 6697
:channels - list of channels to join after ident
:no-tls - if not nil, use `erc' instead of `erc-tls'
:before-functions - a list of functions to run before connecting to a server

To get specific property from the list, use `my-erc-server-get'")

(defun my-erc-server-get (server prop)
  "Get the PROP of SERVER name from `my-erc-server-info' list."
  (plist-get (cdr (assoc server my-erc-server-info)) prop))

(defun my-erc-maybe-run-Bitlbee ()
  (unless (eq 0 (call-process "pidof" nil nil nil "bitlbee"))
    (call-process "sh" nil t nil
		  (concat (getenv "HOME")
			  "/.config/bitlbee/run-bitlbee.sh"))))

(setq my-erc-server-info
      '(("Rizon"
	 :server "irc.rizon.net"
	 :nick "Oxon"
	 :channels ("#krasnale"))
	("freenode"
	 :server "irc.freenode.net"
	 :nick "lampilelo"
	 :channels ("#emacs" "#guile"))
	("BitlBee"
	 :server "localhost"
	 :nick "Oxon"
	 :port 6667
	 :no-tls t
	 :before-functions (my-erc-maybe-run-Bitlbee))))

(defvar my-erc-password-store-names nil
  "Alist of password names corresponding to entries from `my-erc-server-info'.

Names are stored in cdr of an entry and are supposed to be used with \"pass\"
ulitily on Linux: \"pass password-name\".

Example:
  ((\"Rizon\" . \"rizon/My_nick\")
   (\"freenode\" . \"freenode/My_nick\"))")

(setq my-erc-password-store-names
      '(("Rizon" . "irc.rizon.net/Oxon")
	("freenode" . "irc.freenode.net/lampilelo")
	("BitlBee" . "bitlbee/Oxon")))

;; Add passwords to erc-nickserv-passwords
;; Gets password from command "pass server/nick"
;;   where server is :server and nick is :nick from `my-erc-server-info'
(unless (my-print-missing-packages-as-warnings "my-erc-passwords" '("pass"))
  (defun my-erc-refresh-passwords ()
    "Reload passwords using \"pass\" command and `my-erc-server-info'."
    (interactive)
    (setq erc-nickserv-passwords nil)
    (let ((ret t))
      (dolist (server-info my-erc-server-info ret)
	(condition-case pass-err
	    (let ((plist (cdr server-info)))
	      (push
	       `(,(intern (car server-info)) ; server name as symbol
		 ((,(plist-get plist :nick) .
		   ,(with-temp-buffer
		      (if (eq 0 (call-process
				 "/usr/bin/pass" nil (current-buffer) nil
				 ;; get arg from my-erc-password-store-names
				 (or (assoc-default
				      (car server-info)
				      my-erc-password-store-names)
				     (error (format
  "Couldn't retrieve %s profile password from `my-erc-password-store-names'"
					     (car server-info))))))
			  (s-chomp (buffer-string))
			(error (format "No password for %s"
				       (car server-info))))))))
		    erc-nickserv-passwords))
	  (error (display-warning "erc-init.el"
				  (error-message-string pass-err))
		 (setq ret nil)))))
    "Loading passwords finished."))

(defmacro my-erc--define-connect-function (server-name)
  "Create an interactive function for connecting to a specific server.
I.e. \"irc-freenode\".

Uses `my-erc-server-info' to get the information about server settings."
  (when (assoc server-name my-erc-server-info)
    (let ((fun-name (intern (concat "irc-" server-name))))
      `(defun ,fun-name ()
	 ,(concat "Run erc on " server-name " server.

Uses `my-erc-server-info' to get the information about server settings.")
	 (interactive)
	 ,(when (fboundp #'my-erc-refresh-passwords)
	    `(unless (assoc ',(intern server-name) erc-nickserv-passwords)
	       (if (assoc ,server-name my-erc-password-store-names)
		   (my-erc-refresh-passwords)
		 (message "Warning: no password found for server %s"
			  ,server-name))))
	 (mapc #'funcall (my-erc-server-get ,server-name :before-functions))
	 (,(if (my-erc-server-get server-name :no-tls) 'erc 'erc-tls)
	  :server (my-erc-server-get ,server-name :server)
	  :port (or (my-erc-server-get ,server-name :port) 6697)
	  :nick (my-erc-server-get ,server-name :nick))))))

(dolist (serv '("Rizon" "freenode" "BitlBee"))
  (eval `(my-erc--define-connect-function ,serv)))

(setq erc-fill-column 76)

(require 'erc-services)
(add-hook 'erc-mode-hook 'erc-nickserv-mode)

;; logs
(require 'erc-log)
(add-hook 'erc-mode-hook 'erc-log-mode)
(add-hook 'erc-mode-hook 'erc-log-enable)
(setq erc-log-channels-directory "~/.erc/logs/")
(setq erc-save-buffer-on-part t
      erc-save-queries-on-quit t)
;; (setq erc-log-insert-log-on-open t)
;; load modules
;; (require 'erc-services)
(add-hook 'erc-mode-hook '(lambda ()
			    (erc-services-mode)
			    (add-to-list 'erc-modules 'notifications)
			    (erc-services-enable)))
;; (setq erc-notifications-enable t)
;; (erc-services-enable)
;; (setq erc-services-enable 1)

(setq erc-notifications-icon "/usr/share/icons/hicolor/128x128/apps/emacs.png")

;; auto-join channels
(add-hook 'erc-mode-hook 'erc-autojoin-mode)
(setq erc-autojoin-channels-alist
      (mapcar (lambda (item)
		(cons (plist-get (cdr item) :server)
		      (plist-get (cdr item) :channels)))
	      my-erc-server-info))

;; (setq erc-autojoin-channels-alist
;;       '((".*rizon.*" "#krasnale")
;; 	(".*freenode.*" "#emacs")))

;; (defun my-post-vhost-autojoin (proc parsed)
;;   "Autojoin when NickServ tells us to."
;;   (with-current-buffer (process-buffer proc)
;;     (when (string-match ".*Password accepted.*"
;;                              (erc-response.contents parsed))
;;       (erc-autojoin-channels erc-session-server (erc-current-nick))
;;       nil)))
;; (add-hook 'erc-server-NOTICE-functions 'my-post-vhost-autojoin)

(setq erc-autojoin-timing 'ident)
;; end of auto-join

(add-hook 'erc-server-NOTICE-functions 'erc-server-PRIVMSG)

;; misc options
;; Kill buffers for channels after /part
(setq erc-kill-buffer-on-part t)
;; Kill buffers for private queries after quitting the server
(setq erc-kill-queries-on-quit t)
;; Kill buffers for server messages after quitting the server
(setq erc-kill-server-buffer-on-quit t)
 ;; Interpret mIRC-style color commands in IRC chats
(setq erc-interpret-mirc-color t)
;; Ignore certain type of messages when showing on the modeline
(dolist (item '("JOIN" "PART" "QUIT"))
  (add-to-list 'erc-track-exclude-types item))
(setq erc-track-exclude-server-buffer t)
(push "&bitlbee" erc-track-exclude)

;; sound notifications
(defun erc-my-play-new-message-sound ()
  "Play the freedesktop message-new-instant sound."
  (start-process
   "new-message" nil
   "ffplay" "-vn" "-nodisp" "-t" "1" "-autoexit"
   "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga")
  (x-urgent))

(defun erc-my-privmsg-sound (proc parsed)
    (let* ((tgt (car (erc-response.command-args parsed)))
           (privp (erc-current-nick-p tgt)))
      (and
       privp
       (erc-my-play-new-message-sound)
       nil)))
(add-hook 'erc-server-PRIVMSG-functions 'erc-my-privmsg-sound)

(defun my-erc-play-sound-on-my-nick ()
  (goto-char (point-min))
  (when (re-search-forward
	 (regexp-quote  (erc-current-nick)) nil t)
    (erc-my-play-new-message-sound)))
(add-hook 'erc-insert-post-hook 'my-erc-play-sound-on-my-nick)

;; Show message whenever ctcp request is issued.
(defun erc-ctcp-notice (proc parsed)
  ;; (let ((mess (format "%s" parsed)))
  (let ((msg (erc-response.contents parsed)))
    ;; if message is CTCP
    (when (erc-is-message-ctcp-and-not-action-p msg)
      (erc-display-line
       (format "-CTCP- %s request from %s"
	       ;; (format "%s" parsed)
	       (replace-regexp-in-string "" "" msg)
	       (erc-response.sender parsed))
       (car (erc-buffer-list))))))
(add-hook 'erc-server-PRIVMSG-functions 'erc-ctcp-notice)

;; =============================================
