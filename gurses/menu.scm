;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016 John Darrington <jmd@gnu.org>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gurses menu)
  
  #:export (make-menu)
  #:export (menu-post)
  #:export (menu-refresh)
  #:export (menu-down)
  #:export (menu-up)
  #:export (menu-redraw)
  #:export (menu-current-item)
  #:export (menu-active)
  #:export (menu-items)
  #:export (menu-window)
  #:export (menu-set-active!)
  #:export (menu-set-items!)
  #:export (menu-set-active-attr!)
  #:export (menu-set-active-color!)
  #:export (menu-top-item)
  
  #:export (menu-get-current-item)
  
  #:export (std-menu-key-handler)

  #:use-module (ncurses curses)
  #:use-module (srfi srfi-9))

(define-record-type <menu>
  (make-menu' current-item items top-item active active-attr active-color disp)
  menu?
  (current-item menu-current-item menu-set-current-item!)
  (items        menu-items menu-set-items!)
  (top-item     menu-top-item menu-set-top-item!)
  (disp         menu-disp-proc)
  (active       menu-active menu-set-active!)
  (active-attr  menu-active-attr menu-set-active-attr!)
  (active-color menu-active-color menu-set-active-color!)
  (window       menu-window menu-set-window!))

(define* (make-menu items #:key (disp-proc (lambda (datum row)
					     (format #f "~a" datum))))
  (make-menu' 0 items 0 #t A_STANDOUT 0 disp-proc))





(define (menu-get-current-item menu)
  (let ((idx (menu-current-item menu)))
    (list-ref (menu-items menu) idx)))

(define (menu-scroll-down menu step)
  (let ((limit (- (length (menu-items menu))
		  (getmaxy (menu-window menu)))))
    (if (< (menu-top-item menu) limit)
	(begin
	(menu-set-top-item! menu (min limit
				      (+ step (menu-top-item menu))))
	(menu-redraw menu)))))

(define (menu-scroll-up menu step)
  (menu-set-top-item! menu (max 0 (- (menu-top-item menu) step)))
  (menu-redraw menu))

(define* (menu-down menu #:key (step 1))
  "Move the selected item down by STEP items.  Returns #f if on the last item."
  (if (< (menu-current-item menu) (1- (length (menu-items menu))))
      (begin
	(if (>= (- (menu-current-item menu) (menu-top-item menu))
		(- (getmaxy (menu-window menu)) step))
	    (menu-scroll-down menu step))
	(menu-set-current-item! menu (min
				      (1- (length (menu-items menu)))
				      (+ step (menu-current-item menu))))
	#t)
      #f))

(define* (menu-up menu #:key (step 1))
  "Move the selected item up by STEP items."
  (if (positive? (menu-current-item menu))
      (begin
	(if (< (- (menu-current-item menu) step) (menu-top-item menu))
	    (menu-scroll-up menu step))
	(menu-set-current-item! menu (max 0 (- (menu-current-item menu) step))))))

(define (menu-redraw menu)
  (define win (menu-window menu))
  (clear win)
  (let populate ((row (menu-top-item menu))
		 (data (list-tail (menu-items menu) (menu-top-item menu) )))
    (if (and
	 (< row (+ (menu-top-item menu) (getmaxy win)))
	 (not (null? data)))
	(begin
	  (addstr win
		  ((menu-disp-proc menu) (car data) row)
		  #:y (- row (menu-top-item menu)) #:x 0)
	  (populate (1+ row) (cdr data))))))

(define (menu-post menu win)
  (menu-set-window! menu win)
  (menu-redraw menu))

(define (menu-refresh menu)
  (let ((win (menu-window menu))
	(colour (if (menu-active menu) (menu-active-color menu) 0))
	(attr (if (menu-active menu) (menu-active-attr menu) A_DIM)))
    
    (bkgd win (color 0 (normal #\space)))
    (chgat win -1 attr colour #:y
	   (- (menu-current-item menu) (menu-top-item menu))
	   #:x 0)
    (refresh win)))





(define (std-menu-key-handler menu ch)
  (cond
   ((eq? ch KEY_NPAGE)
    (menu-active menu)
    (menu-down menu #:step (getmaxy (menu-window menu))))

   ((eq? ch KEY_PPAGE)
    (menu-active menu)
    (menu-up menu #:step (getmaxy (menu-window menu))))
   
   ((or (eq? ch KEY_DOWN)
	(eq? ch #\so))
    (if (menu-active menu)
	(menu-down menu)))

   ((or (eq? ch KEY_UP)
	(eq? ch #\dle))
    (if (menu-active menu)
	(menu-up menu)))))