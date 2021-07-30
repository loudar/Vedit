CLS: CLOSE
_ACCEPTFILEDROP ON
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
    enabled AS _BYTE 'if visible or not
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
'$INCLUDE: 'dependencies/saveimage.bi'

'--------------------------------------------------------------------------------------------------------------------------------------'

' Layer types
' Image layer
TYPE imageLayer
    img AS LONG 'image handle
    file AS STRING * 500 'file location
    name AS STRING * 50
    ar AS _FLOAT 'aspect ratio
    AS _INTEGER64 w, h, t
END TYPE
REDIM SHARED imageLayer(0) AS imageLayer
TYPE imageEffects
    result AS LONG
    contentid AS _INTEGER64
    AS SINGLE brightness, contrast, r, g, b
END TYPE
TYPE currentImage
    AS INTEGER xOff, yOff, ID, corner
    AS rectangle coord
END TYPE
REDIM SHARED currentImage AS currentImage

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
    'OPEN targetFile FOR OUTPUT AS #freen
    OPEN targetFile FOR BINARY AS #freen
    info$ = "type=fileInfo;width=" + LST$(file.w) + ";height=" + LST$(file.h) + ";zoom=" + LST$(file.zoom) + ";xOffset=" + LST$(file.xOffset) + ";yOffset=" + LST$(file.yOffset) + ";activeLayer=" + LST$(file.activeLayer) + ";name=" + file.name + ";file=" + targetFile + CHR$(13)
    'PRINT #freen, info$
    PUT #freen, , info$
    IF UBOUND(layerinfo) > 0 THEN
        i = 0: DO: i = i + 1
            IF layerInfo(i).type = "image" THEN
                info$ = "type=layerInfo;layert=image;width=" + LST$(layerInfo(i).w) + ";height=" + LST$(layerInfo(i).h) + ";x=" + LST$(layerInfo(i).x) + ";y=" + LST$(layerInfo(i).y) + ";name=" + layerInfo(i).name + ";contentid=" + LST$(layerInfo(i).contentid) + ";file=" + _TRIM$(imageLayer(layerInfo(i).contentid).file) + CHR$(13)
                'PRINT #freen, info$
                PUT #freen, , info$
            ELSE
                info$ = "type=layerInfo;layert=vector;width=" + LST$(layerInfo(i).w) + ";height=" + LST$(layerInfo(i).h) + ";x=" + LST$(layerInfo(i).x) + ";y=" + LST$(layerInfo(i).y) + ";name=" + layerInfo(i).name + ";contentid=" + LST$(layerInfo(i).contentid) + CHR$(13)
                'PRINT #freen, info$
                PUT #freen, , info$
            END IF
        LOOP UNTIL i = UBOUND(layerInfo)
    END IF
    IF UBOUND(vectorPoints, 1) > 0 THEN
        i = 0: DO: i = i + 1
            maxPoints = getMaxPoints(i)
            IF maxPoints > 0 THEN
                p = 0: DO: p = p + 1
                    info$ = "type=vectorPoint;contentid=" + LST$(i) + ";x=" + LST$(vectorPoints(i, p).x) + ";y=" + LST$(vectorPoints(i, p).y) + ";handlex=" + LST$(vectorPoints(i, p).handlex) + ";handley=" + LST$(vectorPoints(i, p).handley) + CHR$(13)
                    'PRINT #freen, info$
                    PUT #freen, , info$
                LOOP UNTIL p = UBOUND(vectorpoints, 2) OR p = maxPoints
            END IF
        LOOP UNTIL i = UBOUND(vectorPoints, 1)
    END IF
    IF UBOUND(imageLayer) > 0 THEN
        i = 0: DO: i = i + 1
            DIM AS _MEM m, m2
            m = _MEMIMAGE(imageLayer(i).img)
            raw$ = SPACE$(m.SIZE)
            m2 = _MEM(_OFFSET(raw$), m.SIZE)
            _MEMCOPY m, m.OFFSET, m.SIZE TO m2, m2.OFFSET

            'Compress the data
            compressed$ = _DEFLATE$(raw$) + CHR$(13)

            ' Write info about image
            imageInfo$ = "type=imageData;length=" + LST$(LEN(compressed$) - 1) + ";size=" + LST$(LEN(raw$)) + ";contentid=" + LST$(i) + ";w=" + LST$(_WIDTH(imageLayer(i).img)) + ";h=" + LST$(_HEIGHT(imageLayer(i).img)) + CHR$(13)
            PUT #freen, , imageInfo$

            'Write image data
            PUT #freen, , compressed$
            _MEMFREE m
            _MEMFREE m2
        LOOP UNTIL i = UBOUND(imageLayer)
    END IF
    CLOSE #freen
