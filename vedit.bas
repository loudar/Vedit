CLS: CLEAR: CLOSE
$RESIZE:ON
REM $DYNAMIC

'_SCREENHIDE
' File list by SMcNeill
DECLARE CUSTOMTYPE LIBRARY "code\direntry"
    FUNCTION load_dir& (s AS STRING)
    FUNCTION has_next_entry& ()
    SUB close_dir ()
    SUB get_next_entry (s AS STRING, flags AS LONG, file_size AS LONG)
END DECLARE

' Variables
TYPE vectorPoint
    AS DOUBLE x, y
    AS DOUBLE handlex, handley
END TYPE
REDIM SHARED vectorPoints(0, 0) AS vectorPoint
TYPE vectorPreview
    AS LONG image
    AS _BYTE status, mouseStatus
END TYPE
REDIM SHARED vectorPreview(0) AS vectorPreview

TYPE layerInfo
    AS DOUBLE x, y, w, h
    AS STRING type
    AS INTEGER contentid
END TYPE
REDIM SHARED layerInfo(0) AS layerInfo

'UI
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
    AS STRING * 512 intpath, license, scheme
    AS _UNSIGNED _INTEGER64 matchthreshhold
    AS _FLOAT margin, padding, round, windowsize, sliderwidth
    AS _BYTE licensestatus, partialsearch, actionlock
END TYPE
REDIM SHARED global AS global

TYPE element
    AS _BYTE show, acceptinput, allownumbers, allowtext, allowspecial, selected, state, deselect
    AS STRING x, y, w, h, style, name, text, buffer, type, color, hovercolor, action, angle, font
    AS STRING view, round, hovertext, padding, url, switchword, group, options
    AS INTEGER sel_start, sel_end, cursor, items, hovertextwait, hoverx, hovery
    AS _UNSIGNED _INTEGER64 scroll
    AS _FLOAT statelock, hovertime, value, offsetx, offsety
    AS LONG drawcolor
    AS _BYTE contextopen, allowcontextclose, expand
    AS INTEGER contextx, contexty
END TYPE
REDIM SHARED elements(0) AS element

REDIM SHARED AS STRING viewname(0), currentview, transmittedtext
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

REDIM SHARED AS INTEGER activeLayer
REDIM SHARED AS _BYTE mainexit, linemode, pointsize
REDIM SHARED AS _INTEGER64 activeGrab, activeHandleGrab, roundsSinceEdit, keyhit
REDIM SHARED AS DOUBLE frameTimes(50), frameTimesFull(200)

RANDOMIZE TIMER

'_SCREENSHOW

resetAllValues
REDIM SHARED AS INTEGER screenresx, screenresy, winresx, winresy
screenresx = _DESKTOPWIDTH
screenresy = _DESKTOPHEIGHT
winresx = INT(screenresx * global.windowsize) 'to be replaced with config-based factor
winresy = INT(screenresy * global.windowsize)
PRINT "resizing window to "; winresx; "x"; winresy
SCREEN _NEWIMAGE(winresx, winresy, 32)
COLOR _RGBA(255, 255, 255, 255), _RGBA(0, 0, 0, 255)
DO: LOOP UNTIL _SCREENEXISTS
_SCREENMOVE (screenresx / 2) - (winresx / 2), (screenresy / 2) - (winresy / 2)
_TITLE "Vedit"

start:

createLayer 0, 0, _WIDTH, _HEIGHT, "vector", UBOUND(vectorPoints, 1) + 1
activeLayer = 1

'loadUI
DO
    frameStart = TIMER
    CLS

    checkResize
    checkMouse
    'keyhit = checkKeyboard
    'displayView keyhit
    displayLayers
    displayText

    IF roundsSinceEdit < 1000 THEN roundsSinceEdit = roundsSinceEdit + 1

    'DEBUG
    lastFrameTime = TIMER - frameStart
    displayFrameTimes lastFrameTime

    _DISPLAY
    _LIMIT internal.setting.fps
LOOP UNTIL mainexit = -1 OR restart = -1
IF restart = -1 THEN GOTO start

SUB resetAllValues
    'internal settings
    internal.setting.trimstrings = -1
    internal.setting.fps = 60
    internal.setting.doubleclickspeed = 0.2

    'data structure
    global.intpath = "internal"
    global.sliderwidth = 200
    proofPath global.intpath
    loadConfig
    mouse.movementTimer = 90 ' amount of rounds until UI fades out
    linemode = 1 ' type of line math
    pointsize = 4 ' how big the control points are
    global.windowsize = 0.5
END SUB

SUB createLayer (x AS DOUBLE, y AS DOUBLE, w AS INTEGER, h AS INTEGER, layerType AS STRING, contentid AS INTEGER)
    REDIM _PRESERVE layerInfo(UBOUND(layerInfo) + 1) AS layerInfo
    layerId = UBOUND(layerInfo)
    layerInfo(layerId).x = x
    layerInfo(layerId).y = y
    layerInfo(layerId).w = w
    layerInfo(layerId).h = h
    layerInfo(layerId).type = layerType
    layerInfo(layerId).contentid = contentid
    SELECT CASE layerType
        CASE "vector"
            REDIM _PRESERVE vectorPoints(UBOUND(vectorPoints, 1) + 1, UBOUND(vectorPoints, 2)) AS vectorPoint
            REDIM _PRESERVE vectorPreview(UBOUND(vectorPreview) + 1) AS vectorPreview
    END SELECT
END SUB

SUB displayFrameTimes (lastFrameTime AS DOUBLE)
    IF lastFrameTime > 0 THEN
        i = 0: DO: i = i + 1
            frameTimes(i) = frameTimes(i + 1)
        LOOP UNTIL i >= UBOUND(frameTimes) - 1
        frameTimes(UBOUND(frameTimes)) = lastFrameTime
    END IF
    i = 0: DO: i = i + 1
        frameTimesFull(i) = frameTimesFull(i + 1)
        avgsum = avgsum + frameTimesFull(i)
        counted = counted + 1
    LOOP UNTIL i >= UBOUND(frameTimesFull) - 1
    frameTimesFull(UBOUND(frameTimesFull)) = lastFrameTime
    avgsum = avgsum + lastFrameTime
    counted = counted + 1
    i = 0: DO: i = i + 1
        IF frameTimes(i) > maxFrameTime THEN maxFrameTime = frameTimes(i)
    LOOP UNTIL i >= UBOUND(frameTimes)
    i = 0: DO: i = i + 1
        IF frameTimes(i) > 0 THEN
            LINE (i + (_FONTWIDTH * 2), 60)-(i + (_FONTWIDTH * 2), 60 - ((frameTimes(i) / maxFrameTime) * 50)), _RGBA(255, 255, 255, 255)
        END IF
    LOOP UNTIL i = UBOUND(frameTimes)
    _PRINTSTRING (getColumn(8), getRow(0)), LTRIM$(STR$(maxFrameTime)) + " frame time / " + LTRIM$(STR$(INT(1 / (avgsum / counted)))) + " FPS"
END SUB

SUB displayText
    _PRINTSTRING (getColumn(1), getRow(4)), "Create point: [CTRL] + [Left Mouse]"
    _PRINTSTRING (getColumn(1), getRow(5)), "Delete point: [CTRL] + [Left Mouse]"
    _PRINTSTRING (getColumn(1), getRow(6)), "Move point:   [Left Mouse] + Drag"
    _PRINTSTRING (getColumn(1), getRow(7)), "Move handle:  [Right Mouse] + Drag"
    'PRINT UBOUND(vectorPoints); " points"
    'PRINT roundsSinceEdit; " rounds since edit"
    'PRINT _KEYDOWN(100306), mouse.x, mouse.y, mouse.left, mouse.right, mouse.middle, mouse.middlerelease, mouse.lefttimedif
END SUB

FUNCTION getRow (row AS _INTEGER64)
    getRow = 10 + (_FONTHEIGHT * row)
END FUNCTION

FUNCTION getColumn (column AS _INTEGER64)
    getColumn = 10 + (_FONTWIDTH * column)
END FUNCTION

SUB displayLayers
    IF UBOUND(layerInfo) < 1 THEN EXIT SUB
    layer = 0: DO: layer = layer + 1
        IF layer = activeLayer THEN layerIsActive = -1 ELSE layerIsActive = 0
        SELECT CASE layerInfo(layer).type
            CASE "vector"
                displayLines layerInfo(layer).contentid, layerIsActive
                IF layerIsActive THEN
                    displayPoints layerInfo(layer).contentid
                END IF
        END SELECT
    LOOP UNTIL layer = UBOUND(layerInfo)
END SUB

FUNCTION vectorPreviewGenerated (contentid AS INTEGER, layerIsActive AS _BYTE)
    IF (vectorPreview(contentid).status = 1 AND layerIsActive = 0) THEN
        vectorPreviewGenerated = -1
    ELSEIF (vectorPreview(contentid).status = 2 AND layerIsActive = 1) THEN
        vectorPreviewGenerated = -1
    ELSE
        vectorPreviewGenerated = 0
    END IF
END FUNCTION

SUB displayVectorPreview (contentid AS INTEGER)
    _PUTIMAGE (0, 0)-(_WIDTH(vectorPreview(contentid).image), _HEIGHT(vectorPreview(contentid).image)), vectorPreview(contentid).image, 0
    LINE (1, 1)-(_WIDTH(vectorPreview(contentid).image) - 1, _HEIGHT(vectorPreview(contentid).image) - 1), _RGBA(0, 255, 0, 255), B
END SUB

SUB generateVectorPreview (contentid AS INTEGER, maxpoints AS INTEGER, roundFactor)
    IF vectorPreview(contentid).image < -1 THEN _FREEIMAGE vectorPreview(contentid).image
    vectorPreview(contentid).image = _NEWIMAGE(_WIDTH, _HEIGHT, 32)
    _DEST vectorPreview(contentid).image
    DO: i = i + 1
        IF mouse.noMovement < mouse.movementTimer AND layerIsActive THEN
            LINE (vectorPoints(contentid, i).x, vectorPoints(contentid, i).y)-(vectorPoints(contentid, i + 1).x, vectorPoints(contentid, i + 1).y), _RGBA(255, 255, 255, 30) ' straight line
            vectorPreview(contentid).mouseStatus = 1
        ELSE
            vectorPreview(contentid).mouseStatus = 0
        END IF

        ' create base vector between the two points
        bVecX = vectorPoints(contentid, i + 1).x - vectorPoints(contentid, i).x
        bVecY = vectorPoints(contentid, i + 1).y - vectorPoints(contentid, i).y
        bVecLength = getVecLength(bVecX, bVecY)
        sampleCount = bVecLength * roundFactor * 0.7

        ' handle vectors
        vec1x = vectorPoints(contentid, i).handlex - vectorPoints(contentid, i).x
        vec1y = vectorPoints(contentid, i).handley - vectorPoints(contentid, i).y
        handle1Length = getVecLength(vec1x, vec1y)
        IF handle1Length > sampleCount / 5 THEN handle1oversampling = 1 + (handle1Length / bVecLength) ELSE handle1oversampling = 1 ' prevents oversampling for small handle lengths

        vec2x = vectorPoints(contentid, i + 1).handlex - vectorPoints(contentid, i + 1).x
        vec2y = vectorPoints(contentid, i + 1).handley - vectorPoints(contentid, i + 1).y
        handle2Length = getVecLength(vec2x, vec2y)
        IF handle2Length > sampleCount / 5 THEN handle2oversampling = 1 + (handle2Length / bVecLength) ELSE handle2oversampling = 1 ' prevents oversampling for small handle lengths
        sampleCount = INT(sampleCount * handle1oversampling * handle2oversampling)

        s = 0: DO
            s = getSampleNumber(s, sampleCount)
            '_DISPLAY
            handle1Influence = getHandleInfluence(s, sampleCount) * (1 - (s / sampleCount))
            handle2Influence = -getHandleInfluence(s, sampleCount) * (s / sampleCount)

            ' merged vector
            SELECT CASE linemode
                CASE 1
                    pX = bVecX * (s / sampleCount) + vec1x * handle1Influence + vec2x * handle2Influence
                    pY = bVecY * (s / sampleCount) + vec1y * handle1Influence + vec2y * handle2Influence
                CASE 2
                    pX = bVecX * (1 - handle1Influence - handle2Influence) + vec1x * handle1Influence + vec2x * handle2Influence
                    pY = bVecY * (1 - handle1Influence - handle2Influence) + vec1y * handle1Influence + vec2y * handle2Influence
                CASE 3
                    pX = bVecX * (handle1Influence * handle2Influence) + vec1x * handle1Influence + vec2x * handle2Influence
                    pY = bVecY * (handle1Influence * handle2Influence) + vec1y * handle1Influence + vec2y * handle2Influence
            END SELECT

            'PSET (vectorPoints(contentid, i).x + bVecX * (s / sampleCount), vectorPoints(contentid, i).y + bVecY * (s / sampleCount)), _RGBA(255, 255, 255, 20)
            PSET (vectorPoints(contentid, i).x + pX, vectorPoints(contentid, i).y + pY), _RGBA(255, 255, 255, 255)
        LOOP UNTIL s >= sampleCount
    LOOP UNTIL i = maxpoints - 1
    _DEST 0
    displayVectorPreview contentid
END SUB

SUB displayLines (contentid AS INTEGER, layerIsActive AS _BYTE)
    maxPoints = getMaxPoints(contentid)
    IF maxPoints < 2 THEN EXIT SUB

    roundFactor = getDownSamplingFactor(roundsSinceEdit, 10)

    IF mouse.noMovement >= mouse.movementTimer AND vectorPreview(contentid).mouseStatus = 1 THEN
        generateVectorPreview contentid, maxPoints, roundFactor
        vectorPreview(contentid).status = 1 + layerIsActive
        EXIT SUB
    ELSEIF roundFactor = 1 THEN
        IF vectorPreviewGenerated(contentid, layerIsActive) THEN
            displayVectorPreview contentid
        ELSE
            generateVectorPreview contentid, maxPoints, 1
            vectorPreview(contentid).status = 1 + layerIsActive
        END IF
        EXIT SUB
    ELSE
        generateVectorPreview contentid, maxPoints, roundFactor
        vectorPreview(contentid).status = 0
    END IF
