@echo off
color 0b

title Compile the Neko HScript Source Code

echo Compiling...

:run_command
lime test neko

choice /c YN /m "Retry?"

if errorlevel 2 (
    exit
) else (
    goto run_command
)
