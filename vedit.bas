CLS: CLOSE
$RESIZE:ON
REM $DYNAMIC

'--------------------------------------------------------------------------------------------------------------------------------------'

' System info
OS$ = MID$(_OS$, 2, INSTR(_OS$, "]") - 2)
OStype$ = MID$(_OS$, INSTR(2, _OS$, "[") + 1, INSTR(INSTR(2, _OS$, "["), _OS$, "]") - INSTR(2, _OS$, "[") - 1)

TYPE layerInfo
    AS DOUBLE x, y, w, h
    AS STRING type
    AS INTEGER contentid
END TYPE
REDIM SHARED layerInfo(0) AS layerInfo

TYPE fileInfo
    AS DOUBLE w, h
    AS STRING name, file, type
END TYPE

'UI
'$INCLUDE: 'um.bi'

'--------------------------------------------------------------------------------------------------------------------------------------'

' Layer types
' Image layer
TYPE imageLayer
    i AS LONG 'image handle
    file AS STRING * 500 'file location
    name AS STRING * 50
    ar AS _FLOAT 'aspect ratio
    t AS INTEGER 'transparency (0-255)
    x AS _FLOAT 'x position
    y AS _FLOAT 'y position
    w AS _FLOAT 'width
    h AS _FLOAT 'height
    enabled AS _BYTE 'if visible or not
END TYPE
REDIM SHARED imageLayer AS imageLayer
REDIM SHARED layerbuffer AS imageLayer

' Vector layer
TYPE vectorPoint
    AS DOUBLE x, y
    AS DOUBLE handlex, handley
END TYPE
REDIM SHARED vectorPoints(0, 0) AS vectorPoint
TYPE vectorPreview
    AS LONG image
    AS _BYTE status, mouseStatus, enabled
END TYPE
REDIM SHARED vectorPreview(0) AS vectorPreview


'--------------------------------------------------------------------------------------------------------------------------------------'

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

loadUI
DO
    frameStart = TIMER
    CLS

    checkResize
    fileDropCheck
    checkMouse
    keyhit = checkKeyboard
    displayView keyhit
    displayText

    IF roundsSinceEdit < 1000 THEN roundsSinceEdit = roundsSinceEdit + 1

    'DEBUG
    lastFrameTime = TIMER - frameStart
    displayFrameTimes lastFrameTime

    _DISPLAY
    _LIMIT internal.setting.fps
LOOP UNTIL mainexit = -1 OR restart = -1
IF restart = -1 THEN GOTO start

SUB fileDropCheck
    IF _TOTALDROPPEDFILES > 0 THEN
        DO
            df$ = _DROPPEDFILE
            IF _FILEEXISTS(df$) THEN
                droptype$ = "file"
            ELSE
                IF _DIREXISTS(a$) THEN
                    droptype$ = "folder"
                ELSE
                    droptype$ = "empty"
                END IF
            END IF
            SELECT CASE droptype$
                CASE "file"
                    'IF MID$(df$, LEN(df$) - 3, 4) = ".png" OR MID$(df$, LEN(df$) - 3, 4) = ".jpg" THEN
                    '    IF img < 0 THEN _FREEIMAGE img
                    '    img = _LOADIMAGE(df$, 32)
                    '    ar = _WIDTH(img) / _HEIGHT(img)
                    '    IF ar = artboard(af, artboard).ar THEN
                    '        w = artboard(af, artboard).w
                    '        h = artboard(af, artboard).h
                    '        x = 0
                    '        y = 0
                    '    ELSEIF ar > artboard(af, artboard).ar THEN 'if new layer is wider than artboard
                    '        w = artboard(af, artboard).w
                    '        h = w / ar
                    '        x = 0
                    '        y = (artboard(af, artboard).h - _HEIGHT(img)) / 2
                    '    ELSEIF ar < artboard(af, artboard).ar THEN 'if new layer is taller than artboard
                    '        h = artboard(af, artboard).h
                    '        w = h * ar
                    '        x = (artboard(af, artboard).w - _WIDTH(img)) / 2
                    '        y = 0
                    '    END IF
                    '    p = 0: DO: p = p + 1
                    '    LOOP UNTIL p = LEN(df$) OR MID$(df$, LEN(df$) + 1 - p, 1) = "\"
                    '    n = LEN(df$) - p + 2
                    '    nl = LEN(df$) - n - 3
                    '    addlayer MID$(df$, n, nl), df$, ar, 255, x, y, w, h, artboard
                    '    activelayer = UBOUND(ilayer, 2)
                    '    drawgraphics 1
                    'END IF
            END SELECT
        LOOP UNTIL _TOTALDROPPEDFILES = 0
        _FINISHDROP
    END IF
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
        CASE "image"
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
            LINE (i + (_FONTWIDTH * 2), 60)-(i + (_FONTWIDTH * 2), 60 - ((frameTimes(i) / maxFrameTime) * 50)), _RGBA(255, 255, 255, 50)
        END IF
    LOOP UNTIL i = UBOUND(frameTimes)
    _PRINTSTRING (getColumn(8), getRow(0)), LTRIM$(STR$(maxFrameTime)) + " frame time / " + LTRIM$(STR$(INT(1 / (avgsum / counted)))) + " FPS"
END SUB

SUB displayText
    '_PRINTSTRING (getColumn(1), getRow(4)), "Create point: [CTRL] + [Left Mouse]"
    '_PRINTSTRING (getColumn(1), getRow(5)), "Delete point: [CTRL] + [Left Mouse]"
    '_PRINTSTRING (getColumn(1), getRow(6)), "Move point:   [Left Mouse] + Drag"
    '_PRINTSTRING (getColumn(1), getRow(7)), "Move handle:  [Right Mouse] + Drag"
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

FUNCTION inRadius (boxX, boxY, pointX, pointY, radius)
    IF pointX > boxX - (radius / 2) AND pointY > boxY - (radius / 2) AND pointX < boxX + (radius / 2) AND pointY < boxY + (radius / 2) THEN
        inRadius = -1
    ELSE
        inRadius = 0
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

'--------------------------------------------------------------------------------------------------------------------------------------'

'$INCLUDE: 'um.bm'
'$INCLUDE: 'um_dependent.bm'