END SUB

FUNCTION getVecLength (xComponent, yComponent)
    getVecLength = SQR((ABS(xComponent) ^ 2) + (ABS(yComponent) ^ 2))
END FUNCTION

FUNCTION getDownSamplingFactor (elapsedRounds, roundLimit)
    roundFactor = (elapsedRounds + 1) / roundLimit
    IF roundFactor > 1 THEN roundFactor = 1
    getDownSamplingFactor = roundFactor
END FUNCTION

FUNCTION getSampleNumber (currentSample, sampleCount AS _INTEGER64)
    IF currentSample = 0 THEN
        getSampleNumber = currentSample + 0.01
    ELSEIF sampleCount - currentSample < 0.01 THEN
        getSampleNumber = sampleCount
    ELSE
        getSampleNumber = currentSample + getHandleInfluence(currentSample, sampleCount)
    END IF
END FUNCTION

FUNCTION getHandleInfluence (currentSample, sampleCount AS _INTEGER64)
    buffer = 1 - ((2 * ABS((currentSample / sampleCount) - 0.5)) ^ 2)
    IF buffer > 0 THEN
        buffer = SQR(buffer)
    ELSEIF buffer < 0 THEN
        buffer = SQR(-buffer)
    END IF
    getHandleInfluence = buffer
END FUNCTION

SUB displayPoints (contentid AS INTEGER)
    maxPoints = getMaxPoints(contentid)
    IF maxPoints > 0 THEN
        i = 0: DO: i = i + 1
            ' base point
            IF mouse.noMovement < mouse.movementTimer THEN LINE (vectorPoints(contentid, i).x - pointsize, vectorPoints(contentid, i).y - pointsize)-(vectorPoints(contentid, i).x + pointsize, vectorPoints(contentid, i).y + pointsize), _RGBA(0, 150, 255, 255), BF
            PSET (vectorPoints(contentid, i).x, vectorPoints(contentid, i).y), _RGBA(255, 255, 255, 255)

            IF clickCondition("deletePoint", vectorPoints(contentid, i).x, vectorPoints(contentid, i).y) THEN
                IF i < maxPoints THEN
                    i2 = i: DO
                        vectorPoints(contentid, i2) = vectorPoints(contentid, i2 + 1)
                        i2 = i2 + 1
                    LOOP UNTIL i2 = maxPoints
                END IF
                vectorPoints(contentid, maxPoints) = vectorPoints(0, 0)
                maxPoints = maxPoints - 1
                roundsSinceEdit = 0
            ELSEIF clickCondition("movePoint", vectorPoints(contentid, i).x, vectorPoints(contentid, i).y) OR activeGrab = i THEN
                HoffX = vectorPoints(contentid, i).handlex - vectorPoints(contentid, i).x
                HoffY = vectorPoints(contentid, i).handley - vectorPoints(contentid, i).y
                vectorPoints(contentid, i).x = mouse.x: vectorPoints(contentid, i).y = mouse.y
                vectorPoints(contentid, i).handlex = vectorPoints(contentid, i).x + HoffX
                vectorPoints(contentid, i).handley = vectorPoints(contentid, i).y + HoffY
                activeGrab = i
                roundsSinceEdit = 0
            END IF

            ' handle
            IF pointDeleted = 0 AND mouse.noMovement < mouse.movementTimer THEN
                LINE (vectorPoints(contentid, i).x, vectorPoints(contentid, i).y)-(vectorPoints(contentid, i).handlex, vectorPoints(contentid, i).handley), _RGBA(255, 255, 255, 100)
                CIRCLE (vectorPoints(contentid, i).handlex, vectorPoints(contentid, i).handley), pointsize * 0.75, _RGBA(255, 205, 11, 255)
                PAINT (vectorPoints(contentid, i).handlex, vectorPoints(contentid, i).handley), _RGBA(255, 205, 11, 255), _RGBA(255, 205, 11, 255)

                IF clickCondition("moveHandle", vectorPoints(contentid, i).handlex, vectorPoints(contentid, i).handley) OR activeHandleGrab = i THEN
                    vectorPoints(contentid, i).handlex = mouse.x: vectorPoints(contentid, i).handley = mouse.y
                    activeHandleGrab = i
                    roundsSinceEdit = 0
                END IF
            END IF
        LOOP UNTIL i >= maxPoints
    END IF

    IF clickCondition("createPoint", 0, 0) THEN
        maxPoints = getMaxPoints(contentid) + 1
        IF UBOUND(vectorPoints, 2) < maxPoints THEN
            REDIM _PRESERVE vectorPoints(UBOUND(vectorPoints, 1), maxPoints) AS vectorPoint
        END IF
        vectorPoints(contentid, maxPoints).x = mouse.x
        vectorPoints(contentid, maxPoints).y = mouse.y
        vectorPoints(contentid, maxPoints).handlex = mouse.x
        vectorPoints(contentid, maxPoints).handley = mouse.y
        roundsSinceEdit = 0
    END IF
END SUB

FUNCTION getMaxPoints (contentid AS INTEGER)
    IF UBOUND(vectorPoints, 2) > 0 THEN
        DO: i = i + 1
            IF pointEmpty(vectorPoints(contentid, i)) THEN
                getMaxPoints = i - 1 ' finds an empty spot before reaching the end
                EXIT FUNCTION
            END IF
        LOOP UNTIL i = UBOUND(vectorPoints, 2)
        getMaxPoints = i ' reached the end and found no empty spot
    ELSE
        getMaxPoints = 0 ' array never had any points
    END IF
END FUNCTION

FUNCTION pointEmpty (vectorPoint AS vectorPoint)
    IF vectorPoint.x = 0 AND vectorPoint.y = 0 AND vectorPoint.handlex = 0 AND vectorPoint.handlex = 0 THEN
        pointEmpty = -1
    ELSE
        pointEmpty = 0
    END IF
END FUNCTION

FUNCTION clickCondition (conditionName AS STRING, x AS DOUBLE, y AS DOUBLE)
    SELECT CASE conditionName
        CASE "deletePoint"
            IF mouse.middle AND inRadius(x, y, mouse.x, mouse.y, 20) AND mouse.middletimedif > .01 THEN
                clickCondition = -1
            ELSEIF ctrlDown AND mouse.left AND inRadius(x, y, mouse.x, mouse.y, 20) AND mouse.lefttimedif > .01 THEN
                clickCondition = -1
            ELSE clickCondition = 0
            END IF
        CASE "movePoint"
            IF mouse.left AND inRadius(x, y, mouse.x, mouse.y, 20) THEN clickCondition = -1 ELSE clickCondition = 0
        CASE "createPoint"
            IF mouse.middle AND mouse.middletimedif > .01 THEN
                clickCondition = -1
            ELSEIF ctrlDown AND mouse.left AND mouse.lefttimedif > .01 THEN
                clickCondition = -1
            ELSE clickCondition = 0
            END IF
        CASE "moveHandle"
            IF mouse.right AND inRadius(x, y, mouse.x, mouse.y, 20) THEN clickCondition = -1 ELSE clickCondition = 0
    END SELECT
END FUNCTION

FUNCTION inRadius (boxX, boxY, pointX, pointY, radius)
    IF pointX > boxX - (radius / 2) AND pointY > boxY - (radius / 2) AND pointX < boxX + (radius / 2) AND pointY < boxY + (radius / 2) THEN
        inRadius = -1
    ELSE
        inRadius = 0
    END IF
END FUNCTION

SUB checkResize
    IF _RESIZE THEN
        DO
            winresx = _RESIZEWIDTH
            winresy = _RESIZEHEIGHT
        LOOP WHILE _RESIZE
        IF (winresx <> _WIDTH(0) OR winresy <> _HEIGHT(0)) THEN
            setWindow winresx, winresy
        END IF
    END IF
END SUB

SUB setWindow (winresx AS INTEGER, winresy AS INTEGER)
    SCREEN _NEWIMAGE(winresx, winresy, 32)
    DO: LOOP UNTIL _SCREENEXISTS
    'screenresx = _DESKTOPWIDTH
    'screenresy = _DESKTOPHEIGHT
    '_SCREENMOVE (screenresx / 2) - (winresx / 2), (screenresy / 2) - (winresy / 2)
END SUB

SUB checkMouse
    mouse.scroll = 0
    startx = mouse.x
    starty = mouse.y
    DO
        mouse.x = _MOUSEX
        mouse.y = _MOUSEY
        mouse.offsetx = mouse.x - startx
        mouse.offsety = mouse.y - starty

        mouse.scroll = mouse.scroll + _MOUSEWHEEL

        mouse.left = _MOUSEBUTTON(1)
        IF mouse.left THEN
            mouse.lefttimedif2 = mouse.lefttimedif
            mouse.lefttimedif = TIMER - mouse.lefttime: mouse.lefttime = TIMER
            IF mouse.leftrelease THEN
                mouse.leftrelease = 0
            END IF
        ELSE
            mouse.leftrelease = -1
            global.actionlock = 0
            lockmouse = 0
        END IF

        mouse.right = _MOUSEBUTTON(2)
        IF mouse.right THEN
            IF mouse.rightrelease THEN
                mouse.rightrelease = 0
                mouse.righttimedif = TIMER - mouse.righttime: mouse.righttime = TIMER
            END IF
        ELSE
            mouse.rightrelease = -1
        END IF

        mouse.middle = _MOUSEBUTTON(3)
        IF mouse.middle THEN
            IF mouse.middlerelease THEN
                mouse.middlerelease = 0
                mouse.middletimedif = TIMER - mouse.middletime: mouse.middletime = TIMER
            END IF
        ELSE
            mouse.rightrelease = -1
        END IF
    LOOP WHILE _MOUSEINPUT
    IF mouse.right = 0 THEN activeHandleGrab = 0
    IF mouse.left = 0 THEN activeGrab = 0
    IF mouse.x = startx AND mouse.y = starty THEN
        IF mouse.noMovement < mouse.movementTimer + 1000 THEN mouse.noMovement = mouse.noMovement + 1
    ELSE
        mouse.noMovement = 0
    END IF
    IF mouse.left OR mouse.right OR mouse.middle THEN mouse.noMovement = 0
END SUB

FUNCTION checkKeyboard
    keyhit = _KEYHIT
    checkKeyboard = keyhit
END FUNCTION

SUB displayView (keyhit AS INTEGER) 'displays a "view"
    'LINE (0, 0)-(_WIDTH(0), _HEIGHT(0)), col&("bg1"), BF
    IF UBOUND(elements) > 0 THEN
        DO: e = e + 1
            IF elements(e).view = currentview THEN
                displayElement e, keyhit
            END IF
        LOOP UNTIL e = UBOUND(elements)
    END IF
    IF UBOUND(elements) > 0 THEN
        e = 0: DO: e = e + 1
            IF elements(e).view = currentview THEN
                displayMenu e, keyhit
            END IF
        LOOP UNTIL e = UBOUND(elements)
    END IF
    '_DISPLAY
END SUB

SUB displayMenu (elementindex AS INTEGER, keyhit AS INTEGER)
    DIM this AS element
    this = elements(elementindex)

    REDIM currentfont AS LONG
    currentfont = getCurrentFont&(this)

    DIM coord AS rectangle
    getCoord coord, elementindex, currentfont

    IF this.expand AND expandable(this) THEN
        expandElement this, elementindex, currentfont
    END IF

    IF mouse.right AND mouseInBounds(coord) THEN
        openContext this
    END IF
    IF NOT mouse.right THEN this.allowcontextclose = -1
    IF this.contextopen AND contextopen THEN displayContext this, elementindex

    IF TIMER - this.hovertime >= this.hovertextwait AND this.hovertime > 0 AND this.hovertext <> "" AND NOT this.contextopen THEN
        displayHoverText this
    END IF

    elements(elementindex) = this 'needed to save the changed data into the original elements array
END SUB

SUB displayHoverText (this AS element)
    hoverpadding = 3
    hoveryoffset = -_FONTHEIGHT(font_normal)
    LINE (mouse.x - hoverpadding, mouse.y - hoverpadding + hoveryoffset)-(mouse.x + (LEN(this.hovertext) * _FONTWIDTH(font_normal)) + hoverpadding, mouse.y + _FONTHEIGHT(font_normal) + hoverpadding + hoveryoffset), col&("bg1"), BF
    LINE (mouse.x - hoverpadding, mouse.y - hoverpadding + hoveryoffset)-(mouse.x + (LEN(this.hovertext) * _FONTWIDTH(font_normal)) + hoverpadding, mouse.y + _FONTHEIGHT(font_normal) + hoverpadding + hoveryoffset), col&("ui"), B
    COLOR col&("ui"), col&("t")
    _PRINTSTRING (mouse.x, mouse.y + hoveryoffset), this.hovertext
END SUB

SUB expandElement (this AS element, elementindex AS INTEGER, currentfont AS LONG)
    DIM coord AS rectangle
    getCoord coord, elementindex, currentfont
    DIM options(0) AS STRING
    getOptionsArray options(), this

    IF UBOUND(options) = 0 THEN EXIT SUB

    originalheight = coord.h
    optionspadding = 6
    lineheight = _FONTHEIGHT(font_normal) + optionspadding
    coord.h = originalheight + (lineheight * (UBOUND(options))) + optionspadding
    LINE (coord.x, coord.y + lineheight + (2 * global.padding))-(coord.x + coord.w, coord.y + coord.h), col&("bg1"), BF
    rectangle "x=" + LST$(coord.x) + ";y=" + LST$(coord.y) + ";w=" + LST$(coord.w) + ";h=" + LST$(originalheight) + ";style=" + this.style + ";angle=" + this.angle + ";round=" + this.round, this.drawcolor
    DO: index = index + 1
        DIM itemcoord AS rectangle
        itemcoord.x = coord.x
        itemcoord.y = coord.y + (lineheight * index) + optionspadding
        itemcoord.w = coord.w
        itemcoord.h = lineheight
        IF mouseInBounds(itemcoord) THEN
            IF mouse.left THEN setGlobal this.name, options(index): lockmouse = -1
            COLOR col&("seltext"), col&("t")
            LINE (itemcoord.x + 1, itemcoord.y + 1)-(itemcoord.x + itemcoord.w - 1, itemcoord.y + itemcoord.h - 1), col&("bg2"), BF
        ELSE
            COLOR col&("ui"), col&("t")
            LINE (itemcoord.x + 1, itemcoord.y + 1)-(itemcoord.x + itemcoord.w - 1, itemcoord.y + itemcoord.h - 1), col&("bg1"), BF
        END IF
        _PRINTSTRING (itemcoord.x + (2 * global.padding), itemcoord.y + global.padding), options(index)
    LOOP UNTIL index = UBOUND(options)
    rectangle "x=" + LST$(coord.x) + ";y=" + LST$(coord.y) + ";w=" + LST$(coord.w) + ";h=" + LST$(coord.h) + ";style=B;angle=" + this.angle + ";round=" + this.round, this.drawcolor
