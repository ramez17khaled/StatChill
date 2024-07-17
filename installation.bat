@echo off
setlocal

rem Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Python is not installed. Installing Python...
    REM Download and install Python from the official website or an appropriate source
    REM Example for downloading Python from the official website
    REM Modify this path as per your requirement
    start /wait "" https://www.python.org/ftp/python/3.9.5/python-3.9.5-amd64.exe /quiet InstallAllUsers=1 PrependPath=1
) else (
    echo Python is already installed.
)

rem Check if Python was successfully installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Failed to install Python. Exiting.
    exit /b 1
)

echo Python installation successful.

rem Check if R is installed
"C:\Program Files\R\R-4.1.3\bin\Rscript.exe" --version >nul 2>&1
if %errorlevel% neq 0 (
    echo R is not installed. Installing R...
    REM Download and install R from the official website or an appropriate source
    REM Example for downloading R from the official website
    REM Modify this path as per your requirement
    start /wait "" https://cran.r-project.org/bin/windows/base/R-4.1.3-win.exe /SILENT
) else (
    echo R is already installed.
)

rem Check if R was successfully installed
"C:\Program Files\R\R-4.1.3\bin\Rscript.exe" --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Failed to install R. Exiting.
    exit /b 1
)

echo R installation successful.



echo Python and R packages installation successful.

pause
