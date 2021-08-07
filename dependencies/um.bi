DECLARE LIBRARY
    SUB glutSetCursor (BYVAL cursor AS LONG)
END DECLARE

CONST GLUT_CURSOR_RIGHT_ARROW = &H0000
CONST GLUT_CURSOR_LEFT_ARROW = &H0001
CONST GLUT_CURSOR_INFO = &H0002
CONST GLUT_CURSOR_DESTROY = &H0003
CONST GLUT_CURSOR_HELP = &H0004
CONST GLUT_CURSOR_CYCLE = &H0005
CONST GLUT_CURSOR_SPRAY = &H0006
CONST GLUT_CURSOR_WAIT = &H0007
CONST GLUT_CURSOR_TEXT = &H0008
CONST GLUT_CURSOR_CROSSHAIR = &H0009
CONST GLUT_CURSOR_UP_DOWN = &H000A
CONST GLUT_CURSOR_LEFT_RIGHT = &H000B
CONST GLUT_CURSOR_TOP_SIDE = &H000C
CONST GLUT_CURSOR_BOTTOM_SIDE = &H000D
CONST GLUT_CURSOR_LEFT_SIDE = &H000E
CONST GLUT_CURSOR_RIGHT_SIDE = &H000F
CONST GLUT_CURSOR_TOP_LEFT_CORNER = &H0010
CONST GLUT_CURSOR_TOP_RIGHT_CORNER = &H0011
CONST GLUT_CURSOR_BOTTOM_RIGHT_CORNER = &H0012
CONST GLUT_CURSOR_BOTTOM_LEFT_CORNER = &H0013
CONST GLUT_CURSOR_INHERIT = &H0064
CONST GLUT_CURSOR_NONE = &H0065
CONST GLUT_CURSOR_FULL_CROSSHAIR = &H0066

TYPE internalsettings
    trimstrings AS _BYTE
    fps AS INTEGER
    doubleclickspeed AS _FLOAT
END TYPE
TYPE internal
    setting AS internalsettings
END TYPE
REDIM SHARED internal AS internal

TYPE global
    AS STRING * 512 intpath, license, scheme, programName, permalink, permalinkCode, fileBackground
    AS _UNSIGNED _INTEGER64 matchthreshhold
    AS _FLOAT margin, padding, round, windowsize, sliderwidth
    AS _BYTE licensestatus, partialsearch, actionlock, altCursors
END TYPE
REDIM SHARED global AS global
global.programName = "Vedit"
global.permalink = "vedit"
global.permalinkCode = "xxxx"

TYPE element
    AS _BYTE show, acceptinput, allownumbers, allowtext, allowspecial, selected, state, deselect
    AS STRING x, y, w, h, style, name, text, buffer, type, color, hovercolor, action, angle, font, textalign
    AS STRING view, round, hovertext, padding, url, switchword, group, options, content
    AS INTEGER sel_start, sel_end, cursor, items, hovertextwait, hoverx, hovery
    AS _INTEGER64 scroll
    AS _FLOAT statelock, hovertime, value, offsetx, offsety
    AS LONG drawcolor
    AS _BYTE contextopen, allowcontextclose, expand
    AS INTEGER contextx, contexty
END TYPE
REDIM SHARED elements(0) AS element

REDIM SHARED AS STRING viewname(0), currentview, previousview, transmittedtext
TYPE invoke
    AS _BYTE delete, back, select, right, left, deselect, jumptoend, jumptofront
END TYPE
REDIM SHARED AS LONG font_normal, font_big
REDIM SHARED AS INTEGER elementlock, activeelement
REDIM SHARED AS _BYTE contextopen, lockuicall, lockmouse, expanded
TYPE history
    element AS INTEGER
    state AS element
END TYPE
REDIM SHARED history(0) AS history
TYPE colour
    name AS STRING
    AS INTEGER r, g, b, a
END TYPE
REDIM SHARED schemecolor(0) AS colour
TYPE gradient
    color AS LONG
    gpos AS _FLOAT
END TYPE
REDIM SHARED gradient(0, 0) AS gradient
TYPE countlist
    name AS STRING
    count AS _UNSIGNED _INTEGER64
END TYPE
TYPE font
    name AS STRING
    handle AS LONG
END TYPE
REDIM SHARED font(0) AS font
TYPE rectangle
    AS _FLOAT x, y, w, h
END TYPE

TYPE mouse
    AS _BYTE left, right, middle, leftrelease, rightrelease, middlerelease
    AS INTEGER scroll, x, y
    AS _FLOAT noMovement, movementTimer, lefttime, righttime, middletime, lefttimedif, righttimedif, middletimedif, lefttimedif2, offsetx, offsety
END TYPE
REDIM SHARED mouse AS mouse

'--------------------------------------------------------------------------------------------------------------------------------------'

' File list by SMcNeill
DECLARE CUSTOMTYPE LIBRARY "code\direntry"
    FUNCTION load_dir& (s AS STRING)
    FUNCTION has_next_entry& ()
    SUB close_dir ()
    SUB get_next_entry (s AS STRING, flags AS LONG, file_size AS LONG)
END DECLARE

'--------------------------------------------------------------------------------------------------------------------------------------'