END SUB

SUB loadVFI (sourceFile AS STRING)
    REDIM _PRESERVE file AS fileInfo
    REDIM _PRESERVE imageLayer(0) AS imageLayer
    REDIM _PRESERVE vectorPoints(0, 0) AS vectorPoint
    REDIM _PRESERVE vectorPreview(0) AS vectorPreview
    REDIM position AS _INTEGER64

    COLOR _RGBA(255, 255, 255, 255), _RGBA(0, 0, 0, 255)
    _PRINTSTRING (getColumn(10), getRow(1)), "Opening file " + sourceFile + "...": _DISPLAY
    freen = FREEFILE
    OPEN sourceFile FOR INPUT AS #freen
    IF EOF(freen) = 0 THEN
        DO
            LINE INPUT #freen, lineinfo$
            position = SEEK(freen)
            parseFileInfo lineinfo$, sourceFile, position
        LOOP UNTIL EOF(freen) = -1
    END IF
    CLOSE #freen
END SUB

SUB parseFileInfo (source AS STRING, sourceFile AS STRING, position AS _INTEGER64)
    REDIM attributes(0) AS STRING
    REDIM AS STRING attribute, value
    createAttributearray source, attributes()
    IF UBOUND(attributes) > 1 THEN
        parseAttributeValue attributes(1), attribute, value
        SELECT CASE value
            CASE "fileInfo"
                _PRINTSTRING (getColumn(10), getRow(3)), "Loading file info...": _DISPLAY
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
                _PRINTSTRING (getColumn(10), getRow(3)), "Loading layer info...": _DISPLAY
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
                _PRINTSTRING (getColumn(10), getRow(3)), "Loading vector data...": _DISPLAY
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
            CASE "imageData"
                _PRINTSTRING (getColumn(10), getRow(3)), "Loading image data...": _DISPLAY
                i = 1: DO: i = i + 1
                    parseAttributeValue attributes(i), attribute, value
                    SELECT CASE attribute
                        CASE "length"
                            length = VAL(value)
                        CASE "w"
                            w = VAL(value)
                        CASE "h"
                            h = VAL(value)
                        CASE "contentid"
                            contentid = VAL(value)
                        CASE "size"
                            size = VAL(value)
                    END SELECT
                LOOP UNTIL i = UBOUND(attributes)
                IF length > 0 AND contentid > 0 AND contentid <= UBOUND(imageLayer) THEN
                    freen = FREEFILE
                    OPEN sourceFile FOR BINARY AS #freen
                    imageDataCompressed$ = SPACE$(length)
                    IF NOT EOF(freen) THEN GET #freen, position, imageDataCompressed$
                    position = SEEK(freen)
                    CLOSE #freen
                    IF imageDataCompressed$ <> SPACE$(length) THEN
                        imageDataRaw$ = _INFLATE$(imageDataCompressed$, size)
                        REDIM AS _MEM m, m2
                        imageLayer(contentid).img = _NEWIMAGE(w, h, 32)
                        imageLayer(contentid).w = w
                        imageLayer(contentid).h = h
                        m = _MEMIMAGE(imageLayer(contentid).img)
                        m2 = _MEM(_OFFSET(imageDataRaw$), m.SIZE)
                        _MEMCOPY m2, m2.OFFSET, m2.SIZE TO m, m.OFFSET
                        _MEMFREE m2
                    END IF
                END IF
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

