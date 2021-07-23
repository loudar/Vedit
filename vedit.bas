CLS: CLOSE
$RESIZE:ON
REM $DYNAMIC

'--------------------------------------------------------------------------------------------------------------------------------------'

' System info
OS$ = MID$(_OS$, 2, INSTR(_OS$, "]") - 2)
OStype$ = MID$(_OS$, INSTR(2, _OS$, "[") + 1, INSTR(INSTR(2, _OS$, "["), _OS$, "]") - INSTR(2, _OS$, "[") - 1)

TYPE layerInfo
    AS DOUBLE x, y, w, h
    AS STRING type, name
    AS INTEGER contentid
END TYPE
REDIM SHARED layerInfo(0) AS layerInfo

TYPE fileInfo
    AS DOUBLE w, h, zoom, xOffset, yOffset
    AS INTEGER activeLayer
    AS STRING name, file
END TYPE
REDIM SHARED file AS fileInfo

'UI
'$INCLUDE: 'dependencies/um.bi'
'$INCLUDE: 'dependencies/opensave.bi'

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
REDIM SHARED imageLayer(0) AS imageLayer
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

loadUI 0
DO
    'frameStart = TIMER
    CLS

    checkResize
    fileDropCheck
    checkMouse
    keyhit = checkKeyboard
    displayView keyhit
    displayText

    IF roundsSinceEdit < 1000 THEN roundsSinceEdit = roundsSinceEdit + 1

    'DEBUG
    'lastFrameTime = TIMER - frameStart
    'displayFrameTimes lastFrameTime

    _DISPLAY
    _LIMIT internal.setting.fps
LOOP UNTIL mainexit = -1 OR restart = -1
IF restart = -1 THEN GOTO start