END SUB

SUB getOptionsArray (array() AS STRING, this AS element)
    DIM AS STRING sep, buffer
    sep = "/"
    buffer = this.options
    DO
        length = INSTR(buffer, sep)
        IF length = 0 THEN
            addToStringArray array(), buffer
            buffer = ""
        ELSE
            addToStringArray array(), MID$(buffer, 1, length - 1)
            buffer = MID$(buffer, length + 1, LEN(buffer))
        END IF
    LOOP UNTIL buffer = ""
    IF UBOUND(array) > 0 THEN IF this.buffer = "" THEN this.buffer = array(1)
END SUB

SUB openContext (this AS element)
    this.contextopen = -1
    contextopen = -1
    this.contextx = mouse.x
    this.contexty = mouse.y
    this.allowcontextclose = 0
END SUB

SUB getCoord (coord AS rectangle, elementindex AS INTEGER, currentfont AS LONG)
    coord.x = VAL(getEXPos$(elementindex, currentfont))
    coord.y = VAL(getEYPos$(elementindex, currentfont))
    coord.w = VAL(getEWidth$(elementindex, currentfont))
    coord.h = VAL(getEHeight$(elementindex, currentfont))
END SUB

SUB displayContext (this AS element, elementindex AS INTEGER)
    REDIM _PRESERVE contextdata(0) AS STRING
    getContextArray contextdata(), this
    IF UBOUND(contextdata) = 0 THEN this.contextopen = 0: contextopen = 0: EXIT SUB
    maxlen = getMaxStringLen(contextdata())
    contextpadding = 6
    contextwidth = (maxlen * _FONTWIDTH(font_normal)) + (2 * contextpadding)
    contextheight = (UBOUND(contextdata) * (contextpadding + _FONTHEIGHT(font_normal))) + contextpadding

    DIM contextcoord AS rectangle
    contextcoord.x = this.contextx - 1
    contextcoord.y = this.contexty - 1
    contextcoord.w = contextwidth
    contextcoord.h = contextheight
    IF (mouse.left OR mouse.right) AND NOT mouseInBounds(contextcoord) AND this.allowcontextclose THEN this.contextopen = 0: contextopen = 0

    LINE (contextcoord.x, contextcoord.y)-(contextcoord.x + contextcoord.w, contextcoord.y + contextcoord.h), col&("bg1"), BF
    LINE (contextcoord.x, contextcoord.y)-(contextcoord.x + contextcoord.w, contextcoord.y + contextcoord.h), col&("ui"), B

    contextentry = 0: DO: contextentry = contextentry + 1
        DIM entrycoord AS rectangle
        entrycoord.x = contextcoord.x
        entrycoord.y = contextcoord.y + ((_FONTHEIGHT(font_normal) + contextpadding) * (contextentry - 1))
        entrycoord.w = contextcoord.w
        entrycoord.h = _FONTHEIGHT(font_normal) + contextpadding + global.padding

        IF mouseInBounds(entrycoord) AND contextdata(contextentry) <> "" THEN
            IF mouse.left THEN uiCall LCASE$(contextdata(contextentry)), this, elmentindex: lockuicall = -1 ELSE lockuicall = 0
            COLOR col&("seltext"), col&("t")
            'IF contextentry = UBOUND(contextdata) THEN highlightadd = global.padding ELSE highlightadd = 0
            LINE (entrycoord.x + 1, entrycoord.y + 1)-(entrycoord.x + entrycoord.w - 1, entrycoord.y + entrycoord.h - 1 + highlightadd), col&("bg2"), BF
        ELSE
            COLOR col&("ui"), col&("t")
        END IF

        _PRINTSTRING (this.contextx + contextpadding, entrycoord.y + contextpadding), contextdata(contextentry)
    LOOP UNTIL contextentry = UBOUND(contextdata)
END SUB

SUB getContextArray (array() AS STRING, this AS element)
    IF textSelectable(this) THEN addToStringArray array(), "Copy"
    IF typable(this) THEN addToStringArray array(), "Paste"
    IF this.action <> "" THEN addToStringArray array(), "Activate"
    IF toggleable(this) THEN addToStringArray array(), "Toggle"
    IF expandable(this) THEN addToStringArray array(), "Expand"
    IF typable(this) THEN addToStringArray array(), "UPPERCASE"
    IF typable(this) THEN addToStringArray array(), "lowercase"
END SUB

FUNCTION toggleable (this AS element)
    IF this.type = "checkbox" OR this.type = "radiobutton" THEN toggleable = -1 ELSE toggleable = 0
END FUNCTION

SUB addToStringArray (array() AS STRING, toadd AS STRING)
    REDIM _PRESERVE array(UBOUND(array) + 1) AS STRING
    array(UBOUND(array)) = toadd
END SUB

SUB addToHistory (this AS element, elementindex AS INTEGER)
    REDIM _PRESERVE history(UBOUND(history) + 1) AS history
    history(UBOUND(history)).element = elementindex
    history(UBOUND(history)).state = this
    elements(elementindex) = this
END SUB

SUB goBackInTime (this AS element)
    maxhis = UBOUND(history)
    index = history(maxhis).element
    this = history(maxhis).state
    REDIM _PRESERVE history(maxhis - 1) AS history
END SUB

FUNCTION getMaxStringLen (array() AS STRING)
    DIM buffer AS _UNSIGNED _INTEGER64
    IF UBOUND(array) > 0 THEN
        DO: i = i + 1
            IF LEN(array(i)) > buffer THEN
                buffer = LEN(array(i))
            END IF
        LOOP UNTIL i = UBOUND(array)
        getMaxStringLen = buffer: EXIT FUNCTION
    ELSE
        getMaxStringLen = 0: EXIT FUNCTION
    END IF
END FUNCTION

FUNCTION getBufferChar$ (this AS element, keyhit AS INTEGER)
    IF isNumChar(keyhit) = -1 AND this.allownumbers THEN
        getBufferChar$ = CHR$(keyhit)
    ELSEIF isNumChar(keyhit) = 1 AND this.allownumbers THEN
        getBufferChar$ = CHR$(-keyhit)
    ELSEIF isTextChar(keyhit) AND this.allowtext THEN
        getBufferChar$ = CHR$(keyhit)
    ELSEIF isSpecialChar(keyhit) AND this.allowspecial THEN
        getBufferChar$ = CHR$(keyhit)
    END IF
END FUNCTION

FUNCTION isTextChar (keyhit AS INTEGER)
    IF (keyhit >= ASC("A") AND keyhit <= ASC("Z")) OR (keyhit >= ASC("a") AND keyhit <= ASC("z")) OR keyhit = ASC(" ") THEN isTextChar = -1 ELSE isTextChar = 0
END FUNCTION

FUNCTION isNumChar (keyhit AS INTEGER)
    IF keyhit >= ASC("0") AND keyhit <= ASC("9") THEN
        isNumChar = -1
    ELSEIF keyhit <= -ASC("0") AND keyhit >= -ASC("9") AND ctrlDown THEN
        isNumChar = 1
    ELSE
        isNumChar = 0
    END IF
END FUNCTION

FUNCTION isSpecialChar (keyhit AS INTEGER)
    IF (keyhit >= ASC("!") AND keyhit <= ASC("~") AND NOT isTextChar(keyhit) AND NOT isNumChar(keyhit)) THEN isSpecialChar = -1 ELSE isSpecialChar = 0
END FUNCTION

SUB displayElement (elementindex AS INTEGER, keyhit AS INTEGER) 'parses abstract coordinates into discrete coordinates
    DIM this AS element
    DIM bufferchar AS STRING
    DIM invoke AS invoke
    this = elements(elementindex)

    REDIM currentfont AS LONG
    currentfont = getCurrentFont&(this)

    IF active(elementindex) THEN bufferchar = getBufferChar$(this, keyhit)

    'general
    SELECT CASE keyhit
        CASE 8: invoke.back = -1 'backspace
        CASE 9 'tab
            IF shiftDown THEN
                waitUntilReleased keyhit
                activeelement = getLastElement(currentview, activeelement)
            ELSE
                waitUntilReleased keyhit
                activeelement = getNextElement(currentview, activeelement)
            END IF
        CASE 13 'enter
            waitUntilReleased keyhit
            buffer$ = ""
            IF this.action <> "" THEN buffer$ = "action=" + this.action + ";"
            IF shiftDown THEN
                activeelement = getNextElement(currentview, activeelement)
            ELSE
                doThis buffer$ + getCurrentInputValues$(-1), 0
            END IF
        CASE 27
            doThis "action=view.main;" + getCurrentInputValues$(0), 0
        CASE 21248: invoke.delete = -1 'delete
        CASE 19200: invoke.left = -1 'left arrow
        CASE 19712: invoke.right = -1 'right arrow
        CASE 20224: invoke.jumptoend = -1 'end key
        CASE 18176: invoke.jumptofront = -1 'home key
    END SELECT

    elementKeyHandling this, elementindex, bufferchar, invoke

    DIM coord AS rectangle
    getCoord coord, elementindex, currentfont

    elementMouseHandling this, elementindex, invoke, coord, currentfont
    IF isException(this.name) THEN this.buffer = getExceptionValue$(this.name)
    drawElement this, elementindex, coord, invoke, currentfont

    elements(elementindex) = this
END SUB

FUNCTION getCurrentFont& (this AS element)
    DIM buffer AS LONG
    buffer = font_normal
    IF this.font <> "" AND UBOUND(font) > 0 THEN
        f = 0: DO: f = f + 1
            IF font(f).name = this.font THEN
                buffer = font(f).handle
            END IF
        LOOP UNTIL f = UBOUND(font)
    END IF
    getCurrentFont& = buffer
END FUNCTION

FUNCTION isException (elementname AS STRING)
    SELECT CASE elementname
        CASE "licensestatus": isException = -1
        CASE ELSE: isException = 0
    END SELECT
END FUNCTION

FUNCTION getExceptionValue$ (elementname AS STRING)
    SELECT CASE elementname
        CASE "licensestatus": getExceptionValue$ = switchWord$("active", global.licensestatus)
    END SELECT
END FUNCTION

