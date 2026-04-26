;;; test-backup-each-save.el --- tests for backup-each-save  -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'backup-each-save)

(defmacro bes--with-defaults (&rest body)
  "Run BODY with all backup-each-save customs bound to safe test defaults."
  `(let ((backup-each-save-ignored-directories nil)
         (backup-each-save-ignored-regexps nil)
         (backup-each-save-remote-files nil)
         (backup-each-save-filter-function #'identity)
         (backup-each-save-size-limit nil)
         (backup-each-save-mirror-location "/tmp/test-backups")
         (backup-each-save-time-format "%Y_%m_%d_%H_%M_%S"))
     ,@body))

;;; backup-each-save--backup-p

(ert-deftest bes-backup-p/normal-file ()
  "Normal local file with default settings should be backed up."
  (bes--with-defaults
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
             ((symbol-function 'buffer-size) (lambda () 100)))
     (should (backup-each-save--backup-p "/home/user/file.el")))))

(ert-deftest bes-backup-p/ignored-directory ()
  "File inside an ignored directory should not be backed up."
  (bes--with-defaults
   (let ((tmpdir (make-temp-file "bes-test-" t)))
     (unwind-protect
         (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
                   ((symbol-function 'buffer-size) (lambda () 100)))
           (setq backup-each-save-ignored-directories (list tmpdir))
           (should-not (backup-each-save--backup-p (expand-file-name "passwords.el" tmpdir))))
       (delete-directory tmpdir t)))))

(ert-deftest bes-backup-p/not-in-ignored-directory ()
  "File outside all ignored directories should still be backed up."
  (bes--with-defaults
   (let ((tmpdir (make-temp-file "bes-test-" t)))
     (unwind-protect
         (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
                   ((symbol-function 'buffer-size) (lambda () 100)))
           (setq backup-each-save-ignored-directories (list tmpdir))
           (should (backup-each-save--backup-p "/home/user/projects/file.el")))
       (delete-directory tmpdir t)))))

(ert-deftest bes-backup-p/multiple-ignored-directories ()
  "File matching any entry in the ignored-directories list should not be backed up."
  (bes--with-defaults
   (let ((tmpdir1 (make-temp-file "bes-test-secrets-" t))
         (tmpdir2 (make-temp-file "bes-test-private-" t)))
     (unwind-protect
         (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
                   ((symbol-function 'buffer-size) (lambda () 100)))
           (setq backup-each-save-ignored-directories (list tmpdir1 tmpdir2))
           (should-not (backup-each-save--backup-p (expand-file-name "notes.el" tmpdir1)))
           (should-not (backup-each-save--backup-p (expand-file-name "key.el" tmpdir2)))
           (should (backup-each-save--backup-p "/home/user/projects/code.el")))
       (delete-directory tmpdir1 t)
       (delete-directory tmpdir2 t)))))

(ert-deftest bes-backup-p/ignored-directory-tilde ()
  "Ignored directories with ~ should be expanded before comparison."
  (bes--with-defaults
   (setq backup-each-save-ignored-directories (list (expand-file-name "~/")))
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
             ((symbol-function 'buffer-size) (lambda () 100)))
     (should-not (backup-each-save--backup-p (expand-file-name "~/file.el"))))))

(ert-deftest bes-backup-p/ignored-regexp-match ()
  "File matching an ignored regexp should not be backed up."
  (bes--with-defaults
   (setq backup-each-save-ignored-regexps '("\\.el\\'"))
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
             ((symbol-function 'buffer-size) (lambda () 100)))
     (should-not (backup-each-save--backup-p "/home/user/file.el")))))

(ert-deftest bes-backup-p/ignored-regexp-no-match ()
  "File not matching any ignored regexp should be backed up."
  (bes--with-defaults
   (setq backup-each-save-ignored-regexps '("\\.org\\'"))
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
             ((symbol-function 'buffer-size) (lambda () 100)))
     (should (backup-each-save--backup-p "/home/user/file.el")))))

(ert-deftest bes-backup-p/multiple-ignored-regexps ()
  "File matching any entry in the ignored-regexps list should not be backed up."
  (bes--with-defaults
   (setq backup-each-save-ignored-regexps '("\\.org\\'" "\\.gpg\\'"))
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
             ((symbol-function 'buffer-size) (lambda () 100)))
     (should-not (backup-each-save--backup-p "/home/user/notes.org"))
     (should-not (backup-each-save--backup-p "/home/user/secrets.gpg"))
     (should (backup-each-save--backup-p "/home/user/code.el")))))

(ert-deftest bes-backup-p/remote-file-blocked ()
  "Remote file should not be backed up when backup-each-save-remote-files is nil."
  (bes--with-defaults
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) t))
             ((symbol-function 'buffer-size) (lambda () 100)))
     (should-not (backup-each-save--backup-p "/ssh:host:/file.el")))))

(ert-deftest bes-backup-p/remote-file-allowed ()
  "Remote file should be backed up when backup-each-save-remote-files is t."
  (bes--with-defaults
   (setq backup-each-save-remote-files t)
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) t))
             ((symbol-function 'buffer-size) (lambda () 100)))
     (should (backup-each-save--backup-p "/ssh:host:/file.el")))))

(ert-deftest bes-backup-p/filter-function-rejects ()
  "File rejected by custom filter function should not be backed up."
  (bes--with-defaults
   (setq backup-each-save-filter-function (lambda (_) nil))
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
             ((symbol-function 'buffer-size) (lambda () 100)))
     (should-not (backup-each-save--backup-p "/home/user/file.el")))))

(ert-deftest bes-backup-p/filter-function-accepts ()
  "File accepted by custom filter function should be backed up."
  (bes--with-defaults
   (setq backup-each-save-filter-function (lambda (f) (string-match-p "\\.el\\'" f)))
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
             ((symbol-function 'buffer-size) (lambda () 100)))
     (should (backup-each-save--backup-p "/home/user/file.el"))
     (should-not (backup-each-save--backup-p "/home/user/file.txt")))))

(ert-deftest bes-backup-p/size-over-limit ()
  "File exceeding the size limit should not be backed up."
  (bes--with-defaults
   (setq backup-each-save-size-limit 1000)
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
             ((symbol-function 'buffer-size) (lambda () 2000)))
     (should-not (backup-each-save--backup-p "/home/user/file.el")))))

(ert-deftest bes-backup-p/size-at-limit ()
  "File exactly at the size limit should be backed up."
  (bes--with-defaults
   (setq backup-each-save-size-limit 1000)
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
             ((symbol-function 'buffer-size) (lambda () 1000)))
     (should (backup-each-save--backup-p "/home/user/file.el")))))

(ert-deftest bes-backup-p/size-under-limit ()
  "File under the size limit should be backed up."
  (bes--with-defaults
   (setq backup-each-save-size-limit 1000)
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
             ((symbol-function 'buffer-size) (lambda () 500)))
     (should (backup-each-save--backup-p "/home/user/file.el")))))

(ert-deftest bes-backup-p/size-limit-nil ()
  "When size limit is nil, files of any size should be backed up."
  (bes--with-defaults
   (setq backup-each-save-size-limit nil)
   (cl-letf (((symbol-function 'file-remote-p) (lambda (_) nil))
             ((symbol-function 'buffer-size) (lambda () 999999999)))
     (should (backup-each-save--backup-p "/home/user/file.el")))))

;;; backup-each-save--compute-location

(ert-deftest bes-compute-location/path-under-mirror ()
  "Backup path should be rooted under the mirror location."
  (bes--with-defaults
   (cl-letf (((symbol-function 'format-time-string) (lambda (_) "2024_01_01_12_00_00")))
     (let ((result (backup-each-save--compute-location "/home/user/projects/file.el")))
       (should (string-prefix-p "/tmp/test-backups/" result))))))

(ert-deftest bes-compute-location/mirrors-directory-tree ()
  "Backup path should mirror the source file's directory tree."
  (bes--with-defaults
   (cl-letf (((symbol-function 'format-time-string) (lambda (_) "2024_01_01_12_00_00")))
     (let ((result (backup-each-save--compute-location "/home/user/projects/file.el")))
       (should (string-prefix-p "/tmp/test-backups/home/user/projects/" result))))))

(ert-deftest bes-compute-location/basename-and-timestamp ()
  "Backup filename should be basename suffixed with a timestamp."
  (bes--with-defaults
   (cl-letf (((symbol-function 'format-time-string) (lambda (_) "2024_01_01_12_00_00")))
     (let ((result (backup-each-save--compute-location "/home/user/projects/file.el")))
       (should (string-suffix-p "file.el-2024_01_01_12_00_00" result))))))

(ert-deftest bes-compute-location/mirror-tilde-expanded ()
  "A ~ in the mirror location should be expanded to an absolute path."
  (bes--with-defaults
   (setq backup-each-save-mirror-location "~/backups")
   (cl-letf (((symbol-function 'format-time-string) (lambda (_) "ts")))
     (let ((result (backup-each-save--compute-location "/home/user/file.el")))
       (should (string-prefix-p (expand-file-name "~/backups") result))
       (should-not (string-prefix-p "~" result))))))

(ert-deftest bes-compute-location/no-double-slash ()
  "Computed path should not contain double slashes."
  (bes--with-defaults
   (cl-letf (((symbol-function 'format-time-string) (lambda (_) "ts")))
     (let ((result (backup-each-save--compute-location "/home/user/file.el")))
       (should-not (string-match-p "//" result))))))

(ert-deftest bes-compute-location/custom-time-format ()
  "Custom time format should be reflected in the backup filename."
  (bes--with-defaults
   (setq backup-each-save-time-format "%Y%m%d")
   (cl-letf (((symbol-function 'format-time-string) (lambda (&rest _) "20240101")))
     (let ((result (backup-each-save--compute-location "/home/user/file.el")))
       (should (string-suffix-p "file.el-20240101" result))))))

;;; backup-each-save (integration)

(ert-deftest bes-backup/copies-file ()
  "When backup-p returns t, copy-file should be called with correct src and dst."
  (bes--with-defaults
   (let (copied-from copied-to)
     (cl-letf (((symbol-function 'buffer-file-name) (lambda () "/home/user/file.el"))
               ((symbol-function 'backup-each-save--backup-p) (lambda (_) t))
               ((symbol-function 'backup-each-save--compute-location)
                (lambda (_) "/tmp/test-backups/home/user/file.el-ts"))
               ((symbol-function 'make-directory) #'ignore)
               ((symbol-function 'copy-file)
                (lambda (from to &rest _)
                  (setq copied-from from copied-to to))))
       (backup-each-save)
       (should (equal copied-from "/home/user/file.el"))
       (should (equal copied-to "/tmp/test-backups/home/user/file.el-ts"))))))

(ert-deftest bes-backup/skips-copy-when-backup-p-nil ()
  "When backup-p returns nil, copy-file should not be called."
  (bes--with-defaults
   (let (copy-called)
     (cl-letf (((symbol-function 'buffer-file-name) (lambda () "/home/user/file.el"))
               ((symbol-function 'backup-each-save--backup-p) (lambda (_) nil))
               ((symbol-function 'copy-file) (lambda (&rest _) (setq copy-called t))))
       (backup-each-save)
       (should-not copy-called)))))

(ert-deftest bes-backup/creates-directory ()
  "make-directory should be called for the backup container directory."
  (bes--with-defaults
   (let (created-dir)
     (cl-letf (((symbol-function 'buffer-file-name) (lambda () "/home/user/file.el"))
               ((symbol-function 'backup-each-save--backup-p) (lambda (_) t))
               ((symbol-function 'backup-each-save--compute-location)
                (lambda (_) "/tmp/test-backups/home/user/file.el-ts"))
               ((symbol-function 'make-directory)
                (lambda (dir &rest _) (setq created-dir dir)))
               ((symbol-function 'copy-file) #'ignore))
       (backup-each-save)
       (should (equal created-dir "/tmp/test-backups/home/user/"))))))

(ert-deftest bes-backup/no-backup-when-no-file-name ()
  "When buffer-file-name returns nil, no backup should be attempted."
  (bes--with-defaults
   (let (copy-called)
     (cl-letf (((symbol-function 'buffer-file-name) (lambda () nil))
               ((symbol-function 'copy-file) (lambda (&rest _) (setq copy-called t))))
       (backup-each-save)
       (should-not copy-called)))))

(provide 'test-backup-each-save)
;;; test-backup-each-save.el ends here
