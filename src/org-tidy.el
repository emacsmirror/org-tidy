;;; org-stealth.el --- A minor mode to clean org-mode.

;;; Commentary:
;;

(require 'org)

;;; Code:

(defgroup org-tidy nil
  "Give you a clean org-mode buffer."
  :prefix "org-tidy-"
  :group 'convenience)

(defcustom org-tidy-properties t
  "If non-nil, add text properties to the region markers."
  :type 'boolean
  :group 'org-tidy)

(defcustom org-tidy-src-block t
  "If non-nil, add text properties to the region markers."
  :type 'boolean
  :group 'org-tidy)

(defvar-local org-tidy-overlays nil
  "Variable to store the regions we put an overlay on.")

(defun org-tidy-hide (beg end)
  "Hides a region by making an invisible overlay over it."
  (interactive)
  (unless (assoc (list beg end) org-tidy-overlays)
    (let ((new-overlay (make-overlay beg end)))
      (overlay-put new-overlay 'invisible t)
      (overlay-put new-overlay 'intangible t)
      (overlay-put new-overlay 'display
                   '(left-fringe flycheck-fringe-bitmap-double-arrow))
      (push (cons (list beg end) new-overlay) org-tidy-overlays))))

(defun org-tidy-src (beg end)
  "Hides a region by making an invisible overlay over it."
  (interactive)
  (unless (assoc (list beg end) org-tidy-overlays)
    (let ((new-overlay (make-overlay beg end)))
      (overlay-put new-overlay 'invisible t)
      (overlay-put new-overlay 'intangible t)
      ;; add underline
      ;; remove background
      ;; add language name
      ;; hide end_src
      ;; end_src overline
      (push (cons (list beg end) new-overlay) org-tidy-overlays))))

(defun org-untidy ()
  "Untidy."
  (interactive)
  (while org-tidy-overlays
    (let* ((ov (cdar org-tidy-overlays)))
      (message "ov:%s" ov)
      (delete-overlay ov)
      (setf org-tidy-overlays (cdr org-tidy-overlays)))))

(defun org-tidy ()
  "Tidy."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward org-property-drawer-re nil t)
        (let* ((beg (match-beginning 0))
               (end (1+ (match-end 0))))
          (org-tidy-hide beg end)))))

(provide 'org-tidy)

;;; org-tidy.el ends here
