@echo off
:R
setlocal enabledelayedexpansion
for %%a in ("mono=1" "stereo=2" "quad=4" "5.1=6" "7.1=8") do (
    for /f "tokens=1,* delims==" %%b in ("%%~a") do (
        set layout_%%b=%%c
    )
)
::  FFMPEG PATH
set "ffmpeg=%~dp0ffmpeg.exe -hide_banner"
::  REVERB TAIL SUSTION TIME :: MS
set ReverbTail=1000
::  REVERB TAIL SUSTION TIME :: S
set /a RvsSlDura = !ReverbTail!/1000
::  REVERB TAIL FADEOUT TIME
set ReverbFade=0.5
::  IR REVERB DRY\WET FOR INPUT AUDIO FILE
set inputWet=1 & set inputDry=9
::  IR REVERB DRY\WET FOR REVERSED AUDIO FILE
set revesWet=9 & set revesDry=1
::  IR REVERB DRY\WET FOR FINAL MIXDOWN AUDIO FILE
set finalWet=0.5 & set finalDry=0.5
title just for fun£ºadd monster fx 2 audio file

set /p "DELAY=DELAY  - if not defined will set DELAY to -123(ms):"
if not defined DELAY set DELAY=-123
set delayed=!DELAY!
set /a DELAY=!DELAY!+!ReverbTail!
set /p "inputAudio=inputAudio:"
:: set loudness
for /f "delims=" %%a in ('%ffmpeg% -i "!inputAudio!" -filter:a loudnorm^=print_format^=json -f null - 2^>^&1') do (
    for /f "tokens=1,2 delims=,:	 " %%b in ("%%~a") do (
        REM ECHO [%%~b:%%~c]
        if "%%~b"=="input_i" (
            set "I=%%~c"
        ) else if "%%~b"=="input_lra" (
            set "LRA=%%~c"
            if "!LRA!" leq "1" set "LRA=1"
        ) else if "%%~b"=="input_tp" (
            set "TP=%%~c"
        )
    )
)
echo "Integrated Loudness (I):!I!"
echo "Loudness Range (LRA):!LRA!"
echo "True Peak (TP):!TP!"
for /f "tokens=3 delims=," %%a in ('%ffmpeg% -i "!inputAudio!" 2^>^&1 ^| findstr ^/ic^:"Stream #0:0"') do (
    set "layoutName=%%a"
    set "layoutName=!layoutName: =!"
)
call set "chnNum=%%layout_!layoutName!%%"
REM set "chnNum=!layout_%layoutName%!"
if defined chnNum (
    echo chnNum:"!chnNum!"
    if "!chnNum!"=="2" (
        set "IRFile=IR.wav"
    ) else (
        %ffmpeg% -loglevel error -i IR.wav -ac !chnNum! IR_temp.wav
        set "IRFile=IR_temp.wav"
    )
    :: set delay parameter
    set "delayParams="
    set "RevTlParams="
    for /l %%i in (1,1,!chnNum!) do (
        set "delayParams=!delayParams!!DELAY!|"
        set "RevTlParams=!RevTlParams!!ReverbTail!|"
    )
    set "delayParams=!delayParams:~0,-1!"
    %ffmpeg% -loglevel error -i "!inputAudio!" -filter_complex "[0:a]apad=pad_dur=!RvsSlDura!" "!inputAudio:~0,-4!_Input_AddSlDura!inputAudio:~-4!"
    %ffmpeg% -loglevel error -i "!inputAudio:~0,-4!_Input_AddSlDura!inputAudio:~-4!" -i "%~dp0!IRFile!" -filter_complex "[0:a]apad=pad_dur=!RvsSlDura![a0];[a0][1:a]afir=dry=!inputDry!:wet=!inputWet!,loudnorm=I=!I!:LRA=!LRA!:TP=!TP!" "!inputAudio:~0,-4!_Input_AddSlDura_Reverb!inputAudio:~-4!" && del "!inputAudio:~0,-4!_Input_AddSlDura!inputAudio:~-4!"
    %ffmpeg% -loglevel error -i "!inputAudio!" -af "areverse" "!inputAudio:~0,-4!_Reverse!inputAudio:~-4!"
    %ffmpeg% -loglevel error -i "!inputAudio:~0,-4!_Reverse!inputAudio:~-4!" -filter_complex "[0:a]apad=pad_dur=!RvsSlDura!" "!inputAudio:~0,-4!_Reversed!inputAudio:~-4!" && del "!inputAudio:~0,-4!_Reverse!inputAudio:~-4!"
    %ffmpeg% -loglevel error -i "!inputAudio:~0,-4!_Reversed!inputAudio:~-4!" -i "%~dp0!IRFile!" -filter_complex "[0:a]adelay=!RevTlParams![a0];[a0][1:a]afir=dry=!revesDry!:wet=!revesWet!,loudnorm=I=!I!:LRA=!LRA!:TP=!TP!" "!inputAudio:~0,-4!_Reversed_Reverb!inputAudio:~-4!" && del "!inputAudio:~0,-4!_Reversed!inputAudio:~-4!"
    %ffmpeg% -loglevel error -i "!inputAudio:~0,-4!_Reversed_Reverb!inputAudio:~-4!" -af areverse "!inputAudio:~0,-4!_Reversed_Reverb_Reversed!inputAudio:~-4!" && del "!inputAudio:~0,-4!_Reversed_Reverb!inputAudio:~-4!"
    %ffmpeg% -loglevel error -i "!inputAudio:~0,-4!_Reversed_Reverb_Reversed!inputAudio:~-4!" -i "!inputAudio!" -filter_complex "[0:a]volume=!finalWet![a0]; [1:a]adelay=!delayParams!,volume=!finalDry![a1]; [a0][a1]amix=inputs=2:duration=longest,loudnorm=I=!I!:LRA=!LRA!:TP=!TP!" -y "!inputAudio:~0,-4!_FX_!delayed!!inputAudio:~-4!" && del "!inputAudio:~0,-4!_Reversed_Reverb_Reversed!inputAudio:~-4!" & del "!inputAudio:~0,-4!_Input_AddSlDura_Reverb!inputAudio:~-4!"
    del "%~dp0IR_temp.wav" 2>nul
) else (
    echo Unknow Channel Number :%layoutName%-"!inputAudio!"
)
echo.
echo DONE£¡ - output£º"!inputAudio:~0,-4!_FX_!delayed!!inputAudio:~-4!"
echo.
endlocal
goto R