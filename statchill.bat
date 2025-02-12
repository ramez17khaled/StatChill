@echo off
setlocal

set "R_PATH=C:\Program Files\R\R-4.1.3\bin\Rscript.exe"

python GUI.py

set "config_file=config.txt"

if not exist "%config_file%" (
    echo Config file not found. Exiting.
    exit /b 1
)

for /F "usebackq tokens=1* delims==" %%i in ("%config_file%") do (
    set "%%i=%%j"
)

if "%method%"=="PLS-Da" (
    python PLS-Da.py "%meta_file_path%" "%file_path%" "%sheet%" "%output_path%" "%column%" "%conditions%"
) else if "%method%"=="Volcano" (
    "%R_PATH%" Volcano.R "%meta_file_path%" "%file_path%" "%sheet%" "%output_path%" "%column%" "%conditions%"
) else if "%method%"=="sigDiff" (
    python metabo_sigDiff.py "%config_file%"
    python family_sigDiff.py "%config_file%"
) else if "%method%"=="PCA" (
    "%R_PATH%" PCA.R "%meta_file_path%" "%file_path%" "%sheet%" "%output_path%" "%column%" "%conditions%"
    pause
) else if "%method%"=="corrHeatmap" (
    "%R_PATH%" corrHeatmap.R "%meta_file_path%" "%file_path%" "%sheet%" "%output_path%" "%column%" "%conditions%" "%label_column%"
    pause
) else if "%method%"=="repartition" (
    "%R_PATH%" metRepartition.R "%meta_file_path%" "%file_path%" "%sheet%" "%output_path%" "%column%" "%conditions%" "%label_column%"
    "%R_PATH%" sousclassHeatmap.R "%meta_file_path%" "%file_path%" "%sheet%" "%output_path%" "%column%" "%conditions%" "%label_column%"
    pause
) else if "%method%"=="boxplot sum" (
    python boxplot_sum.py "%config_file%"
    python boxplot_sum_lbylipid.py "%config_file%"
    python histogram_sum.py "%config_file%"
    pause
) else if "%method%"=="venn sum" (
    python venn.py "%config_file%"
    pause
) else if "%method%"=="QC boxplot" (
    python boxplot_QCs.py "%config_file%"
    pause
)

endlocal
