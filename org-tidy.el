;;; org-tidy.el --- A minor mode to tidy org-mode buffers -*- lexical-binding: t; -*-

;; Copyright (C) 2023 Xuqing Jia

;; Author: Xuqing Jia <jxq@jxq.me>
;; URL: https://github.com/jxq0/org-tidy
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (dash "2.19.1"))
;; Keywords: convenience, org

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; A minor mode to tidy org-mode buffers.

(require 'org)
(require 'org-element)
(require 'dash)

;;; Code:

(defgroup org-tidy nil
  "A minor mode to tidy `org-mode' buffers."
  :prefix "org-tidy-"
  :group 'convenience)

(defcustom org-tidy-properties-style 'inline
  "How to tidy property drawers."
  :group 'org-tidy
  :type '(choice
          (const :tag "Show fringe bitmap" fringe)
          (const :tag "Show inline symbol" inline)
          (const :tag "Completely invisible" invisible)))

(defcustom org-tidy-top-property-style 'invisible
  "How to tidy the topmost property drawer."
  :group 'org-tidy
  :type '(choice
          (const :tag "Completely invisible" invisible)
          (const :tag "Keep" keep)))

(defcustom org-tidy-properties-inline-symbol "♯"
  "The inline symbol."
  :type 'string)

(defun org-tidy-protected-text-edit ()
  "Keymap to protect property drawers."
  (user-error "Property drawer is protected in org-tidy mode"))

(defvar org-tidy-properties-backspace-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<backspace>") 'org-tidy-protected-text-edit)
    map)
  "Keymap to protect property drawers.")

(defvar org-tidy-properties-delete-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-d") #'org-tidy-protected-text-edit)
    (define-key map (kbd "<deletechar>") 'org-tidy-protected-text-edit)
    map)
  "Keymap to protect property drawers.")

(defvar-local org-tidy-overlays nil
  "Variable to store the regions we put an overlay on.")

(define-fringe-bitmap
  'org-tidy-fringe-bitmap-sharp
  [#b00100100
   #b00100100
   #b11111111
   #b00100100
   #b00100100
   #b11111111
   #b00100100
   #b00100100])

(defun org-tidy-overlay-exists (ovly-beg ovly-end)
  "Check whether overlay from OVLY-BEG to OVLY-END exists."
  (-filter (lambda (item)
             (let* ((ov (plist-get item :ov))
                    (old-ovly-beg (overlay-start ov))
                    (old-ovly-end (overlay-end ov)))
               (and (= ovly-beg old-ovly-beg)
                    (>= ovly-end old-ovly-end))))
           org-tidy-overlays))

(defun org-tidy-make-protect-ov (backspace-beg backspace-end del-beg del-end)
  "Make two read-only overlay: (BACKSPACE-BEG, BACKSPACE-END) (DEL-BEG, DEL-END)."
  (let* ((backspace-ov (make-overlay backspace-beg backspace-end nil t t))
         (del-ov (make-overlay del-beg del-end nil t nil)))
    (overlay-put backspace-ov
                 'local-map org-tidy-properties-backspace-map)
    (overlay-put del-ov
                 'local-map org-tidy-properties-delete-map)

    (push (list :type 'protect :ov backspace-ov) org-tidy-overlays)
    (push (list :type 'protect :ov del-ov) org-tidy-overlays)))

(defun org-tidy-properties-single (element)
  "Tidy a single property ELEMENT."
  (-let* (((_ props _) element)
          ((&plist :begin beg :end end) props)
          (is-top-property (= 1 beg))
          (ovly-beg (if is-top-property 1 (1- beg)))
          (ovly-end (if is-top-property end (1- end))))
    (unless (org-tidy-overlay-exists ovly-beg ovly-end)
      (let* ((backspace-beg (1- end))
             (backspace-end end)
             (del-beg (max 1 (1- beg)))
             (del-end (1+ del-beg))
             (ovly (make-overlay ovly-beg ovly-end nil t nil))
             (push-ovly nil))
        (pcase (list is-top-property
                     org-tidy-top-property-style
                     org-tidy-properties-style)
          (`(t invisible ,_)
           (overlay-put ovly 'display "")
           (setf push-ovly t))
          (`(t keep ,_) (delete-overlay ovly))
          (`(nil ,_ inline)
           (overlay-put ovly 'display
                        (format " %s" org-tidy-properties-inline-symbol))
           (setf push-ovly t))
          (`(nil ,_ fringe)
           (overlay-put ovly 'display
                        '(left-fringe org-tidy-fringe-bitmap-sharp org-drawer))
           (setf push-ovly t)))

        (when push-ovly
          (push (list :type 'property
                      :ov ovly)
                org-tidy-overlays)

          (org-tidy-make-protect-ov backspace-beg backspace-end
                                    del-beg del-end))))))

(defun org-tidy-properties ()
  "Tidy drawers."
  (save-excursion
    (org-element-map (org-element-parse-buffer)
        'property-drawer #'org-tidy-properties-single)))

(defun org-tidy-untidy-buffer ()
  "Untidy."
  (interactive)
  (while org-tidy-overlays
    (-let* ((item (pop org-tidy-overlays))
            ((&plist :type type) item))
      (pcase type
        ('property (delete-overlay (plist-get item :ov)))
        ('protect (delete-overlay (plist-get item :ov)))
        (_ nil)))))

(defun org-tidy-buffer ()
  "Tidy."
  (interactive)
  (org-tidy-properties))

;;;###autoload
(define-minor-mode org-tidy-mode
  "Automatically tidy org mode buffers."
  :global nil
  :group 'org-tidy
  (if org-tidy-mode
      (progn
        (if (eq org-tidy-properties-style 'fringe)
            (let* ((width 10))
              (setq left-fringe-width width)
              (set-window-fringes nil width)))
        (org-tidy-buffer)
        (add-hook 'before-save-hook #'org-tidy-buffer nil t))
    (progn
      (if (eq org-tidy-properties-style 'fringe)
          (progn (setq left-fringe-width nil)
                 (set-window-fringes nil nil)))
      (org-tidy-untidy-buffer)
      (remove-hook 'before-save-hook #'org-tidy-buffer t))))

(provide 'org-tidy)

;;; org-tidy.el ends here