SUB newFile (filePath AS STRING, fileName AS STRING, w AS INTEGER, h AS INTEGER, activeLayer AS INTEGER, xOff AS DOUBLE, yOff AS DOUBLE, zoom AS DOUBLE)
    'REDIM _PRESERVE file AS fileInfo
    REDIM _PRESERVE layerInfo(0) AS layerInfo

    file.file = filePath
    file.name = fileName
    file.w = w
    file.h = h
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
                    IF MID$(df$, LEN(df$) - 3, 4) = ".png" OR MID$(df$, LEN(df$) - 3, 4) = ".jpg" THEN
                        IF img < 0 THEN _FREEIMAGE img
                        img = _LOADIMAGE(df$, 32)
                        ar = _WIDTH(img) / _HEIGHT(img)
                        filear = file.w / file.h
                        'IF ar = filear THEN
                        '    w = file.w
                        '    h = file.h
                        '    x = 0
                        '    y = 0
                        'ELSEIF ar > filear THEN 'if new layer is wider than artboard
                        '    w = file.w
                        '    h = w / ar
                        '    x = 0
                        '    y = (file.h - _HEIGHT(img)) / 2
                        'ELSEIF ar < filear THEN 'if new layer is taller than artboard
                        '    h = file.h
                        '    w = h * ar
                        '    x = (file.w - _WIDTH(img)) / 2
                        '    y = 0
                        'ELSE
                        w = _WIDTH(img)
                        h = _HEIGHT(img)
                        x = 0
                        y = 0
                        'END IF
                        p = 0: DO: p = p + 1
                        LOOP UNTIL p = LEN(df$) OR MID$(df$, LEN(df$) + 1 - p, 1) = "\"
                        n = LEN(df$) - p + 2
                        nl = LEN(df$) - n - 3
                        createLayer MID$(df$, n, nl), x, y, w, h, "image", UBOUND(imageLayer) + 1, df$
                        _FREEIMAGE img
                    END IF
            END SELECT
        LOOP UNTIL _TOTALDROPPEDFILES = 0
        _FINISHDROP
    END IF
END SUB

SUB createLayer (layname AS STRING, x AS DOUBLE, y AS DOUBLE, w AS INTEGER, h AS INTEGER, layerType AS STRING, contentid AS INTEGER, sourceFile AS STRING)
    REDIM _PRESERVE layerInfo(UBOUND(layerInfo) + 1) AS layerInfo
    layerId = UBOUND(layerInfo)
    layerInfo(layerId).name = layname
    layerInfo(layerId).x = x
    layerInfo(layerId).y = y
    layerInfo(layerId).w = w
    layerInfo(layerId).h = h
    layerInfo(layerId).type = layerType
    layerInfo(layerId).contentid = contentid
    layerInfo(layerId).enabled = -1
    file.activeLayer = layerId
    SELECT CASE layerType
        CASE "vector"
            REDIM _PRESERVE vectorPoints(UBOUND(vectorPoints, 1) + 1, UBOUND(vectorPoints, 2)) AS vectorPoint
            REDIM _PRESERVE vectorPreview(UBOUND(vectorPreview) + 1) AS vectorPreview
        CASE "image"
            IF contentid > UBOUND(imageLayer) THEN REDIM _PRESERVE imageLayer(contentid) AS imageLayer
            ID = contentid
            imageLayer(ID).file = sourceFile
            imageLayer(ID).img = _LOADIMAGE(sourceFile, 32)
            imageLayer(ID).w = w
            imageLayer(ID).h = h
            ProcessRGBImage imageLayer(ID).img, 1, 1, 1, 0.5
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
    'PRINT file.zoom; " zoom"
    'PRINT currentImage.xOff, currentImage.yOff, currentImage.corner
    'PRINT _KEYDOWN(100306), mouse.x, mouse.y, mouse.left, mouse.right, mouse.middle, mouse.middlerelease, mouse.lefttimedif