SUB drawElement (this AS element, elementindex AS INTEGER, coord AS rectangle, invoke AS invoke, currentfont AS LONG)
    checkGlobal this
    _FONT currentfont
    SELECT CASE this.type
        CASE "button"
            rectangle "x=" + LST$(coord.x) + ";y=" + LST$(coord.y) + ";w=" + LST$(coord.w) + ";h=" + LST$(coord.h) + ";style=" + this.style + ";angle=" + this.angle + ";round=" + this.round, this.drawcolor
            coord.x = coord.x + (2 * global.padding)
            coord.y = coord.y + global.padding
            IF LCASE$(this.style) = "bf" THEN
                COLOR col&("bg1"), col&("t")
            ELSE
                COLOR this.drawcolor, col&("t")
            END IF
            _PRINTSTRING (coord.x, coord.y), this.text + " " + this.buffer
        CASE "input"
            underlinedistance = -2
            LINE (coord.x, coord.y + coord.h + underlinedistance)-(coord.x + coord.w - (2 * global.padding), coord.y + coord.h + underlinedistance), this.drawcolor
            COLOR this.drawcolor, col&("t")
            _PRINTSTRING (coord.x, coord.y), this.text + " " + this.buffer
        CASE "text"
            coord.y = coord.y + global.padding
            COLOR this.drawcolor, col&("t")
            checkForSpecialText this
            _PRINTSTRING (coord.x, coord.y), this.text + " " + this.buffer
        CASE "title"
            _FONT font_big
            COLOR this.drawcolor, col&("t")
            _PRINTSTRING (coord.x, coord.y), this.text
            _FONT font_normal
        CASE "line"
            LINE (coord.x, coord.y)-(coord.x + coord.w - global.padding, coord.y), this.drawcolor
        CASE "box"
            rectangle "x=" + LST$(coord.x) + ";y=" + LST$(coord.y) + ";w=" + LST$(coord.w) + ";h=" + LST$(coord.h) + ";style=" + this.style + ";angle=" + this.angle + ";round=" + this.round, this.drawcolor
        CASE "gradient"
            makeGradient this, -1
            drawGradient 1, coord.x, coord.x + coord.w, coord.y, coord.y + coord.h, 0, "h"
        CASE "checkbox"
            boxsize = _FONTHEIGHT(currentfont) * 0.75
            boxoffset = 0
            coord.w = coord.w + boxsize + global.margin
            coord.y = coord.y + global.padding
            rectangle "x=" + LST$(coord.x) + ";y=" + LST$(coord.y + boxoffset) + ";w=" + LST$(boxsize) + ";h=" + LST$(boxsize) + ";style=b;round=0", this.drawcolor
            inset = 3
            IF this.state = -1 THEN rectangle "x=" + LST$(coord.x + inset) + ";y=" + LST$(coord.y + boxoffset + inset) + ";w=" + LST$(boxsize - (2 * inset)) + ";h=" + LST$(boxsize - (2 * inset)) + ";style=bf;round=0", this.drawcolor
            COLOR this.drawcolor, col&("t")
            _PRINTSTRING (coord.x + boxsize + global.margin, coord.y), this.text + " " + switchWord$(this.switchword, this.state)
        CASE "radiobutton"
            boxsize = _FONTHEIGHT(currentfont) * 0.75
            boxoffset = 0
            coord.w = coord.w + boxsize + global.margin
            cx = coord.x + (boxsize / 2)
            cy = coord.y + (boxsize / 2)
            CIRCLE (cx, cy), boxsize * 0.5, this.drawcolor
            IF this.state = -1 THEN
                CIRCLE (cx, cy), boxsize * 0.3, this.drawcolor
                PAINT (cx, cy), this.drawcolor, this.drawcolor
            END IF
            COLOR this.drawcolor, col&("t")
            _PRINTSTRING (coord.x + boxsize + global.margin, coord.y), this.text + " " + switchWord$(this.switchword, this.state)
        CASE "dropdown"
            IF NOT this.expand THEN rectangle "x=" + LST$(coord.x) + ";y=" + LST$(coord.y) + ";w=" + LST$(coord.w) + ";h=" + LST$(coord.h) + ";style=" + this.style + ";angle=0;round=" + this.round, this.drawcolor
            coord.x = coord.x + (2 * global.padding)
            coord.y = coord.y + global.padding
            IF LCASE$(this.style) = "bf" THEN
                COLOR col&("bg1"), col&("t")
            ELSE
                COLOR this.drawcolor, col&("t")
            END IF
            _PRINTSTRING (coord.x, coord.y), this.text + " " + this.buffer
        CASE "slider"
            coord.y = coord.y + global.padding
            COLOR this.drawcolor, col&("t")
            _PRINTSTRING (coord.x, coord.y), this.text
            textwidth = LEN(this.text) * _FONTWIDTH(currentfont) + global.margin
            _PRINTSTRING (coord.x + textwidth + global.sliderwidth + global.margin, coord.y), this.buffer
            val_start = coord.x + textwidth
            val_end = coord.x + textwidth + global.sliderwidth
            cy = coord.y + (_FONTHEIGHT(currentfont) / 2)
            circlesize = (_FONTHEIGHT(currentfont) * 0.75) * 0.5
            CIRCLE (val_start + (this.value * (val_end - val_start)), cy), circlesize, this.drawcolor, BF
            PAINT (val_start + (this.value * (val_end - val_start)), cy), this.drawcolor, this.drawcolor
            LINE (val_start, cy)-(val_end, cy + 1), this.drawcolor, BF
        CASE "list"
            coord.x = coord.x + (2 * global.padding)
            coord.y = coord.y + global.padding
            SELECT CASE this.name
                'CASE "linklist"
                'searchnode$ = elements(gettitleid).text
                'DIM AS STRING linkarray(0)
                'getlinkarray linkarray(), searchnode$
                'displaylistarray this, nodearray(), coord, currentfont
            END SELECT
            rectangle "x=" + LST$(coord.x - (2 * global.padding)) + ";y=" + LST$(coord.y - global.padding) + ";w=" + LST$(coord.w) + ";h=" + LST$(coord.h) + ";style=" + this.style + ";angle=" + this.angle + ";round=" + this.round, this.drawcolor
        CASE "canvas"
            rectangle "x=" + LST$(coord.x) + ";y=" + LST$(coord.y) + ";w=" + LST$(coord.w) + ";h=" + LST$(coord.h) + ";style=" + this.style + ";angle=" + this.angle + ";round=" + this.round, this.drawcolor
    END SELECT
    displaySelection this, elementindex, coord, currentfont
END SUB

SUB checkForSpecialText (this AS element)
    SELECT CASE this.name
        CASE "time"
            this.buffer = TIME$
        CASE "date"
            this.buffer = DATE$
        CASE "transmit"
            this.buffer = transmittedtext
    END SELECT
END SUB

SUB makeGradient (this AS element, clearprevious AS _BYTE)
    IF clearprevious THEN clearGradients
    IF this.type = "gradient" THEN
        colorcount = getColorCount(this.color)
        DO: gindex = gindex + 1
            newGColor VAL(this.name), gindex, INT((100 / (colorcount - 1)) * (gindex - 1)), col&(getColor$(this.color, gindex))
        LOOP UNTIL gindex = colorcount
    END IF
END SUB

FUNCTION getColor$ (basestring AS STRING, num AS INTEGER)
    COLOR col&("ui"), col&("bg1")
    DIM buffer AS STRING
    buffer = basestring
    DO
        testfor = INSTR(buffer, "/")
        colors = colors + 1
        IF testfor = 0 THEN testfor = LEN(buffer) + 2
        IF colors = num THEN
            getColor$ = MID$(buffer, 1, testfor - 1): EXIT FUNCTION
        END IF
        buffer = MID$(buffer, testfor + 1, LEN(buffer))
    LOOP UNTIL buffer = ""
END FUNCTION

FUNCTION getColorCount (basestring AS STRING)
    DIM buffer AS STRING
    buffer = basestring
    DO
        testfor = INSTR(buffer, "/")
        IF testfor THEN colors = colors + 1
        buffer = MID$(buffer, testfor + 1, LEN(buffer))
    LOOP UNTIL testfor = 0
    getColorCount = colors + 1
END FUNCTION

FUNCTION isBrightColor (colour AS LONG)
    IF _RED(colour) > 127 OR _GREEN(colour) > 127 OR _BLUE(colour) > 127 THEN
        isBrightColor = -1
    ELSE
        isBrightColor = 0
    END IF
END FUNCTION

FUNCTION inBounds (inner AS rectangle, outer AS rectangle)
    IF inner.x > outer.x AND inner.x + inner.w < outer.x + outer.w AND inner.y > outer.y AND inner.y + inner.h < outer.y + outer.h THEN inBounds = -1 ELSE inBounds = 0
END FUNCTION

SUB sortCountList (target() AS countlist)
    unsorted = -1
    IF UBOUND(target) < 2 THEN EXIT SUB
    DO
        swapped = 0
        i = 0: DO: i = i + 1
            IF target(i).count < target(i + 1).count THEN
                SWAP target(i), target(i + 1)
                swapped = -1
            END IF
        LOOP UNTIL swapped = -1 OR i = UBOUND(target) - 1
    LOOP UNTIL i = UBOUND(target) - 1
END SUB

SUB displayListArray (this AS element, array() AS STRING, coord AS rectangle, currentfont AS LONG)
    IF UBOUND(array) = 0 THEN EXIT SUB

    IF this.scroll > UBOUND(array) THEN this.scroll = UBOUND(array)
    IF this.scroll < 0 THEN this.scroll = 0

    n = this.scroll
    DO: n = n + 1
        lineheight = global.margin + _FONTHEIGHT(currentfont)
        listitemy = coord.y + global.padding + (lineheight * (n - 1))

        IF listitemy + _FONTHEIGHT(currentfont) < coord.y + coord.h THEN
            IF mouse.x > coord.x - (2 * global.padding) AND mouse.x < coord.x + coord.w - (2 * global.padding) AND mouse.y > listitemy AND mouse.y < listitemy + _FONTHEIGHT(currentfont) THEN
                IF mouse.left THEN clickListItem this, array(), n
                COLOR col&("seltext"), col&("t")
                IF n = 1 THEN
                    LINE (coord.x - (2 * global.padding) + 1, listitemy - (2 * global.padding))-(coord.x - (2 * global.padding) + coord.w - 1, listitemy - global.padding + lineheight), col&("selected"), BF
                ELSE
                    LINE (coord.x - (2 * global.padding) + 1, listitemy - global.padding)-(coord.x - (2 * global.padding) + coord.w - 1, listitemy - global.padding + lineheight), col&("selected"), BF
                END IF
            ELSE
                COLOR this.drawcolor, col&("t")
            END IF

            DIM AS STRING listitems(0)
            getListItems listitems(), array(), n, this

            'display info
            IF UBOUND(listitems) > 0 THEN
                li = 0: DO: li = li + 1
                    listitemx = coord.x + ((coord.w / UBOUND(listitems)) * (li - 1))
                    _PRINTSTRING (listitemx, listitemy), listitems(li)
                LOOP UNTIL li = UBOUND(listitems)
            END IF
            ERASE listitems 'clean up array, will otherwise produce errors when dimming again
        END IF
    LOOP UNTIL n = UBOUND(array) OR (listitemy + _FONTHEIGHT(currentfont) >= coord.y - global.padding + coord.h)
    this.items = n - this.scroll
END SUB

SUB clickListItem (this AS element, array() AS STRING, n AS INTEGER)
    SELECT CASE this.name
        CASE "nodelist"
            doThis "action=view.nodegraph;nodetarget=" + array(n), 0
        CASE "linklist"
            'TODO
    END SELECT
END SUB

SUB getListItems (array() AS STRING, sourcearray() AS STRING, index AS INTEGER, this AS element)
    SELECT CASE this.name
        'CASE "linklist"
        '    REDIM AS STRING array(3)
        '    array(1) = getargument$(sourcearray(index), "nodeorigin")
        '    array(2) = getargument$(sourcearray(index), "linkname")
        '    array(3) = getargument$(sourcearray(index), "nodetarget")
    END SELECT
END SUB

SUB displaySelection (this AS element, elementindex AS INTEGER, coord AS rectangle, currentfont AS LONG)
    IF textSelectable(this) AND active(elementindex) THEN
        IF longSelection(this) THEN
            COLOR col&("seltext"), col&("selected")
            minx = min(this.sel_start, this.sel_end)
            maxx = max(this.sel_start, this.sel_end)
            _PRINTSTRING (coord.x + (_FONTWIDTH(currentfont) * (LEN(this.text) + minx)), coord.y), MID$(this.buffer, minx, maxx - minx + 1)
        ELSE
            IF (TIMER - mouse.lefttime) MOD 2 = 0 AND typable(this) THEN
                cursoroffset = -1
                cursorx = coord.x + (_FONTWIDTH(currentfont) * (LEN(this.text) + this.cursor + 1)) + cursoroffset
                LINE (cursorx, coord.y - 2)-(cursorx, coord.y + _FONTHEIGHT(currentfont) + 2), this.drawcolor, BF
            END IF
        END IF
    END IF
    IF (this.sel_start OR this.sel_end) AND mouse.left = 0 THEN
        this.deselect = -1
    END IF
END SUB

FUNCTION active (elementindex AS INTEGER)
    IF elementindex = activeelement THEN active = -1 ELSE active = 0
END FUNCTION

FUNCTION selectable (this AS element)
    IF this.type = "input" OR this.type = "button" THEN selectable = -1 ELSE selectable = 0
END FUNCTION

FUNCTION typable (this AS element)
    IF this.type = "input" THEN typable = -1 ELSE typable = 0
END FUNCTION

FUNCTION textSelectable (this AS element)
    IF this.type = "input" OR this.type = "text" OR this.type = "time" OR this.type = "date" THEN textSelectable = -1 ELSE textSelectable = 0
END FUNCTION

FUNCTION draggable (this AS element)
    draggable = 0
END FUNCTION

FUNCTION expandable (this AS element)
    IF this.type = "dropdown" THEN expandable = -1 ELSE expandable = 0
END FUNCTION

FUNCTION longSelection (this AS element)
    IF this.sel_start > 0 AND this.sel_end > 0 AND (this.sel_start <> this.sel_end) THEN longSelection = -1 ELSE longSelection = 0
END FUNCTION

SUB waitUntilReleased (keyhit AS INTEGER)
    DO: LOOP UNTIL _KEYDOWN(keyhit) = 0: keyhit = 0
END SUB

FUNCTION getLastElement (viewtogetfrom AS STRING, elementindex AS INTEGER)
    IF elementindex = 1 THEN e = UBOUND(elements) + 1 ELSE e = elementindex
    IF UBOUND(elements) > 0 THEN
        DO: e = e - 1
            IF elements(e).view = viewtogetfrom AND selectable(elements(e)) THEN getLastElement = e: EXIT FUNCTION
        LOOP UNTIL e = 1
    END IF
END FUNCTION

FUNCTION getNextElement (viewtogetfrom AS STRING, elementindex AS INTEGER)
    IF elementindex = UBOUND(elements) THEN e = 0 ELSE e = elementindex
    IF UBOUND(elements) > 0 THEN
        DO: e = e + 1
            IF elements(e).view = viewtogetfrom AND selectable(elements(e)) THEN getNextElement = e: EXIT FUNCTION
        LOOP UNTIL e = UBOUND(elements)
    END IF
END FUNCTION

FUNCTION getMaxElement (viewtogetfrom AS STRING)
    IF UBOUND(elements) > 0 THEN
        DO: e = e + 1
            IF elements(e).view = viewtogetfrom THEN
                buffer = e
            END IF
        LOOP UNTIL e = UBOUND(elements)
    END IF
    getMaxElement = buffer
END FUNCTION

