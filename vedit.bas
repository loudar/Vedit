DO UNTIL _SCREENEXISTS: LOOP
CLS: CLOSE
_ACCEPTFILEDROP ON
$RESIZE:ON
'$CHECKING:OFF
' /\ might perfomance-boost the program
REM $DYNAMIC
$EXEICON:'..\TargonIndustries\Vedit\internal\ico\Vedit_4.ico'

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
    AS STRING name, file, activeTool
    AS _BYTE showgrid, snapgrid
END TYPE
REDIM SHARED file AS fileInfo

'UI
'$INCLUDE: 'dependencies/um.bi'
'$INCLUDE: 'dependencies/gif.bi'
'$INCLUDE: 'dependencies/opensave.bi'
'$INCLUDE: 'dependencies/saveimage.bi'
REDIM SHARED layerListElements(0) AS element

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
    AS _INTEGER64 layerID, effectID
    AS _BYTE isEnabled
    AS LONG resultImg
    AS DOUBLE value1, value2, value3, value4
END TYPE
REDIM SHARED imageEffects(0) AS imageEffects
TYPE currentImage
    AS INTEGER xOff, yOff, ID, corner
    AS rectangle coord
END TYPE
REDIM SHARED currentImage AS currentImage
resetCurrentImage

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

' Grid layer
TYPE grid
    AS _BYTE isGenerated
    AS LONG img
    AS _INTEGER64 atW, atH
END TYPE
REDIM SHARED grid AS grid

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

    'DEBUG
    'lastFrameTime = TIMER - frameStart
    'displayFrameTimes lastFrameTime

    _DISPLAY
LOOP UNTIL mainexit = -1 OR restart = -1
IF restart = -1 THEN GOTO start

SUB adjustZoom (coord AS rectangle)
    REDIM mcoord AS rectangle
    mcoord.x = mouse.x
    mcoord.y = mouse.y
    IF inBounds(mcoord, coord) THEN
        IF mouse.scroll < 0 THEN
            IF file.zoom < 1000 THEN
                IF altDown THEN
                    file.xOffset = file.xOffset - (((file.w * file.zoom) - ((mouse.x - coord.x) - (file.xOffset - (file.w * file.zoom)))) * (-0.1))
                    file.yOffset = file.yOffset - (((file.h * file.zoom) - ((mouse.y - coord.y) - (file.yOffset - (file.h * file.zoom)))) * (-0.1))
                    file.zoom = file.zoom * 1.1
                ELSEIF ctrlDown THEN
                    file.zoom = file.zoom * 1.1
                END IF
            END IF
            IF shiftDown THEN
                file.xOffset = file.xOffset + (file.zoom * file.w * 0.05 * (1 / file.zoom))
            ELSE
                IF NOT altDown AND NOT ctrlDown THEN
                    file.yOffset = file.yOffset + (file.zoom * file.h * 0.05 * (1 / file.zoom))
                END IF
            END IF
        ELSEIF mouse.scroll > 0 THEN
            IF file.zoom > 0.001 THEN
                IF altDown THEN
                    file.xOffset = file.xOffset + (((file.w * file.zoom) - ((mouse.x - coord.x) - (file.xOffset - (file.w * file.zoom)))) * (-0.1))
                    file.yOffset = file.yOffset + (((file.h * file.zoom) - ((mouse.y - coord.y) - (file.yOffset - (file.h * file.zoom)))) * (-0.1))
                    file.zoom = file.zoom / 11 * 10
                ELSEIF ctrlDown THEN
                    file.zoom = file.zoom / 11 * 10
                END IF
            END IF
            IF shiftDown THEN
                file.xOffset = file.xOffset - (file.zoom * file.w * 0.05 * (1 / file.zoom))
            ELSE
                IF NOT altDown AND NOT ctrlDown THEN
                    file.yOffset = file.yOffset - (file.zoom * file.h * 0.05 * (1 / file.zoom))
                END IF
            END IF
        END IF
    END IF
END SUB