END SUB

FUNCTION getRow (row AS _INTEGER64)
    getRow = 10 + (_FONTHEIGHT * row)
END FUNCTION

FUNCTION getColumn (column AS _INTEGER64)
    getColumn = 10 + (_FONTWIDTH * column)
END FUNCTION

SUB displayLayers (coord AS rectangle)
    LINE (coord.x, coord.y)-(coord.x + (coord.w * file.zoom), coord.y + (coord.h * file.zoom)), _RGBA(150, 150, 150, 255), BF
    IF UBOUND(layerInfo) < 1 THEN EXIT SUB
    layer = 0: DO: layer = layer + 1
        IF layer = file.activeLayer THEN layerIsActive = -1 ELSE layerIsActive = 0
        SELECT CASE layerInfo(layer).type
            CASE "vector"
                IF layerIsActive AND keyhit = 21248 THEN
                    deleteLayer layer
                ELSE
                    IF layerInfo(layer).enabled THEN
                        displayLines layerInfo(layer), layerIsActive, coord
                        IF layerIsActive THEN
                            displayPoints layerInfo(layer).contentid, coord
                        END IF
                    END IF
                END IF
            CASE "image"
                IF layerIsActive AND keyhit = 21248 THEN
                    deleteLayer layer
                ELSE
                    IF layerInfo(layer).enabled THEN displayImageLayer layerInfo(layer), layerIsActive, coord, layer
                END IF
        END SELECT
    LOOP UNTIL layer >= UBOUND(layerInfo)
END SUB

SUB deleteLayer (layerID AS INTEGER)
    IF layerID > UBOUND(layerInfo) THEN EXIT SUB
    IF UBOUND(layerInfo) = 0 THEN EXIT SUB
    SELECT CASE layerInfo(layerID).type
        CASE "vector"
            deleteVectorLayer layerInfo(layerID).contentid
        CASE "image"
            deleteImageLayer layerInfo(layerID).contentid
    END SELECT
    IF layerID < UBOUND(layerInfo) THEN
        i = layerID - 1: DO: i = i + 1
            SWAP layerInfo(i), layerInfo(i + 1)
        LOOP UNTIL i = UBOUND(layerInfo) - 1
    END IF
    REDIM _PRESERVE layerInfo(UBOUND(layerInfo) - 1) AS layerInfo
END SUB

SUB deleteVectorLayer (contentID AS INTEGER)
    IF contentID > UBOUND(vectorPoints, 1) OR contentID > UBOUND(vectorPreview, 1) THEN EXIT SUB
    IF UBOUND(vectorPoints, 1) = 0 OR UBOUND(vectorPreview, 1) = 0 THEN EXIT SUB
    IF UBOUND(vectorPoints, 2) = 0 THEN EXIT SUB
    vectorPreview(contentID) = vectorPreview(0)
    i = contentID - 1: DO: i = i + 1
        vectorPoints(contentID, i) = vectorPoints(0, 0)
    LOOP UNTIL i = UBOUND(vectorPoints, 2)
END SUB

SUB deleteImageLayer (contentID AS INTEGER)
    IF contentID > UBOUND(imageLayer) THEN EXIT SUB
    IF UBOUND(imageLayer) = 0 THEN EXIT SUB
    imageLayer(contentID) = imageLayer(0)
END SUB