SUB elementMouseHandling (this AS element, elementindex AS INTEGER, invoke AS invoke, coord AS rectangle, currentfont AS LONG)
    IF this.hovertextwait = 0 THEN this.hovertextwait = 1
    'IF NOT active(elementindex) AND this.expand THEN this.expand = 0
    IF mouseInBounds(coord) THEN
        IF this.hovertime = 0 OR this.hoverx <> mouse.x OR this.hovery <> mouse.y THEN this.hovertime = TIMER: this.hoverx = mouse.x: this.hovery = mouse.y
    ELSE
        this.hovertime = 0
    END IF
    IF mouseInBounds(coord) AND (elementlock = 0 OR elementlock = elementindex) AND NOT contextopen THEN
        IF ctrlDown THEN
            IF mouse.left AND selectable(this) THEN
                IF this.selected = -1 THEN this.selected = 0 ELSE this.selected = -1
                DO: m = _MOUSEINPUT: LOOP UNTIL _MOUSEBUTTON(1) = 0
            END IF
        ELSE
            IF mouse.left THEN
                IF this.action <> "" THEN
                    uiCall "activate", this, elementindex
                ELSEIF toggleable(this) AND NOT expanded THEN
                    uiCall "toggle", this, elementindex
                ELSEIF this.action = "" AND NOT active(elementindex) AND textSelectable(this) THEN
                    activeelement = elementindex
                    this.sel_start = 0: this.sel_end = 0
                ELSEIF expandable(this) AND this.statelock = 0 THEN
                    uiCall "expand", this, elementindex
                ELSEIF this.type = "slider" AND NOT expanded THEN
                    textwidth = LEN(this.text) * _FONTWIDTH(currentfont) + global.margin
                    val_start = coord.x + textwidth
                    val_end = coord.x + textwidth + global.sliderwidth
                    IF mouse.x > val_start AND mouse.x < val_end THEN
                        factor = (mouse.x - val_start) / (val_end - val_start)
                        this.value = factor
                        this.buffer = MID$(LST$(factor), 1, 4)
                        setGlobal this.name, LST$(this.value)
                    END IF
                END IF
            END IF

            IF mouse.scroll THEN
                this.scroll = this.scroll + mouse.scroll
            END IF
        END IF

        IF textSelectable(this) THEN
            sel_leftbound = coord.x + ((LEN(this.text) + 1) * _FONTWIDTH(currentfont))
            sel_rightbound = coord.x + ((LEN(this.text) + 1 + LEN(this.buffer)) * _FONTWIDTH(currentfont))
            IF mouse.x > sel_leftbound AND mouse.x < sel_rightbound AND mouse.left AND this.action = "" THEN
                charcount = (sel_rightbound - sel_leftbound) / _FONTWIDTH(currentfont)
                mousehoverchar = INT((((mouse.x - sel_leftbound) / (sel_rightbound - sel_leftbound)) * charcount) + 0.5)

                IF mouse.lefttimedif > internal.setting.doubleclickspeed THEN
                    IF this.deselect THEN
                        this.deselect = 0
                        this.sel_start = 0: this.sel_end = 0
                    END IF
                    IF this.sel_start THEN
                        this.sel_end = mousehoverchar
                        this.cursor = this.sel_end
                    ELSE
                        this.sel_start = mousehoverchar
                        this.cursor = mousehoverchar
                    END IF

                    elementlock = elementindex 'locks all actions to only the current element
                ELSEIF doubleClick THEN
                    this.cursor = mousehoverchar
                    this.sel_start = _INSTRREV(MID$(this.buffer, 1, this.cursor - 1), " ") + 1
                    this.sel_end = INSTR(MID$(this.buffer, this.sel_start + 1, LEN(this.buffer)), " ") + this.sel_start - 1
                    IF this.sel_end = this.sel_start - 1 THEN this.sel_end = LEN(this.buffer)
                ELSE 'triple click
                    uiCall "select all", this, elementindex
                END IF
            END IF
        ELSEIF draggable(this) THEN
            IF mouse.left AND NOT lockmouse THEN
                this.offsetx = this.offsetx + mouse.offsetx
                this.offsety = this.offsety + mouse.offsety
            END IF
        END IF
        IF NOT active(elementindex) THEN this.drawcolor = col&(this.hovercolor)
    ELSEIF active(elementindex) THEN
        this.drawcolor = col&("active")
    ELSEIF this.selected THEN
        this.drawcolor = col&("green")
    ELSE
        this.drawcolor = col&(this.color)
    END IF
    IF mouse.left = 0 THEN elementlock = 0: this.statelock = 0
END SUB

FUNCTION doubleClick
    IF mouse.lefttimedif <= internal.setting.doubleclickspeed AND mouse.lefttimedif2 > internal.setting.doubleclickspeed THEN doubleClick = -1 ELSE doubleClick = 0
END FUNCTION

FUNCTION mouseInBounds (coord AS rectangle)
    IF mouse.x > coord.x AND mouse.x < coord.x + coord.w AND mouse.y > coord.y AND mouse.y < coord.y + coord.h THEN mouseInBounds = -1 ELSE mouseInBounds = 0
END FUNCTION

SUB uiCall (func AS STRING, this AS element, elementindex AS INTEGER)
    IF NOT lockuicall THEN
        SELECT CASE func
            CASE "activate"
                doThis "action=" + this.action + ";" + getCurrentInputValues$(0), 0
            CASE "select all"
                this.sel_start = 1: this.sel_end = LEN(this.buffer)
            CASE "paste"
                addToHistory this, elementindex
                IF longSelection(this) THEN
                    paste this.buffer, this.sel_start, this.sel_end
                ELSE
                    this.buffer = MID$(this.buffer, 1, this.cursor) + _CLIPBOARD$ + MID$(this.buffer, this.cursor + 1, LEN(this.buffer))
                END IF
            CASE "copy"
                IF longSelection(this) THEN
                    copy this.buffer, this.sel_start, this.sel_end
                ELSE
                    IF this.buffer = "" THEN _CLIPBOARD$ = this.text ELSE _CLIPBOARD$ = this.buffer
                END IF
            CASE "revert"
                IF elementindex = history(UBOUND(history)).element THEN goBackInTime this
            CASE "expand"
                IF this.expand = -1 THEN this.expand = 0: expanded = 0: ELSE this.expand = -1: expanded = -1
                this.statelock = -1
            CASE "uppercase"
                addToHistory this, elementindex
                IF longSelection(this) THEN
                    minc = min(this.sel_start, this.sel_end)
                    maxc = max(this.sel_start, this.sel_end)
                    this.buffer = MID$(this.buffer, 1, minc - 1) + UCASE$(MID$(this.buffer, minc, maxc - minc + 1)) + MID$(this.buffer, maxc + 1, LEN(this.buffer))
                ELSE
                    this.buffer = UCASE$(this.buffer)
                END IF
            CASE "lowercase"
                addToHistory this, elementindex
                IF longSelection(this) THEN
                    minc = min(this.sel_start, this.sel_end)
                    maxc = max(this.sel_start, this.sel_end)
                    this.buffer = MID$(this.buffer, 1, minc - 1) + LCASE$(MID$(this.buffer, minc, maxc - minc + 1)) + MID$(this.buffer, maxc + 1, LEN(this.buffer))
                ELSE
                    this.buffer = LCASE$(this.buffer)
                END IF
            CASE "toggle"
                IF this.type = "radiobutton" THEN
                    this.state = -1
                    e = 0: DO: e = e + 1
                        IF elements(e).group = this.group AND elements(e).view = currentview AND elements(e).type = "radiobutton" AND e <> elementindex THEN
                            elements(e).state = 0
                        END IF
                    LOOP UNTIL e = UBOUND(elements)
                ELSEIF this.type = "checkbox" AND this.statelock = 0 THEN
                    IF this.state = 0 THEN this.state = -1 ELSE this.state = 0
                    setGlobal this.name, LST$(this.state)
                    this.statelock = -1
                END IF
        END SELECT
    END IF
END SUB

SUB elementKeyHandling (this AS element, elementindex AS INTEGER, bufferchar AS STRING, invoke AS invoke)
    IF (this.selected OR active(elementindex)) AND invoke.delete AND shiftDown THEN 'delete the entire buffer with shift+delete
        this.buffer = ""
        this.cursor = 0
        resetSelection this
    END IF
    IF this.cursor > LEN(this.buffer) THEN this.cursor = LEN(this.buffer)
    IF this.sel_start > LEN(this.buffer) THEN this.sel_start = LEN(this.buffer)
    IF this.sel_end > LEN(this.buffer) THEN this.sel_end = LEN(this.buffer)

    IF active(elementindex) = 0 THEN EXIT SUB

    'BELOW CODE WILL ONLY RUN IF ELEMENT IS ACTIVE!

    IF bufferchar <> "" THEN
        IF ctrlDown THEN 'ctrl
            SELECT CASE LCASE$(bufferchar)
                CASE "a"
                    uiCall "select all", this, elementindex
                CASE "v" 'paste something into an input field
                    uiCall "paste", this, elementindex
                CASE "c" 'copy something from an input field
                    uiCall "copy", this, elementindex
                CASE "u" 'uppercase
                    uiCall "uppercase", this, elementindex
                CASE "l" 'lowercase
                    uiCall "lowercase", this, elementindex
                CASE "z" 'revert last change
                    uiCall "revert", this, elementindex
                CASE "f" 'replace buffer with "nodetarget="
                    uiCall "search", this, elementindex
                CASE "n" 'replace buffer with "action=add.node;nodetarget="
                    uiCall "add node", this, elementindex
                CASE "0"
                    IF this.name = "commandline" THEN addToHistory this, elementindex: this.buffer = this.buffer + "action=": this.cursor = LEN(this.buffer)
                CASE "1" 'attach "nodeorigin=" to buffer
                    IF this.name = "commandline" THEN addToHistory this, elementindex: this.buffer = this.buffer + "nodeorigin=": this.cursor = LEN(this.buffer)
                CASE "2" 'attach "nodeorigin=" to buffer
                    IF this.name = "commandline" THEN addToHistory this, elementindex: this.buffer = this.buffer + "linkname=": this.cursor = LEN(this.buffer)
                CASE "3" 'attach "nodeorigin=" to buffer
                    IF this.name = "commandline" THEN addToHistory this, elementindex: this.buffer = this.buffer + "nodetarget=": this.cursor = LEN(this.buffer)
                CASE "r" 'should reset the offset position, but doesn't for some reason
                    this.offsetx = 0: this.offsety = 0
                CASE ELSE
                    insertBufferChar this, elementindex, bufferchar
            END SELECT
        ELSE
            IF longSelection(this) THEN
                sel_start = min(this.sel_start, this.sel_end)
                sel_end = max(this.sel_start, this.sel_end)
                this.buffer = deletePart$(this.buffer, sel_start, sel_end)
                this.cursor = sel_start - 1
            END IF
            insertBufferChar this, elementindex, bufferchar
        END IF
    ELSE
        IF ctrlDown AND shiftDown THEN
            IF invoke.left THEN
                this.sel_start = this.cursor
                IF this.sel_end = 0 AND NOT longSelection(this) THEN this.sel_end = this.sel_start
                this.sel_end = _INSTRREV(" " + MID$(this.buffer, 1, this.sel_end - 2), " ")
            END IF
            IF invoke.right THEN
                this.sel_start = this.cursor + 1
                IF this.sel_end = 0 THEN this.sel_end = this.sel_start
                this.sel_end = INSTR(MID$(this.buffer, this.sel_end + 2, LEN(this.buffer)) + " ", " ") + this.sel_end
            END IF
        ELSEIF ctrlDown AND NOT shiftDown THEN
            IF invoke.left THEN this.cursor = _INSTRREV(" " + MID$(this.buffer, 1, this.cursor - 1), " ") - 1
            IF invoke.right THEN this.cursor = INSTR(MID$(this.buffer, this.cursor + 1, LEN(this.buffer)) + " ", " ") + this.cursor
        ELSEIF shiftDown AND NOT ctrlDown THEN
            IF invoke.left THEN
                IF this.sel_start THEN
                    IF this.sel_end > 0 THEN this.sel_end = this.sel_end - 1
                ELSE
                    this.sel_start = this.cursor
                    this.sel_end = this.sel_start
                END IF
            END IF
            IF invoke.right THEN
                IF this.sel_start THEN
                    IF this.sel_end < LEN(this.buffer) THEN this.sel_end = this.sel_end + 1
                ELSE
                    this.sel_start = this.cursor
                    this.sel_end = this.sel_start
                END IF
            END IF
        ELSE
            IF invoke.left THEN
                IF longSelection(this) THEN
                    resetSelection this
                ELSE
                    IF this.cursor > 0 THEN this.cursor = this.cursor - 1
                END IF
            END IF
            IF invoke.right THEN
                IF longSelection(this) THEN
                    resetSelection this
                ELSE
                    IF this.cursor < LEN(this.buffer) THEN this.cursor = this.cursor + 1
                END IF
            END IF
        END IF
        IF invoke.jumptoend THEN
            IF shiftDown THEN
                this.sel_start = this.cursor + 1
                this.sel_end = LEN(this.buffer)
            ELSE
                this.cursor = LEN(this.buffer)
            END IF
        END IF
        IF invoke.jumptofront THEN
            IF shiftDown THEN
                this.sel_start = this.cursor
                this.sel_end = 1
            ELSE
                this.cursor = 0
            END IF
        END IF
    END IF

    'selection management
    IF longSelection(this) AND (invoke.delete OR invoke.back) THEN 'deleting with selection
        addToHistory this, elementindex
        deleteSelection this
    ELSE 'deleting only one character
        IF invoke.back AND this.cursor > 0 THEN 'backspace
            addToHistory this, elementindex
            this.buffer = MID$(this.buffer, 1, this.cursor - 1) + MID$(this.buffer, this.cursor + 1, LEN(this.buffer))
            this.cursor = this.cursor - 1
            resetSelection this
        ELSEIF invoke.delete AND this.cursor < LEN(this.buffer) THEN 'delete
            addToHistory this, elementindex
            this.buffer = MID$(this.buffer, 1, this.cursor) + MID$(this.buffer, this.cursor + 2, LEN(this.buffer))
            resetSelection this
        END IF
    END IF
END SUB

SUB deleteSelection (this AS element)
    sel_start = min(this.sel_start, this.sel_end)
    sel_end = max(this.sel_start, this.sel_end)
    this.buffer = deletePart$(this.buffer, sel_start, sel_end)
    this.cursor = sel_start - 1
    resetSelection this
END SUB

FUNCTION deletePart$ (basestring AS STRING, delstart AS INTEGER, delend AS INTEGER)
    deletePart$ = MID$(basestring, 1, delstart - 1) + MID$(basestring, delend + 1, LEN(basestring))
END FUNCTION

SUB resetSelection (this AS element)
    this.sel_start = 0: this.sel_end = 0
END SUB

SUB paste (basestring AS STRING, clipstart AS INTEGER, clipend AS INTEGER)
    clipbuffer = min(clipstart, clipend)
    clipend = max(clipstart, clipend)
    clipstart = clipbuffer
    basestring = MID$(basestring, 1, clipstart - 1) + _CLIPBOARD$ + MID$(basestring, clipend + 1, LEN(basestring))