SUB saveFileDialog
    filter$ = "VFI (*.vfi)|*.VFI" + CHR$(0)
    'filter$ = "VFI (*.vfi)|*.VFI|PNG (*.png)|*.PNG|JPG/JPEG (*.jpeg)|*.JPEG" + CHR$(0)
    flags& = OFN_OVERWRITEPROMPT + OFN_NOCHANGEDIR '   add flag constants here
    targetfile$ = GetSaveFileName$("Vedit - Save File", ".\", filter$, 1, flags&, _WINDOWHANDLE)
    saveFile targetfile$
END SUB

SUB openFileDialog
    filter$ = "VFI (*.vfi)|*.VFI" + CHR$(0)
    flags& = OFN_FILEMUSTEXIST + OFN_NOCHANGEDIR + OFN_READONLY '    add flag constants here
    sourcefile$ = GetOpenFileName$("Vedit - Open File", ".\", filter$, 1, flags&, _WINDOWHANDLE)
    openFile sourcefile$
END SUB

SUB saveFile (targetFile AS STRING)
    format$ = MID$(targetFile$, _INSTRREV(targetFile$, "."), LEN(targetFile$))
    SELECT CASE format$
        CASE ".vfi"
            writeVFI targetFile$
        CASE ".png"
        CASE ".jpeg"
    END SELECT
END SUB

SUB writeVFI (targetFile AS STRING)
    file.file = targetFile
    freen = FREEFILE
    OPEN targetFile FOR OUTPUT AS #freen
    info$ = "type=fileInfo;width=" + LST$(file.w) + ";height=" + LST$(file.h) + ";zoom=" + LST$(file.zoom) + ";xOffset=" + LST$(file.xOffset) + ";yOffset=" + LST$(file.yOffset) + ";activeLayer=" + LST$(file.activeLayer) + ";name=" + file.name + ";file=" + targetFile
    PRINT #freen, info$
    IF UBOUND(layerinfo) > 0 THEN
        i = 0: DO: i = i + 1
            IF layerInfo(i).type = "image" THEN
                info$ = "type=layerInfo;layert=image;width=" + LST$(layerInfo(i).w) + ";height=" + LST$(layerInfo(i).h) + ";x=" + LST$(layerInfo(i).x) + ";y=" + LST$(layerInfo(i).y) + ";name=" + layerInfo(i).name + ";contentid=" + LST$(layerInfo(i).contentid) + ";file=" + imageLayer(layerInfo(i).contentid).file
                PRINT #freen, info$
            ELSE
                info$ = "type=layerInfo;layert=vector;width=" + LST$(layerInfo(i).w) + ";height=" + LST$(layerInfo(i).h) + ";x=" + LST$(layerInfo(i).x) + ";y=" + LST$(layerInfo(i).y) + ";name=" + layerInfo(i).name + ";contentid=" + LST$(layerInfo(i).contentid)
                PRINT #freen, info$
            END IF
        LOOP UNTIL i = UBOUND(layerInfo)
    END IF
    IF UBOUND(vectorPoints, 1) > 0 THEN
        i = 0: DO: i = i + 1
            maxPoints = getMaxPoints(i)
            IF maxPoints > 0 THEN
                p = 0: DO: p = p + 1
                    info$ = "type=vectorPoint;contentid=" + LST$(i) + ";x=" + LST$(vectorPoints(i, p).x) + ";y=" + LST$(vectorPoints(i, p).y) + ";handlex=" + LST$(vectorPoints(i, p).handlex) + ";handley=" + LST$(vectorPoints(i, p).handley)
                    PRINT #freen, info$
                LOOP UNTIL p = UBOUND(vectorpoints, 2) OR p = maxPoints
            END IF
        LOOP UNTIL i = UBOUND(vectorPoints, 1)
    END IF
    CLOSE #freen
END SUB

SUB loadVFI (sourceFile AS STRING)
    REDIM _PRESERVE file AS fileInfo
    REDIM _PRESERVE imageLayer(0) AS imageLayer
    REDIM _PRESERVE vectorPoints(0, 0) AS vectorPoint
    REDIM _PRESERVE vectorPreview(0) AS vectorPreview

    freen = FREEFILE
    OPEN sourceFile FOR INPUT AS #freen
    IF EOF(freen) = 0 THEN
        DO
            LINE INPUT #freen, lineinfo$
            parseFileInfo lineinfo$
        LOOP UNTIL EOF(freen) = -1
    END IF
    CLOSE #freen
END SUB

SUB parseFileInfo (source AS STRING)
    REDIM attributes(0) AS STRING
    REDIM AS STRING attribute, value
    createAttributearray source, attributes()
    IF UBOUND(attributes) > 1 THEN
        parseAttributeValue attributes(1), attribute, value
        SELECT CASE value
            CASE "fileInfo"
                i = 1: DO: i = i + 1
                    parseAttributeValue attributes(i), attribute, value
                    SELECT CASE attribute
                        CASE "width"
                            file.w = VAL(value)
                        CASE "height"
                            file.h = VAL(value)
                        CASE "zoom"
                            file.zoom = VAL(value)
                        CASE "xOffset"
                            file.xOffset = VAL(value)
                        CASE "yOffset"
                            file.yOffset = VAL(value)
                        CASE "activeLayer"
                            file.activeLayer = VAL(value)
                        CASE "name"
                            file.name = value
                        CASE "file"
                            file.file = value
                    END SELECT
                LOOP UNTIL i = UBOUND(attributes)
            CASE "layerInfo"
                i = 1: DO: i = i + 1
                    parseAttributeValue attributes(i), attribute, value
                    SELECT CASE attribute
                        CASE "file"
                            file$ = value
                        CASE "name"
                            layname$ = value
                        CASE "t"
                            t = VAL(value)
                        CASE "x"
                            x = VAL(value)
                        CASE "y"
                            y = VAL(value)
                        CASE "width"
                            w = VAL(value)
                        CASE "height"
                            h = VAL(value)
                        CASE "contentid"
                            contentid = VAL(value)
                        CASE "layert"
                            layertype$ = value
                    END SELECT
                LOOP UNTIL i = UBOUND(attributes)
                createLayer layname$, x, y, w, h, layertype$, contentid, file$
            CASE "vectorPoint"
                i = 1: DO: i = i + 1
                    parseAttributeValue attributes(i), attribute, value
                    SELECT CASE attribute
                        CASE "x"
                            x = VAL(value)
                        CASE "y"
                            y = VAL(value)
                        CASE "handlex"
                            handlex = VAL(value)
                        CASE "handley"
                            handley = VAL(value)
                        CASE "contentid"
                            contentid = VAL(value)
                    END SELECT
                LOOP UNTIL i = UBOUND(attributes)
                createPoint x, y, handlex, handley, contentid
        END SELECT
    END IF
END SUB

SUB parseAttributeValue (source AS STRING, attribute AS STRING, value AS STRING)
    attribute = MID$(source, 1, INSTR(source, "=") - 1)
    'value = MID$(source, INSTR(source, "=") + 1, INSTR(source, ";") - INSTR(source, "=") - 1)
    value = MID$(source, INSTR(source, "=") + 1, LEN(source))
END SUB

SUB createAttributearray (source AS STRING, targetArray() AS STRING)
    REDIM buffer AS STRING
    buffer = source
    DO: p = p + 1
        IF MID$(buffer, p, 1) = ";" THEN
            addstrarray targetArray(), MID$(buffer, 1, p - 1)
            buffer = MID$(buffer, p + 1, LEN(buffer))
            p = 0
        ELSEIF p = LEN(buffer) THEN
            addstrarray targetArray(), buffer
        END IF
    LOOP UNTIL LEN(buffer) = 0 OR p >= LEN(buffer)
END SUB

SUB addstrarray (array() AS STRING, content AS STRING)
    REDIM _PRESERVE array(UBOUND(array) + 1) AS STRING
    array(UBOUND(array)) = content
END SUB

SUB newFile (filePath AS STRING, fileName AS STRING, width AS INTEGER, height AS INTEGER, activeLayer AS INTEGER, xOff AS DOUBLE, yOff AS DOUBLE, zoom AS DOUBLE)
    REDIM _PRESERVE file AS fileInfo
    REDIM _PRESERVE layerInfo(0) AS layerInfo

    file.file = filePath
    file.name = fileName
    file.w = width
    file.h = height
    file.activeLayer = activeLayer
    file.xOffset = xOff
    file.yOffset = yOff
    file.zoom = zoom

    createLayer "test layer", 0, 0, _WIDTH, _HEIGHT, "vector", UBOUND(vectorPoints, 1) + 1, ""
    activeLayer = 1
END SUB

SUB openFile (sourceFile AS STRING)
    IF sourceFile = "" THEN
        newFile _CWD$ + "/untitled.vfi", "untitled", 1000, 1000, 1, 0, 0, 1
    END IF
    format$ = MID$(sourceFile, _INSTRREV(sourceFile, "."), LEN(sourceFile))
    SELECT CASE format$
        CASE ".vfi"
            loadVFI sourceFile
        CASE ".png"
        CASE ".jpeg"
    END SELECT
    currentview = "main"
END SUB

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

SUB createLayer (layname AS STRING, x AS DOUBLE, y AS DOUBLE, w AS INTEGER, h AS INTEGER, layerType AS STRING, contentid AS INTEGER, sourcefile AS STRING)
    REDIM _PRESERVE layerInfo(UBOUND(layerInfo) + 1) AS layerInfo
    layerId = UBOUND(layerInfo)
    layerInfo(layerId).name = layname
    layerInfo(layerId).x = x
    layerInfo(layerId).y = y
    layerInfo(layerId).w = w
    layerInfo(layerId).h = h
    layerInfo(layerId).type = layerType
    layerInfo(layerId).contentid = contentid
    file.activeLayer = layerId
    SELECT CASE layerType
        CASE "vector"
            REDIM _PRESERVE vectorPoints(UBOUND(vectorPoints, 1) + 1, UBOUND(vectorPoints, 2)) AS vectorPoint
            REDIM _PRESERVE vectorPreview(UBOUND(vectorPreview) + 1) AS vectorPreview
        CASE "image"
            REDIM _PRESERVE imageLayer(UBOUND(imageLayer) + 1) AS imageLayer
            imageLayer(UBOUND(imageLayer)).file = sourcefile
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
    'PRINT UBOUND(vectorPoints); " points", UBOUND(layerinfo); " layers"
    'PRINT roundsSinceEdit; " rounds since edit"
    'PRINT _KEYDOWN(100306), mouse.x, mouse.y, mouse.left, mouse.right, mouse.middle, mouse.middlerelease, mouse.lefttimedif
END SUB

FUNCTION getRow (row AS _INTEGER64)
    getRow = 10 + (_FONTHEIGHT * row)
END FUNCTION

FUNCTION getColumn (column AS _INTEGER64)
    getColumn = 10 + (_FONTWIDTH * column)
END FUNCTION

SUB displayLayers (coord AS rectangle)
    IF UBOUND(layerInfo) < 1 THEN EXIT SUB
    layer = 0: DO: layer = layer + 1
        IF layer = file.activeLayer THEN layerIsActive = -1 ELSE layerIsActive = 0
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
        createPoint mouse.x, mouse.y, mouse.x, mouse.y, contentid
        roundsSinceEdit = 0
    END IF
END SUB

SUB createPoint (x AS INTEGER, y AS INTEGER, handlex AS INTEGER, handley AS INTEGER, contentid AS INTEGER)
    maxPoints = getMaxPoints(contentid) + 1
    IF UBOUND(vectorPoints, 1) < contentid THEN
        REDIM _PRESERVE vectorPoints(contentid, UBOUND(vectorPoints)) AS vectorPoint
    END IF
    IF UBOUND(vectorPoints, 2) < maxPoints THEN
        REDIM _PRESERVE vectorPoints(UBOUND(vectorPoints, 1), maxPoints) AS vectorPoint
    END IF
    vectorPoints(contentid, maxPoints).x = x
    vectorPoints(contentid, maxPoints).y = y
    vectorPoints(contentid, maxPoints).handlex = handlex
    vectorPoints(contentid, maxPoints).handley = handley
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

'$INCLUDE: 'dependencies/opensave.bm'
'$INCLUDE: 'dependencies/um.bm'
'$INCLUDE: 'dependencies/um_dependent.bm'