SUB displayImageLayer (layer AS layerInfo, layerIsActive AS _BYTE, coord AS rectangle, layerID AS INTEGER)
    contentid = layer.contentid
    REDIM layerCoord AS rectangle
    layerCoord.x = coord.x + layer.x + file.xOffset
    layerCoord.y = coord.y + layer.y + file.yOffset
    layerCoord.w = layerCoord.x + layer.w * file.zoom
    layerCoord.h = layerCoord.y + layer.h * file.zoom
    IF imageLayer(contentid).img > -2 THEN
        imageLayer(contentid).img = _LOADIMAGE(imageLayer(contentid).file, 32)
        imageLayer(contentid).w = _WIDTH(imageLayer(contentid).img)
        imageLayer(contentid).h = _HEIGHT(imageLayer(contentid).img)
        layer.w = imageLayer(contentid).w
        layer.h = imageLayer(contentid).h
    END IF
    _PUTIMAGE (layerCoord.x, layerCoord.y)-(layerCoord.w, layerCoord.h), imageLayer(contentid).img
    IF layerIsActive THEN
        displayLayerOutline layerCoord, layer, layerIsActive, layerID
    END IF
END SUB

SUB displayLayerOutline (coord AS rectangle, layer AS layerInfo, layerIsActive AS _BYTE, layerID AS INTEGER)
    LINE (coord.x, coord.y)-(coord.w, coord.h), _RGBA(72, 144, 255, 255), B
    handleSize = 5
    coordCorr = INT((handleSize - 1) / 2)
    LINE (coord.x - coordCorr, coord.y - coordCorr)-(coord.x + coordCorr, coord.y + coordCorr), _RGBA(72, 144, 255, 255), BF
    IF NOT mouse.left THEN IF currentImage.corner = 1 THEN resetCurrentImage
    IF (inRadius(coord.x, coord.y, mouse.x, mouse.y, handleSize * 2) AND mouse.left) OR (currentImage.ID = layerID AND currentImage.corner = 1) THEN
        moveLayerCorner layer, 1, layerID
        blockMove = -1
    END IF
    LINE (coord.w - coordCorr, coord.y - coordCorr)-(coord.w + coordCorr, coord.y + coordCorr), _RGBA(72, 144, 255, 255), BF
    IF NOT mouse.left THEN IF NOT blockMove AND currentImage.corner = 2 THEN resetCurrentImage
    IF (inRadius(coord.w, coord.y, mouse.x, mouse.y, handleSize * 2) AND mouse.left) OR (currentImage.ID = layerID AND currentImage.corner = 2) AND NOT blockMove THEN
        moveLayerCorner layer, 2, layerID
        blockMove = -1
    END IF
    LINE (coord.x - coordCorr, coord.h - coordCorr)-(coord.x + coordCorr, coord.h + coordCorr), _RGBA(72, 144, 255, 255), BF
    IF NOT mouse.left THEN IF NOT blockMove AND currentImage.corner = 3 THEN resetCurrentImage
    IF (inRadius(coord.x, coord.h, mouse.x, mouse.y, handleSize * 2) AND mouse.left) OR (currentImage.ID = layerID AND currentImage.corner = 3) AND NOT blockMove THEN
        moveLayerCorner layer, 3, layerID
        blockMove = -1
    END IF
    LINE (coord.w - coordCorr, coord.h - coordCorr)-(coord.w + coordCorr, coord.h + coordCorr), _RGBA(72, 144, 255, 255), BF
    IF NOT mouse.left THEN IF NOT blockMove AND currentImage.corner = 4 THEN resetCurrentImage
    IF (inRadius(coord.w, coord.h, mouse.x, mouse.y, handleSize * 2) AND mouse.left) OR (currentImage.ID = layerID AND currentImage.corner = 4) AND NOT blockMove THEN
        moveLayerCorner layer, 4, layerID
        blockMove = -1
    END IF
    IF (clickCondition("moveImage", 0, 0, coord) AND layerIsActive AND NOT blockMove) OR (currentImage.ID = layerID AND currentImage.corner = 5 AND mouse.left) THEN
        IF currentImage.xOff = -1 AND currentImage.yOff = -1 THEN
            currentImage.xOff = mouse.x - layer.x
            currentImage.yOff = mouse.y - layer.y
            currentImage.corner = 5
            currentImage.ID = layerID
        END IF
        layer.x = mouse.x - currentImage.xOff
        layer.y = mouse.y - currentImage.yOff
    ELSE
        IF NOT blockMove THEN resetCurrentImage
    END IF
