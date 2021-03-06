;;; init.el --- Initialization file for Emacs -*- lexical-binding: t; -*-
;;; Commentary: Emacs Startup File --- initialization for Emacs

(when (< emacs-major-version 27)
  (package-initialize))
(setq package-archives
      '(;("melpa-stable" . "https://stable.melpa.org/packages/")
	("melpa" . "https://melpa.org/packages/")
	("gnu" . "https://elpa.gnu.org/packages/")
	("org" . "https://orgmode.org/elpa/")))

(when (< emacs-major-version 27)
  (require 'tls)
  (defun safe-tls-disable-gnutls (&rest args) nil)
  (advice-add 'gnutls-available-p :override 'safe-tls-disable-gnutls)
  (setq tls-program
	'("gnutls-cli -p %p --dh-bits=2048 --ocsp --x509cafile=%t \
--priority='SECURE192:+SECURE128:-VERS-ALL:+VERS-TLS1.2:%%PROFILE_MEDIUM' %h")))

(setq gnutls-verify-error t)
(setq tls-checktrust t)
(setq network-security-level 'high)
;; (setq nsm-save-host-names t)

(setq network-stream-use-client-certificates t)

(setq load-prefer-newer t)

;; USE-PACKAGE
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(setq use-package-always-ensure t
      use-package-always-defer t)

(use-package diminish
  :defer nil
  :ensure t
  :config
  (diminish 'eldoc-mode)
  (diminish 'abbrev-mode))

(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)
(blink-cursor-mode -1)
;; (global-hl-line-mode) ;; slows down next-line nad previous-line
(setq inhibit-startup-screen t)
(setq scroll-conservatively 101)
;; Default value for scroll-conservatively when isearching.
(add-hook 'isearch-mode-hook
	  (lambda () (setq-local scroll-conservatively 0)))
(add-hook 'isearch-mode-end-hook
	  (lambda () (kill-local-variable 'scroll-conservatively)))
(setq sentence-end-double-space nil)
(setq bookmark-save-flag 1) ;; always save the bookmark list

(defun my-set-scratch-lexical ()
  (with-current-buffer "*scratch*"
    (setq-local lexical-binding t)))
(add-hook 'emacs-startup-hook #'my-set-scratch-lexical)

(add-hook 'before-save-hook #'delete-trailing-whitespace)
(setq custom-file (concat user-emacs-directory "custom.el"))

;; If a new info file is added to a directory from Info-default-directory-list
;; install-info DIR/FILE DIR/dir needs to be called for Emacs to be able to
;; detect it. Info-default-directory-list, Info-additional-directory-list.
;; (info "(efaq) Installing Texinfo documentation")
(dolist (dir '("$HOME/.local/share/info/"
	       "$HOME/.guix-profile/share/info"))
  (add-to-list 'Info-additional-directory-list
	       (substitute-env-in-file-name dir)))

(with-eval-after-load 'man
  (defun my-Man-open-in-same-buffer ()
    "Open new man buffer in place of the current."
    (interactive)
    (let ((old-buffer (current-buffer))
	  (Man-notify-method 'pushy))
      (call-interactively #'man)
      (when (string-prefix-p "*Man" (buffer-name old-buffer))
	(kill-buffer old-buffer))))
  (define-key Man-mode-map (kbd "M") #'my-Man-open-in-same-buffer))

(setq woman-fill-frame t)

(defvar my-man-function 'man)
(global-set-key (kbd "C-c m") my-man-function)

(dolist (spec '((woman-bold . font-lock-function-name-face)
		(woman-italic . font-lock-keyword-face)
		(woman-addition . font-lock-constant-face)
		(woman-unknown . error)
		(Man-overstrike . woman-bold)
		(Man-underline . woman-italic)))
  (add-to-list 'face-remapping-alist spec))

;; NOTE: Probably temporary. I added it because of abnoxious ding when on
;;       battery power. Maybe it would be better to call 'ignore instead.
(setq ring-bell-function
      (lambda ()
        (let ((orig-bg (face-background 'mode-line))
	      (orig-fg (face-foreground 'mode-line)))
          (set-face-background 'mode-line orig-fg)
	  (set-face-foreground 'mode-line orig-bg)
          (run-with-idle-timer 0.1 nil
                               (lambda (bg fg)
				 (set-face-background 'mode-line bg)
				 (set-face-foreground 'mode-line fg))
                               orig-bg orig-fg))))

;; Fix for helm buffers showing slowly (it was necessary in emacs 26.1
;; or some older version of helm but isn't anymore; it's still slightly
;; beneficial though)
(setq x-wait-for-event-timeout nil)

(let ((src-dir "~/emacs/"))
  (if (file-exists-p src-dir)
      (setq source-directory src-dir)
    (message (concat "Emacs source not found in: " src-dir))))

;; IDO mode
;; TODO: check out https://masteringemacs.org/article/introduction-to-ido-mode
;; (setq ido-enable-flex-matching t)
;; (setq ido-everywhere t)
;; (ido-mode 1)

;; Load functions for checking missing host packages
(load "~/.emacs.d/missing-packages.el")

(when (with-check-for-missing-packages ("gnutls-cli") "gnutls" nil)
  (error "GnuTLS not installed"))

;; org mode customizations
(use-package org
  :ensure org-plus-contrib
  :pin org
  :config
  (org-babel-do-load-languages 'org-babel-load-languages
			       (list (cons 'emacs-lisp t)
				     (cons 'shell t))))
(setq org-edit-src-content-indentation 2
      org-hide-emphasis-markers t
      org-pretty-entities t
      org-pretty-entities-include-sub-superscripts nil
      org-src-fontify-natively t
      org-src-tab-acts-natively t
      org-startup-indented t
      org-use-extra-keys t
      org-todo-keywords '((sequence "TODO" "IN-PROGRESS" "WAITING" "DONE"))
      org-todo-keyword-faces '(("IN-PROGRESS" . "yellow1")
			       ("WAITING" . "gold2")))
(add-to-list 'face-remapping-alist '(org-block . font-lock-builtin-face))

;; Enable changing width of an image in org with #+ATTR_ORG: :width <width>
(setq org-image-actual-width nil)
(add-hook 'org-mode-hook #'org-display-inline-images)
(add-hook 'org-mode-hook #'visual-line-mode)
;; (setq org-ellipsis " ↴")

;; org-mode source coloring
(use-package htmlize)
;; Note 1: python-pygments needs to be installed
(with-check-for-missing-packages ("pygments") "latex minted" nil)
(setq org-latex-listings 'minted)
(setq org-export-with-smart-quotes t)
(setq org-html-postamble nil)
(eval-after-load 'org
  '(add-to-list 'org-latex-packages-alist '("" "minted")))

(setq org-latex-pdf-process
      '("%latex -shell-escape -interaction nonstopmode -output-directory %o %f"
	"%latex -shell-escape -interaction nonstopmode -output-directory %o %f"
	"%latex -shell-escape -interaction nonstopmode -output-directory %o %f"))

(load "~/.emacs.d/org-agenda-init.el")
(use-package helm-org-rifle
  :bind
  ("C-c r" . #'helm-org-rifle-org-directory))

;; Polish quotation marks
(eval-after-load 'ox
  '(push
   '("pl"
     (primary-opening :utf-8 "„"  :html "&bdquo;"
			   :latex ",," :texinfo "@quotedblbase{}")
     (primary-closing :utf-8 "”"  :html "&rdquo;"
			   :latex "''" :texinfo "@quotedblright{}")
     (secondary-opening :utf-8 "»"  :html "&raquo;"
			   :latex ">>" :texinfo "@guillemetright{}")
     (secondary-closing :utf-8 "«"  :html "&laquo;"
			   :latex "<<" :texinfo "@guillemetleft{}")
     (apostrophe :utf-8 "’" :html "&rsquo;"))
   org-export-smart-quotes-alist))
;; Default to polish language for export
;; To change language per document add i.e. '#+LANGUAGE: en' to the org file
(setq org-export-default-language "pl"
      org-export-with-smart-quotes t)

(use-package org-bullets
  :init
  (add-hook 'org-mode-hook #'org-bullets-mode))


;; TODO: Check if we can convert current mode name to helm-info function
;; Relevant symbols:
;;   helm-default-info-index-list, helm-info-search-index
(defun my-contextual-helm-info (&optional generic-info)
  "If there is known function for helm-info-<MODE> for current major mode,
call it. Otherwise call ‘helm-info’.

If GENERIC-INFO is non-nil, call generic ‘helm-info’.

With a prefix argument \\[universal-argument], just call generic ‘helm-info’."
  (interactive "P")
  (if generic-info		 ;if universal prefix argument is used
      (funcall #'helm-info)	 ;call helm-info and exit
    (let ((fun-to-call
	   (intern		   ;call function by name
	    (let ((current-mode ;get mode name that matches helm-info
		   (downcase (replace-regexp-in-string
			      "-mode" "" (symbol-name major-mode)))))
	      ;; Get function name, e.g. helm-info-cpp
	      ;; Some modes are called differently in info, so we need
	      ;; to rename them before evaluating
	      (concat "helm-info-"
		      (pcase current-mode
			("c++" "cpp")
			("emacs-lisp" "elisp")
			("lisp-interaction" "elisp")
			(_ current-mode)))))))
      ;; check if helm-info-CURRENT_MODE exists, if so - call it
      ;; otherwise call generic helm-info
      (if (not (eq (fboundp fun-to-call) nil))
	  (funcall fun-to-call)
	(funcall #'helm-info)))))
(define-key help-map "h" #'my-contextual-helm-info)
(define-key help-map "F" #'find-function)
(define-key Info-mode-map (kbd "<up>") #'scroll-down-line)
(define-key Info-mode-map (kbd "<down>") #'scroll-up-line)
(define-key Info-mode-map (kbd "<right>") (kbd "]"))
(define-key Info-mode-map (kbd "<left>") (kbd "["))

;; bind M-RET to open files externally with helm
(with-eval-after-load 'helm-files
  (define-key helm-find-files-map (kbd "M-RET")
    #'helm-ff-run-open-file-with-default-tool)
  (define-key helm-generic-files-map (kbd "M-RET")
    #'helm-ff-run-open-file-with-default-tool))

;; bind M-RET to open files externally with dired
(with-eval-after-load 'dired
  (defun my-dired-open-file-with-default-tool ()
    "Open FILE with the default tool on this platform."
    (interactive)
    (dired-do-async-shell-command
     (cond ((eq system-type 'gnu/linux)
	    "xdg-open")
	   ((or (eq system-type 'darwin) ;; Mac OS X
		(eq system-type 'macos)) ;; Mac OS 9
	    "open"))
     nil (dired-get-marked-files)))
  (define-key dired-mode-map (kbd "M-RET")
    #'my-dired-open-file-with-default-tool))

(column-number-mode 1)
(setq split-width-threshold 140)
(setq split-window-preferred-function (function split-window-sensibly))

;; autosaves
;; create the autosave dir if necessary, since emacs won't.
(defvar my-autosave-directory "~/.emacs.d/autosaves/")
(make-directory my-autosave-directory t)
;; Put autosave files (ie #foo#) and backup files (ie foo~) in ~/.emacs.d/.
(setq backup-directory-alist `((".*" . ,my-autosave-directory))
      auto-save-file-name-transforms `((".*" ,my-autosave-directory t))
      auto-save-list-file-prefix my-autosave-directory)

;; Set default browser for opening links
(setq browse-url-browser-function #'browse-url-generic
      ;; browse-url-generic-program "vivaldi-stable"
      browse-url-generic-program "firefox")

(require 'uniquify)
;; (setq uniquify-buffer-name-style 'post-forward-angle-brackets)

(setq save-interprogram-paste-before-kill t
      ediff-window-setup-function 'ediff-setup-windows-plain)

;; C++ default options
(use-package google-c-style
  :init
  (add-hook 'c-mode-common-hook #'google-set-c-style))
;; (setq c-default-style "linux"
;;       c-basic-offset 4)

;; GDB
(setq gdb-many-windows t
      ;; Display source file containing the main routine at startup
      gdb-show-main t)

;; Custom global keybindings
(global-set-key (kbd "M-o") #'other-window)
(global-set-key (kbd "M-i") #'imenu)
(global-set-key (kbd "C-x k") #'(lambda () (interactive) (kill-buffer nil)))
(global-set-key (kbd "C-c i") #'iedit-mode)

;; TODO: make it the global minor mode instead of rebinding help
;;       default help bindings are required for some packages
;; (define-key global-map (kbd "C-z") 'help-command)
(setq help-char ?\C-z)
(define-key global-map (kbd "C-h") (kbd "DEL"))
(define-key global-map (kbd "M-h") (kbd "M-DEL"))
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "M-h") (kbd "M-DEL")))
;; (define-key counsel-mode-map (kbd "M-h") (kbd "M-DEL"))
(with-eval-after-load 'helm
  (define-key helm-map (kbd "C-h") 'backward-delete-char))

;; Monday as first day of the week
(setq calendar-week-start-day 1)

;; Type break config
;; (type-break-mode 1)
(setq type-break-demo-functions '(type-break-demo-boring))
(setq type-break-query-function 'y-or-n-p)

(dolist (spec '((eshell-prompt . font-lock-keyword-face)
		(erc-timestamp-face . font-lock-constant-face)))
  (add-to-list 'face-remapping-alist spec))

(setq indent-tabs-mode nil)

(eval-after-load 'iso-transl
  '(let ((map (make-sparse-keymap)))
     (define-key map (kbd "c") [?č])
     (define-key map (kbd "C") [?Č])
     (define-key iso-transl-ctl-x-8-map (kbd "v") map)))

;; ==================== FUNCTIONS ===================

;; Got it from here: http://www.draketo.de/light/english/emacs/babcore
(defun x-urgency-hint (frame arg &optional source)
  "Set the x-urgency hint for the FRAME to ARG:

- If arg is nil, unset the urgency.
- If arg is any other value, set the urgency.

If you unset the urgency, you still have to visit the frame to make the urgency setting disappear (at least in KDE)."
  (let* ((wm-hints (append (x-window-property
			    "WM_HINTS" frame "WM_HINTS" source nil t)
			   nil))
	 (flags (car wm-hints)))
    (setcar wm-hints
	    (if arg
		(logior flags #x100)
	      (logand flags (lognot #x100))))
    (x-change-window-property "WM_HINTS" wm-hints frame "WM_HINTS" 32 t)))

(defun x-urgent (&optional arg)
  "Mark the current Emacs frame as requiring urgent attention.

With a prefix argument which does not equal a boolean value of nil, remove the urgency flag (which might or might not change display, depending on the window manager)."
  (interactive "P")
  (let (frame (selected-frame))
    (x-urgency-hint frame (not arg))))

(defmacro measure-time (&rest body)
  "Measure the time it takes to evaluate BODY."
  `(let ((time (current-time)))
     ,@body
     (format "%.06f" (float-time (time-since time)))))

;; MOTD
(defun my-create-motd-buffer ()
  "Create *MOTD* buffer and switch to it."
  (switch-to-buffer (generate-new-buffer "*MOTD*")))

(defun sudo-find-file (file-name)
  "Like find file, but open the file as root.
FILE-NAME is path to the file."
  (interactive "FSudo Find File: ")
  (find-file (concat "/sudo::" (expand-file-name file-name))))

(defun string-match-from-list-p (regexp-list string)
  (seq-find (lambda (author)
	      (string-match-p author string))
	    regexp-list))

;; TERM
(defun my-term-command (command &optional term-name pop-buffer)
  "Run COMMAND in ‘term-mode’ in the default shell.

TERM-NAME will be the buffer name, if nil it defaults to *term*.

If POP-BUFFER not nil it will pop the buffer in a new window, otherwise in current."
  (interactive (let ((command (read-string "Command: ")))
		 (list command)))
  (let ((term-name (or term-name "term"))) ;default value for TERM-NAME
    (set-buffer (apply #'make-term term-name
  		       (getenv "SHELL")
  		       nil
  		       (list "-c" command)))
    (term-mode)
    (term-char-mode)
    (if pop-buffer
	(pop-to-buffer (concat "*" term-name "*"))
      (switch-to-buffer (concat "*" term-name "*")))))

;; FIXME: this doesn't work, maybe there is another map for term?
(eval-after-load 'term
  '(define-key term-mode-map (kbd "M-o") #'other-window))

(defun my-swap-windows ()
  "Swap positions of current window and `next-window'."
  (interactive)
  (let ((current-buffer (current-buffer)))
    (switch-to-buffer (window-buffer (next-window)))
    (switch-to-buffer-other-window current-buffer)))
(global-set-key (kbd "M-O") #'my-swap-windows)

(defun my-find-url-file (url)
  "Open a remote file in place with appropriate major mode selected.

Works for images, pdfs, etc."
  (interactive "sURL: ")
  (url-retrieve url
		(lambda (status)
		  (when-let* ((err (plist-get status :error))
			      (code (assoc (nth 2 err) url-http-codes)))
		    (user-error "[my-find-url-file] %d: %s"
				(car code) (caddr code)))
		  (delete-region (point-min) (1+ url-http-end-of-headers))
		  (switch-to-buffer (current-buffer))
		  (normal-mode))))

(defun my-current-file-name ()
  "Show and save to the kill ring and the X clipboard current file's name."
  (interactive)
  (let ((file-name (buffer-file-name)))
   (with-temp-buffer
     (insert file-name)
     (clipboard-kill-ring-save (point-min) (point-max))
     (message file-name))))


;; Import parts of the environment from .zshrc
(defvar my-env-to-import
  '("CXX" "CC" "PATH" "LD_LIBRARY_PATH" "C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH"
    "PKG_CONFIG_PATH")
  "A list of environment variables to import from ~/.zshrc")

(defun my-env-from-export (export-directive)
  "Return a list (VARIABLE VALUE) given an EXPORT_DIRECTIVE
(i.e. \"export VARIABLE=VALUE\"."
  (save-match-data
    (let ((export (and (string-match "^export " export-directive)
		       (split-string-and-unquote
			(substring-no-properties export-directive
						 (match-end 0))
			"="))))
      (unless (and export
		   (consp export)
		   (= (length export) 2))
	(user-error "Error: Bad export: %s" export-directive))
      (list (car export)
	    (string-trim (shell-command-to-string
			  (concat "echo " (cadr export))))))))

(with-temp-buffer
  (insert-file-contents-literally "~/.zshrc")
  (goto-char (point-min))
  (while (re-search-forward "^export [[:alnum:]_]+=.*$" nil t)
    (let ((var (my-env-from-export (match-string-no-properties 0))))
      (when (member (car var) my-env-to-import)
	(apply #'setenv var)))))

(defun my-timer (time message)
  "Show the notification with MESSAGE after TIME."
  (interactive (list (read-string "Time: ")
		     (read-string "Message: ")))
  (unless (string-match-p "[[:digit:]:]+" time)
    (user-error "[my-timer] Wrong time format"))
  (let* ((split-time (nreverse (mapcar #'string-to-number
				       (split-string time ":")))))
    (setq time (apply #'+ (seq-map-indexed (lambda (value idx)
				   (* (expt 60 idx) value))
				 split-time)))
    (run-at-time time nil (lambda ()
			    (call-process "notify-send" nil nil nil
					  "Timer finished" message)))
    (message "Timer started. Finishing in %s seconds..." time)))

;; ==================== PACKAGES ====================

;; TODO: customize company theming for tangotango and remove monokai
;; or customize coloring in monokai
;; (use-package monokai-theme
;;   :config
;;   (load-theme 'monokai t)
;;   (set-face-attribute 'default nil :height 120))

;; (use-package tangotango-theme
;;   :config
;;   (load-theme 'tangotango t))

(dolist (theme-dir (directory-files (concat user-emacs-directory "themes")
				    'full "[^\.]"))
  (add-to-list 'custom-theme-load-path theme-dir)
  (add-to-list 'load-path theme-dir))

(defcustom my-theme-light 'leuven
  "Light theme.

Can be a symbol or a function that takes no arguments and returns a symbol.")
(defcustom my-theme-dark 'wombat
  "Dark theme.

Can be a symbol or a function that takes no arguments and returns a symbol.")
(when (member 'monokai (custom-available-themes))
  (setq my-theme-dark 'one-dark))
(when (member 'one-dark (custom-available-themes))
  (setq my-theme-dark 'one-dark))

(defvar my-theme-current-type 'light)

(defvar my-light-themes '(one-light lenlen))
(let ((themes (apply #'vector
		     (or (seq-intersection my-light-themes
					   (custom-available-themes))
			 '(leuven)))))
  (defun my-random-light-theme ()
    (elt themes (random (length themes)))))
;; (setq my-theme-light #'my-random-light-theme)
(setq my-theme-light 'one-light)

(defvar my-theme-after-switch-hook nil
  "Functions to call after theme is switched with `my-theme-switch'.

A function should take one argument - the type of the theme.")

(defun my-theme-switch (&optional type)
  "Switch between dark and light themes specified in `my-theme-light' and
`my-theme-dark' variables.

TYPE is either 'light or 'dark symbol."
  (interactive)
  (defun get-theme (theme)
    (cond ((functionp theme) (funcall theme))
	  (t theme)))
  (unless type
    (setq type (if (eq my-theme-current-type 'light)
		   'dark
		 'light)))
  (unless (member type '(light dark))
    (user-error "Wrong theme type: %s" type))
  (seq-do #'disable-theme custom-enabled-themes)
  (cl-case type
    ('dark (load-theme (get-theme my-theme-dark) 'no-confirm)
	   (setq my-theme-current-type 'dark))
    ('light (load-theme (get-theme my-theme-light) 'no-confirm)
	    (setq my-theme-current-type 'light))
    (t (error "Don't know what theme to choose!")))
  (run-hook-with-args 'my-theme-after-switch-hook type))

(defun my-theme-after-load-leuven (type)
  (when (and (eq type 'light) (custom-theme-enabled-p 'leuven))
    (setq org-todo-keyword-faces
	  '(("TODO" .
	     (t (:box (:line-width 1 :color "#ec9e14") :weight bold
		      :background "#f2e3ca" :foreground "#ec9e14")))
	    ("IN-PROGRESS" .
	     ((t (:box (:line-width 1 :color "#00a2e4")
		       :background "#bcd6e0" :foreground "#00a2e4"))))
	    ("WAITING" .
	     ((t (:box (:line-width 1 :color "#c96332") :weight bold
		       :background "#eed2c5" :foreground "#c96332"))))))
    (custom-theme-set-faces
     'leuven
     '(default ((t (:background "#fffff7"))))
     '(Man-overstrike ((t (:foreground "#82481e" :weight bold))))
     '(Man-underline ((t (:foreground "lime green" :weight bold))))
     '(Info-quoted ((t (:foreground "dark slate blue" :weight bold)))))))

(add-hook 'my-theme-after-switch-hook #'my-theme-after-load-leuven)

(use-package org-beautify-theme
  :init
  (defun my-org-beautify-enable (arg)
    (run-at-time
     1 nil
     (lambda () (load-theme 'org-beautify 't))))
  (add-hook 'my-theme-after-switch-hook #'my-org-beautify-enable))


(when (or (daemonp) (display-graphic-p))
  (my-theme-switch 'dark)
  (set-face-attribute 'default nil :height 120 :family "DejaVu Sans Mono")
  ;; Set font for emoticons since DejaVu Sans Mono doesn't have them.
  ;; If Symbola is not available, use DejaVu Sans (it's not as complete).
  (if (member "Symbola" (font-family-list))
      (set-fontset-font t (cons #x1f030 #x1f644)
			"Symbola" nil 'prepend)
    (set-fontset-font t (cons #x1f030 #x1f644)
		      "DejaVu Sans" nil 'prepend)))

;; IVY
(use-package flx)  ;better matching for Ivy
(use-package smex) ;better M-x, remembers frequently used commands
(use-package ivy
  :demand
  :init
  ;; use fuzzy regex for everything but swiper
  (setq ivy-re-builders-alist
	'((t . ivy--regex-fuzzy)
	  (swiper . ivy--regex-plus)
	  (counsel-git . ivy--regex-plus)
	  (counsel-git-grep . ivy--regex-plus)))
  :config
  (ivy-mode t)
  (diminish 'ivy-mode)
  :bind (:map ivy-minibuffer-map
	      ("C-s" . #'ivy-toggle-fuzzy)))

(use-package swiper
  :bind
  ;; (("C-s" . #'counsel-grep-or-swiper)
  ;;  ("M-s M-s" . #'isearch-forward)
  ;;  ("M-s M-r" . #'isearch-backward))
  ("M-s M-s" . #'swiper))
(use-package counsel
  :bind
  (("M-x" . #'counsel-M-x)
   ;; ("C-x C-f" . #'counsel-find-file) ;; switched to helm
   ("<f1> f" . #'counsel-describe-function)
   ("<f1> v" . #'counsel-describe-variable)
   ("<f1> l" . #'counsel-find-library)
   ("<f1> s" . #'counsel-info-lookup-symbol)
   ("<f1> S" . #'describe-syntax) ;; switched from "<f1> s"
   ("<f1> u" . #'counsel-unicode-char)
   ;; Attention: C-c bindings for git (may interfere with other modes)
   ("C-c f" . #'counsel-git)
   ("C-c j" . #'counsel-git-grep)
   ("C-c k" . #'counsel-ag)))

(use-package helm
  :defer nil
  :init
  ;; HACK: Fix for the memory leak.
  (setq helm-ff-keep-cached-candidates nil)
  :config
  (require 'helm)
  (require 'helm-config)
  (with-eval-after-load 'helm-buffers
    (define-key helm-buffer-map (kbd "C-k") #'helm-buffer-run-kill-persistent)
    (define-key helm-buffer-map (kbd "C-M-k") #'helm-buffer-run-kill-buffers))
  :bind
  (("C-x f" . helm-for-files)
   ("C-x C-f" . helm-find-files)
   ("C-x b" . helm-buffers-list)
   ("C-x C-b" . helm-buffers-list)))

;; The line below conflicts with helm-map. When helm-map is created it throws
;; an error. The reason are these lines in helm.el inside
;; (defvar helm-map ...):
;;; (cl-dolist (k (where-is-internal 'describe-mode global-map))
;;;   (define-key map k 'helm-help))
;;
;; It tries to bind C-z m to the map but it conflicts with previous binding.
;; The solution is to put (define-key ...) inside (ignore-errors ...). I don't
;; care if helm can't create some bindings, especially for describe-mode lol.
;; Non-invasive solution is to eval this line after helm was loaded.
;; WARNING: byte-compile helm.el after the change
;; NOTE: if helm-map is loaded before this line, it works fine and since
;;       helm functions is almost always my first used command, requiring it
;;       costs pretty much nothing
(define-key global-map (kbd "C-z") 'help-command)

(use-package flycheck
  :init
  ;; (add-hook 'c-mode-common-hook #'flycheck-mode)
  (add-hook 'python-mode-hook #'flycheck-mode))

(use-package company
  :diminish
  :init
  (setq company-idle-delay 0.25)
  (global-company-mode t)
  :bind
  ("C-\"" . #'company-complete))

(use-package yasnippet
  :defer nil
  :diminish yas-minor-mode
  :init
  (defun my-company-yasnippet (command &optional arg &rest ignore)
    (interactive (list 'interactive))
    "In company-search-mode company-active-map is used.
We need to exit that mode to call company-yasnippet."
    (company-abort)
    (company-yasnippet command arg ignore))
  :config
  (yas-global-mode 1)
  :bind
  ;; In company-search-mode company-active-map is used
  ;; We need to exit that mode to call company-yasnippet
  ;; Also we pass all needed args to it
  ("C-'" . #'my-company-yasnippet))
(use-package yasnippet-snippets)

(autoload #'my/c++-create-include-guard "~/.emacs.d/cpp-utils.el" nil t)

(add-hook 'c-mode-common-hook #'subword-mode)

(with-check-for-missing-packages ("ccls") "ccls" nil
  (setq ccls-executable
		  "/home/lampilelo/Programming/ccls/build/Release/ccls"))

(use-package eldoc :pin gnu)
(use-package flymake :pin gnu
  :init
  (setq flymake-start-on-save-buffer t))
(use-package xref :pin gnu)
(use-package project :pin gnu)

(use-package eglot
  :init
  (with-eval-after-load 'cc-mode
    ;; (add-hook 'c++-mode-hook #'eglot-ensure)
    (define-key c++-mode-map (kbd "C-c C-r") #'eglot-rename)
    (define-key c-mode-base-map (kbd "C-c o") #'ff-find-other-file))

  ;; company-clang backend is higher on a list but when using ccls it's
  ;; better to use company-capf backend
  (setq company-clang-modes nil)
  (setq eglot-autoshutdown t)
  :config
  (push (list 'c++-mode ccls-executable) eglot-server-programs)
  (push (list 'c-mode ccls-executable) eglot-server-programs)
  (push (list 'c++-mode "clangd") eglot-server-programs)
  (defun my-eglot-imenu-flatten-c-mode-advice (oldfun)
    (if (eq major-mode 'c-mode)
	(seq-reduce (lambda (result category)
		      (mapcar
		       (lambda (elem)
			 (setf (car elem)
			       (concat (car elem) "\t(" (car category) ")"))
			 elem)
		       (cdr category))
		      (append (cdr category) result))
		    (funcall oldfun)
		    '())
      (funcall oldfun)))
  (advice-add 'eglot-imenu :around #'my-eglot-imenu-flatten-c-mode-advice)
  (defun my-company-add-space-before-args (arg)
    (when (and (eq major-mode 'c-mode)
	       (stringp arg))
      (save-excursion
	(cond
	 ((looking-back "(" 0)
	  (backward-char 1)
	  (insert ?\ ))
	 ((looking-back "()" 0)
	  (backward-sexp)
	  (insert ?\ ))))))
  (add-hook 'company-after-completion-hook #'my-company-add-space-before-args)
  (defun my-eglot-show-help ()
    (interactive)
    (display-buffer (eglot--help-buffer)))
  (define-key eglot-mode-map (kbd "C-c h") #'my-eglot-show-help)
  (defun my-eglot-shutdown-all ()
    (interactive)
    (maphash (lambda (key value)
	       (when value
		 (eglot-shutdown (car value))))
	     eglot--servers-by-project))
  (defun my-eglot-restart ()
    (interactive)
    (if (eglot-current-server)
	(progn (eglot-shutdown (eglot-current-server))
	       (call-interactively #'eglot))
      (message "Server not running in the current buffer")))
  (defalias 'eglot-shutdown-all #'my-eglot-shutdown-all)
  (defalias 'eglot-restart #'my-eglot-restart))

;; (use-package eldoc-box
;;   :after eglot
;;   :hook (eldoc-box-hover-mode . eglot--managed-mode))

;; eglot uses flymake that doesn't show errors in the minibuffer, so:
;; (add-to-list 'load-path "~/.emacs.d/emacs-flymake-cursor")
;; (custom-set-variables
;;  '(help-at-pt-timer-delay 0.1)
;;  '(help-at-pt-display-when-idle '(flymake-diagnostic)))
;; OR (this is a workaround for some bug that above stumbles into
(advice-add 'eglot-eldoc-function :around
            (lambda (oldfun)
              (let ((help (help-at-pt-kbd-string)))
                (if help (message "%s" help) (funcall oldfun)))))
;; (add-hook 'flymake-mode-hook #'flymake-cursor)

;; DOXYMACS
(let ((path (expand-file-name "~/.emacs.d/doxymacs-1.8.0/build/lisp")))
  (when (file-exists-p path)
    (add-to-list 'load-path path)
    (setq doxymacs-doxygen-dirs
	  '(("Programming/my-youtube-client/"
	     "~/Programming/my-youtube-client/builddir/doc/tagfile.xml"
	     "~/Programming/my-youtube-client/builddir/doc/html/")))
    (setq doxymacs-browse-url-function
	  (lambda (url)
	    (funcall (if (package-installed-p 'w3m)
			 #'w3m
		       #'eww)
		     (concat "file://" (expand-file-name url))))))
  (with-eval-after-load 'cc-mode (require 'doxymacs)))

;; TODO: Configure cedit's map (cedit.el has a good documentation inside)
;; (use-package cedit
;;   :bind (:map c-mode-base-map
;; 	      ("M-k" . #'cedit-raise)))

;; I don't use it so it's disabled for now
;; (use-package rmsbolt)

;; C++ compile functions
(with-eval-after-load 'cc-mode
  (and (load (concat user-emacs-directory "cpp-editing-cmds.el") t)
       (define-key c-mode-base-map (kbd "C-M-t") #'cppedit-transpose-sexps))
  (defvar my/c++-build-systems-alist
    '(("meson.build" . my/c++--meson-compile)
      ("CMakeLists.txt" . my/c++--cmake-compile))
    "List of filenames that determine which build-system is used with corresponding function symbols to call when compiling with this system.")

  (defun my/c++--create-compile-commands-link (project-root build-dir)
    "Create symbolic link to compile_commands.json from BUILD-DIR to PROJECT-ROOT.

BUILD-DIR is just a name of directory in PROJECT-ROOT, not whole path.

For internal use only!"
    (unless (file-exists-p (concat project-root "compile_commands.json"))
      (message "compile_commands doesn't exist")
      (make-symbolic-link
       (concat project-root build-dir "/compile_commands.json")
       (concat project-root "compile_commands.json")
       t)))


  (defun my/c++--meson-compile (project-root)
    "Compile C++ project using Meson build system.

PROJECT-ROOT is the root directory of the project you want to compile.

Function uses PROJECT-ROOT/builddir for its build directory and ninja as
a backend for compilation."
    ;; if builddir directory doesn't exist, create it
    (unless (file-exists-p (concat project-root "builddir"))
      (shell-command "meson builddir"))
    ;; create symbolic link to compile_commands.json in the project root dir
    ;; if it doesn't already exist
    (my/c++--create-compile-commands-link project-root "builddir")
    ;; compile using ninja
    (compile (concat "cd " project-root "builddir && " "ninja")))


  (defun my/c++--cmake-compile (project-root)
    "Compile C++ project using CMake build system.

PROJECT-ROOT is the root directory of the project you want to compile.

Function uses PROJECT-ROOT/build for its build directory."
    ;; if build directory doesn't exist, create it
    (unless (file-exists-p (concat project-root "build"))
      (make-directory (concat project-root "build")))
    ;; create symbolic link to compile_commands.json in the project root dir
    ;; if it doesn't already exist
    (my/c++--create-compile-commands-link project-root "build")
    ;; run cmake and make from inside build directory
    (compile (concat "cd " project-root "build && "
		     "cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=YES .. && "
		     "make")))

  (defun my/c++--find-project-root ()
    "Find project root.

Returns string of absolute path to project root directory
or nil if not found."
    (ignore-errors
      (file-truename (or
		      ;; check if cquery found root dir, return nil if not
		      (ignore-errors
			(when-let (dir (locate-dominating-file
					default-directory
					"compile_commands.json"))
			  (expand-file-name dir)))
		      ;; if cquery didn't find root, find it by git
		      (vc-git-root buffer-file-name)))))
  (defun my-c++-find-project (dir)
    (let* ((default-directory dir)
	   (root (my/c++--find-project-root)))
      (when root
	(cons 'cpp root))))
  (cl-defmethod project-root ((project (head cpp)))
    (cdr project))
  (add-hook 'project-find-functions #'my-c++-find-project)


  (defvar my/c++-compile-before-hook nil)
  (defvar my/c++-compile-after-hook nil)

  ;; (assoc-default "CMakeLists.txt" my/c++-build-systems-alist)
  ;; TODO: When compile_commands.json is a broken symbolic link in the project
  ;;       root, function doesn't work (cquery--get-root returns error).
  ;;       Maybe ask to initialize a project?
  (defun my/c++-compile ()
    "Compile current C++ project using detected build system."
    (interactive)
    (when (or (eq major-mode 'c++-mode)
	      (eq major-mode 'glsl-mode))
      (let ((project-root (my/c++--find-project-root)))
	(if project-root	;if project-root not found, var is nil
	    (progn
	      ;; check list of build systems and call appropriate compile func
	      (dolist (element my/c++-build-systems-alist)
		(when (file-exists-p (concat project-root (car element)))
		  (run-hooks 'my/c++-compile-before-hook)
		  (funcall (cdr element) project-root)
		  ;; run my/c++-compile-after-hook after the successful
		  ;; compilation
		  (let* ((proc (get-buffer-process
				(get-buffer "*compilation*")))
			 (old-sentinel (process-sentinel proc)))
		    (set-process-sentinel
		     proc
		     (lambda (process event)
		       (funcall old-sentinel process event)
		       (when (string= event "finished\n")
			 (run-hooks 'my/c++-compile-after-hook)))))))
	      (when (functionp 'lsp-cquery-enable)
		(lsp-cquery-enable)))
	  ;; else (when project root directory was not found)
	  (message "Project's root directory not found. \
Please initialize version control or build-system project.")))))

  (defun my/c++-run-cppcheck ()
    (let* ((project-dir (my/c++--find-project-root))
	   (cppcheck-file (concat project-dir "cppcheck.sh")))
      (when (file-exists-p cppcheck-file)
	(with-current-buffer (get-buffer "*compilation*")
		 (goto-char (point-max))
		 (read-only-mode 0)
		 (insert "\ncppcheck:\n")
		 (let ((default-directory project-dir))
		   (call-process "sh" nil t nil "cppcheck.sh"))
		 (read-only-mode 1)
		 (setq-local default-directory project-dir)))))
  (add-hook 'my/c++-compile-after-hook #'my/c++-run-cppcheck)

  ;; End of C++ compile functions

  (setq cpp-reference-index-path
	"~/cppreference-doc")
  (setq cpp-reference-wiki-path
	"~/cppreference-doc/reference/en")
  ;; (setq cpp-reference-wiki-path
  ;; 	"/usr/share/doc/cppreference/en/")

  (if (file-exists-p cpp-reference-wiki-path)
      (progn
	(autoload #'cpp-reference "~/.emacs.d/cpp-reference-mode.el" nil t)
	(define-key c++-mode-map (kbd "C-c d") #'cpp-reference))
    (display-warning "cppreference"
  		     (concat "cppreference not found in "
			     cpp-reference-wiki-path)))

  (defun my-grep-references ()
    "Find references of a symbol at point with grep."
    (interactive)
    ;; (counsel-git-grep nil (find-tag-default-as-symbol-regexp))
    (counsel-git-grep nil (symbol-name (symbol-at-point))))
  (defun my-find-references ()
    "Find references of a symbol at point with xref."
    (interactive)
    (xref-find-references (find-tag-default)))

  (define-key c++-mode-map (kbd "C-c C-c") #'my/c++-compile)
  (define-key c++-mode-map (kbd "C-.") #'xref-find-definitions-other-window)
  (define-key c++-mode-map (kbd "C-,") #'my-find-references)
  ;; (define-key c++-mode-map (kbd "M-,") #'my-grep-references)
  (define-key c++-mode-map (kbd "M-i") #'counsel-imenu)
  (define-key c++-mode-map (kbd "M-[") #'xref-pop-marker-stack)

  ;; TODO: Check if I could use LSP to give me the type of the variable
  ;; TODO: Add "public:" keyword before accessor functions and "private:"
  ;;       before a variable or create accessors at the bottom of class
  ;;       Maybe add a variable (or prefix argument) to set the behavior.
  (defun my-cpp-create-accessors ()
    "Create accessors to the variable declared on a current line.

By default accessors use constant references.
If the variable is a pointer or a reference, only \"const\" qualifier
is added."
    (interactive)
    (save-excursion
      (beginning-of-line-text)
      ;; FIXME: fundamental type variables should be passed by value
      (condition-case error
	  (save-match-data
	    (re-search-forward "\\<\\(?1:[[:word:]-_<>: ]*\\)\
\\(?:\s+\\(?2:[*&]+\\)?\\|\\(?2:[*&]+\\)\s+\\)\
\\(?3:[[:word:]-_:]+\\)"
			       (line-end-position))
	    (let* ((type (match-string 1))
		   (name (match-string 3))
		   ;; m_foo, _foo, foo_, mFoo => Foo
		   (setter-name (s-upper-camel-case
				 (s-replace-regexp "\\(^m?_*\\)\\|\\(_+$\\)"
						   ""
						   name)))
		   (pointer-or-ref (match-string 2)))
	      (princ-list type "\n" name "\n" setter-name "\n" pointer-or-ref)
	      (end-of-line)
	      (newline)
	      (insert "inline const " type
		      (format "%s " (or pointer-or-ref "&"))
		      (s-upper-camel-case name)
		      "() const {\n"
		      "return " name ";\n}\n")
	      (c-indent-defun)
	      (insert "inline void Set" (s-upper-camel-case name) "(const "
		      type (format "%s " (or pointer-or-ref "&"))
		      setter-name ") {\n" name " = " setter-name ";\n}\n")
	      (c-indent-defun)))
	(search-failed (message "Couldn't find a variable declaration."))))))
;; TEST CASES THAT PASSED :
;; char** foo;
;; char **foo;
;; char *foo;
;; char * foo;
;; std::string& foo;
;; std::string &foo;
;; const std::string& foo;
;; int foo = 5;
;; std::string foo = "blabla";
;; std::string foo("blabla");
;; std::string bla = foo;
;; std::string bla{"foo"};
;; thread-local int foo;
;; const int bla::foo = 5;
;; std::string id_;

(add-to-list 'load-path (substitute-env-in-file-name
			 "$HOME/.emacs.d/in-progress/cpp-scratchpad/"))
(autoload 'cpp-scratchpad-new
  (substitute-env-in-file-name
   "$HOME/.emacs.d/in-progress/cpp-scratchpad/cpp-scratchpad.el")
  nil t)
(defun my-kill-current-eglot-server ()
  (ignore-errors (eglot-shutdown (eglot--current-server))))
(eval-after-load 'cpp-scratchpad
  (add-hook 'cpp-scratchpad-before-kill-hook #'my-kill-current-eglot-server))
(setq cpp-scratchpad-before-kill-hook nil)


(use-package meson-mode
  :config
  (with-check-for-missing-packages ("meson") "MESON-MODE" nil))

(use-package helm-xref
  :init
  (eval-after-load 'xref '(require 'helm-xref))
  ;; (autoload 'helm-xref-show-xrefs "helm-xref")
  :config
  (setq xref-show-xrefs-function 'helm-xref-show-xrefs-27)
  (setq xref-show-definitions-function 'helm-xref-show-defs-27))


(use-package highlight-parentheses
  :defer nil
  :config
  (global-highlight-parentheses-mode)
  (diminish 'highlight-parentheses-mode))

;; (use-package smartparens
;;   :config
;;   (require 'smartparens-config)
;;   (show-smartparens-global-mode t)
;;   ;; (smartparens-global-mode 1)
;;   ;; smartparens-strict-mode changes kill commands to omit parens
;;   ;; TODO: add keybindings for manipulating sexpressions in elisp mode
;;   ;; (add-hook 'emacs-lisp-mode-hook 'smartparens-strict-mode)
;;   (sp-with-modes '(c-mode c++-mode)
;;     (sp-local-pair "{" nil :post-handlers '(("||\n[i]" "RET")))
;;     (sp-local-pair "/*" "*/" :post-handlers '((" | " "SPC")
;; 					      ("* ||\n[i]" "RET"))))

;; (global-set-key (kbd "C-M-t") #'sp-transpose-sexp)
;; ;; (global-set-key (kbd "M-r") #'sp-raise-sexp) ;replaces parent with the child
;; (global-set-key (kbd "M-(") #'sp-rewrap-sexp))

(electric-pair-mode)

(show-paren-mode)

(use-package paredit
  :diminish paredit-mode
  :init
  (dolist (hook '(emacs-lisp-mode-hook
		  lisp-interaction-mode-hook
		  scheme-mode-hook
		  eval-expression-minibuffer-setup-hook))
    (add-hook hook 'enable-paredit-mode))
  :bind (:map paredit-mode-map
	      ("M-k" . #'paredit-raise-sexp)
	      ("C-(" . #'paredit-wrap-round)
	      ("C-)" . #'paredit-close-round-and-newline)
	      ("M-(" . #'paredit-backward-slurp-sexp)
	      ("M-)" . #'paredit-forward-slurp-sexp)))

;; FIXME: Doesn't work so flawlessly inside of a comment.
;; TODO: single quotes
;; if show-paren--categorize-paren returns nil, process pos with following:
(define-advice show-paren--categorize-paren (:after-until (pos))
  (when (and (eq (syntax-class (syntax-after pos)) 7)
	     (show-paren--unescaped-p pos))
    (if (save-excursion (nth 3 (syntax-ppss (1+ pos))))
	(cons 1 pos)
      (cons -1 (1+ pos)))))
;; to remove advice: (advice-remove #'show-paren--categorize-paren nil)

;; TODO: Maybe use 'C-( C-(' for it, making C-( a prefix command.
;;       It would let you select the wrapping char (instead of using prefix
;;       arg).
;; TODO: The region thing is redundant because of electric-pair-mode. It's
;;       only useful in c++-mode because syntax table doesn't specify < as a
;;       paren char.
(defun my-wrap-round (&optional prefix beg end)
  "Wrap the following sexp in parentheses.

If \\[universal-argument\\] is used, wrap with a selected char in accordance
to the mode's syntax-table.
If region is selected, wrap the region instead of the sexp."
  (interactive "P\nr")
  (let* ((ch (if prefix (read-char "Input wrapping char") ?\())
	 (syntax (electric-pair-syntax-info ch)))
    (when (and (eq major-mode 'c++-mode)
	       (eq ch ?\<))
      (setq syntax (list ch ?\> nil nil)))
    (when syntax
      (save-excursion
	(unless (region-active-p)
	  (setq beg (point))
	  (setq end (progn (forward-sexp 1) (point))))
	(goto-char beg)
	(insert ch)
	(goto-char (1+ end))
	(insert (cadr syntax)))
      (goto-char beg)
      (indent-sexp)
      (forward-char))))
(global-set-key (kbd "C-(") #'my-wrap-round)

;; (with-eval-after-load 'cc-mode
;;   (use-package smartparens)
;;   (defun my-kill-hybrid-sexp ()
;;     "Kill a line respecting delimiters.
;; Used second time kills the delimiter and everything up to the next delimiter."
;;     (interactive)
;;     (if (member (char-to-string (char-after))
;; 		(cl-loop for (left . right) in sp-pair-list
;; 			 collect right))
;; 	(progn (delete-char 1)
;; 	       (unless (looking-at "\n")
;; 		 (sp-kill-hybrid-sexp (point))))
;;       (sp-kill-hybrid-sexp (point))))
;;   (define-key c-mode-base-map (kbd "C-k") #'my-kill-hybrid-sexp))

(use-package magit
  :init
  (with-check-for-missing-packages ("git") "MAGIT" nil)
  ;; set up ssh-agent
  (setenv "SSH_AUTH_SOCK"
	  (concat
	   (getenv "XDG_RUNTIME_DIR")
	   "/ssh-agent.socket"))
  :bind ("C-x g" . #'magit-status))

(use-package magit-todos
  :init
  (eval-after-load 'magit '(magit-todos-mode t)))

(use-package which-key
  :defer nil
  ;; According to documentation this should be :config, but it seems
  ;; like these options are reversed
  ;; How do you load mode before package is loaded?
  :config
  (which-key-mode 1)
  (diminish 'which-key-mode)
  ;; (global-unset-key (kbd "C-h C-h"))	;unbind conflicting key binding
  (substitute-key-definition 'help-for-help 'which-key-C-h-dispatch help-map)
  :bind ("C-*" . #'which-key-show-top-level))

(use-package whole-line-or-region
  :diminish (whole-line-or-region-mode whole-line-or-region-local-mode)
  :init
  (whole-line-or-region-global-mode nil)
  :config
  (defalias 'whole-line-or-region-kill-ring-save #'kill-ring-save)
  ;; (setcar (alist-get 'kill-ring-save whole-line-or-region-extensions-alist)
  ;; 	  'kill-ring-save)
  ;; (whole-line-or-region-bind-keys)
  )

(use-package dockerfile-mode)

;; ERC
(load "~/.emacs.d/erc-init.el")

;; YAML-MODE
(use-package yaml-mode)

;; LATEX

;; mainly additional navigation for LaTeX
(let ((byte-compile-warnings '(not-free-vars)))
  (use-package latex-extra
    :init
    (add-hook 'LaTeX-mode-hook #'latex-extra-mode)))

;; preview buffer for LaTeX
(use-package latex-preview-pane
  :pin melpa
  :init
  (eval-after-load 'latex-mode
    (add-hook 'LaTeX-mode-hook #'latex-preview-pane-mode))
  :config
  (latex-preview-pane-enable)
  (setq shell-escape-mode "-shell-escape"))

;; emacs' notifications.el
(use-package notifications)

;; ACE for switching windows
;; (use-package ace-window
;;   ;; TODO: Bind ace-delete-window
;;   :bind ("M-o" . #'ace-window))

;; Avy for jumping to char
(use-package avy
  :config
  (setq avy-background t)
  (custom-set-faces
   '(avy-lead-face   ((t (:background "#294552" :foreground "white"))))
   '(avy-lead-face-0 ((t (:background "#597884" :foreground "white"))))
   '(avy-lead-face-2 ((t (:background "#294552" :foreground "white"))))
   '(avy-lead-face-1 ((t (:background "#597884" :foreground "white")))))
  :bind (("C-;" . #'avy-goto-word-or-subword-1)
	 ("C-:" . #'avy-goto-char-in-line)
	 ("C-M-;" . #'avy-goto-char)))

(defun my/jump-to-next-char (query-char)
  "Jump forward to the closest QUERY-CHAR."
  (interactive (list (read-char "Query Char:")))
  (forward-char)			;omit char at point
  (unless (search-forward (char-to-string query-char) nil t)
    (message "Occurence not found."))
  (backward-char))

(defun my/jump-to-next-word (query-char)
  "Jump forward to the closest word starting with QUERY-CHAR."
  (interactive (list (read-char "Query Char:")))
  (forward-char)
  (unless (search-forward-regexp
	   (concat "\\<" (char-to-string query-char)) nil t)
    (message "Occurence not found."))
  (backward-char))

;; Mutliple cursors
;; Documentation: https://github.com/magnars/multiple-cursors.el
(use-package multiple-cursors
  :bind (("C-S-c C-S-c" . #'mc/edit-lines)
	 ("C->" . #'mc/mark-next-like-this)
	 ("C-<" . #'mc/mark-previous-like-this)
	 ("C-c C-<" . #'mc/mark-all-like-this)))

;; Undo tree
;; C-x u - undo-tree-visualize
;; C-?   - undo-tree-redo
(use-package undo-tree
  :defer nil
  :config
  (global-undo-tree-mode 1)
  (diminish 'undo-tree-mode))

;; PYTHON
;; (use-package company-jedi
;;   ;; python-virtualenv must be installed on a host system
;;   ;; I could automate it by checking and calling pip install
;;   :config
;;   (add-to-list 'company-backends 'company-jedi))
(use-package elpy
  ;; Python packages needed:
  ;;   jedi or rope, flake8, importmagic, autopep8, yapf
  :init
  (with-check-for-missing-packages
      ("jedi" "flake8" "importmagic" "autopep8" "yapf") "ELPY" nil)
  (eval-after-load 'python-mode
    '(elpy-enable)))

;; MAIL
(with-check-for-missing-packages ("mu") "MU4E" nil
  (add-to-list 'load-path "/usr/share/emacs/site-lisp/mu4e")
  (require 'mu4e)
  ;; (autoload 'mu4e "mu4e")
  (global-set-key (kbd "C-x m") 'mu4e)
  (eval-after-load 'mu4e
    '(load "~/.emacs.d/mu4e-init.el")))

;; password-store
;; https://git.zx2c4.com/password-store/tree/contrib/emacs/README.md
;; For smtp auth check defun smtpmail-try-auth-methods in smtpmail.el
;; (use-package password-store)

;; elfeed - for rss feeds
(use-package elfeed
  :defer t
  :config
  (setq elfeed-db-directory "~/.emacs.d/elfeed-db")
  (with-eval-after-load 'elfeed
    (load "~/.emacs.d/elfeed-init.el" t)
    (load "~/.emacs.d/elfeed-feeds.el" t)
    (elfeed-search-fetch nil)))

;; lyrics
(use-package lyrics
  :init
  (autoload 'my-lyrics "~/.emacs.d/my-lyrics.el"
    "Gets lyrics for a song playing in MOC player." t)
  :config
  (setq lyrics-backend 'lyrics-azlyrics)
  (load "~/.emacs.d/my-lyrics.el" t))

;; eww customization

(use-package eww
  :init
  (autoload 'my-search-web "~/.emacs.d/eww-init.el" nil t))

;; RUST
;; (use-package lsp-rust
;;   :config
;;   (setq lsp-rust-rls-command '("rustup" "run" "nightly" "rls"))
;;   (add-hook 'rust-mode-hook #'lsp-rust-enable)
;;   (add-hook 'rust-mode-hook #'flycheck-mode))

;; GUILE (SCHEME)
(use-package geiser
  :config
  (setq geiser-default-implementation 'guile)
  ;; (let ((guix-profile (substitute-env-vars "$HOME/.guix-profile/")))
  ;;   (add-to-list 'exec-path (concat guix-profile "bin"))
  ;;   (setenv "GUILE_LOAD_PATH" (concat guix-profile "share/guile/site/3.0"))
  ;;   (setenv "GUILE_LOAD_COMPILED_PATH"
  ;; 	    (concat guix-profile "lib/guile/3.0/site-ccache" ":"
  ;; 		    guix-profile "share/guile/site/3.0"))
  ;;   (setenv "PKG_CONFIG_PATH"
  ;; 	    (concat guix-profile "lib/pkgconfig")))
  )

;; PDF-TOOLS
;; Use pdf-tools instead of doc-view
(with-check-for-missing-packages
    ("gcc" "make" "automake" "autoconf" "libpng" "zlib" "poppler"
     "g++" "pkg-config") "pdf-tools" t
  (use-package pdf-tools
    :init
    (pdf-loader-install t)
    :config
    ;; latex-preview-pane hardcodes usage of doc-view so it doesn't update
    ;; properly when using pdf-tools; this is a workaround:
    (with-eval-after-load 'LaTeX-mode
      (when (member #'latex-preview-pane-mode LaTeX-mode-hook)
	(defun my-redefine-doc-view-revert-buffer-advice (oldfun)
	  (cl-letf (((symbol-function 'doc-view-revert-buffer)
		     #'revert-buffer))
	    (funcall oldfun)))
	(advice-add 'latex-preview-pane-update-p :around
		    #'my-redefine-doc-view-revert-buffer-advice)))))
;; to uninstall you have to call (pdf-tools-uninstall)

;; GNUS
;; (setq gnus-select-method '(nntp "news.aioe.org"))
(setq gnus-select-method '(nntp "news.gwene.org"))
(setq gnus-read-active-file nil)

;; INFO-LOOKMORE
;; ftp://download.tuxfamily.org/user42/info-lookmore.el

(with-eval-after-load 'info-look
  (info-lookup-add-help
   :mode 'scheme-mode
   :regexp "[^()`'‘’,\" \t\n]+"
   :doc-spec '(("(guile) Procedure Index" nil nil nil)
	       ("(guile) Variable Index" nil nil nil)
	       ("(guile) R5RS Index" nil nil nil)
	       ("(guile) Type Index" nil nil nil)
	       ("(guile) Concept Index" nil nil nil)
	       ("(r5rs)Index" nil "^[ 	]+-+ [^:]+:[ 	]*" "\\b")))
  ;; (info-lookup-add-help
  ;;  :mode 'c-mode
  ;;  :regexp "\\(?:scm\\|SCM\\)_.*"
  ;;  :doc-spec '(("(guile) Procedure Index" nil nil nil)))
  (info-lookup-add-help :mode 'python-mode
			:regexp "[[:alnum:]_()<> )]+"
			:doc-spec
			'(("(python) Index" nil ""))))

;; FIXME: Make it a function since dir-locals can't load a mode with just
;;        setting the variable. The function should be sufficient.
(define-minor-mode c-guile-mode
  "Minor mode enabling guile documentation when using `info-lookup-symbol' in
C files.

The documentation will be added to `c-mode' globally and be visible from the
outside of `c-guile-mode'."
  nil " Cguile" nil
  (defun c-guile--translation-func (item)
    (and (string-match-p "^\\*?\\(?:scm\\|SCM\\)_.*" item)
	 (concat item " (guile)")))
  (with-eval-after-load 'info-look
    (info-lookup-maybe-add-help
     :mode 'c-guile-mode
     :regexp "\\(?:scm\\|SCM\\)_.*"
     :doc-spec '(("(guile) Procedure Index" c-guile--translation-func nil nil)
		 ("(guile) Variable Index" c-guile--translation-func nil nil)
		 ("(guile) Type Index" c-guile--translation-func nil nil)))
    (let* ((mode-value (info-lookup->mode-value 'symbol 'c-mode))
	   (lst (nth 5 mode-value)))
      (unless (member 'c-guile-mode lst)
	(add-to-list 'lst 'c-guile-mode 'append)
	(setcar (nthcdr 5 mode-value) lst)
	(info-lookup-reset)))))

;; dpaste (like pastebin)
;; TODO: Interactively get syntax info to font-lock the paste
;;       It's done by adding '-F "syntax=scheme"' to the curl command
;;       List of syntax choices: http://dpaste.com/api/v2/syntax-choices/
;; TODO: When uploading plain text, modify the link to show raw text
(defun my-upload-region (start end &optional expiry-days)
  "Upload the contents of the region to dpaste.com.
Link to the paste is copied to a clipboard.

EXPIRY-DAYS is the number of days after which the paste will expire.

Return nil if not succeeded."
  (interactive
   (progn (unless (mark)
	    (user-error "The mark is not set now, so there is no region"))
	  (let ((expiry-days (read-number "Expiry days: " 3)))
	    (list (region-beginning) (region-end) expiry-days))))
  (let* ((buffer (generate-new-buffer "*dpaste result*"))
	 (result (call-process-region start end "curl" nil buffer nil
				      "-s"
				      "-F" (concat "expiry_days="
						   (number-to-string
						    (or expiry-days 3)))
				      "-F" "content=<-"
				      "http://dpaste.com/api/v2/")))
    (if (eq 0 result)
	(with-current-buffer buffer
	  (progn
	    (goto-char (point-min))
	    (clipboard-kill-ring-save (point) (line-end-position))
	    (and (buffer-name buffer)
	      	 (kill-buffer buffer))
	    (message
	     "Link to the uploaded paste copied to the system clipboard...")))
      (and (buffer-name buffer)
	   (kill-buffer buffer)
	   nil))))
;; end of dpaste

;; unkillable scratch
(load "~/.emacs.d/unkillable-scratch.el")
(unkillable-scratch t)
;; end of unkillable scratch

;; my web search
;; TODO: add to load-path?
(autoload #'web-search "~/.emacs.d/web-search.el" nil t)
(global-set-key (kbd "C-c s") #'web-search)
;; end of my web search

;; wgrep
(use-package wgrep)
;; end of wgrep

;; nov.el (epub)
;; (add-to-list 'auto-mode-alist (cons "\\.epub\\'" 'nov-mode))
;; (let ((nov-file "/ssd-data/lampilelo/Programming/nov.el/nov.elc"))
;;   (autoload 'nov-mode nov-file nil t)
;;   (eval-after-load nov-file '(warn "Using local nov.el"))
;;   (setq nov-text-width 77)
;;   (with-eval-after-load 'nov
;;     (define-key nov-mode-map (kbd "<up>") #'scroll-down-line)
;;     (define-key nov-mode-map (kbd "<down>") #'scroll-up-line)))

(use-package nov
  :init
  (add-to-list 'auto-mode-alist (cons "\\.epub\\'" 'nov-mode))
  (setq nov-text-width 77)
  :bind (:map nov-mode-map
	      ("<up>" . #'scroll-down-line)
	      ("<down>" . #'scroll-up-line)))
;; end of nov.el

;; haskell
(use-package haskell-mode
  :init
  (setq haskell-compile-command
	"ghc -Wall -ferror-spans -fforce-recomp -dynamic %s")
  (eval-after-load 'haskell-mode
    '(setq flymake-allowed-file-name-masks
	   (remove '("\\.l?hs\\'" haskell-flymake-init)
		   flymake-allowed-file-name-masks)))
  (with-eval-after-load 'eglot
    (add-to-list
     'eglot-server-programs
     '(haskell-mode . ("/home/lampilelo/docker/haskell-ide-engine/installed/bin/hie" "--lsp"))))
  :bind (:map haskell-mode-map
	      ("C-c C-c" . haskell-compile)))
;; end of haskell

;; emms
(use-package emms
  :init
  (setq emms-source-file-default-directory "~/Music/")
  :config
  (require 'emms-setup)
  (emms-all)
  (emms-default-players)
  (require 'emms-history)
  (emms-history-load)
  ;; (load "~/.emacs.d/emms-init.el")
  )
;; end of emms

(use-package ox-reveal
  :after ox
  :init
  (require 'ox-reveal)
  (let* ((ox-reveal-path (file-name-directory (locate-library "ox-reveal")))
	 (reveal-js-path (concat ox-reveal-path "reveal.js")))
    (unless (file-exists-p reveal-js-path)
      (require 'dom)
      (url-retrieve
       "https://github.com/hakimel/reveal.js/releases/latest"
       (lambda (status ox-reveal-args reveal-js-path)
	 (let* ((ghub-dom
		 (libxml-parse-html-region (point-min) (point-max)))
		(tar-file (concat ox-reveal-path "reveal.js.tar.gz"))
		(default-directory ox-reveal-path)
		(untarred-dir
		 (progn
		   (url-copy-file
		    (concat
		     "https://github.com"
		     (dom-attr (seq-find
				(lambda (dom)
				  (string-match-p "archive.*tar\\.gz"
						  (dom-attr dom 'href)))
				(dom-by-tag ghub-dom 'a))
			       'href))
		    tar-file)
		   ;; Untar and get the first entry in the log, which should
		   ;; be the top-most directory
		   (with-temp-buffer
		     (call-process "tar" nil t nil
				   "xvf" tar-file)
		     (goto-char (point-min))
		     (buffer-substring-no-properties (point-at-bol)
						     (point-at-eol))))))
	   (rename-file untarred-dir reveal-js-path)
	   (delete-file tar-file)))
       (list ox-reveal-path reveal-js-path)))
    (setq org-reveal-root reveal-js-path)))

(use-package glsl-mode
  :bind (:map glsl-mode-map
	      ("C-c C-c" . my/c++-compile)))
(use-package company-glsl
  :config
  (when (executable-find "glslangValidator")
    (add-to-list 'company-backends 'company-glsl)))

(use-package scala-mode
  :config
  (add-hook 'scala-mode-hook #'subword-mode)
  (let ((metals-executable (concat (file-truename user-emacs-directory)
				   "scala-metals/metals-emacs")))
    (unless (file-exists-p metals-executable)
      (let ((default-directory (file-name-directory metals-executable)))
	(pop-to-buffer
	 (process-buffer (start-process "update-metals" "*update-metals*" "sh"
					"update-metals.sh")))))
    (when (file-exists-p metals-executable)
      (with-eval-after-load 'eglot
	(add-to-list 'eglot-server-programs
		     `(scala-mode ,metals-executable))))))

(use-package sbt-mode
  :commands sbt-start sbt-command
  ;; :config
  ;; WORKAROUND: https://github.com/ensime/emacs-sbt-mode/issues/31
  ;; allows using SPACE when in the minibuffer
  ;; (substitute-key-definition
  ;;  'minibuffer-complete-word
  ;;  'self-insert-command
  ;;  minibuffer-local-completion-map)
  )

;; (use-package ox-hugo
;;   :init
;;   (eval-after-load 'ox '(require 'ox-hugo)))

(defun my-translate--maybe-start-goldendict ()
  (unless (= 0 (call-process "pidof" nil nil nil "goldendict"))
    (start-process "goldendict" nil "goldendict")
    (sleep-for 0.5)))

(defun my-translate (string)
  "Translate a STRING using goldendict."
  (interactive "MString: ")
  (my-translate--maybe-start-goldendict)
  (call-process "goldendict" nil nil nil string))

(defun my-translate-word-at-point ()
  (interactive)
  (my-translate (word-at-point)))

;; (use-package projectile
;;   :init
;;   (define-key projectile-mode-map (kbd "C-c p") #'projectile-command-map))

(use-package gdscript-mode
  :init
  (with-eval-after-load 'eglot
    (defun my-eglot-godot-connect ()
      (interactive)
      (eglot--connect
       'gdscript-mode
       (cons 'transient
	     (locate-dominating-file default-directory "project.godot"))
       'eglot-lsp-server
       (list "localhost" 6008)))
    ;; FIXME: doesn't work because of eglot bug
    ;; (add-to-list 'eglot-server-programs
    ;; 		 '(gdscript-mode . ("localhost" 6008)))
    ))

(use-package haxe-mode
  :init
  (add-to-list 'auto-mode-alist '("\\.hx\\'" . haxe-mode))
  (with-check-for-missing-packages ("node") "HAXE" nil
    (let ((haxe-lang-serv "/home/lampilelo/Programming/haxe/haxe-language-server/bin/server.js"))
      (if (file-exists-p haxe-lang-serv)
	  (with-eval-after-load 'eglot
	    (defclass eglot-haxe-ls (eglot-lsp-server) ()
	      :documentation "Haxe Language Server")
	    (cl-defmethod eglot-initialization-options
	      ((server eglot-haxe-ls))
	      (let* ((roots (project-root (eglot--project server)))
		     (root (car roots)))
	       `(:displayArguments [,(concat root "build.hxml")])))

	    (defun eglot--haxe-ls-contact (interactive)
	      (cons 'eglot-haxe-ls
		    (list (executable-find "node")
			  haxe-lang-serv)))
	    (add-to-list 'eglot-server-programs
			 `(haxe-mode . eglot--haxe-ls-contact))

	    ;; HACK: eglot-workspace-configuration should be used, but how?
	    ;;       Should it be set in haxe-mode-hook?
	    (defun my-eglot-haxe-advice (server)
	      (when (eglot-haxe-ls-p server)
		(jsonrpc-notify
		 server :workspace/didChangeConfiguration
		 (list :settings
		       '(:haxe.executable "/usr/bin/haxe")))
		t))
	    (advice-add #'eglot-signal-didChangeConfiguration :before-until
			#'my-eglot-haxe-advice))
	(warn "Haxe Language Server not found at `%s'" haxe-lang-serv))))
  (defun my-haxe-find-project (dir)
    (when (eq major-mode 'haxe-mode)
      (when-let ((file (locate-dominating-file dir "build.hxml")))
	(cons 'haxe (file-name-directory file)))))
  (cl-defmethod project-root ((project (head haxe)))
    (list (cdr project)))
  (add-hook 'project-find-functions #'my-haxe-find-project))

;; LUA + fennel
(use-package lua-mode
  :init
  (use-package company-lua
    :init
    (eval-after-load 'company '(add-to-list 'company-backends 'company-lua))
    :config
    (add-hook 'lua-mode-hook
	      (lambda () (setq-local company-lua-interpreter 'love))))
  (use-package flymake-lua
    :config
    (add-hook 'lua-mode-hook #'flymake-lua-load)))
(use-package fennel-mode
  :init
  (add-to-list 'auto-mode-alist '("\\.fnl\\'" . fennel-mode)))

;; TODO: Set it up so that the project root for elm is the directory with
;;       elm.json file in it.
(use-package elm-mode
  :init
  (eval-after-load 'eglot
    '(add-to-list 'eglot-server-programs '(elm-mode "elm-language-server")))
  (defun my-elm-find-project (dir)
    (when (eq major-mode 'elm-mode)
      (when-let ((file (locate-dominating-file dir "elm.json")))
	(cons 'elm (file-name-directory file)))))
  (add-hook 'project-find-functions #'my-elm-find-project))

(provide 'init)
;;; init.el ends here
