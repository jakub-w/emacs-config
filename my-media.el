;; -*- lexical-binding: t -*-

(require 'seq)
(require 'cl-lib)

(defvar media--vorbis-exts '("ogg"))
(defvar media--flac-exts '("flac"))
(defvar media--id3-exts '("mp3"))
(defvar media--opus-exts '("opus"))
(defvar media--tags-dispatch
  `((,(regexp-opt media--vorbis-exts) :set media--set-vorbis-tags)
    (,(regexp-opt media--id3-exts) :set media--set-id3-tags)
    (,(regexp-opt media--flac-exts) :set media--set-flac-tags)
    (,(regexp-opt media--opus-exts) :set media--set-opus-tags))
  "An alist. The first value is a key in the form of a regex to match.
The cdr of every entry is a plist of setters (:set) and getters (:get).")

(defun media--check-extension (ext-list filename)
  (unless (member (file-name-extension filename) ext-list)
    (user-error "Wrong file type" filename)))

(defun media--set-vorbis-tags (artist album year title track-num filename)
  (setq filename (shell-quote-argument filename))
  (media--check-extension media--vorbis-exts filename)
  (unless (executable-find "vorbiscomment")
    (user-error "Could not find vorbiscomment"))
  (let ((tags (mapcar (lambda (tag)
			(string-match "\\([^=]+?\\)=\\(.*\\)" tag)
			(cons (upcase (match-string-no-properties 1 tag))
			      (match-string-no-properties 2 tag)))
		      (process-lines "vorbiscomment" "--list" filename))))
    (dolist (tag `(("ARTIST" . ,artist)
    		   ("ALBUM" . ,album)
    		   ("YEAR" . ,year)
    		   ("TITLE" . ,title)
    		   ("TRACKNUMBER" . ,track-num)))
      (setf (alist-get (car tag) tags nil nil #'string=) (cdr tag)))
    (shell-command
     (concat "vorbiscomment --raw --write "
	     (mapconcat
	      (lambda (tag)
		(if (cdr tag)
		    (format "--tag '%s=%s'" (car tag) (cdr tag))
		  ""))
	      tags " ")
	     " '" filename "'"))))

(defun media--set-flac-tags (artist album year title track-num filename)
  (media--check-extension media--flac-exts filename)
  (unless (executable-find "metaflac")
    (user-error "Could not find metaflac"))
  (let (tag-args)
    (when artist
      (push (format "--set-tag=ARTIST=%s" artist) tag-args)
      (push "--remove-tag=ARTIST" tag-args))
    (when album
      (push (format "--set-tag=ALBUM=%s" album) tag-args)
      (push "--remove-tag=ALBUM" tag-args))
    (when year
      (push (format "--set-tag=YEAR=%s" year) tag-args)
      (push "--remove-tag=YEAR" tag-args))
    (when title
      (push (format "--set-tag=TITLE=%s" title) tag-args)
      (push "--remove-tag=TITLE" tag-args))
    (when track-num
      (push (format "--set-tag=TRACKNUMBER=%s" track-num) tag-args)
      (push "--remove-tag=TRACKNUMBER" tag-args))
    (apply #'call-process "metaflac" nil nil nil filename tag-args)))

(defun media--set-id3-tags (artist album year title track-num filename)
  (media--check-extension media--id3-exts filename)
  (let ((id3-exec
	 (or (executable-find "id3tag")
	     (executable-find "id3v2")
	     (user-error "Could not find neither id3tag nor id3v2"))))
    (call-process id3-exec nil nil nil
		  "--artist" artist
		  "--album" album
		  "--year" (format "%s" year)
		  "--song" title
		  "--track" (format "%s" track-num)
		  filename)))

(defun media--set-opus-tags (artist album year title track-num filename)
  (media--check-extension media--opus-exts filename)
  (let ((opus-exec (or (executable-find "ffmpeg")
		       (user-error "Could not find ffmpeg")))
	(temp-file (format "%s.opus" (make-temp-name "/tmp/music-file-"))))
    (when (= 0 (call-process opus-exec nil "*my-test-ffmpeg*" nil
			     "-i" filename
			     "-metadata" (format "artist=%s" artist)
			     "-metadata" (format "album=%s" album)
			     "-metadata" (format "date=%s" year)
			     "-metadata" (format "title=%s" title)
			     "-metadata" (format "tracknumber=%s" track-num)
			     "-codec" "copy"
			     temp-file))
      (copy-file temp-file filename t)
      (delete-file temp-file)
      t)))

(defun media-set-tags (artist album year title track-num filename)
  "Set id3 tags, vorbis comments or flac metadata of a music file."
  (setq filename (expand-file-name (substitute-in-file-name filename)))
  (let ((plist (assoc-default (file-name-extension filename)
			      media--tags-dispatch
			      #'string-match-p)))
    (if (not plist)
	(user-error "[media-set-tags] No known method to set tags")
      (funcall (plist-get plist :set)
	       artist album year title track-num filename))))

(defun media-extract-from-file (filename from to outfile &optional then)
  "Asynchronously extract a part of the file FILENAME designated by the time
values FROM and TO.  Save the result as OUTFILE.

Optional argument THEN should be a function taking a parameter to which
OUTFILE will be passed.  The function will be evaluated after this function
finishes (only if the extraction succeeded)."
  (let ((buffer (generate-new-buffer " *ffmpeg-extract*")))
    (make-process :name "*ffmpeg-extract*"
		  :buffer buffer
		  :command
		  (list "ffmpeg"
			"-i" filename
			"-acodec" "copy"
			"-ss" (format "%s" from)
			"-to" (format "%s" to)
			outfile)
		  :sentinel
		  (lambda (process event)
		    (unless (process-live-p process)
		      (if (= (process-exit-status process) 0)
			  (when then
			    (funcall then outfile)
			    (kill-buffer buffer))
			(pop-to-buffer buffer)))))))

(defun media-split-album (artist album year songlist input-file)
  "Split one-file album to multiple files based on SONGLIST.

Also set id3 tags in the output files using \"id3tag\" command.

SONGLIST needs to have a following format:
  ((1 \"Song 1 name\" \"0:00\" \"4:08\")
   (2 \"Song 2 name\" \"4:08\" \"8:03\")
   ... )
So every entry is: (<number> \"<name>\" \"<start-time>\" \"<end-time>\")"
  (unless (file-exists-p input-file)
    (user-error "[media-split-album] File doesn't exist: %s" input-file))
  (with-temp-buffer
    (dolist (song songlist)
      (let* ((title (nth 1 song))
	     (track-num (nth 0 song))
	     (from (nth 2 song))
	     (to (nth 3 song))
	     (outdir (format "%s(%d) %s/"
			     (file-name-directory input-file) year album))
	     (outfile (format "%s%02d. %s.%s"
			      outdir
			      track-num
			      title
			      (file-name-extension input-file))))
	(mkdir outdir t)
	(media-extract-from-file
	 input-file from to outfile
	 (lambda (outfile)
	   (media-set-tags artist album year title track-num outfile)))))))

(defun media-split-flac (cue-file flac-file)
  (cl-assert (and (executable-find "shnsplit")
		  (executable-find "cuetag.shs")))
  (with-temp-buffer
    (insert-file-contents cue-file)
    (let* ((year (progn
		   (goto-char (point-min))
		   (search-forward-regexp "DATE \\([[:digit:]]\\{4\\}\\)")
		   (match-string 1)))
	   (album
	    (progn (goto-char (point-min))
		   (search-forward-regexp "TITLE \"\\(.+\\)\"$")
		   (match-string 1)))
	   (outdir (format "%s(%s) %s/"
			  (file-name-directory flac-file)
			  year
			  album)))
      (make-directory outdir t)
      (erase-buffer)
      (unless (= 0 (call-process "shnsplit" nil t nil
				 "-f" cue-file
				 "-t" "%n. %t"
				 "-d" outdir
				 "-o" "flac"
				 flac-file))
	(error "Couldn't split the flac file: %s" (buffer-string)))
      (erase-buffer)
      (unless (= 0 (apply #'call-process "cuetag.sh" nil t nil
			  cue-file
			  (directory-files outdir t "^[^.].*")))
	(error ("Couldn't apply the tags to resulting flac files: %s"
		(buffer-string)))))))