END SUB

SUB resetCurrentImage
    currentImage.xOff = -1
    currentImage.yOff = -1
    currentImage.coord.x = -1
    currentImage.coord.y = -1
    currentImage.coord.w = -1
    currentImage.coord.h = -1
    currentImage.ID = -1
    currentImage.corner = -1
END SUB

SUB moveLayerCorner (layer AS layerInfo, corner AS _BYTE, layerID AS INTEGER)
    IF currentImage.xOff = -1 AND currentImage.yOff = -1 THEN
        currentImage.xOff = mouse.x - layer.x
        currentImage.yOff = mouse.y - layer.y
        currentImage.coord.x = layer.x
        currentImage.coord.y = layer.y
        currentImage.coord.w = layer.w
        currentImage.coord.h = layer.h
        currentImage.ID = layerID
        currentImage.corner = corner
    END IF
    xdif = (mouse.x - (currentImage.xOff - layer.w) - layer.x) - layer.w
    ydif = (mouse.y - (currentImage.yOff - layer.h) - layer.y) - layer.h
    SELECT CASE corner
        CASE 1
            layer.x = mouse.x - currentImage.xOff
            layer.y = mouse.y - currentImage.yOff
            layer.w = layer.w - (layer.x - currentImage.coord.x)
            layer.h = layer.h - (layer.y - currentImage.coord.y)
        CASE 2
            layer.y = mouse.y - currentImage.yOff
            layer.w = mouse.x - (currentImage.xOff - layer.w) - layer.x
            layer.h = layer.h - (layer.y - currentImage.coord.y)
        CASE 3
            IF shiftDown THEN
                IF ABS(xdif) >= ABS(ydif) THEN
                    layer.w = mouse.x - (currentImage.xOff - layer.w) - layer.x
                    relation = layer.w / currentImage.coord.w
                    layer.h = layer.h * relation
                ELSE
                    layer.h = mouse.y - (currentImage.yOff - layer.h) - layer.y
                    relation = layer.h / currentImage.coord.h
                    layer.w = layer.w * relation
                END IF
            ELSE
                layer.x = mouse.x - currentImage.xOff
                layer.w = layer.w - (layer.x - currentImage.coord.x)
                layer.h = mouse.y - (currentImage.yOff - layer.h) - layer.y
            END IF
        CASE 4
            IF shiftDown THEN
                IF ABS(xdif) >= ABS(ydif) THEN
                    layer.w = mouse.x - (currentImage.xOff - layer.w) - layer.x
                    relation = layer.w / currentImage.coord.w
                    layer.h = layer.h * relation
                ELSE
                    layer.h = mouse.y - (currentImage.yOff - layer.h) - layer.y
                    relation = layer.h / currentImage.coord.h
                    layer.w = layer.w * relation
                END IF
            ELSE
                layer.w = mouse.x - (currentImage.xOff - layer.w) - layer.x
                layer.h = mouse.y - (currentImage.yOff - layer.h) - layer.y
            END IF
    END SELECT
    ' update coordinates
    currentImage.xOff = mouse.x - layer.x
    currentImage.yOff = mouse.y - layer.y
    currentImage.coord.x = layer.x
    currentImage.coord.y = layer.y
    currentImage.coord.w = layer.w
    currentImage.coord.h = layer.h
END SUB

