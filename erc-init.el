;; ==================== ERC ====================
;; ident
(setq
 ;; erc-nick "Oxon"
 ;; erc-server "irc.rizon.net"
 erc-prompt-for-password nil
 erc-prompt-for-nickserv-password nil)
;;(erc :server "irc.rizon.net" :port 6667 :nick "Oxon")
(add-hook 'erc-mode-hook 'erc-nickserv-mode)
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
                       (server-2-name
                        ...))

server-name - server name as in `erc-server-alist'
:server - i.e. \"irc.freenode.net\"
:nick - nick to use on the server
Optional:
:port - port to use for connection, if not specified - use 6697
:channels - list of channels to join after ident

To get specific property from the list, use `my-erc-server-get'")

(defun my-erc-server-get (server prop)
  "Get the PROP of SERVER name from `my-erc-server-info' list."
  (plist-get (cdr (assoc server my-erc-server-info)) prop))

(setq my-erc-server-info
      '(("Rizon"
	 :server "irc.rizon.net"
	 :nick "Oxon"
	 :channels ("#krasnale" "#test"))
	("freenode"
	 :server "irc.freenode.net"
	 :nick "lampilelo"
	 :channels ("#emacs"))))

(defmacro my-erc--define-connect-function (server-name)
  "Create an interactive function for connecting to a specific server.
I.e. \"irc-freenode\"

Uses `my-erc-server-info' to get the information about server settings."
  (when (assoc server-name my-erc-server-info)
    (let ((fun-name (intern (concat "irc-" server-name))))
      `(defun ,fun-name ()
	 (interactive)
	 (erc-tls :server (my-erc-server-get ,server-name :server)
		   :port (or (my-erc-server-get ,server-name :port) 6697)
		   :nick (my-erc-server-get ,server-name :nick))))))

(dolist (serv '("Rizon" "freenode"))
  (eval `(my-erc--define-connect-function ,serv)))

(setq erc-fill-column 76)

(require 'erc-services)
;; Add passwords to erc-nickserv-passwords
;; Gets password from command "pass server/nick"
;;   where server is :server and nick is :nick from `my-erc-server-info'
(defun my-erc-refresh-passwords ()
  "Reload passwords using \"pass\" command and `my-erc-server-info'."
  (interactive)
  (setq erc-nickserv-passwords nil)
  (dolist (server-info my-erc-server-info)
    (condition-case pass-err
	(let ((plist (cdr server-info)))
	  (push `(,(intern (car server-info))
		  ((,(plist-get plist :nick) .
		    ,(s-chomp
		      (with-temp-buffer
			(let ((pass-name (format "%s/%s"
						 (plist-get plist :server)
						 (plist-get plist :nick))))
			  (if (eq 0 (call-process "/usr/bin/pass"
						  nil
						  (current-buffer)
						  nil
						  pass-name))
			      (buffer-string)
			    (error (format "No password for %s"
					   pass-name)))))))))
		erc-nickserv-passwords))
      (error (display-warning "erc-init.el"
			      (error-message-string pass-err))))))
(my-erc-refresh-passwords)

;; logs
;; (require 'erc-log)
;; (add-hook 'erc-mode-hook 'erc-log-mode)
;; (erc-log-enable)
(add-hook 'erc-mode-hook '(lambda ()
			    (erc-log-mode)
			    (erc-log-enable)))
(setq erc-log-channels-directory "~/.erc/logs/")
(setq erc-save-buffer-on-part t)
(setq erc-log-insert-log-on-open t)
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
      '((".*rizon.*" "#krasnale")
	(".*freenode.*" "#emacs")))
(add-hook 'erc-server-NOTICE-functions 'my-post-vhost-autojoin)
(defun my-post-vhost-autojoin (proc parsed)
  "Autojoin when NickServ tells us to."
  (with-current-buffer (process-buffer proc)
    (when (string-match ".*Password accepted.*"
                             (erc-response.contents parsed))
      (erc-autojoin-channels erc-session-server (erc-current-nick))
      nil)))

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

;; sound notifications
(defun erc-my-play-new-message-sound ()
  "Play the freedesktop message-new-instant sound."
  (and
   (start-process-shell-command
 "new-message"
 nil
 "ffplay -vn -nodisp -t 0.5 -autoexit /usr/share/sounds/freedesktop/stereo/message-new-instant.oga")
   (x-urgent)))

(defun erc-my-privmsg-sound (proc parsed)
    (let* ((tgt (car (erc-response.command-args parsed)))
           (privp (erc-current-nick-p tgt)))
      (and
       privp
       (erc-my-play-new-message-sound)
       nil)))
(add-hook 'erc-server-PRIVMSG-functions 'erc-my-privmsg-sound)

(add-hook 'erc-insert-post-hook 
	  (lambda () (goto-char (point-min)) 
	    (when (re-search-forward
		   (regexp-quote  (erc-current-nick)) nil t)
	      (erc-my-play-new-message-sound))))

;; Something is broken here
;; Show message whenever ctcp request is issued.
(defun erc-ctcp-notice (proc parsed)
  ;; (let ((mess (format "%s" parsed)))
  (let ((msg (erc-response.contents parsed)))
    ;; if message is CTCP
    (if (erc-is-message-ctcp-and-not-action-p msg)
	;; is CTCP
	(erc-display-line
	 (format "-CTCP- %s request from %s"
		 ;; (format "%s" parsed)
		 (replace-regexp-in-string "" "" msg)
		 (erc-response.sender parsed))
	 (first (erc-buffer-list)))
      ;; do nothing if isn't CTCP
      )))
(add-hook 'erc-server-PRIVMSG-functions 'erc-ctcp-notice)

;; =============================================
