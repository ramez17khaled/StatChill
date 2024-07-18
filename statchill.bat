@echo off
setlocal

rem Start the Python GUI script
python GUI.py

rem Read the generated config file
set "config_file=config.txt"

if not exist "%config_file%" (
    echo Config file not found. Exiting.
    exit /b 1
)

rem Read each line in config.txt to set variables
for /F "usebackq tokens=1* delims==" %%i in ("%config_file%") do (
    set "%%i=%%j"
)

rem Call the appropriate script based on the method
if "%method%"=="PLS-Da" (
    python PLS-Da.py "%meta_file_path%" "%file_path%" "%sheet%" "%output_path%" "%column%" "%conditions%"
) else if "%method%"=="Volcano" (
    "C:\Program Files\R\R-4.1.3\bin\Rscript.exe" Volcano.R "%meta_file_path%" "%file_path%" "%sheet%" "%output_path%" "%column%" "%conditions%"
) else if "%method%"=="ANOVA" (
    python ANOVA.py %config_file%
) else if "%method%"=="PCA" (
    "C:\Program Files\R\R-4.1.3\bin\Rscript.exe" PCA.R "%meta_file_path%" "%file_path%" "%sheet%" "%output_path%" "%column%" "%conditions%"
    pause  # Pause the batch file execution to keep the command prompt window open
) else if "%method%"=="batchCorrect" (
    "C:\Program Files\R\R-4.1.3\bin\Rscript.exe" batchCorrecting.R "%meta_file_path%" "%file_path%" "%sheet%" "%output_path%" "%column%" "%conditions%" "%label_column%"
    pause  # Pause the batch file execution to keep the command prompt window open
) else if "%method%"=="corrHeatmap" (
    "C:\Program Files\R\R-4.1.3\bin\Rscript.exe" corrHeatmap.R "%meta_file_path%" "%file_path%" "%sheet%" "%output_path%" "%column%" "%conditions%" "%label_column%"
    pause  # Pause the batch file execution to keep the command prompt window open
)

endlocal