SUB ProcessRGBImage (Image AS LONG, R AS SINGLE, G AS SINGLE, B AS SINGLE, A AS SINGLE)
    IF R < 0 OR R > 1 OR G < 0 OR G > 1 OR B < 0 OR B > 1 OR _PIXELSIZE(Image) <> 4 THEN EXIT SUB
    DIM Buffer AS _MEM: Buffer = _MEMIMAGE(Image) 'Get a memory reference to our image

    'Used to avoid slow floating point calculations
    DIM AS LONG R_Frac, G_Frac, B_Frac, A_Frac
    R_Frac = R * 65536
    G_Frac = G * 65536
    B_Frac = B * 65536
    A_Frac = A * 65536

    DIM O AS _OFFSET, O_Last AS _OFFSET
    O = Buffer.OFFSET 'We start at this offset
    O_Last = Buffer.OFFSET + _WIDTH(Image) * _HEIGHT(Image) * 4 'We stop when we get to this offset
    'use on error free code ONLY!
    $CHECKING:OFF
    DO
        _MEMPUT Buffer, O, (_MEMGET(Buffer, O, _UNSIGNED _BYTE) * B_Frac) \ 65536 AS _UNSIGNED _BYTE
        _MEMPUT Buffer, O + 1, (_MEMGET(Buffer, O + 1, _UNSIGNED _BYTE) * G_Frac) \ 65536 AS _UNSIGNED _BYTE
        _MEMPUT Buffer, O + 2, (_MEMGET(Buffer, O + 2, _UNSIGNED _BYTE) * R_Frac) \ 65536 AS _UNSIGNED _BYTE
        _MEMPUT Buffer, O + 3, (_MEMGET(Buffer, O + 3, _UNSIGNED _BYTE) * A_Frac) \ 65536 AS _UNSIGNED _BYTE
        O = O + 4
    LOOP UNTIL O = O_Last
    'turn checking back on when done!
    $CHECKING:ON
    _MEMFREE Buffer
END SUB

SUB ContrastImage (Image AS LONG, Contrast AS SINGLE)
    IF Contrast < 0 OR Contrast > 1 OR _PIXELSIZE(Image) <> 4 THEN EXIT SUB
    DIM Buffer AS _MEM: Buffer = _MEMIMAGE(Image) 'Get a memory reference to our image

    'Used to avoid slow floating point calculations
    DIM AS LONG C_Frac
    C_Frac = Contrast ' * 65536

    DIM O AS _OFFSET, O_Last AS _OFFSET
    O = Buffer.OFFSET 'We start at this offset
    O_Last = Buffer.OFFSET + _WIDTH(Image) * _HEIGHT(Image) * 4 'We stop when we get to this offset
    tresh = 123 ' * 65536
    'use on error free code ONLY!
    $CHECKING:OFF
    DO
        B = _MEMGET(Buffer, O, _UNSIGNED _BYTE)
        G = _MEMGET(Buffer, O + 1, _UNSIGNED _BYTE)
        R = _MEMGET(Buffer, O + 2, _UNSIGNED _BYTE)
        'IF B + G + R < tresh * 3 AND NOT B > 200 AND NOT G > 200 AND NOT R > 200 THEN
        IF B + G + R < tresh * 3 THEN
            B = tresh - (B * C_Frac)
            G = tresh - (G * C_Frac)
            R = tresh - (R * C_Frac)
        ELSE
            B = tresh + ((255 - B) * C_Frac)
            G = tresh + ((255 - G) * C_Frac)
            R = tresh + ((255 - R) * C_Frac)
        END IF
        _MEMPUT Buffer, O, INT(B) AS _UNSIGNED _BYTE
        _MEMPUT Buffer, O + 1, INT(G) AS _UNSIGNED _BYTE
        _MEMPUT Buffer, O + 2, INT(R) AS _UNSIGNED _BYTE
        O = O + 4
    LOOP UNTIL O = O_Last
    'turn checking back on when done!
    $CHECKING:ON
    _MEMFREE Buffer
END SUB

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