END SUB

SUB copy (basestring AS STRING, clipstart AS INTEGER, clipend AS INTEGER)
    cliplength = ABS(clipstart - clipend) + 1
    clipstart = min(clipstart, clipend)
    _CLIPBOARD$ = MID$(basestring, clipstart, cliplength)
END SUB

FUNCTION min (a, b)
    IF a < b THEN min = a ELSE min = b
END FUNCTION

FUNCTION max (a, b)
    IF a > b THEN max = a ELSE max = b
END FUNCTION

SUB insertBufferChar (this AS element, elementindex AS INTEGER, insert AS STRING)
    addToHistory this, elementindex
    this.buffer = MID$(this.buffer, 1, this.cursor) + insert + MID$(this.buffer, this.cursor + 1, LEN(this.buffer))
    this.cursor = this.cursor + 1
    resetSelection this
END SUB

FUNCTION ctrlDown
    IF _KEYDOWN(100305) OR _KEYDOWN(100306) THEN ctrlDown = -1 ELSE ctrlDown = 0
END FUNCTION

FUNCTION shiftDown
    IF _KEYDOWN(100303) OR _KEYDOWN(100304) THEN shiftDown = -1 ELSE shiftDown = 0
END FUNCTION

FUNCTION switchWord$ (word AS STRING, state AS _BYTE)
    IF word = "" THEN switchWord$ = "": EXIT FUNCTION
    DIM AS STRING state1, state2
    SELECT CASE LCASE$(word)
        CASE "on"
            state1 = "On"
            state2 = "Off"
        CASE "active"
            state1 = "Active"
            state2 = "Inactive"
    END SELECT
    IF state = -1 THEN
        switchWord$ = state1
    ELSE
        switchWord$ = state2
    END IF
END FUNCTION

FUNCTION getCurrentInputValues$ (killbuffer AS _BYTE)
    DIM buffer AS STRING
    IF UBOUND(elements) > 0 THEN
        DO: e = e + 1
            IF elements(e).view = currentview AND elements(e).name <> "commandline" THEN
                IF elements(e).buffer <> "" THEN buffer = buffer + elements(e).name + "=" + elements(e).buffer + ";"
                IF killbuffer THEN elements(e).buffer = ""
                IF elements(e).url <> "" THEN buffer = buffer + "url=" + elements(e).url + ";"
            ELSEIF elements(e).view = currentview AND elements(e).name = "commandline" THEN
                buffer = buffer + elements(e).buffer + ";"
                IF killbuffer THEN elements(e).buffer = ""
            END IF
            IF elements(e).type = "input" AND killbuffer THEN
                elements(e).cursor = 0
                elements(e).sel_start = 0
                elements(e).sel_end = 0
            END IF
        LOOP UNTIL e = UBOUND(elements)
    END IF
    getCurrentInputValues$ = buffer
END FUNCTION

FUNCTION getEXPos$ (e AS INTEGER, currentfont AS LONG)
    IF (elements(e).x = "previousright" OR elements(e).x = "prevr" OR elements(e).x = "flex") AND e > 1 THEN
        getEXPos$ = LST$(VAL(getEXPos$(e - 1, currentfont)) + VAL(getEWidth$(e - 1, currentfont)) + global.margin)
    ELSEIF (elements(e).x = "previousleft" OR elements(e).x = "prevl" OR elements(e).x = "-flex") AND e > 1 THEN
        getEXPos$ = LST$(VAL(getEXPos$(e - 1, currentfont)) - VAL(getEWidth$(e, currentfont)) - global.margin)
    ELSEIF (elements(e).x = "previous" OR elements(e).x = "p" OR elements(e).x = "prev") AND e > 1 THEN
        getEXPos$ = getEXPos$(e - 1, currentfont)
    ELSEIF (elements(e).x = "right" OR elements(e).x = "r") THEN
        getEXPos$ = LST$(_WIDTH(0) - VAL(getEWidth$(e, currentfont)) - global.margin)
    ELSEIF (elements(e).x = "margin" OR elements(e).x = "m" OR elements(e).x = "left" OR elements(e).x = "l" OR elements(e).x = "0") THEN
        getEXPos$ = LST$(global.margin)
    ELSE
        getEXPos$ = elements(e).x
    END IF
END FUNCTION

FUNCTION getEYPos$ (e AS INTEGER, currentfont AS LONG)
    IF (elements(e).y = "previousbottom" OR elements(e).y = "prevb" OR elements(e).y = "pb" OR elements(e).y = "flex") AND e > 1 THEN
        getEYPos$ = LST$(VAL(getEYPos$(e - 1, currentfont)) + VAL(getEHeight$(e - 1, currentfont)) + (SGN(VAL(getEHeight$(e - 1, currentfont))) * global.margin))
    ELSEIF (elements(e).y = "previoustop" OR elements(e).y = "prevt" OR elements(e).y = "pt" OR elements(e).y = "-flex") AND e > 1 THEN
        getEYPos$ = LST$(VAL(getEYPos$(e - 1, currentfont)) - VAL(getEHeight$(e, currentfont)) - global.margin)
    ELSEIF (elements(e).y = "nexttop" OR elements(e).y = "nextt" OR elements(e).y = "nt") AND e < UBOUND(elements) THEN
        getEYPos$ = LST$(VAL(getEYPos$(e + 1, currentfont)) - VAL(getEHeight$(e, currentfont)) - global.margin)
    ELSEIF (elements(e).y = "previous" OR elements(e).y = "p" OR elements(e).y = "prev") AND e > 1 THEN
        getEYPos$ = getEYPos$(e - 1, currentfont)
    ELSEIF (elements(e).y = "bottom" OR elements(e).y = "b") THEN
        getEYPos$ = LST$(_HEIGHT(0) - VAL(getEHeight$(e, currentfont)) - global.margin)
    ELSEIF (elements(e).y = "margin" OR elements(e).y = "m" OR elements(e).y = "top" OR elements(e).y = "t" OR elements(e).y = "0") THEN
        getEYPos$ = LST$(global.margin)
    ELSE
        getEYPos$ = elements(e).y
    END IF
END FUNCTION

FUNCTION getEWidth$ (e AS INTEGER, currentfont AS LONG)
    IF elements(e).w = "flex" OR elements(e).w = "f" THEN 'you would normally want this one for text-based elements
        IF elements(e).type = "slider" THEN
            getEWidth$ = LST$(VAL(elements(e).w) + (_FONTWIDTH(currentfont) * (LEN(elements(e).text) + 1 + SGN(LEN(elements(e).buffer)) + LEN(elements(e).buffer))) + 1 + (2 * global.padding) + global.margin + global.sliderwidth)
        ELSE
            getEWidth$ = LST$(VAL(elements(e).w) + (_FONTWIDTH(currentfont) * (LEN(elements(e).text) + 1 + SGN(LEN(elements(e).buffer)) + LEN(elements(e).buffer))) + 1 + (2 * global.padding))
        END IF
    ELSEIF elements(e).w = "full" THEN
        getEWidth$ = LST$(_WIDTH(0) - VAL(getEXPos$(e, currentfont)) - global.margin)
    ELSE
        getEWidth$ = elements(e).w
    END IF
END FUNCTION

FUNCTION getEHeight$ (e AS INTEGER, currentfont AS LONG)
    IF elements(e).type = "title" OR elements(e).type = "text" THEN
        IF elements(e).text = "" AND elements(e).buffer = "" THEN
            getEHeight$ = "0": EXIT FUNCTION
        END IF
    END IF
    IF elements(e).type = "title" THEN getEHeight$ = LST$(_FONTHEIGHT(font_big) + (2 * global.padding)): EXIT FUNCTION
    IF elements(e).h = "0" THEN
        getEHeight$ = LST$(_FONTHEIGHT(font_normal) + (2 * global.padding))
    ELSEIF (elements(e).h = "nextt" OR elements(e).h = "next.top" OR elements(e).h = "nt") AND e < UBOUND(elements) THEN
        getEHeight$ = LST$(VAL(getEYPos$(e + 1, currentfont)) - (2 * global.margin) - VAL(getEYPos$(e, currentfont)))
    ELSE
        getEHeight$ = elements(e).h
    END IF
END FUNCTION

FUNCTION getEPadding$ (e AS INTEGER)
    IF elements(e).padding = "" THEN
        getEPadding$ = LST$(global.padding)
    ELSE
        getEPadding$ = elements(e).padding
    END IF
END FUNCTION

SUB doThis (arguments AS STRING, recursivecall AS _BYTE) 'program-specific actions
    IF global.actionlock AND NOT recursivecall THEN
        EXIT SUB
    ELSE
        IF mouse.left THEN global.actionlock = -1
    END IF
    DIM AS STRING license, url, success
    action$ = getArgument$(arguments, "action")
    license = getArgument$(arguments, "license")
    transmittedtext = getArgument$(arguments, "transmit")
    url = getArgument$(arguments, "url")
    SELECT CASE action$
        CASE "add.license"
            IF set(license) THEN
                success = add.License$("license=" + license)
                doThis "action=view.main;transmit=" + success, -1
            ELSE
                doThis "action=view.add.license", -1
            END IF
        CASE "web"
            openBrowser url
        CASE "check.license"
            loadConfig
        CASE "saveconfig"
            saveConfig
            loadConfig
        CASE "resetconfig"
            resetConfig
            loadConfig
        CASE "quit"
            SYSTEM
    END SELECT
    SELECT CASE MID$(action$, 1, INSTR(action$, ".") - 1)
        CASE "view"
            currentview = MID$(action$, INSTR(action$, ".") + 1, LEN(action$))
    END SELECT
END SUB

FUNCTION getTitleID
    IF UBOUND(elements) = 0 THEN EXIT FUNCTION
    DO: e = e + 1
        IF elements(e).view = currentview AND elements(e).type = "title" THEN getTitleID = e: EXIT FUNCTION
    LOOP UNTIL e = UBOUND(elements)
END FUNCTION

FUNCTION add.License$ (arguments AS STRING)
    DIM license AS STRING
    license = getArgument$(arguments, "license")
    IF checkLicense(license) THEN
        setLicense license, -1
        license = ""
        saveConfig
        add.License$ = "License added successfully."
    ELSE
        add.License$ = "License verification failed."
    END IF
END FUNCTION

SUB getFileArray (array() AS STRING, file AS STRING)
    IF _FILEEXISTS(file) = 0 THEN EXIT SUB
    freen = FREEFILE
    OPEN file FOR INPUT AS #freen
    IF EOF(freen) THEN CLOSE #freen: EXIT SUB
    DO
        INPUT #freen, filedata$
        addToStringArray array(), filedata$
    LOOP UNTIL EOF(freen)
    CLOSE #freen
END SUB

SUB writeFileArray (array() AS STRING, file AS STRING, exclude AS STRING)
    freen = FREEFILE
    OPEN file FOR OUTPUT AS #freen
    DO: index = index + 1
        IF array(index) <> exclude THEN PRINT #freen, array(index)
    LOOP UNTIL index = UBOUND(array)
    CLOSE #freen
END SUB

FUNCTION illegalFile (totest AS STRING)
    t$ = LCASE$(totest)
    IF t$ = "con" THEN illegalFile = -1 ELSE illegalFile = 0
END FUNCTION

FUNCTION notInArray (array() AS STRING, search AS STRING)
    IF UBOUND(array) = 0 THEN notInArray = -1: EXIT FUNCTION
    DO: index = index + 1
        IF array(index) = search THEN notInArray = 0: EXIT FUNCTION
    LOOP UNTIL index = UBOUND(array)
    notInArray = -1
END FUNCTION

FUNCTION partMatch (comparison AS STRING, search AS STRING)
    IF INSTR(comparison, search) > 0 AND LEN(search) >= global.matchthreshhold THEN partMatch = -1 ELSE partMatch = 0
END FUNCTION

SUB loadConfig
    configfile$ = global.intpath + "\config.dst"
    proofFile configfile$, -1
    freen = FREEFILE
    OPEN configfile$ FOR INPUT AS #freen
    IF EOF(freen) = 0 THEN
        DO
            INPUT #freen, configline$
            config$ = config$ + configline$
        LOOP UNTIL EOF(freen) = -1
    END IF
    CLOSE #freen

    global.padding = getArgumentv(config$, "padding")
    global.margin = getArgumentv(config$, "margin")
    global.round = getArgumentv(config$, "round")
    global.license = getArgument$(config$, "license")
    global.partialsearch = getArgumentv(config$, "partialsearch")
    global.scheme = getArgument$(config$, "colorscheme")
    global.matchthreshhold = getArgumentv(config$, "matchthreshhold")
    global.windowsize = getArgumentv(config$, "windowsize")
    loadColors global.scheme
    loadFonts
    IF checkLicense(_INFLATE$(global.license)) = 0 THEN setLicense "", 0: saveConfig
    IF global.license <> "" THEN global.licensestatus = -1
END SUB

SUB resetConfig
    config$ = "round=3;margin=10;padding=6;license=;colorscheme=teal;matchthreshhold=2;partialsearch=-1;windowsize=.5"
    configfile$ = global.intpath + "\config.dst"
    freen = FREEFILE
    OPEN configfile$ FOR OUTPUT AS #freen
    PRINT #freen, config$
    CLOSE #freen
END SUB

SUB saveConfig
    config$ = "round=" + LST$(global.round) + ";margin=" + LST$(global.margin) + ";padding=" + LST$(global.padding) + ";license=" + global.license
    config$ = config$ + ";colorscheme=" + global.scheme + ";matchthreshhold=" + LST$(global.matchthreshhold) + ";partialsearch=" + LST$(global.partialsearch) + ";windowsize=" + LST$(global.windowsize)
    configfile$ = global.intpath + "\config.dst"
    freen = FREEFILE
    OPEN configfile$ FOR OUTPUT AS #freen
    PRINT #freen, config$
    CLOSE #freen
END SUB

