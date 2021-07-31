'#######################################################################################
'# Animated GIF decoder v1.0                                                           #
'# By Zom-B                                                                            #
'#######################################################################################

'DEFINT A-Z

DIM SHARED Dbg: Dbg = 0
DIM SHARED powerOf2&(11)
FOR a = 0 TO 11: powerOf2&(a) = 2 ^ a: NEXT a

TYPE GIFDATA
    file AS INTEGER
    sigver AS STRING * 6
    width AS _UNSIGNED INTEGER
    height AS _UNSIGNED INTEGER
    bpp AS _UNSIGNED _BYTE
    sortFlag AS _BYTE ' Unused
    colorRes AS _UNSIGNED _BYTE
    colorTableFlag AS _BYTE
    bgColor AS _UNSIGNED _BYTE
    aspect AS SINGLE ' Unused
    numColors AS _UNSIGNED INTEGER
    palette AS STRING * 768
END TYPE

TYPE FRAMEDATA
    addr AS LONG
    left AS _UNSIGNED INTEGER
    top AS _UNSIGNED INTEGER
    width AS _UNSIGNED INTEGER
    height AS _UNSIGNED INTEGER
    localColorTableFlag AS _BYTE
    interlacedFlag AS _BYTE
    sortFlag AS _BYTE ' Unused
    palBPP AS _UNSIGNED _BYTE
    minimumCodeSize AS _UNSIGNED _BYTE
    transparentFlag AS _BYTE 'GIF89a-specific (animation) values
    userInput AS _BYTE ' Unused
    disposalMethod AS _UNSIGNED _BYTE
    delay AS SINGLE
    transColor AS _UNSIGNED _BYTE
END TYPE

' Open gif file. This reads the headers and palette but not the image data.
' The array will be redimentioned to fit the exact number of frames in the file.

DIM gifData AS GIFDATA, frameData(0 TO 0) AS FRAMEDATA

'filename$ = "mygif.gif" '<<<<<<<<<<<< Enter a file name here!!!

'IF LEN(filename$) = 0 THEN END
'openGif filename$, gifData, frameData()

'' Loop away.
'frame = 0
'DO
'    ' Request a frame. If it has been requested before, it is re-used,
'    ' otherwise it is read and decoded from the file.
'    _PUTIMAGE (0, 0), getGifFrame&(gifData, frameData(), frame)
'    _DELAY frameData(frame).delay
'    frame = (frame + 1) MOD (UBOUND(framedata) + 1)
'LOOP UNTIL LEN(INKEY$)

''Close the file and free the allocated frames.
'codeGif gifData, frameData()
'END