FUNCTION clickCondition (conditionName AS STRING, x AS DOUBLE, y AS DOUBLE, coord AS rectangle)
    IF mouse.x > coord.x AND mouse.x < coord.x + coord.w AND mouse.y > coord.y AND mouse.y < coord.y + coord.h THEN
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
            CASE "moveImage"
                IF mouse.left THEN clickCondition = -1 ELSE clickCondition = 0
        END SELECT
    ELSE
        clickCondition = 0
    END IF
END FUNCTION

SUB displayList (coord AS rectangle, content AS STRING)
    REDIM text AS STRING
    REDIM AS rectangle mcoord, lcoord, viscoord
    mcoord.x = mouse.x
    mcoord.y = mouse.y
    mcoord.w = 0
    mcoord.h = 0
    margin = global.margin / 2
    lineheight = _FONTHEIGHT * 1.6
    SELECT CASE content
        CASE "layers"
            IF UBOUND(layerInfo) > 0 THEN
                DO: i = i + 1
                    lcoord.x = coord.x
                    lcoord.y = coord.y + margin + (lineheight * (i - 1))
                    lcoord.w = coord.w - (margin * 5)
                    lcoord.h = lineheight
                    text = layerInfo(i).name
                    viswidth = 20
                    IF LEN(text) * _FONTWIDTH >= lcoord.w - viswidth THEN
                        cutlength = INT((lcoord.w - viswidth) / _FONTWIDTH)
                        text = MID$(text, 1, cutlength - 3) + "..."
                    END IF

                    IF i = file.activeLayer THEN
                        rectangle "x=" + LST$(lcoord.x - (global.margin / 2)) + ";y=" + LST$(lcoord.y - (global.margin / 2)) + ";w=" + LST$(lcoord.w + global.margin) + ";h=" + LST$(_FONTHEIGHT + global.margin) + ";style=bf;angle=0;round=" + LST$(global.round), col&("bg2")
                    END IF

                    viscoord.x = lcoord.x - (global.margin / 2) + lcoord.w - viswidth
                    viscoord.y = lcoord.y
                    viscoord.w = viswidth
                    viscoord.h = _FONTHEIGHT
                    IF layerInfo(i).enabled THEN
                        rectangle "x=" + LST$(viscoord.x) + ";y=" + LST$(viscoord.y) + ";w=" + LST$(viscoord.w) + ";h=" + LST$(viscoord.h) + ";style=bf;angle=0;round=" + LST$(global.round), col&("ui")
                    ELSE
                        rectangle "x=" + LST$(viscoord.x) + ";y=" + LST$(viscoord.y) + ";w=" + LST$(viscoord.w) + ";h=" + LST$(viscoord.h) + ";style=b;angle=0;round=" + LST$(global.round), col&("ui")
                    END IF
                    _PRINTSTRING (lcoord.x, lcoord.y), text

                    IF inBounds(mcoord, viscoord) AND mouse.left AND mouse.lefttimedif > .1 THEN
                        IF layerInfo(i).enabled = 0 THEN layerInfo(i).enabled = -1 ELSE layerInfo(i).enabled = 0
                    ELSEIF inBounds(mcoord, lcoord) AND mouse.left THEN
                        'LINE (lcoord.x, lcoord.y)-(lcoord.x + lcoord.w, lcoord.y + lcoord.h), _RGBA(255, 0, 0, 255), B
                        file.activeLayer = i
                    END IF
                LOOP UNTIL i = UBOUND(layerInfo)
            END IF
    END SELECT
END SUB

'--------------------------------------------------------------------------------------------------------------------------------------'

'$INCLUDE: 'dependencies/VEvector.bm'
'$INCLUDE: 'dependencies/saveimage.bm'
'$INCLUDE: 'dependencies/opensave.bm'
'$INCLUDE: 'dependencies/um.bm'
'$INCLUDE: 'dependencies/um_dependent.bm'