SUB saveFileDialog
    filter$ = "VFI (*.vfi)|*.vfi|BMP (*.bmp)|*.bmp|GIF (*.gif)|*.gif|JPG (*.jpg)|*.jpg|PNG (*.png)|*.png" + CHR$(0)
    flags& = OFN_OVERWRITEPROMPT + OFN_NOCHANGEDIR + SAVE_DIALOG '   add flag constants here
    targetfile$ = ComDlgFileName("Vedit - Save File", ".\", filter$, 3, flags&)
    saveFile targetfile$
    CLS
    PRINT "Saving file..."
    _DISPLAY
    invoke.ignoremouse = 0
END SUB

SUB openFileDialog
    filter$ = "Vedit Files (*.vfi)|*.vfi|Image Files (*.BMP;*.JPG;*.GIF;*.PNG)|*.BMP;*.JPG;*.GIF;*.PNG" + CHR$(0)
    flags& = OFN_FILEMUSTEXIST + OFN_NOCHANGEDIR + OFN_READONLY '    add flag constants here
    sourcefile$ = ComDlgFileName("Vedit - Open File", ".\", filter$, 1, flags&)
    CLS
    PRINT "Loading file..."
    _DISPLAY
    openFile sourcefile$
    invoke.ignoremouse = 0
END SUB

SUB saveFile (targetFile AS STRING)
    format$ = MID$(targetFile, _INSTRREV(targetFile, "."), LEN(targetFile))
    REDIM img AS LONG
    SELECT CASE LCASE$(format$)
        CASE ".vfi"
            writeVFI targetFile
        CASE ".bmp"
            makeExportIMG file.w, file.h, img
            success = SaveImage(targetFile, img, 0, 0, _WIDTH(img) - 1, _HEIGHT(img) - 1)
            _FREEIMAGE img
        CASE ".gif"
            makeExportIMG file.w, file.h, img
            success = SaveImage(targetFile, img, 0, 0, _WIDTH(img) - 1, _HEIGHT(img) - 1)
            _FREEIMAGE img
        CASE ".jpg"
            makeExportIMG file.w, file.h, img
            success = SaveImage(targetFile, img, 0, 0, _WIDTH(img) - 1, _HEIGHT(img) - 1)
            _FREEIMAGE img
        CASE ".png"
            makeExportIMG file.w, file.h, img
            success = SaveImage(targetFile, img, 0, 0, _WIDTH(img) - 1, _HEIGHT(img) - 1)
            _FREEIMAGE img
    END SELECT
END SUB

SUB writeVFI (targetFile AS STRING)
    file.file = targetFile
    freen = FREEFILE
    'OPEN targetFile FOR OUTPUT AS #freen
    OPEN targetFile FOR BINARY AS #freen
    info$ = "type=fileInfo;width=" + LST$(file.w) + ";height=" + LST$(file.h) + ";zoom=" + LST$(file.zoom) + ";xOffset=" + LST$(file.xOffset) + ";yOffset=" + LST$(file.yOffset) + ";activeLayer=" + LST$(file.activeLayer) + ";activeTool=" + file.activeTool + ";name=" + file.name + ";file=" + targetFile + ";showgrid=" + LST$(file.showgrid) + CHR$(13)
    'PRINT #freen, info$
    PUT #freen, , info$
    IF UBOUND(layerInfo) > 0 THEN
        i = 0: DO: i = i + 1
            IF layerInfo(i).type = "image" THEN
                info$ = "type=layerInfo;layert=image;width=" + LST$(layerInfo(i).w) + ";height=" + LST$(layerInfo(i).h) + ";x=" + LST$(layerInfo(i).x) + ";y=" + LST$(layerInfo(i).y) + ";name=" + layerInfo(i).name + ";contentid=" + LST$(layerInfo(i).contentid) + CHR$(13)
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
                LOOP UNTIL p = UBOUND(vectorPoints, 2) OR p = maxPoints
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
    REDIM _PRESERVE layerInfo(0) AS layerInfo
    REDIM _PRESERVE imageLayer(0) AS imageLayer
    REDIM _PRESERVE vectorPoints(0, 0) AS vectorPoint
    REDIM _PRESERVE vectorPreview(0) AS vectorPreview
    REDIM position AS _INTEGER64
    file.activeTool = "move"

    COLOR _RGBA(255, 255, 255, 255), _RGBA(0, 0, 0, 255)
    _PRINTSTRING (getColumn(10), getRow(1)), "Opening file " + sourceFile + "...": _DISPLAY
    freen = FREEFILE
    OPEN sourceFile FOR INPUT AS #freen
    IF EOF(freen) = 0 THEN
        DO
            LINE INPUT #freen, lineinfo$
            position = SEEK(freen)
            parseFileInfo lineinfo$, sourceFile, position
            SEEK freen, position
        LOOP UNTIL EOF(freen)
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
                        CASE "activeTool"
                            file.activeTool = value
                        CASE "name"
                            file.name = value
                        CASE "file"
                            file.file = value
                        CASE "showgrid"
                            file.showgrid = VAL(value)
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
    REDIM _PRESERVE imageLayer(0) AS imageLayer
    REDIM _PRESERVE imageEffects(0) AS imageEffects
    REDIM _PRESERVE vectorPoints(0, 0) AS vectorPoint
    REDIM _PRESERVE vectorPreview(0) AS vectorPreview

    file.file = filePath
    file.name = fileName
    file.w = w
    file.h = h
    file.activeLayer = activeLayer
    file.activeTool = "move"
    file.xOffset = xOff
    file.yOffset = yOff
    file.zoom = zoom

    activeLayer = 1
END SUB

SUB openFile (sourceFile AS STRING)
    IF sourceFile = "" THEN
        newFile _CWD$ + "\untitled.vfi", "untitled", 1000, 1000, 1, 0, 0, 1
    END IF
    format$ = MID$(sourceFile, _INSTRREV(sourceFile, "."), LEN(sourceFile))
    SELECT CASE format$
        CASE ".vfi"
            loadVFI sourceFile
        CASE ".png"
            namestart = _INSTRREV(sourceFile, "\")
            nameend = _INSTRREV(sourceFile, ".")
            name$ = MID$(sourceFile, namestart + 1, nameend - namestart - 1)
            bufImg = _LOADIMAGE(sourceFile, 32)
            IF bufImg < -1 THEN
                w = _WIDTH(bufImg)
                h = _HEIGHT(bufImg)
                _FREEIMAGE bufImg
                newFile sourceFile, name$, w, h, 1, 0, 0, 1
                addFileAsLayer sourceFile
            END IF
        CASE ".jpg"
            namestart = _INSTRREV(sourceFile, "\")
            nameend = _INSTRREV(sourceFile, ".")
            name$ = MID$(sourceFile, namestart + 1, nameend - namestart - 1)
            bufImg = _LOADIMAGE(sourceFile, 32)
            IF bufImg < -1 THEN
                w = _WIDTH(bufImg)
                h = _HEIGHT(bufImg)
                _FREEIMAGE bufImg
                newFile sourceFile, name$, w, h, 1, 0, 0, 1
                addFileAsLayer sourceFile
            END IF
        CASE ".bmp"
            namestart = _INSTRREV(sourceFile, "\")
            nameend = _INSTRREV(sourceFile, ".")
            name$ = MID$(sourceFile, namestart + 1, nameend - namestart - 1)
            bufImg = _LOADIMAGE(sourceFile, 32)
            IF bufImg < -1 THEN
                w = _WIDTH(bufImg)
                h = _HEIGHT(bufImg)
                _FREEIMAGE bufImg
                newFile sourceFile, name$, w, h, 1, 0, 0, 1
                addFileAsLayer sourceFile
            END IF
        CASE ".gif" ' add a gif handler, add a different work mode for animations
            namestart = _INSTRREV(sourceFile, "\")
            nameend = _INSTRREV(sourceFile, ".")
            name$ = MID$(sourceFile, namestart + 1, nameend - namestart - 1)
            bufImg = _LOADIMAGE(sourceFile, 32)
            IF bufImg < -1 THEN
                w = _WIDTH(bufImg)
                h = _HEIGHT(bufImg)
                _FREEIMAGE bufImg
                newFile sourceFile, name$, w, h, 1, 0, 0, 1
                addFileAsLayer sourceFile
            END IF
    END SELECT
    currentview = "main"
END SUB

SUB fileDropCheck
    IF _TOTALDROPPEDFILES > 0 THEN
        REDIM img AS LONG
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
                    addFileAsLayer df$
            END SELECT
        LOOP UNTIL _TOTALDROPPEDFILES = 0
        _FINISHDROP
    END IF
END SUB

SUB addFileAsLayer (filename AS STRING)
    extension$ = MID$(filename, LEN(filename) - 3, 4)
    IF extension$ = ".png" OR extension$ = ".jpg" OR extension$ = ".bmp" OR extension$ = ".gif" THEN
        img = _LOADIMAGE(filename, 32)
        ar = _WIDTH(img) / _HEIGHT(img)
        filear = file.w / file.h
        IF ar = filear THEN
            w = file.w
            h = file.h
            x = 0
            y = 0
        ELSEIF ar > filear THEN 'if new layer is wider than artboard
            w = file.w
            h = w / ar
            x = 0
            y = (file.h - h) / 2
        ELSEIF ar < filear THEN 'if new layer is taller than artboard
            h = file.h
            w = h * ar
            x = (file.w - w) / 2
            y = 0
        END IF
        createLayer getFileBaseName$(filename), x, y, w, h, "image", UBOUND(imageLayer) + 1, filename
        _FREEIMAGE img
    END IF
END SUB

FUNCTION getFileBaseName$ (filename AS STRING)
    p = 0: DO: p = p + 1
    LOOP UNTIL p = LEN(filename) OR MID$(filename, LEN(filename) + 1 - p, 1) = "\"
    n = LEN(filename) - p + 2
    nl = LEN(filename) - n - 3
    getFileBaseName$ = MID$(filename, n, nl)
END FUNCTION

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
            REDIM bufferVectorPoints(UBOUND(vectorPoints, 1), UBOUND(vectorPoints, 2)) AS vectorPoint
            copyVectorPoints bufferVectorPoints()
            REDIM _PRESERVE vectorPoints(UBOUND(vectorPoints, 1) + 1, UBOUND(vectorPoints, 2)) AS vectorPoint
            pasteVectorPoints bufferVectorPoints()
            ERASE bufferVectorPoints
            REDIM _PRESERVE vectorPreview(UBOUND(vectorPreview) + 1) AS vectorPreview
        CASE "image"
            IF contentid > UBOUND(imageLayer) THEN REDIM _PRESERVE imageLayer(contentid) AS imageLayer
            ID = contentid
            imageLayer(ID).file = sourceFile
            IF sourceFile <> "" THEN
                imageLayer(ID).img = _LOADIMAGE(sourceFile, 32)
            ELSE
                imageLayer(ID).img = _NEWIMAGE(w, h, 32)
            END IF
            imageLayer(ID).w = w
            imageLayer(ID).h = h
            'ProcessRGBImage imageLayer(ID).img, 1, 0, 0, 1
        CASE "text"
            ' create a UM element, then check for moving in displayLayers
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
            LINE (i + (_FONTWIDTH * 2), 160)-(i + (_FONTWIDTH * 2), 160 - ((frameTimes(i) / maxFrameTime) * 50)), _RGBA(255, 255, 255, 50)
        END IF
    LOOP UNTIL i = UBOUND(frameTimes)
    COLOR _RGBA(255, 255, 255, 255), _RGBA(0, 0, 0, 255)
    _PRINTSTRING (getColumn(8), getRow(0) + 100), LTRIM$(STR$(maxFrameTime)) + " frame time / " + LTRIM$(STR$(1 / (avgsum / counted))) + " FPS"
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

SUB makeExportIMG (w AS _INTEGER64, h AS _INTEGER64, IMG AS LONG)
    fileXbuffer = file.xOffset
    fileYbuffer = file.yOffset
    file.xOffset = 0
    file.yOffset = 0
    IMG = _NEWIMAGE(w, h, 32)
    _DEST IMG
    REDIM coord AS rectangle
    coord.w = w
    coord.h = h
    'LINE (file.xOffset, file.yOffset)-(file.xOffset + (file.w * file.zoom), file.yOffset + (file.h * file.zoom)), _RGBA(150, 150, 150, 255), BF
    IF UBOUND(layerInfo) > 0 THEN
        layer = 0: DO: layer = layer + 1
            SELECT CASE layerInfo(layer).type
                CASE "vector"
                    IF layerInfo(layer).enabled THEN displayLines layerInfo(layer), layerIsActive, coord, IMG, -1
                CASE "image"
                    IF layerInfo(layer).enabled THEN displayImageLayer layerInfo(layer), layerIsActive, layer, coord, -1
                CASE "text"
            END SELECT
        LOOP UNTIL layer >= UBOUND(layerInfo)
    END IF
    _DEST 0
    file.xOffset = fileXbuffer
    file.yOffset = fileYbuffer
END SUB

SUB displayLayers (coord AS rectangle)
    IF roundsSinceEdit < 1000 THEN roundsSinceEdit = roundsSinceEdit + 1
    REDIM canvasImg AS LONG
    canvasImg = _NEWIMAGE(coord.w, coord.h, 32)
    _DEST canvasImg
    displayFileBG
    IF UBOUND(layerInfo) > 0 THEN
        IF file.activeLayer > UBOUND(layerInfo) THEN file.activeLayer = UBOUND(layerInfo)
        layer = 0: DO: layer = layer + 1
            IF layer = file.activeLayer THEN layerIsActive = -1 ELSE layerIsActive = 0
            IF layerIsActive AND keyhit = 21248 THEN
                deleteLayer layer
            ELSE
                SELECT CASE layerInfo(layer).type
                    CASE "vector"
                        IF layerInfo(layer).enabled THEN
                            displayLines layerInfo(layer), layerIsActive, coord, canvasImg, 0
                            IF layerIsActive AND file.activeTool = "move" THEN
                                displayPoints layerInfo(layer), coord
                            END IF
                        END IF
                    CASE "image"
                        IF layerInfo(layer).enabled THEN displayImageLayer layerInfo(layer), layerIsActive, layer, coord, 0
                    CASE "text"
                        IF layerInfo(layer).enabled THEN displayTextLayer layerInfo(layer), layerIsActive, layer, coord
                END SELECT
            END IF
        LOOP UNTIL layer >= UBOUND(layerInfo)
    END IF
    IF file.showgrid THEN displayGrid canvasImg
    REDIM borCol AS LONG
    IF _TRIM$(global.fileBackground) = "grey60" OR _TRIM$(global.fileBackground) = "grey80" OR _TRIM$(global.fileBackground) = "white" THEN
        borCol = _RGBA(20, 20, 20, 255)
    ELSE
        borCol = _RGBA(255, 255, 255, 255)
    END IF
    LINE (file.xOffset, file.yOffset)-(file.xOffset + (file.w * file.zoom), file.yOffset + (file.h * file.zoom)), borCol, B
    _DEST 0
    _PUTIMAGE (coord.x, coord.y)-(coord.x + coord.w, coord.y + coord.h), canvasImg, 0
    _FREEIMAGE canvasImg
END SUB

SUB displayFileBG
    REDIM AS LONG bgCol
    SELECT CASE _TRIM$(global.fileBackground)
        CASE "black"
            bgCol = _RGBA(0, 0, 0, 255)
        CASE "grey20"
            bgCol = _RGBA(51, 51, 51, 255)
        CASE "grey40"
            bgCol = _RGBA(102, 102, 102, 255)
        CASE "grey60"
            bgCol = _RGBA(153, 153, 153, 255)
        CASE "grey80"
            bgCol = _RGBA(204, 204, 204, 255)
        CASE "white"
            bgCol = _RGBA(255, 255, 255, 255)
        CASE ELSE
            bgCol = _RGBA(150, 150, 150, 255)
    END SELECT
    LINE (file.xOffset, file.yOffset)-(file.xOffset + (file.w * file.zoom), file.yOffset + (file.h * file.zoom)), bgCol, BF
    IF _TRIM$(global.fileBackground) = "checkerboard" THEN
        LINE (file.xOffset, file.yOffset)-(file.xOffset + (file.w * file.zoom), file.yOffset + (file.h * file.zoom)), _RGBA(240, 240, 240, 255), BF
        gridsize = 10 * file.zoom
        IF file.w * file.zoom > gridsize THEN
            xpos = -(gridsize * 2): DO: xpos = xpos + (gridsize * 2)
                ypos = -(gridsize * 2): DO: ypos = ypos + (gridsize * 2)
                    LINE (file.xOffset + xpos, file.yOffset + ypos)-(file.xOffset + xpos + gridsize, file.yOffset + ypos + gridsize), _RGBA(204, 204, 204, 255), BF
                LOOP UNTIL ypos + (2 * gridsize) + 1 >= (file.h * file.zoom)
            LOOP UNTIL xpos + (2 * gridsize) + 1 >= (file.w * file.zoom)

            xpos = -gridsize: DO: xpos = xpos + (gridsize * 2)
                ypos = -gridsize: DO: ypos = ypos + (gridsize * 2)
                    LINE (file.xOffset + xpos, file.yOffset + ypos)-(file.xOffset + xpos + gridsize, file.yOffset + ypos + gridsize), _RGBA(204, 204, 204, 255), BF
                LOOP UNTIL ypos + (2 * gridsize) >= (file.h * file.zoom)
            LOOP UNTIL xpos + (2 * gridsize) >= (file.w * file.zoom)
        END IF
    END IF
END SUB

SUB displayGrid (canvas AS LONG)
    IF grid.isGenerated = 0 OR grid.atW <> file.w * file.zoom OR grid.atH <> file.h * file.zoom THEN
        ' set when grid was generated
        grid.atW = file.w * file.zoom
        grid.atH = file.h * file.zoom
        IF grid.img < -1 THEN _FREEIMAGE grid.img
        grid.img = _NEWIMAGE(grid.atW, grid.atH, 32)

        _DEST grid.img
        IF _TRIM$(global.fileBackground) = "grey60" OR _TRIM$(global.fileBackground) = "grey80" OR _TRIM$(global.fileBackground) = "white" THEN
            gridCol = _RGBA(0, 0, 0, 80)
            gridCol2 = _RGBA(0, 0, 0, 150)
        ELSE
            gridCol = _RGBA(255, 255, 255, 80)
            gridCol2 = _RGBA(255, 255, 255, 150)
        END IF

        gridsize = 10 * file.zoom
        IF file.w * file.zoom > gridsize THEN
            xpos = 0: DO: xpos = xpos + gridsize
                LINE (xpos, 0)-(xpos, (file.h * file.zoom)), gridCol
            LOOP UNTIL xpos + gridsize >= file.w * file.zoom
        END IF
        IF file.h * file.zoom > gridsize THEN
            ypos = 0: DO: ypos = ypos + gridsize
                LINE (0, ypos)-((file.w * file.zoom), ypos), gridCol
            LOOP UNTIL ypos + gridsize >= file.h * file.zoom
        END IF
        gridsize = 10 * gridsize
        IF file.w * file.zoom > gridsize THEN
            xpos = 0: DO: xpos = xpos + gridsize
                LINE (xpos, 0)-(xpos, (file.h * file.zoom)), gridCol2
            LOOP UNTIL xpos + gridsize >= file.w * file.zoom
        END IF
        IF file.h * file.zoom > gridsize THEN
            ypos = 0: DO: ypos = ypos + gridsize
                LINE (0, ypos)-((file.w * file.zoom), ypos), gridCol2
            LOOP UNTIL ypos + gridsize >= file.h * file.zoom
        END IF
    END IF
    _DEST canvas
    _PUTIMAGE (file.xOffset, file.yOffset), grid.img, canvas
END SUB

SUB deleteLayer (layerID AS INTEGER)
    IF layerID > UBOUND(layerInfo) THEN EXIT SUB
    IF UBOUND(layerInfo) = 0 THEN EXIT SUB
    SELECT CASE layerInfo(layerID).type
        CASE "vector"
            deleteVectorLayer layerInfo(layerID).contentid
        CASE "image"
            deleteImageLayer layerInfo(layerID).contentid
        CASE "text"
            deleteTextLayer layerInfo(layerID).contentid
    END SELECT
    IF layerID < UBOUND(layerInfo) THEN
        i = layerID - 1: DO: i = i + 1
            SWAP layerInfo(i), layerInfo(i + 1)
        LOOP UNTIL i = UBOUND(layerInfo) - 1
    END IF
    REDIM _PRESERVE layerInfo(UBOUND(layerInfo) - 1) AS layerInfo
    IF file.activeLayer > UBOUND(layerInfo) THEN file.activeLayer = UBOUND(layerInfo)
END SUB

SUB deleteVectorLayer (contentID AS INTEGER)
    IF contentID > UBOUND(vectorPoints, 1) OR contentID > UBOUND(vectorPreview, 1) THEN EXIT SUB
    IF UBOUND(vectorPoints, 1) = 0 OR UBOUND(vectorPreview, 1) = 0 THEN EXIT SUB
    IF UBOUND(vectorPoints, 2) = 0 THEN EXIT SUB
    vectorPreview(contentID) = vectorPreview(0)
    i = contentID - 1: DO: i = i + 1
        vectorPoints(contentID, i) = vectorPoints(0, 0)
    LOOP UNTIL i = UBOUND(vectsorPoints, 2)
END SUB

SUB deleteImageLayer (contentID AS INTEGER)
    IF contentID > UBOUND(imageLayer) THEN EXIT SUB
    IF UBOUND(imageLayer) = 0 THEN EXIT SUB
    imageLayer(contentID) = imageLayer(0)
END SUB

SUB deleteTextLayer (contentID AS INTEGER)

END SUB

SUB displayTextLayer (layer AS layerInfo, layerIsActive AS _BYTE, layerID AS INTEGER, canvas AS rectangle)

END SUB

SUB displayImageLayer (layer AS layerInfo, layerIsActive AS _BYTE, layerID AS INTEGER, canvas AS rectangle, forExport AS _BYTE)
    contentid = layer.contentid
    REDIM layerCoord AS rectangle
    IF forExport THEN
        layerCoord.x = layer.x
        layerCoord.y = layer.y
        layerCoord.w = layer.w
        layerCoord.h = layer.h
    ELSE
        layerCoord.x = (layer.x * file.zoom) + file.xOffset
        layerCoord.y = (layer.y * file.zoom) + file.yOffset
        layerCoord.w = (layer.w * file.zoom)
        layerCoord.h = (layer.h * file.zoom)
    END IF
    IF imageLayer(contentid).img < -1 AND layer.w > 0 AND layer.h > 0 THEN
        layerEffectID = layerHasEffects(layerID)
        IF layerEffectID > 0 THEN
            _PUTIMAGE (layerCoord.x, layerCoord.y)-(layerCoord.x + layerCoord.w, layerCoord.y + layerCoord.h), imageEffects(layerEffectID).resultImg
        ELSE
            _PUTIMAGE (layerCoord.x, layerCoord.y)-(layerCoord.x + layerCoord.w, layerCoord.y + layerCoord.h), imageLayer(contentid).img
        END IF
    END IF
    IF layerIsActive THEN
        displayLayerOutline layerCoord, layer, layerIsActive, layerID, canvas
    END IF
END SUB

FUNCTION layerHasEffects (layerID AS _INTEGER64)
    IF UBOUND(imageEffects) < 1 THEN EXIT FUNCTION
    i = 0: DO: i = i + 1
        IF imageEffects(i).layerID = layerID THEN buffer = i
    LOOP UNTIL i = UBOUND(imageEffects)
    layerHasEffects = buffer
END FUNCTION

SUB displayLayerOutline (coord AS rectangle, layer AS layerInfo, layerIsActive AS _BYTE, layerID AS INTEGER, canvas AS rectangle)
    LINE (coord.x, coord.y)-(coord.x + coord.w, coord.y + coord.h), _RGBA(72, 144, 255, 255), B
    handleSize = 7
    coordCorr = INT((handleSize - 1) / 2)

    IF file.activeTool = "move" THEN
        ' corner 1
        LINE (coord.x - coordCorr, coord.y - coordCorr)-(coord.x + coordCorr, coord.y + coordCorr), _RGBA(72, 144, 255, 255), BF
        IF NOT mouse.left THEN IF currentImage.corner = 1 THEN resetCurrentImage
        IF inRadius(coord.x, coord.y, mouse.x - canvas.x, mouse.y - canvas.y, handleSize * 2) THEN
            IF global.altCursors THEN
                _MOUSEHIDE
                drawShape "shape=resize1;x=" + LST$(mouse.x - canvas.x) + ";y=" + LST$(mouse.y - canvas.y), col&("ui")
            ELSE
                _MOUSESHOW "TOPLEFT_BOTTOMRIGHT"
            END IF
            blockCursor = -1
        ELSE
            IF global.altCursors THEN _MOUSESHOW "DEFAULT"
        END IF
        IF (inRadius(coord.x, coord.y, mouse.x - canvas.x, mouse.y - canvas.y, handleSize * 2) AND mouse.left AND currentImage.corner < 2) OR (currentImage.ID = layerID AND currentImage.corner = 1) THEN
            moveLayerCorner layer, 1, layerID, canvas
            blockMove = -1
        END IF

        ' corner 2
        LINE (coord.x + coord.w - coordCorr, coord.y - coordCorr)-(coord.x + coord.w + coordCorr, coord.y + coordCorr), _RGBA(72, 144, 255, 255), BF
        IF inRadius(coord.x + coord.w, coord.y, mouse.x - canvas.x, mouse.y - canvas.y, handleSize * 2) THEN
            IF global.altCursors THEN
                _MOUSEHIDE
                drawShape "shape=resize2;x=" + LST$(mouse.x - canvas.x) + ";y=" + LST$(mouse.y - canvas.y), col&("ui")
            ELSE
                _MOUSESHOW "TOPRIGHT_BOTTOMLEFT"
            END IF
            blockCursor = -1
        ELSE
            IF global.altCursors THEN _MOUSESHOW "DEFAULT"
        END IF
        IF NOT mouse.left THEN IF NOT blockMove AND currentImage.corner = 2 THEN resetCurrentImage
        IF (inRadius(coord.x + coord.w, coord.y, mouse.x - canvas.x, mouse.y - canvas.y, handleSize * 2) AND mouse.left AND (currentImage.corner = 2 OR currentImage.corner < 1)) OR (currentImage.ID = layerID AND currentImage.corner = 2) AND NOT blockMove THEN
            moveLayerCorner layer, 2, layerID, canvas
            blockMove = -1
        END IF

        ' corner 3
        LINE (coord.x - coordCorr, coord.y + coord.h - coordCorr)-(coord.x + coordCorr, coord.y + coord.h + coordCorr), _RGBA(72, 144, 255, 255), BF
        IF inRadius(coord.x, coord.y + coord.h, mouse.x - canvas.x, mouse.y - canvas.y, handleSize * 2) THEN
            IF global.altCursors THEN
                _MOUSEHIDE
                drawShape "shape=resize2;x=" + LST$(mouse.x - canvas.x) + ";y=" + LST$(mouse.y - canvas.y), col&("ui")
            ELSE
                _MOUSESHOW "TOPRIGHT_BOTTOMLEFT"
            END IF
            blockCursor = -1
        ELSE
            IF global.altCursors THEN _MOUSESHOW "DEFAULT"
        END IF
        IF NOT mouse.left THEN IF NOT blockMove AND currentImage.corner = 3 THEN resetCurrentImage
        IF (inRadius(coord.x, coord.y + coord.h, mouse.x - canvas.x, mouse.y - canvas.y, handleSize * 2) AND mouse.left AND (currentImage.corner = 3 OR currentImage.corner < 1)) OR (currentImage.ID = layerID AND currentImage.corner = 3) AND NOT blockMove THEN
            moveLayerCorner layer, 3, layerID, canvas
            blockMove = -1
        END IF

        ' corner 4
        LINE (coord.x + coord.w - coordCorr, coord.y + coord.h - coordCorr)-(coord.x + coord.w + coordCorr, coord.y + coord.h + coordCorr), _RGBA(72, 144, 255, 255), BF
        IF inRadius(coord.x + coord.w, coord.y + coord.h, mouse.x - canvas.x, mouse.y - canvas.y, handleSize * 2) THEN
            IF global.altCursors THEN
                _MOUSEHIDE
                drawShape "shape=resize1;x=" + LST$(mouse.x - canvas.x) + ";y=" + LST$(mouse.y - canvas.y), col&("ui")
            ELSE
                _MOUSESHOW "TOPLEFT_BOTTOMRIGHT"
            END IF
            blockCursor = -1
        ELSE
            IF global.altCursors THEN _MOUSESHOW "DEFAULT"
        END IF
        IF NOT mouse.left THEN IF NOT blockMove AND currentImage.corner = 4 THEN resetCurrentImage
        IF (inRadius(coord.x + coord.w, coord.y + coord.h, mouse.x - canvas.x, mouse.y - canvas.y, handleSize * 2) AND mouse.left AND (currentImage.corner = 4 OR currentImage.corner < 1)) OR (currentImage.ID = layerID AND currentImage.corner = 4) AND NOT blockMove THEN
            moveLayerCorner layer, 4, layerID, canvas
            blockMove = -1
        END IF

        ' moving image
        IF NOT mouse.left THEN IF NOT blockMove AND currentImage.corner = 5 THEN resetCurrentImage
        REDIM AS rectangle mcoord, mcoord2
        mcoord.x = mouse.x
        mcoord.y = mouse.y
        mcoord2.x = mouse.x - canvas.x
        mcoord2.y = mouse.y - canvas.y
        IF inBounds(mcoord, canvas) AND inBounds(mcoord2, coord) THEN glutSetCursor GLUT_CURSOR_CYCLE ELSE IF NOT blockCursor THEN _MOUSESHOW "DEFAULT"
        IF layerIsActive AND (inBounds(mcoord, coord) AND mouse.left) OR (mouse.left AND (currentImage.corner = 5)) AND NOT blockMove THEN
            moveLayerCorner layer, 5, layerID, canvas
        END IF
    END IF

    ' painting on image
    IF file.activeTool = "paint" THEN
        IF mouse.left THEN
            REDIM AS LONG canvasRef
            canvasRef = _DEST
            _DEST imageLayer(layer.contentid).img
            size = 5
            mX = INT((mouse.x - canvas.x - file.xOffset - (layer.x * file.zoom)) * (1 / file.zoom) * (_WIDTH(imageLayer(layer.contentid).img) / layer.w))
            mY = INT((mouse.y - canvas.y - file.yOffset - (layer.y * file.zoom)) * (1 / file.zoom) * (_HEIGHT(imageLayer(layer.contentid).img) / layer.h))
            CIRCLE (mX, mY), size, _RGBA(255, 255, 255, 255)
            PAINT (mX, mY), _RGBA(255, 255, 255, 255), _RGBA(255, 255, 255, 255)
            _DEST canvasRef
        END IF
    END IF
END SUB

FUNCTION clickCondition (conditionName AS STRING, x AS DOUBLE, y AS DOUBLE, coord AS rectangle, canvas AS rectangle)
    REDIM mcoord AS rectangle
    mcoord.x = mouse.x - canvas.x
    mcoord.y = mouse.y - canvas.y
    IF inBounds(mcoord, coord) THEN
        SELECT CASE conditionName
            CASE "deletePoint"
                IF mouse.middle AND inRadius(x, y, mouse.x - coord.x, mouse.y - coord.y, 20) AND mouse.middletimedif > .01 THEN
                    clickCondition = -1
                ELSEIF ctrlDown AND mouse.left AND inRadius(x, y, mouse.x - coord.x, mouse.y - coord.y, 20) AND mouse.lefttimedif > .01 THEN
                    clickCondition = -1
                ELSE clickCondition = 0
                END IF
            CASE "movePoint"
                IF mouse.left AND inRadius(x, y, mouse.x - coord.x, mouse.y - coord.y, 20) THEN clickCondition = -1 ELSE clickCondition = 0
            CASE "createPoint"
                IF mouse.middle AND mouse.middletimedif > .01 THEN
                    clickCondition = -1
                ELSEIF ctrlDown AND mouse.left AND mouse.lefttimedif > .01 THEN
                    clickCondition = -1
                ELSE clickCondition = 0
                END IF
            CASE "moveHandle"
                IF mouse.right AND inRadius(x, y, mouse.x - coord.x, mouse.y - coord.y, 20) THEN clickCondition = -1 ELSE clickCondition = 0
            CASE "moveImage"
                IF mouse.left THEN clickCondition = -1 ELSE clickCondition = 0
        END SELECT
    ELSE
        clickCondition = 0
    END IF
END FUNCTION

SUB resetCurrentImage
    currentImage.xOff = -1
    currentImage.yOff = -1
    currentImage.coord.x = -1
    currentImage.coord.y = -1
    currentImage.coord.w = -1
    currentImage.coord.h = -1
    currentImage.ID = -1
    currentImage.corner = -1
    _MOUSESHOW "DEFAULT"
END SUB

SUB moveLayerCorner (layer AS layerInfo, corner AS _BYTE, layerID AS INTEGER, canvas AS rectangle)
    IF currentImage.xOff = -1 AND currentImage.yOff = -1 THEN
        currentImage.xOff = INT(mouse.x - (file.xOffset + (layer.x * file.zoom) + canvas.x)) ' offset to image 0-coordinate
        currentImage.yOff = INT(mouse.y - (file.yOffset + (layer.y * file.zoom) + canvas.y))
        currentImage.coord.x = layer.x
        currentImage.coord.y = layer.y
        currentImage.coord.w = layer.w
        currentImage.coord.h = layer.h
        currentImage.ID = layerID
        currentImage.corner = corner
    END IF
    gridsize = 10
    mXcorr = (currentImage.xOff + file.xOffset + canvas.x)
    mXcorrected = INT((mouse.x - mXcorr) * (1 / file.zoom))
    IF file.snapgrid THEN mXcorrected = mXcorrected - (mXcorrected MOD gridsize)
    mYcorr = (currentImage.yOff + file.yOffset + canvas.y)
    mYcorrected = INT((mouse.y - mYcorr) * (1 / file.zoom))
    IF file.snapgrid THEN mYcorrected = mYcorrected - (mYcorrected MOD gridsize)
    mWcorr = (file.xOffset + canvas.x + (layer.x * file.zoom))
    mWcorrected = INT((mouse.x - mWcorr) * (1 / file.zoom))
    IF file.snapgrid THEN mWcorrected = mWcorrected - (mWcorrected MOD gridsize)
    mHcorr = (file.yOffset + canvas.y + (layer.y * file.zoom))
    mHcorrected = INT((mouse.y - mHcorr) * (1 / file.zoom))
    IF file.snapgrid THEN mHcorrected = mHcorrected - (mHcorrected MOD gridsize)
    wDif = mWcorr - (layer.w * file.zoom)
    hDif = mHcoor - (layer.h * file.zoom)
    SELECT CASE corner
        CASE 1
            IF shiftDown THEN
                IF ABS(wDif) >= ABS(hDif) THEN
                    layer.x = mXcorrected
                    layer.w = INT(layer.w - (layer.x - currentImage.coord.x))
                    layer.h = INT(layer.w * (currentImage.coord.h / currentImage.coord.w))
                    layer.y = INT(layer.y + currentImage.coord.h - layer.h)
                ELSE
                    layer.y = mYcorrected
                    layer.h = INT(layer.h - (layer.y - currentImage.coord.y))
                    layer.w = INT(layer.h * (currentImage.coord.w / currentImage.coord.h))
                    layer.x = INT(layer.x + currentImage.coord.w - layer.w)
                END IF
            ELSE
                layer.x = mXcorrected
                layer.y = mYcorrected
                layer.w = INT(layer.w - (layer.x - currentImage.coord.x))
                layer.h = INT(layer.h - (layer.y - currentImage.coord.y))
            END IF
        CASE 2
            IF shiftDown THEN
                IF ABS(wDif) >= ABS(hDif) THEN
                    layer.w = mWcorrected
                    layer.h = INT(layer.w * (currentImage.coord.h / currentImage.coord.w))
                    layer.y = INT(layer.y + currentImage.coord.h - layer.h)
                ELSE
                    layer.y = mYcorrected
                    layer.h = INT(layer.h - (layer.y - currentImage.coord.y))
                    layer.w = INT(layer.h * (currentImage.coord.w / currentImage.coord.h))
                END IF
            ELSE
                layer.y = mYcorrected
                layer.h = INT(layer.h - (layer.y - currentImage.coord.y))
                layer.w = mWcorrected
            END IF
        CASE 3
            IF shiftDown THEN
                IF ABS(wDif) >= ABS(hDif) THEN
                    layer.x = mXcorrected
                    layer.w = INT(layer.w - (layer.x - currentImage.coord.x))
                    layer.h = INT(layer.w * (currentImage.coord.h / currentImage.coord.w))
                ELSE
                    layer.h = mHcorrected
                    layer.w = INT(layer.h * (currentImage.coord.w / currentImage.coord.h))
                    layer.x = INT(layer.x + currentImage.coord.w - layer.w)
                END IF
            ELSE
                layer.x = mXcorrected
                layer.w = INT(layer.w - (layer.x - currentImage.coord.x))
                layer.h = mHcorrected
            END IF
        CASE 4
            IF shiftDown THEN
                IF ABS(wDif) >= ABS(hDif) THEN
                    layer.w = mWcorrected
                    layer.h = INT(layer.w * (currentImage.coord.h / currentImage.coord.w))
                ELSE
                    layer.h = mHcorrected
                    layer.w = INT(layer.h * (currentImage.coord.w / currentImage.coord.h))
                END IF
            ELSE
                layer.w = mWcorrected
                layer.h = mHcorrected
            END IF
        CASE 5
            layer.x = mXcorrected
            layer.y = mYcorrected
    END SELECT
    IF layer.w < 1 OR layer.h < 1 THEN
        layer.x = currentImage.coord.x
        layer.y = currentImage.coord.y
        layer.w = currentImage.coord.w
        layer.h = currentImage.coord.h
    END IF
    IF corner < 5 THEN
        ' update coordinates
        currentImage.xOff = INT(mouse.x - (file.xOffset + (layer.x * file.zoom) + canvas.x)) ' offset to image 0-coordinate
        currentImage.yOff = INT(mouse.y - (file.yOffset + (layer.y * file.zoom) + canvas.y))
        currentImage.coord.x = layer.x
        currentImage.coord.y = layer.y
        currentImage.coord.w = layer.w
        currentImage.coord.h = layer.h
    END IF
END SUB

FUNCTION effect_RectangleToPolar& (Image AS LONG)
    IF R < 0 OR R > 1 OR G < 0 OR G > 1 OR B < 0 OR B > 1 OR _PIXELSIZE(Image) <> 4 THEN EXIT FUNCTION
    DIM Buffer AS _MEM: Buffer = _MEMIMAGE(Image) 'Get a memory reference to our image

    maxx = _WIDTH(Image)
    maxy = _HEIGHT(Image)
    mx = maxx / 2
    my = maxy / 2

    DIM O AS _OFFSET, O_Last AS _OFFSET
    O = Buffer.OFFSET 'We start at this offset
    O_Last = Buffer.OFFSET + maxx * maxy * 4 'We stop when we get to this offset
    DIM imgPoints(maxy, maxx, 0 TO 3) AS _UNSIGNED _BYTE
    DIM p, maxp AS _UNSIGNED _INTEGER64
    maxp = maxx * maxy
    'use on error free code ONLY!
    $CHECKING:OFF
    DO
        p = p + 1
        y = FIX((p / maxp) * maxy)
        x = p - (FIX((p / maxp) * maxy) * maxx)
        imgPoints(y, x, 0) = _MEMGET(Buffer, O, _UNSIGNED _BYTE)
        imgPoints(y, x, 1) = _MEMGET(Buffer, O + 1, _UNSIGNED _BYTE)
        imgPoints(y, x, 2) = _MEMGET(Buffer, O + 2, _UNSIGNED _BYTE)
        imgPoints(y, x, 3) = _MEMGET(Buffer, O + 3, _UNSIGNED _BYTE)
        O = O + 4
    LOOP UNTIL O = O_Last
    'create new image
    DIM newImg AS LONG
    newImg = _NEWIMAGE(maxx, maxy, 32)
    prevDest& = _DEST
    _DEST newImg
    COLOR _RGBA(0, 0, 0, 255), _RGBA(0, 0, 0, 0)
    CLS
    scaley = (maxx / 2 / _PI)
    dPi = 2 * _PI
    IF scaley > maxy THEN scaley = maxy / 2
    pixel = 0
    progresscolor = col&("ui")
    y = -1: DO: y = y + 1
        yfactor = ((y / (maxy))) * scaley
        x = -1: DO: x = x + 1
            xfactor = dPi * (1 - (x / maxx))
            PSET (mx + (yfactor * SIN(xfactor)), my - (yfactor * COS(xfactor))), _RGBA(imgPoints(y, x, 2), imgPoints(y, x, 1), imgPoints(y, x, 0), imgPoints(y, x, 3))
            pixel = pixel + 1
            IF pixel MOD 1000 = 0 THEN
                _DEST 0
                LINE (_WIDTH(0) * ((pixel - 1000) / maxp), 0)-(_WIDTH(0) * (pixel / maxp), 3), progresscolor, BF
                _DISPLAY
                _DEST newImg
            END IF
        LOOP UNTIL x = maxx
    LOOP UNTIL y = maxy
    ERASE imgPoints
    DIM imgPoints(0, 0, 0) AS _UNSIGNED _BYTE
    _DEST prevDest&
    'turn checking back on when done!
    $CHECKING:ON
    _MEMFREE Buffer
    effect_RectangleToPolar& = newImg
END FUNCTION

SUB effect_ProcessRGBImage (Image AS LONG, R AS SINGLE, G AS SINGLE, B AS SINGLE, A AS SINGLE)
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

FUNCTION effect_BoxBlur& (Image AS LONG, Radius AS _INTEGER64)
    REDIM AS LONG newImg, progresscolor
    REDIM AS _OFFSET yO, xyO
    newImg = _COPYIMAGE(Image, 32)
    smallestSide = min(_WIDTH(newImg), _HEIGHT(newImg))
    IF Radius > smallestSide THEN Radius = smallestSide
    IF Radius < 1 THEN Radius = 1
    Diameter = INT(Radius * 2) + 1
    IF _PIXELSIZE(newImg) <> 4 THEN EXIT FUNCTION
    DIM Buffer AS _MEM: Buffer = _MEMIMAGE(Image) 'Get a memory reference to our image
    DIM Buffer2 AS _MEM: Buffer2 = _MEMIMAGE(newImg) 'Get a memory reference to our new image
    DIM AS _OFFSET O, O2, O_Last
    O = Buffer.OFFSET 'We start at this offset
    O_Last = Buffer.OFFSET + _WIDTH(newImg) * _HEIGHT(newImg) * 4 'We stop when we get to this offset
    O2 = Buffer2.OFFSET
    maxx = _WIDTH(newImg)
    maxy = _HEIGHT(newImg)
    divider = Diameter * Diameter
    pixelcount = maxx * maxy
    progresscolor = col&("ui")

    'use on error free code ONLY!
    $CHECKING:OFF
    _DEST 0
    pixel = 0
    DO
        pixel = pixel + 1
        y = _CEIL(pixel / maxx)
        x = pixel - ((y - 1) * maxx)
        IF x < Radius + 1 OR y < Radius + 1 OR x + Radius > maxx OR y + Radius > maxy THEN
        ELSE
            sumR = 0: sumG = 0: sumB = 0: sumA = 0
            yi = -1: DO: yi = yi + 1
                xi = -1: DO: xi = xi + 1
                    yO = O - (4 * maxx * Radius) + (4 * maxx * yi)
                    xyO = yO - (4 * Radius) + (4 * xi)
                    sumA = sumA + _MEMGET(Buffer, xyO + 3, _UNSIGNED _BYTE)
                    sumR = sumR + _MEMGET(Buffer, xyO + 2, _UNSIGNED _BYTE)
                    sumG = sumG + _MEMGET(Buffer, xyO + 1, _UNSIGNED _BYTE)
                    sumB = sumB + _MEMGET(Buffer, xyO, _UNSIGNED _BYTE)
                LOOP UNTIL xi = Diameter - 1
            LOOP UNTIL yi = Diameter - 1
            _MEMPUT Buffer2, O2, INT(sumB / divider) AS _UNSIGNED _BYTE
            _MEMPUT Buffer2, O2 + 1, INT(sumG / divider) AS _UNSIGNED _BYTE
            _MEMPUT Buffer2, O2 + 2, INT(sumR / divider) AS _UNSIGNED _BYTE
            _MEMPUT Buffer2, O2 + 3, INT(sumA / divider) AS _UNSIGNED _BYTE
        END IF
        IF pixel MOD 1000 = 0 THEN
            LINE (_WIDTH(0) * ((pixel - 1000) / pixelcount), 0)-(_WIDTH(0) * (pixel / pixelcount), 3), progresscolor, BF
            _DISPLAY
        END IF
        O = O + 4
        O2 = O2 + 4
    LOOP UNTIL O = O_Last
    'turn checking back on when done!
    $CHECKING:ON
    _MEMFREE Buffer
    _MEMFREE Buffer2
    effect_BoxBlur& = newImg
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

SUB displayList (coord AS rectangle, content AS STRING, this AS element)
    REDIM AS rectangle lcoord, mcoord
    mcoord.x = mouse.x
    mcoord.y = mouse.y
    mcoord.w = 0
    mcoord.h = 0
    margin = global.margin
    lineheight = INT(_FONTHEIGHT * 1.6)
    COLOR col&("ui"), col&("t")
    SELECT CASE content
        CASE "layers"
            IF UBOUND(layerInfo) > 0 THEN
                IF this.state = 0 THEN
                    countRelation = (INT((coord.h - (3 * margin)) / lineheight) / UBOUND(layerInfo))
                    lastChild = findLastChild(this.name)
                    IF lastChild > 0 THEN yOffset = VAL(getEYPos$(lastChild, _FONT)) + VAL(getEHeight$(lastChild, _FONT)) - VAL(getEYPos$(getElementID(this.name), _FONT))
                    IF countRelation < 1 THEN
                        IF mouse.scroll AND inBounds(mcoord, coord) THEN
                            this.scroll = this.scroll + (mouse.scroll * lineheight)
                        END IF
                        IF this.scroll < 0 THEN this.scroll = 0
                        IF this.scroll > lineheight * (UBOUND(layerInfo) - 1) THEN this.scroll = lineheight * (UBOUND(layerInfo) - 1)
                        relation = this.scroll / (lineheight * (UBOUND(layerInfo) - 1))
                        scrollH = countRelation * (coord.h - (3 * margin))
                        scrollY = coord.y + ((coord.h - (3 * margin) - scrollH) * relation) + (1.5 * margin)
                        scrollW = 2
                        scrollX = coord.x + coord.w - 1 - scrollW
                        LINE (scrollX, scrollY)-(scrollX + scrollW, scrollY + scrollH), _RGBA(150, 150, 150, 150), BF
                    END IF
                    DO: i = i + 1
                        lcoord.x = coord.x + margin
                        lcoord.y = coord.y + (1.5 * margin) + (lineheight * (i - 1)) - this.scroll + yOffset
                        lcoord.w = coord.w - (margin * 3)
                        lcoord.h = lineheight
                        IF lcoord.y + lcoord.h < coord.y + coord.h AND lcoord.y > coord.y + yOffset THEN
                            drawLayerListElement i, lcoord
                        END IF
                    LOOP UNTIL i = UBOUND(layerInfo)
                ELSEIF this.state = -1 THEN

                END IF
            END IF
    END SELECT
END SUB

SUB createLayerListElement (text AS STRING, index, state)
    IF index > UBOUND(layerListElements) THEN
        REDIM _PRESERVE layerListElements(index) AS element
    END IF
    elements(index).action = "layer.rename"
    elements(index).buffer = ""
    elements(index).color = "ui"
    elements(index).content = ""
    elements(index).name = text
    elements(index).x = "margin"
    elements(index).y = "prevb"
    elements(index).w = "full"
    elements(index).h = "flex"
    elements(index).hovercolor = "ui2"
    elements(index).style = "bf"
    elements(index).hovertext = text
    elements(index).hovertextwait = getArgumentv(uielement$, "hovertextwait")
    elements(index).padding = getArgument$(uielement$, "padding")
    elements(index).url = getArgument$(uielement$, "url")
    elements(index).switchword = getArgument$(uielement$, "switchword")
    elements(index).group = getArgument$(uielement$, "group")
    elements(index).font = getArgument$(uielement$, "font")
    elements(index).scroll = getArgumentv(uielement$, "scroll")
    elements(index).state = getArgumentv(uielement$, "state")
    elements(index).text = text
    elements(index).type = "layerListElement"
    elements(index).options = getArgument$(uielement$, "options")
    elements(index).parent = getArgument$(uielement$, "parent")
END SUB

SUB drawLayerListElement (i, coord AS rectangle)
    REDIM text AS STRING
    REDIM AS rectangle viscoord, mcoord
    mcoord.x = mouse.x
    mcoord.y = mouse.y
    mcoord.w = 0
    mcoord.h = 0
    text = layerInfo(i).name
    viswidth = _FONTHEIGHT
    margin = global.margin
    IF LEN(text) * _FONTWIDTH >= coord.w - viswidth - global.margin THEN
        cutlength = INT((coord.w - viswidth - global.margin) / _FONTWIDTH)
        text = MID$(text, 1, cutlength - 3) + "..."
    END IF

    IF i = file.activeLayer THEN
        rectangle "x=" + LST$(coord.x) + ";y=" + LST$(coord.y - (global.margin / 2)) + ";w=" + LST$(coord.w + global.margin) + ";h=" + LST$(_FONTHEIGHT + global.margin) + ";style=bf;angle=0;round=" + LST$(global.round), col&("bg2")
    END IF

    viscoord.x = coord.x + (coord.w - viswidth)
    viscoord.y = coord.y
    viscoord.w = viswidth
    viscoord.h = _FONTHEIGHT
    IF layerInfo(i).enabled THEN
        rectangle "x=" + LST$(viscoord.x) + ";y=" + LST$(viscoord.y) + ";w=" + LST$(viscoord.w) + ";h=" + LST$(viscoord.h) + ";style=bf;angle=0;round=" + LST$(global.round), col&("ui")
        checkmargin = 2
        drawShape "x=" + LST$(viscoord.x + checkmargin) + ";y=" + LST$(viscoord.y + checkmargin) + ";w=" + LST$(viscoord.w - (checkmargin * 3)) + ";h=" + LST$(viscoord.h - (checkmargin * 2)) + ";shape=check;thickness=2", col&("bg1")
    ELSE
        rectangle "x=" + LST$(viscoord.x) + ";y=" + LST$(viscoord.y) + ";w=" + LST$(viscoord.w) + ";h=" + LST$(viscoord.h) + ";style=bf;angle=0;round=" + LST$(global.round), col&("ui")
    END IF
    _PRINTSTRING (coord.x + margin, coord.y + 2), text

    IF inBounds(mcoord, viscoord) AND mouse.left AND mouse.lefttimedif > .1 THEN
        IF layerInfo(i).enabled = 0 THEN layerInfo(i).enabled = -1 ELSE layerInfo(i).enabled = 0
    ELSEIF inBounds(mcoord, coord) AND mouse.left THEN
        'LINE (coord.x, coord.y)-(coord.x + coord.w, coord.y + coord.h), _RGBA(255, 0, 0, 255), B
        file.activeLayer = i
    END IF
END SUB

SUB doThis (arguments AS STRING, recursivecall AS _BYTE) 'program-specific actions
    IF global.actionlock AND NOT recursivecall THEN
        EXIT SUB
    ELSE
        IF mouse.left THEN global.actionlock = -1
    END IF
    REDIM AS STRING license, url, success, newview
    action$ = getArgument$(arguments, "action")
    license = getArgument$(arguments, "license")
    transmittedtext = getArgument$(arguments, "transmit")
    url = getArgument$(arguments, "url")
    SELECT CASE action$
        CASE "save.file"
            saveFileDialog
        CASE "new.file"
            openFile ""
        CASE "open.file"
            openFileDialog
        CASE "add.vector"
            createLayer "Untitled", 0, 0, file.w, file.h, "vector", UBOUND(vectorPoints, 1) + 1, ""
        CASE "add.image"
            createLayer "Untitled", 0, 0, file.w, file.h, "image", UBOUND(imageLayer) + 1, ""
        CASE "add.license"
            IF set(license) THEN
                success = add.License$("license=" + license)
                doThis "action=view.main;transmit=" + success, -1
            ELSE
                doThis "action=view.add.license", -1
            END IF
        CASE "resize.file"
            w = getArgumentv(arguments, "w")
            h = getArgumentv(arguments, "h")
            wF = w / file.w
            hF = h / file.h
            file.w = w
            file.h = h
            DO: index = index + 1
                layerInfo(index).x = layerInfo(index).x * wF
                layerInfo(index).y = layerInfo(index).y * hF
                layerInfo(index).w = layerInfo(index).w * wF
                layerInfo(index).h = layerInfo(index).h * hF
            LOOP UNTIL index = UBOUND(layerInfo)
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
        CASE "effect"
            createEffect file.activeLayer, MID$(action$, INSTR(action$, ".") + 1, LEN(action$))
        CASE "subview"
            newview = MID$(action$, INSTR(action$, ".") + 1, LEN(action$))
            subview = newview
            resetExpansions
        CASE "view"
            newview = MID$(action$, INSTR(action$, ".") + 1, LEN(action$))
            IF newview = "previous" THEN
                SWAP currentview, previousview
            ELSE
                previousview = currentview
                currentview = newview
            END IF
            resetExpansions
        CASE "tool"
            file.activeTool = MID$(action$, INSTR(action$, ".") + 1, LEN(action$))
    END SELECT
END SUB

FUNCTION getLastLayerImage& (layerID)
    layerEffectID = layerHasEffects(layerID)
    IF layerEffectID > 0 THEN
        getLastLayerImage& = imageEffects(layerEffectID).resultImg
    ELSE
        SELECT CASE _TRIM$(layerInfo(layerID).type)
            CASE "image"
                getLastLayerImage& = imageLayer(layerInfo(layerID).contentid).img
            CASE "vector"
                getLastLayerImage& = vectorPreview(layerInfo(layerID).contentid).image
            CASE "text"
                'getLayerImage& = imageLayer(layerInfo(layerID).contentid).img
        END SELECT
    END IF
END FUNCTION

SUB createEffect (layerID, effectName AS STRING)
    REDIM AS LONG resultIMG
    SELECT CASE effectName
        CASE "toPolar"
            resultIMG = effect_RectangleToPolar&(getLastLayerImage&(layerID))
            addEffect layerID, 1, -1, resultIMG, 0, 0, 0, 0
        CASE "desaturate"
            resultIMG = effect_Saturation&(getLastLayerImage&(layerID), 0.8)
            addEffect layerID, 1, -1, resultIMG, 0.8, 0, 0, 0
        CASE "contrast"
            resultIMG = effect_Contrast&(getLastLayerImage&(layerID), 0.2)
            addEffect layerID, 1, -1, resultIMG, 0.2, 0, 0, 0
        CASE "boxBlur"
            resultIMG = effect_BoxBlur&(getLastLayerImage&(layerID), 8)
            addEffect layerID, 1, -1, resultIMG, 8, 0, 0, 0
    END SELECT
END SUB

SUB addEffect (layerID, effectID AS _INTEGER64, isEnabled AS _BYTE, resultImg AS LONG, value1, value2, value3, value4)
    REDIM _PRESERVE imageEffects(UBOUND(imageEffects) + 1) AS imageEffects
    efID = UBOUND(imageEffects)
    imageEffects(efID).layerID = layerID
    imageEffects(efID).effectID = effectID
    imageEffects(efID).isEnabled = isEnabled
    imageEffects(efID).resultImg = resultImg
    imageEffects(efID).value1 = value1
    imageEffects(efID).value2 = value2
    imageEffects(efID).value2 = value3
    imageEffects(efID).value4 = value4
END SUB

SUB resetExpansions
    IF UBOUND(elements) > 0 THEN
        DO: e = e + 1
            IF elements(e).expand THEN
                elements(e).expand = 0
            END IF
        LOOP UNTIL e = UBOUND(elements)
    END IF
    expanded = 0
END SUB

'--------------------------------------------------------------------------------------------------------------------------------------'

'$INCLUDE: 'dependencies/effects.bm'
'$INCLUDE: 'dependencies/VEvector.bm'
'$INCLUDE: 'dependencies/gif.bm'
'$INCLUDE: 'dependencies/saveimage.bm'
'$INCLUDE: 'dependencies/opensave.bm'
'$INCLUDE: 'dependencies/um.bm'
'$INCLUDE: 'dependencies/um_dependent.bm'