SUB loadFonts
    REDIM AS STRING filedata(0), schemefonts, fontname
    REDIM _PRESERVE font(0) AS font
    schemefonts = global.intpath + "\schemes\" + global.scheme + ".fonts"
    IF _FILEEXISTS(schemefonts) THEN
        getFileArray filedata(), schemefonts
        IF UBOUND(filedata) > 0 THEN
            index = 0: DO: index = index + 1
                fontname = getArgument$(filedata(index), "name")
                IF fontname = "" THEN fontname = filedata(index)
                REDIM testfont(4) AS STRING
                testfont(1) = "C:\Windows\Fonts\" + fontname + ".ttf"
                testfont(2) = "C:\Windows\Fonts\" + fontname + ".otf"
                testfont(3) = global.intpath + "\fonts\" + fontname + ".ttf"
                testfont(4) = global.intpath + "\fonts\" + fontname + ".otf"
                tf = 0: DO: tf = tf + 1
                    IF _FILEEXISTS(testfont(tf)) THEN
                        addFont fontname, testfont(tf)
                        tf = 4
                    END IF
                LOOP UNTIL tf = 4
            LOOP UNTIL index = UBOUND(filedata)
        END IF
    END IF

    'fontr$ = "C:\Windows\Fonts\consola.ttf"
    fontr$ = "internal\fonts\PTMono-Regular.ttf" 'replace with file loaded from config file
    fonteb$ = "internal\fonts\OpenSans-ExtraBold.ttf"
    font_normal = _LOADFONT(fontr$, 16, "MONOSPACE")
    font_big = _LOADFONT(fonteb$, 48)
    _FONT font_normal
END SUB

SUB addFont (fontname AS STRING, fontfile AS STRING)
    REDIM _PRESERVE font(UBOUND(font) + 1) AS font
    i = UBOUND(font)
    font(i).name = fontname
    font(i).handle = _LOADFONT(fontfile, 16, "MONOSPACE")
END SUB

SUB loadUI
    REDIM _PRESERVE viewname(0) AS STRING

    loadFonts

    'freen = FREEFILE
    'viewfile$ = global.intpath + "\views.dui"
    'proofFile viewfile$, -1
    'OPEN viewfile$ FOR INPUT AS #freen
    'IF EOF(freen) = 0 THEN
    '    DO: lview = lview + 1
    '        REDIM _PRESERVE viewname(UBOUND(viewname) + 1) AS STRING
    '        INPUT #freen, viewname(lview)
    '    LOOP UNTIL EOF(freen) = -1
    'ELSE
    '    PRINT "internal/views.dui is empty, could not load UI!"
    '    SLEEP: SYSTEM
    'END IF
    'CLOSE #freen

    'IF UBOUND(viewname) > 0 THEN
    '    lview = 0: DO: lview = lview + 1
    '        freen = FREEFILE
    '        viewfile$ = global.intpath + "\" + viewname(lview) + ".dui"
    '        IF _FILEEXISTS(viewfile$) THEN
    '            OPEN viewfile$ FOR INPUT AS #freen
    '            IF EOF(freen) = 0 THEN
    '                DO
    '                    INPUT #freen, uielement$

    '                    IF MID$(_TRIM$(uielement$), 1, 1) <> "/" THEN
    '                        REDIM _PRESERVE elements(UBOUND(elements) + 1) AS element
    '                        eub = UBOUND(elements)
    '                        elements(eub).view = viewname(lview)
    '                        elements(eub).type = getArgument$(uielement$, "type")
    '                        elements(eub).allownumbers = getArgumentv(uielement$, "allownumbers")
    '                        elements(eub).allowtext = getArgumentv(uielement$, "allowtext")
    '                        elements(eub).allowspecial = getArgumentv(uielement$, "allowspecial")
    '                        elements(eub).name = getArgument$(uielement$, "name")
    '                        elements(eub).x = getArgument$(uielement$, "x")
    '                        elements(eub).y = getArgument$(uielement$, "y")
    '                        elements(eub).w = getArgument$(uielement$, "w")
    '                        elements(eub).h = getArgument$(uielement$, "h")
    '                        elements(eub).color = getArgument$(uielement$, "color")
    '                        elements(eub).hovercolor = getArgument$(uielement$, "hovercolor")
    '                        elements(eub).style = getArgument$(uielement$, "style")
    '                        elements(eub).text = getArgument$(uielement$, "text")
    '                        elements(eub).action = getArgument$(uielement$, "action")
    '                        elements(eub).angle = getArgument$(uielement$, "angle")
    '                        elements(eub).buffer = getArgument$(uielement$, "buffer")
    '                        elements(eub).round = getArgument$(uielement$, "round")
    '                        elements(eub).hovertext = getArgument$(uielement$, "hovertext")
    '                        elements(eub).hovertextwait = getArgumentv(uielement$, "hovertextwait")
    '                        elements(eub).padding = getArgument$(uielement$, "padding")
    '                        elements(eub).url = getArgument$(uielement$, "url")
    '                        elements(eub).switchword = getArgument$(uielement$, "switchword")
    '                        elements(eub).group = getArgument$(uielement$, "group")
    '                        elements(eub).options = getArgument$(uielement$, "options")
    '                        elements(eub).font = getArgument$(uielement$, "font")
    '                        elements(eub).selected = 0

    '                        checkGlobal elements(eub)

    '                        IF elements(eub).type = "input" AND activeelement = 0 THEN
    '                            activeelement = eub
    '                        END IF
    '                    END IF
    '                LOOP UNTIL EOF(freen)
    '            END IF
    '            CLOSE #freen
    '            PRINT "Successfully loaded UI for view " + LST$(lview) + "!"
    '        ELSE
    '            PRINT "Error loading UI for view " + LST$(lview)
    '        END IF
    '    LOOP UNTIL lview = UBOUND(viewname)
    '    currentview = viewname(1)
    'ELSE
    '    PRINT "Could not load UI!"
    '    SLEEP: SYSTEM
    'END IF
END SUB

SUB checkGlobal (this AS element)
    SELECT CASE this.name
        CASE "colorscheme"
            this.buffer = global.scheme
        CASE "partialsearch"
            this.state = global.partialsearch
        CASE "license"
            this.buffer = global.license
        CASE "windowsize"
            this.value = global.windowsize
            this.buffer = MID$(LST$(this.value), 1, 4)
    END SELECT
END SUB

SUB setGlobal (globalname AS STRING, value AS STRING)
    SELECT CASE globalname
        CASE "colorscheme"
            global.scheme = value
            saveConfig
            loadConfig
        CASE "partialsearch"
            global.partialsearch = VAL(value)
        CASE "license"
            global.license = value
        CASE "windowsize"
            global.windowsize = VAL(value)
        CASE ELSE: EXIT SUB
    END SELECT
END SUB

SUB proofPath (pathtoproof AS STRING) 'creates a folder if it doesn't exist
    IF _DIREXISTS(pathtoproof) = 0 THEN
        PRINT _CWD$; pathtoproof
        MKDIR pathtoproof
    END IF
END SUB

SUB proofFile (filetoproof AS STRING, giveerror AS _BYTE) 'creates a file if it doesn't exist
    IF _FILEEXISTS(filetoproof) = 0 THEN
        IF giveerror THEN PRINT "The following file could not be found, the program might not work as intended: " + filetoproof: _DELAY 2
        freen = FREEFILE
        OPEN filetoproof FOR OUTPUT AS #freen
        CLOSE #freen
    END IF
END SUB

SUB getFileList (SearchDirectory AS STRING, DirList() AS STRING, FileList() AS STRING)
    CONST IS_DIR = 1
    CONST IS_FILE = 2
    DIM flags AS LONG, file_size AS LONG
    REDIM DirList(100), FileList(1000)
    DirCount = 0: FileCount = 0
    IF load_dir(SearchDirectory + CHR$(0)) THEN
        DO
            length = has_next_entry
            IF length > -1 THEN
                nam$ = SPACE$(length)
                get_next_entry nam$, flags, file_size
                IF flags AND IS_DIR THEN
                    DirCount = DirCount + 1
                    IF DirCount > UBOUND(DirList) THEN REDIM _PRESERVE DirList(UBOUND(DirList) + 100)
                    DirList(DirCount) = nam$
                ELSEIF flags AND IS_FILE THEN
                    FileCount = FileCount + 1
                    IF FileCount > UBOUND(filelist) THEN REDIM _PRESERVE FileList(UBOUND(filelist) + 100)
                    FileList(FileCount) = nam$
                END IF
            END IF
        LOOP UNTIL length = -1
        close_dir
    ELSE
    END IF
    REDIM _PRESERVE DirList(DirCount)
    REDIM _PRESERVE FileList(FileCount)
END SUB

FUNCTION getArgument$ (basestring AS STRING, argument AS STRING)
    getArgument$ = stringValue$(basestring, argument)
END FUNCTION

FUNCTION getArgumentv (basestring AS STRING, argument AS STRING)
    getArgumentv = VAL(stringValue$(basestring, argument))
END FUNCTION

FUNCTION set (tocheck AS STRING) 'just returns if a string variable has a value or not
    IF LTRIM$(RTRIM$(tocheck)) <> "" THEN
        set = -1: EXIT FUNCTION
    ELSE
        set = 0: EXIT FUNCTION
    END IF
END FUNCTION

FUNCTION stringValue$ (basestring AS STRING, argument AS STRING)
    IF LEN(basestring) > 0 THEN
        p = 1: DO
            IF MID$(basestring, p, LEN(argument)) = argument THEN
                endpos = INSTR(p + LEN(argument), basestring, ";")
                IF endpos = 0 THEN endpos = LEN(basestring) ELSE endpos = endpos - 1 'means that no comma has been found. taking the entire rest of the string as argument value.

                startpos = INSTR(p + LEN(argument), basestring, "=")
                IF startpos > endpos THEN
                    startpos = p + LEN(argument)
                ELSE
                    IF startpos = 0 THEN startpos = p + LEN(argument) ELSE startpos = startpos + 1 'means that no equal sign has been found. taking value right from the end of the argument name.
                END IF

                IF internal.setting.trimstrings = -1 THEN
                    stringValue$ = LTRIM$(RTRIM$(MID$(basestring, startpos, endpos - startpos + 1)))
                    EXIT FUNCTION
                ELSE
                    stringValue$ = MID$(basestring, startpos, endpos - startpos + 1)
                    EXIT FUNCTION
                END IF
            END IF
            finder = INSTR(p + 1, basestring, ";") + 1
            IF finder > 1 THEN p = finder ELSE stringValue$ = "": EXIT FUNCTION
        LOOP UNTIL p >= LEN(basestring)
    END IF
END FUNCTION

SUB drawShape (arguments AS STRING, clr AS LONG)
    DIM AS _FLOAT x, y, w, h, thickness
    x = getArgumentv(arguments, "x")
    y = getArgumentv(arguments, "y")
    w = getArgumentv(arguments, "w")
    h = getArgumentv(arguments, "h")
    thickness = getArgumentv(arguments, "thickness")
    SELECT CASE getArgument$(arguments, "shape")
        CASE "+"
            LINE (x + (w / 2) - (thickness / 2), y)-(x + (w / 2) + (thickness / 2), y + h), clr, BF
            LINE (x, y + (h / 2) - (thickness / 2))-(x + w, y + (h / 2) + (thickness / 2)), clr, BF
        CASE "x"
    END SELECT
END SUB

SUB rectangle (arguments AS STRING, clr AS LONG)
    x = getArgumentv(arguments, "x")
    y = getArgumentv(arguments, "y")
    w = getArgumentv(arguments, "w")
    h = getArgumentv(arguments, "h")
    round$ = getArgument$(arguments, "round")
    rotation = getArgumentv(arguments, "angle")
    rotation = rotation / 180 * _PI
    IF round$ = "" THEN
        round = global.round
    ELSE
        round = VAL(round$)
    END IF
    SELECT CASE UCASE$(getArgument$(arguments, "style"))
        CASE "BF"
            rectangleOutline x, y, w, h, round, rotation, clr, _PI / 20
            PAINT (x + (w / 2), y + (h / 2)), clr, clr
        CASE "B"
            rectangleOutline x, y, w, h, round, rotation, clr, 0
        CASE ELSE
            rectangleOutline x, y, w, h, round, rotation, clr, 0
    END SELECT
END SUB

SUB rectangleOutline (x, y, w, h, round, rotation, clr AS LONG, bfadjust)
    IF rotation <> 0 THEN
        IF w < h THEN mininmum = w ELSE mininmum = h
        IF round > mininmum / 2 THEN round = mininmum / 2
        distance = SQR((w ^ 2) + (h ^ 2)) / 2 'distance to center point
        rotation = rotation - (_PI / 2)
        rounddistance = distance - SQR(round ^ 2 + round ^ 2)
        cx = x + (w / 2)
        cy = y + (h / 2)
        detail = _PI * round 'how many pixels are calculated for one rounded corner
        angle1 = ATN((h / 2) / (w / 2))
        angle2 = ((_PI) - (2 * angle1)) / 2
        rotation = rotation - angle1
        DO
            corner = corner + 1
            IF corner MOD 2 = 0 THEN 'alternates between the two different possible angles within a rectangle
                cangle = angle2 * 2
                offset = -_PI / 4
            ELSE
                cangle = angle1 * 2
                offset = _PI / 4
            END IF

            'rcf = round corner factor, adds the angle progressively together to go "around" the rectangle based off the middle
            rcf = rotation + anglebase
            rcfp1 = rotation + anglebase + cangle

            px = cx + (rounddistance * SIN(rcf))
            py = cy - (rounddistance * COS(rcf))

            px1 = cx + (rounddistance * SIN(rcfp1))
            py1 = cy - (rounddistance * COS(rcfp1))

            'start is left end of rounding, end is right end of rounding
            startangle = -(_PI / 2) + ((cangle / 2))
            endangle = ((cangle / 2))

            'uses endangle of current corner to connect to startangle of next
            LINE (px + (SIN(endangle + rcf) * round), py - (COS(endangle + rcf) * round))-(px1 + (SIN(startangle + rcfp1 + offset) * round), py1 - (COS(startangle + rcfp1 + offset) * round)), clr

            'draws the curves on the corners pixel by pixel
            angle = startangle + rcf - bfadjust
            DO: angle = angle + ((0.5 * _PI) / detail)
                PSET (px + (SIN(angle) * round), py - (COS(angle) * round)), clr
            LOOP UNTIL angle >= startangle + rcf + (_PI / 2) + bfadjust

            anglebase = anglebase + cangle
        LOOP UNTIL corner = 4
    ELSE
        detail = _PI * round
        corner = 0: DO: corner = corner + 1
            xdir = getCornerXDir(corner)
            ydir = getCornerYDir(corner)
            px = getPX(x, w, xdir)
            py = getPY(y, h, ydir)
            drawCornerConnector x, y, w, h, corner, clr, round
            cornerangle = (_PI / 2) * (corner - 1)
            angle = -(_PI / 2) + cornerangle
            DO: angle = angle + ((0.5 * _PI) / detail)
                PSET (px + (round * xdir) + (SIN(angle) * round), py + (round * ydir) - (COS(angle) * round)), clr
            LOOP UNTIL angle >= cornerangle
        LOOP UNTIL corner = 4
    END IF
