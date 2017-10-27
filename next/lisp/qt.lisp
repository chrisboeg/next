;;;; qt.lisp --- QT helper functions & data

(in-package :interface)

(defun initialize ()
  (eql:qrequire :webkit)
  (initialize-keycodes)
  (defvar *control-modifier* nil
    "A variable to store the status of the control key")
  (defvar *meta-modifier* nil
    "A variable to store the status of the alt/meta key")
  (defvar *super-modifier* nil
    "A variable to store the status of the super/cmd key")
  (eql:qadd-event-filter nil eql:|QEvent.KeyPress| 'key-press)
  (eql:qadd-event-filter nil eql:|QEvent.KeyRelease| 'key-release))

(defun start ()
  (defparameter *window* (eql:qnew "QWidget" "windowTitle" "nEXT"))
  (defparameter *root-layout* (eql:qnew "QGridLayout"))
  (defparameter *stack-layout* (eql:qnew "QStackedLayout"))
  (defparameter *minibuffer* nil "reference for widget containing all minibuffer views")
  (defparameter *minibuffer-prompt* (eql:qnew "QLabel" "text" "input:"))
  (defparameter *minibuffer-input* (eql:qnew "QLineEdit"))
  (defparameter *minibuffer-completion* (eql:qnew "QListView"))
  (defparameter *minibuffer-completion-model* (eql:qnew "QStringListModel"))
  (defparameter *minibuffer-completion-function* nil)
  ;; remove margins around root widgets
  (eql:|setSpacing| *root-layout* 0)
  (eql:|setContentsMargins| *root-layout* 0 0 0 0)
  ;; arguments for grid layout: row, column, rowspan, colspan
  (eql:|addLayout| *root-layout* *stack-layout* 0 0 1 1)
  (eql:|setLayout| *window* *root-layout*)
  (eql:|show| *window*))

(defun quit ()
  (eql:qquit))

(defun set-visible-view (view)
  (eql:|setCurrentWidget| *stack-layout* view))

(defun add-to-stack-layout (view)
  (eql:|addWidget| *stack-layout* view))

(defun delete-view (view)
  (eql:qdelete view))

(defun make-web-view ()
  (eql:qnew "QWebView"))

(defun web-view-scroll-down (view distance)
  (eql:|scroll| (eql:|mainFrame| (eql:|page| view))
	    0 distance))

(defun web-view-scroll-up (view distance)
  (eql:|scroll| (eql:|mainFrame| (eql:|page| view))
	    0 (- distance)))

(defun web-view-set-url (view url)
  (eql:qlet ((url (eql:qnew "QUrl(QString)" url)))
	(eql:|setUrl| view url)))

(defun web-view-set-url-loaded-callback (view function)
  (eql:qconnect (eql:|mainFrame| (eql:|page| view)) "loadFinished(bool)"
	    function))

(defun web-view-get-url (view)
  (eql:|toString| (eql:|url| view)))

(defun make-minibuffer ()
  (let ((minibuffer (eql:qnew "QWidget")) (layout (eql:qnew "QGridLayout")))
    (eql:|addWidget| layout *minibuffer-prompt*      0 0 1 5)
    (eql:|addWidget| layout *minibuffer-input*       0 1 1 15)
    (eql:|addWidget| layout *minibuffer-completion*  1 1 1 15)
    (eql:|setLayout| minibuffer layout)
    (eql:|setModel| *minibuffer-completion* *minibuffer-completion-model*)
    (eql:qadd-event-filter *minibuffer-input* eql:|QEvent.KeyRelease| 'update-candidates)
    ;; add it to the main grid layout (*root-layout*)
    ;; arguments for grid layout: row, column, rowspan, colspan
    (eql:|addWidget| *root-layout* minibuffer  1 0 1 1)
    (eql:|hide| minibuffer)
    (setf *minibuffer* minibuffer)
    ;; return the widget
    *minibuffer*))

(defun update-candidates (obj event)
  (declare (ignore obj)) ; supress unused warnings
  (declare (ignore event)) ; supress unused warnings
  (when *minibuffer-completion-function*
    (let ((candidates (funcall *minibuffer-completion-function* (minibuffer-get-input))))
      (eql:|setStringList| *minibuffer-completion-model* candidates)))
  nil)

(defun minibuffer-set-completion-function (function)
  (setf *minibuffer-completion-function* function))

(defun minibuffer-show ()
  (eql:|show| *minibuffer*)
  (eql:|setFocus| *minibuffer-input*))

(defun minibuffer-hide ()
  (eql:|setText| *minibuffer-input* "")
  (eql:|hide| *minibuffer*))

(defun minibuffer-get-input ()
  (eql:|text| *minibuffer-input*))

(defun key-press (obj event)
  ;; Invoked upon key-press
  (declare (ignore obj)) ; supress unused warnings
  (let ((key (eql:|key| event)))
    (cond
      ((equalp key *control-key*)
       (setf *control-modifier* t))
      ((equalp key *meta-key*)
       (setf *meta-modifier* t))
      ((equalp key *super-key*)
       (setf *super-modifier* t))
      (t (next:push-key-chord
	  *control-modifier*
	  *meta-modifier*
	  *super-modifier*
	  (gethash key *keycode->character*))))))

(defun key-release (obj event)
  ;; Invoked upon key-release
  (declare (ignore obj)) ; supress unused warnings
  (let ((key (eql:|key| event)))
    (cond
      ((equalp key *control-key*)
       (setf *control-modifier* nil))
      ((equalp key *meta-key*)
       (setf *meta-modifier* nil))
      ((equalp key *super-key*)
       (setf *super-modifier* nil))
      (t (return-from key-release)))))

(defparameter *keycode->character* (make-hash-table :test 'equalp)
  "A character -> keycode hashmap for associating the QT keycodes")

(defun keycode (character keycode)
  (setf (gethash character *keycode->character*) keycode))

(defun initialize-keycodes ()
  (defparameter *control-key* 16777249) ; OSX: command
  (defparameter *meta-key*    16777250) ; OSX: control
  (defparameter *alt-key*     16777251) ; OSX: option
  (defparameter *super-key*   16777249) ; OSX: command
  (when (equalp (eql:|platformName.QGuiApplication|) "cocoa")
    (let ((original_control *control-key*)
	  (original_meta *meta-key*)
	  (original_alt *alt-key*))
      (setf *control-key* original_meta)
      (setf *meta-key* original_alt)
      (setf *super-key* original_control)))
  (keycode 48 "0")
  (keycode 49 "1")
  (keycode 50 "2")
  (keycode 51 "3")
  (keycode 52 "4")
  (keycode 53 "5")
  (keycode 54 "6")
  (keycode 55 "7")
  (keycode 56 "8")
  (keycode 57 "9")
  (keycode 198 "AE")
  (keycode 193 "Aacute")
  (keycode 194 "Acircumflex")
  (keycode 16777408 "AddFavorite")
  (keycode 196 "Adiaeresis")
  (keycode 192 "Agrave")
  (keycode 16781571 "AltGr")
  (keycode 16777251 "Alt")
  (keycode 38 "Ampersand")
  (keycode 32 "Any")
  (keycode 39 "Apostrophe")
  (keycode 16777415 "ApplicationLeft")
  (keycode 16777416 "ApplicationRight")
  (keycode 197 "Aring")
  (keycode 94 "AsciiCircum")
  (keycode 126 "AsciiTilde")
  (keycode 42 "Asterisk")
  (keycode 195 "Atilde")
  (keycode 64 "At")
  (keycode 16777478 "AudioCycleTrack")
  (keycode 16777474 "AudioForward")
  (keycode 16777476 "AudioRandomPlay")
  (keycode 16777475 "AudioRepeat")
  (keycode 16777413 "AudioRewind")
  (keycode 16777464 "Away")
  (keycode 65 "A")
  (keycode 16777414 "BackForward")
  (keycode 92 "Backslash")
  (keycode 16777219 "Backspace")
  (keycode 16777218 "Backtab")
  (keycode 16777313 "Back")
  (keycode 124 "Bar")
  (keycode 16777331 "BassBoost")
  (keycode 16777333 "BassDown")
  (keycode 16777332 "BassUp")
  (keycode 16777470 "Battery")
  (keycode 16777471 "Bluetooth")
  (keycode 16777495 "Blue")
  (keycode 16777417 "Book")
  (keycode 123 "BraceLeft")
  (keycode 125 "BraceRight")
  (keycode 91 "BracketLeft")
  (keycode 93 "BracketRight")
  (keycode 16777410 "BrightnessAdjust")
  (keycode 66 "B")
  (keycode 16777418 "CD")
  (keycode 16777419 "Calculator")
  (keycode 16777444 "Calendar")
  (keycode 17825796 "Call")
  (keycode 17825825 "CameraFocus")
  (keycode 17825824 "Camera")
  (keycode 16908289 "Cancel")
  (keycode 16777252 "CapsLock")
  (keycode 199 "Ccedilla")
  (keycode 16777497 "ChannelDown")
  (keycode 16777496 "ChannelUp")
  (keycode 16777421 "ClearGrab")
  (keycode 16777227 "Clear")
  (keycode 16777422 "Close")
  (keycode 16781623 "Codeinput")
  (keycode 58 "Colon")
  (keycode 44 "Comma")
  (keycode 16777412 "Community")
  (keycode 17825792 "Context1")
  (keycode 17825793 "Context2")
  (keycode 17825794 "Context3")
  (keycode 17825795 "Context4")
  (keycode 16777485 "ContrastAdjust")
  (keycode 16777249 "Control")
  (keycode 16777423 "Copy")
  (keycode 16777424 "Cut")
  (keycode 67 "C")
  (keycode 16777426 "DOS")
  (keycode 16777223 "Delete")
  (keycode 36 "Dollar")
  (keycode 16777237 "Down")
  (keycode 68 "D")
  (keycode 208 "ETH")
  (keycode 201 "Eacute")
  (keycode 202 "Ecircumflex")
  (keycode 203 "Ediaeresis")
  (keycode 200 "Egrave")
  (keycode 16777401 "Eject")
  (keycode 16777233 "End")
  (keycode 16777221 "Enter")
  (keycode 61 "Equal")
  (keycode 16777216 "Escape")
  (keycode 33 "Exclam")
  (keycode 16908291 "Execute")
  (keycode 16908298 "Exit")
  (keycode 16777429 "Explorer")
  (keycode 69 "E")
  (keycode 16777273 "F10")
  (keycode 16777274 "F11")
  (keycode 16777275 "F12")
  (keycode 16777276 "F13")
  (keycode 16777277 "F14")
  (keycode 16777278 "F15")
  (keycode 16777279 "F16")
  (keycode 16777280 "F17")
  (keycode 16777281 "F18")
  (keycode 16777282 "F19")
  (keycode 16777264 "F1")
  (keycode 16777283 "F20")
  (keycode 16777284 "F21")
  (keycode 16777285 "F22")
  (keycode 16777286 "F23")
  (keycode 16777287 "F24")
  (keycode 16777288 "F25")
  (keycode 16777289 "F26")
  (keycode 16777290 "F27")
  (keycode 16777291 "F28")
  (keycode 16777292 "F29")
  (keycode 16777265 "F2")
  (keycode 16777293 "F30")
  (keycode 16777294 "F31")
  (keycode 16777295 "F32")
  (keycode 16777296 "F33")
  (keycode 16777297 "F34")
  (keycode 16777298 "F35")
  (keycode 16777266 "F3")
  (keycode 16777267 "F4")
  (keycode 16777268 "F5")
  (keycode 16777269 "F6")
  (keycode 16777270 "F7")
  (keycode 16777271 "F8")
  (keycode 16777272 "F9")
  (keycode 16777361 "Favorites")
  (keycode 16777411 "Finance")
  (keycode 16777506 "Find")
  (keycode 17825798 "Flip")
  (keycode 16777314 "Forward")
  (keycode 70 "F")
  (keycode 16777430 "Game")
  (keycode 16777431 "Go")
  (keycode 62 "Greater")
  (keycode 16777493 "Green")
  (keycode 16777498 "Guide")
  (keycode 71 "G")
  (keycode 16777304 "Help")
  (keycode 16781603 "Henkan")
  (keycode 16777480 "Hibernate")
  (keycode 16777407 "History")
  (keycode 16777360 "HomePage")
  (keycode 16777232 "Home")
  (keycode 16777409 "HotLinks")
  (keycode 16777302 "Hyper_L")
  (keycode 16777303 "Hyper_R")
  (keycode 72 "H")
  (keycode 205 "Iacute")
  (keycode 206 "Icircumflex")
  (keycode 207 "Idiaeresis")
  (keycode 204 "Igrave")
  (keycode 16777499 "Info")
  (keycode 16777222 "Insert")
  (keycode 73 "I")
  (keycode 74 "J")
  (keycode 16777398 "KeyboardBrightnessDown")
  (keycode 16777397 "KeyboardBrightnessUp")
  (keycode 16777396 "KeyboardLightOnOff")
  (keycode 75 "K")
  (keycode 16777378 "Launch0")
  (keycode 16777379 "Launch1")
  (keycode 16777380 "Launch2")
  (keycode 16777381 "Launch3")
  (keycode 16777382 "Launch4")
  (keycode 16777383 "Launch5")
  (keycode 16777384 "Launch6")
  (keycode 16777385 "Launch7")
  (keycode 16777386 "Launch8")
  (keycode 16777387 "Launch9")
  (keycode 16777388 "LaunchA")
  (keycode 16777389 "LaunchB")
  (keycode 16777390 "LaunchC")
  (keycode 16777391 "LaunchD")
  (keycode 16777392 "LaunchE")
  (keycode 16777393 "LaunchF")
  (keycode 16777486 "LaunchG")
  (keycode 16777487 "LaunchH")
  (keycode 16777376 "LaunchMail")
  (keycode 16777377 "LaunchMedia")
  (keycode 16777234 "Left")
  (keycode 60 "Less")
  (keycode 16777405 "LightBulb")
  (keycode 16777433 "LogOff")
  (keycode 76 "L")
  (keycode 16777467 "MailForward")
  (keycode 16777434 "Market")
  (keycode 16781612 "Massyo")
  (keycode 16842751 "MediaLast")
  (keycode 16777347 "MediaNext")
  (keycode 16777349 "MediaPause")
  (keycode 16777344 "MediaPlay")
  (keycode 16777346 "MediaPrevious")
  (keycode 16777348 "MediaRecord")
  (keycode 16777345 "MediaStop")
  (keycode 16777350 "MediaTogglePlayPause")
  (keycode 16777435 "Meeting")
  (keycode 16777404 "Memo")
  (keycode 16777436 "MenuKB")
  (keycode 16777437 "MenuPB")
  (keycode 16777301 "Menu")
  (keycode 16777465 "Messenger")
  (keycode 16777250 "Meta")
  (keycode 16777491 "MicMute")
  (keycode 16777502 "MicVolumeDown")
  (keycode 16777501 "MicVolumeUp")
  (keycode 45 "Minus")
  (keycode 77 "M")
  (keycode 16777439 "News")
  (keycode 16777504 "New")
  (keycode 16842754 "No")
  (keycode 209 "Ntilde")
  (keycode 16777253 "NumLock")
  (keycode 35 "NumberSign")
  (keycode 78 "N")
  (keycode 211 "Oacute")
  (keycode 212 "Ocircumflex")
  (keycode 214 "Odiaeresis")
  (keycode 16777440 "OfficeHome")
  (keycode 210 "Ograve")
  (keycode 216 "Ooblique")
  (keycode 16777364 "OpenUrl")
  (keycode 16777505 "Open")
  (keycode 16777441 "Option")
  (keycode 213 "Otilde")
  (keycode 79 "O")
  (keycode 16777239 "PageDown")
  (keycode 16777238 "PageUp")
  (keycode 40 "ParenLeft")
  (keycode 41 "ParenRight")
  (keycode 16777442 "Paste")
  (keycode 16777224 "Pause")
  (keycode 37 "Percent")
  (keycode 46 "Period")
  (keycode 16777443 "Phone")
  (keycode 16777468 "Pictures")
  (keycode 16908293 "Play")
  (keycode 43 "Plus")
  (keycode 16777483 "PowerDown")
  (keycode 16777399 "PowerOff")
  (keycode 16781630 "PreviousCandidate")
  (keycode 16908290 "Printer")
  (keycode 16777225 "Print")
  (keycode 80 "P")
  (keycode 63 "Question")
  (keycode 34 "QuoteDbl")
  (keycode 96 "QuoteLeft")
  (keycode 81 "Q")
  (keycode 16777508 "Redo")
  (keycode 16777492 "Red")
  (keycode 16777316 "Refresh")
  (keycode 16777446 "Reload")
  (keycode 16777445 "Reply")
  (keycode 16777220 "Return")
  (keycode 16777236 "Right")
  (keycode 16781604 "Romaji")
  (keycode 16777447 "RotateWindows")
  (keycode 16777449 "RotationKB")
  (keycode 16777448 "RotationPB")
  (keycode 82 "R")
  (keycode 16777450 "Save")
  (keycode 16777402 "ScreenSaver")
  (keycode 16777254 "ScrollLock")
  (keycode 16777362 "Search")
  (keycode 16842752 "Select")
  (keycode 59 "Semicolon")
  (keycode 16777451 "Send")
  (keycode 16777500 "Settings")
  (keycode 16777248 "Shift")
  (keycode 16777406 "Shop")
  (keycode 16781628 "SingleCandidate")
  (keycode 47 "Slash")
  (keycode 16908292 "Sleep")
  (keycode 32 "Space")
  (keycode 16777452 "Spell")
  (keycode 16777453 "SplitScreen")
  (keycode 16777363 "Standby")
  (keycode 16777315 "Stop")
  (keycode 16777477 "Subtitle")
  (keycode 16777299 "Super_L")
  (keycode 16777300 "Super_R")
  (keycode 16777454 "Support")
  (keycode 16777484 "Suspend")
  (keycode 16777226 "SysReq")
  (keycode 83 "S")
  (keycode 222 "THORN")
  (keycode 16777217 "Tab")
  (keycode 16777455 "TaskPane")
  (keycode 16777456 "Terminal")
  (keycode 16777479 "Time")
  (keycode 16777420 "ToDoList")
  (keycode 17825799 "ToggleCallHangup")
  (keycode 16777457 "Tools")
  (keycode 16777482 "TopMenu")
  (keycode 16777490 "TouchpadOff")
  (keycode 16777489 "TouchpadOn")
  (keycode 16777488 "TouchpadToggle")
  (keycode 16781611 "Touroku")
  (keycode 16777458 "Travel")
  (keycode 16777335 "TrebleDown")
  (keycode 16777334 "TrebleUp")
  (keycode 84 "T")
  (keycode 16777473 "UWB")
  (keycode 218 "Uacute")
  (keycode 219 "Ucircumflex")
  (keycode 220 "Udiaeresis")
  (keycode 217 "Ugrave")
  (keycode 95 "Underscore")
  (keycode 16777507 "Undo")
  (keycode 16777235 "Up")
  (keycode 85 "U")
  (keycode 16777459 "Video")
  (keycode 16777481 "View")
  (keycode 17825800 "VoiceDial")
  (keycode 16777328 "VolumeDown")
  (keycode 16777329 "VolumeMute")
  (keycode 16777330 "VolumeUp")
  (keycode 86 "V")
  (keycode 16777472 "WLAN")
  (keycode 16777403 "WWW")
  (keycode 16777400 "WakeUp")
  (keycode 16777466 "WebCam")
  (keycode 16777460 "Word")
  (keycode 87 "W")
  (keycode 16777461 "Xfer")
  (keycode 88 "X")
  (keycode 221 "Yacute")
  (keycode 16777494 "Yellow")
  (keycode 16842753 "Yes")
  (keycode 89 "Y")
  (keycode 16777462 "ZoomIn")
  (keycode 16777463 "ZoomOut")
  (keycode 16908294 "Zoom")
  (keycode 90 "Z")
  (keycode 180 "acute")
  (keycode 166 "brokenbar")
  (keycode 184 "cedilla")
  (keycode 162 "cent")
  (keycode 169 "copyright")
  (keycode 164 "currency")
  (keycode 176 "degree")
  (keycode 168 "diaeresis")
  (keycode 247 "division")
  (keycode 161 "exclamdown")
  (keycode 171 "guillemotleft")
  (keycode 187 "guillemotright")
  (keycode 173 "hyphen")
  (keycode 16777432 "iTouch")
  (keycode 175 "macron")
  (keycode 186 "masculine")
  (keycode 215 "multiply")
  (keycode 181 "mu")
  (keycode 160 "nobreakspace")
  (keycode 172 "notsign")
  (keycode 189 "onehalf")
  (keycode 188 "onequarter")
  (keycode 185 "onesuperior")
  (keycode 170 "ordfeminine")
  (keycode 182 "paragraph")
  (keycode 183 "periodcentered")
  (keycode 177 "plusminus")
  (keycode 191 "questiondown")
  (keycode 174 "registered")
  (keycode 167 "section")
  (keycode 223 "ssharp")
  (keycode 163 "sterling")
  (keycode 190 "threequarters")
  (keycode 179 "threesuperior")
  (keycode 178 "twosuperior")
  (keycode 33554431 "unknown")
  (keycode 255 "ydiaeresis")
  (keycode 165 "yen"))