END SUB

SUB drawCornerConnector (x AS INTEGER, y AS INTEGER, w AS INTEGER, h AS INTEGER, corner AS INTEGER, clr AS LONG, round)
    SELECT CASE corner
        CASE 1: LINE (x + round, y)-(x + w - round, y), clr
        CASE 2: LINE (x + w, y + round)-(x + w, y + h - round), clr
        CASE 3: LINE (x + w - round, y + h)-(x + round, y + h), clr
        CASE 4: LINE (x, y + h - round)-(x, y + round), clr
    END SELECT
END SUB

FUNCTION isPositive (value)
    IF value > 0 THEN isPositive = -1 ELSE isPositive = 0
END FUNCTION

FUNCTION isNegative (value)
    IF value < 0 THEN isNegative = -1 ELSE isNegative = 0
END FUNCTION

FUNCTION getPX (x AS INTEGER, w AS INTEGER, xdir AS _BYTE)
    IF xdir = 1 THEN getPX = x ELSE getPX = x + w
END FUNCTION

FUNCTION getPY (y AS INTEGER, h AS INTEGER, ydir AS _BYTE)
    IF ydir = 1 THEN getPY = y ELSE getPY = y + h
END FUNCTION

FUNCTION getCornerXDir (corner AS _BYTE)
    IF corner > 4 THEN corner = (corner MOD 4) * 4
    SELECT CASE corner
        CASE 1: getCornerXDir = 1
        CASE 2: getCornerXDir = -1
        CASE 3: getCornerXDir = -1
        CASE 4: getCornerXDir = 1
    END SELECT
END FUNCTION

FUNCTION getCornerYDir (corner AS _BYTE)
    IF corner > 4 THEN corner = (corner MOD 4) * 4
    SELECT CASE corner
        CASE 1: getCornerYDir = 1
        CASE 2: getCornerYDir = 1
        CASE 3: getCornerYDir = -1
        CASE 4: getCornerYDir = -1
    END SELECT
END FUNCTION

FUNCTION LST$ (number AS _FLOAT)
    LST$ = LTRIM$(STR$(number))
END FUNCTION

FUNCTION checkLicense (license$)
    IF _FILEEXISTS("license.txt") THEN KILL "license.txt"
    shellcmd$ = "cmd /c curl http://api.gumroad.com/v2/licenses/verify -d " + CHR$(34) + "product_permalink=XXun" + CHR$(34) + " -d " + CHR$(34) + "license_key=" + license$ + CHR$(34) + " > license.txt"
    SHELL _HIDE shellcmd$
    DO: LOOP UNTIL _FILEEXISTS("license.txt") = -1
    OPEN "license.txt" FOR INPUT AS #1
    IF EOF(1) = 0 THEN
        DO
            LINE INPUT #1, licensecallback$
            p = 0
            u = 0
            o = 0
            DO
                p = p + 1
                IF MID$(licensecallback$, p, 1) = CHR$(34) THEN
                    u = p
                    DO: u = u + 1: LOOP UNTIL MID$(licensecallback$, u, 1) = CHR$(34)
                    attribute$ = MID$(licensecallback$, p + 1, u - p - 1)
                    IF attribute$ <> "purchase" AND attribute$ <> "custom_fields" AND attribute$ <> "How did you discover Datanet?" AND attribute$ <> "variants" THEN
                        o = u
                        DO: o = o + 1: LOOP UNTIL MID$(licensecallback$, o, 1) = "," OR MID$(licensecallback$, o, 1) = "}"
                        IF MID$(licensecallback$, o - 1, 1) = CHR$(34) THEN
                            value$ = MID$(licensecallback$, u + 3, o - u - 4)
                        ELSE
                            value$ = MID$(licensecallback$, u + 2, o - u - 2)
                        END IF
                        p = o
                        SELECT CASE attribute$
                            CASE IS = "success": success$ = value$
                            CASE IS = "uses": uses = VAL(value$)
                            CASE IS = "seller_id": sellerID$ = value$
                            CASE IS = "product_id": productID$ = value$
                            CASE IS = "product_name": productname$ = value$
                            CASE IS = "permalink": permalink$ = value$
                            CASE IS = "product_permalink": productpermalink$ = value$
                            CASE IS = "email": email$ = value$
                            CASE IS = "price": price = VAL(value$)
                            CASE IS = "currency": currency$ = value$
                            CASE IS = "quantity": quantity = VAL(value$)
                            CASE IS = "order_number": ordernumber = VAL(value$)
                            CASE IS = "sale_id": saleID$ = value$
                            CASE IS = "sale_timestamp": saletimestamp$ = value$
                            CASE IS = "purchaser_id": purchaserID = VAL(value$)
                            CASE IS = "test": test$ = value$
                            CASE IS = "How did you discover Datanet?": discovery$ = value$
                            CASE IS = "license_key": licensekey$ = value$
                            CASE IS = "ip_country": IPcountry$ = value$
                            CASE IS = "is_gift_receiver_purchase": isgift$ = value$
                            CASE IS = "refunded": refunded$ = value$
                            CASE IS = "disputed": disputed$ = value$
                            CASE IS = "dispute_won": disputewon$ = value$
                            CASE IS = "id": id$ = value$
                            CASE IS = "created_at": createdat$ = value$
                            CASE IS = "variants": variants$ = value$
                            CASE IS = "chargebacked": chargebacked$ = value$
                            CASE IS = "ended_at": endedat$ = value$
                            CASE IS = "failed_at": failedat$ = value$
                        END SELECT
                    ELSE
                        DO: p = p + 1: LOOP UNTIL MID$(licensecallback$, p, 1) = "{" OR MID$(licensecallback$, p, 1) = "[" OR MID$(licensecallback$, p, 1) = ","
                    END IF
                    attribute$ = ""
                    value$ = ""
                END IF
            LOOP UNTIL p >= LEN(licensecallback$)
        LOOP UNTIL EOF(1) = -1
    END IF
    CLOSE #1
    KILL "license.txt"
    IF success$ = "true" AND productname$ = "Datanet" AND permalink$ = "datanet" AND licensekey$ = license$ AND endedat$ = "" AND failedat$ = "" THEN
        checkLicense = -1
    ELSE
        checkLicense = 0
    END IF
END FUNCTION

SUB openBrowser (url AS STRING)
    SHELL _HIDE "rundll32 url.dll,FileProtocolHandler " + url
END SUB

SUB setLicense (license AS STRING, status AS _BYTE)
    global.license = _DEFLATE$(license)
    global.licensestatus = status
END SUB

SUB loadColors (scheme AS STRING)
    REDIM _PRESERVE schemecolor(0) AS colour
    file$ = global.intpath + "\schemes\" + scheme + ".colors"
    IF NOT _FILEEXISTS(file$) THEN
        file$ = global.intpath + "\schemes\standard.colors"
    END IF
    freen = FREEFILE
    OPEN file$ FOR INPUT AS #freen
    IF EOF(freen) = 0 THEN
        DO
            INPUT #freen, color$
            addColor color$
        LOOP UNTIL EOF(freen)
    END IF
    CLOSE #freen
END SUB

SUB addColor (colour AS STRING)
    REDIM _PRESERVE schemecolor(UBOUND(schemecolor) + 1) AS colour
    index = UBOUND(schemecolor)
    schemecolor(index).name = getArgument$(colour, "name")
    schemecolor(index).r = getArgumentv(colour, "r")
    schemecolor(index).g = getArgumentv(colour, "g")
    schemecolor(index).b = getArgumentv(colour, "b")
    schemecolor(index).a = getArgumentv(colour, "a")
END SUB

FUNCTION col& (colour AS STRING)
    IF UBOUND(schemecolor) > 0 THEN
        DO: i = i + 1
            IF LCASE$(schemecolor(i).name) = LCASE$(colour) THEN col& = _RGBA(schemecolor(i).r, schemecolor(i).g, schemecolor(i).b, schemecolor(i).a): EXIT FUNCTION
        LOOP UNTIL i = UBOUND(schemecolor)
    END IF
END FUNCTION

SUB clearGradients
    REDIM _PRESERVE gradient(0, 0) AS gradient
END SUB

SUB newGColor (gindex AS INTEGER, cindex AS INTEGER, position AS _FLOAT, clr AS LONG)
    IF cindex > 0 AND gindex > 0 THEN
        IF gindex > UBOUND(gradient, 1) THEN REDIM _PRESERVE gradient(UBOUND(gradient, 1) + 1, UBOUND(gradient, 2)) AS gradient
        IF cindex > UBOUND(gradient, 2) THEN REDIM _PRESERVE gradient(UBOUND(gradient, 1), UBOUND(gradient, 2) + 1) AS gradient
        gradient(gindex, cindex).color = clr
        gradient(gindex, cindex).gpos = position
    END IF
END SUB

FUNCTION gradientColor& (gindex AS INTEGER, grposition)
    IF UBOUND(gradient, 1) = 0 OR UBOUND(gradient, 2) = 0 THEN EXIT FUNCTION

    grcolor = 0: DO: grcolor = grcolor + 1
        IF grposition = gradient(gindex, grcolor).gpos THEN
            gradientColor& = gradient(gindex, grcolor).color
            EXIT FUNCTION
        ELSE
            IF grcolor < UBOUND(gradient, 2) THEN
                IF grposition > gradient(gindex, grcolor).gpos AND grposition < gradient(gindex, grcolor + 1).gpos THEN
                    r1 = _RED(gradient(gindex, grcolor).color)
                    g1 = _GREEN(gradient(gindex, grcolor).color)
                    b1 = _BLUE(gradient(gindex, grcolor).color)
                    a1 = _ALPHA(gradient(gindex, grcolor).color)
                    r2 = _RED(gradient(gindex, grcolor + 1).color)
                    g2 = _GREEN(gradient(gindex, grcolor + 1).color)
                    b2 = _BLUE(gradient(gindex, grcolor + 1).color)
                    a2 = _ALPHA(gradient(gindex, grcolor + 1).color)
                    p1 = gradient(gindex, grcolor).gpos
                    p2 = gradient(gindex, grcolor + 1).gpos
                    f = (grposition - p1) / (p2 - p1)
                    IF r1 > r2 THEN
                        rr = r1 - ((r1 - r2) * f)
                    ELSEIF r1 = r2 THEN
                        rr = r1
                    ELSE
                        rr = r1 + ((r2 - r1) * f)
                    END IF
                    IF g1 > g2 THEN
                        gg = g1 - ((g1 - g2) * f)
                    ELSEIF g1 = g2 THEN
                        gg = g1
                    ELSE
                        gg = g1 + ((g2 - g1) * f)
                    END IF
                    IF b1 > b2 THEN
                        bb = b1 - ((b1 - b2) * f)
                    ELSEIF b1 = b2 THEN
                        bb = b1
                    ELSE
                        bb = b1 + ((b2 - b1) * f)
                    END IF
                    IF a1 > a2 THEN
                        aa = a1 - ((a1 - a2) * f)
                    ELSEIF a1 = a2 THEN
                        aa = a1
                    ELSE
                        aa = a1 + ((a2 - a1) * f)
                    END IF
                    gradientColor& = _RGBA(INT(rr), INT(gg), INT(bb), INT(aa))
                    EXIT FUNCTION
                END IF
            END IF
        END IF
    LOOP UNTIL grcolor = UBOUND(gradient, 2)
END FUNCTION

SUB drawGradient (gradient, lx, ux, ly, uy, Around, orientation$)
    round = Around
    SELECT CASE orientation$
        CASE "h"
            IF ux < lx THEN: buffer = ux: ux = lx: lx = buffer
            IF round > 0 THEN
                rx = lx: DO: rx = rx + 1
                    LINE (rx, ly + COS((round - rx) / round * _PI / 2))-(rx, uy - COS((round - rx) / round * _PI / 2)), gradientColor&(gradient, (rx - lx) / (ux - lx) * 100)
                LOOP UNTIL rx >= lx + round
                DO: rx = rx + 1
                    LINE (rx, ly)-(rx, uy), gradientColor&(gradient, (rx - lx) / (ux - lx) * 100)
                LOOP UNTIL rx >= ux - round
                DO: rx = rx + 1
                    LINE (rx, ly + SIN((rx - (ux - round)) / round * _PI / 2))-(rx, uy - SIN((rx - (ux - round)) / round * _PI / 2)), gradientColor&(gradient, (rx - lx) / (ux - lx) * 100)
                LOOP UNTIL rx >= ux
            ELSE
                rx = lx: DO: rx = rx + 1
                    LINE (rx, ly)-(rx, uy), gradientColor&(gradient, (rx - lx) / (ux - lx) * 100)
                LOOP UNTIL rx >= ux
            END IF
        CASE "v"
            IF uy < ly THEN: buffer = uy: uy = ly: ly = buffer
            ry = 0: DO: ry = ry + 1
                LINE (lx, ly + ry)-(ux, ly + ry), gradientColor&(gradient, ry / (uy - ly) * 100)
            LOOP UNTIL ry >= uy - ly
    END SELECT
END SUB
