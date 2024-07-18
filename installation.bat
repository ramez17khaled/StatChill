@echo off
setlocal

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Python is not installed. Installing Python...
    REM Download and install Python from the official website or an appropriate source
    REM Example for downloading Python from the official website
    REM Modify this path as per your requirement
    start /wait "" msiexec.exe /i https://www.python.org/ftp/python/3.9.5/python-3.9.5-amd64.exe /quiet InstallAllUsers=1 PrependPath=1
) else (
    echo Python is already installed.
)

REM Check if Python was successfully installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Failed to install Python. Exiting.
    exit /b 1
)

echo Python installation successful.

REM Check if R is installed
"C:\Program Files\R\R-4.3.1\bin\Rscript.exe" --version >nul 2>&1
if %errorlevel% neq 0 (
    echo R is not installed. Installing R...

    REM Fetch the latest version number using PowerShell
    for /f "delims=" %%i in ('powershell -NoProfile -Command "(Invoke-WebRequest -Uri 'https://cran.r-project.org/bin/windows/base/').Links.href | Select-String -Pattern 'R-[0-9]+\.[0-9]+\.[0-9]+-win\.exe' | Sort-Object -Descending | Select-Object -First 1"') do set "LATEST_VERSION=%%i"
    
    REM Extract the version from the URL
    for /f "tokens=1,2 delims=R-" %%a in ("%LATEST_VERSION%") do set "VERSION=%%b"
    
    REM Construct the full URL
    set "URL=https://cran.r-project.org/bin/windows/base/R-%VERSION%"

    REM Download the file
    set OUTPUT=R-%VERSION%
    curl -o %OUTPUT% %URL%

    REM Check if the download was successful
    if %errorlevel% neq 0 (
        echo Download failed!
        exit /b %errorlevel%
    )

    REM Install R
    start /wait "" %OUTPUT% /SILENT

) else (
    echo R is already installed.
)

REM Check if R was successfully installed
"C:\Program Files\R\R-4.3.1\bin\Rscript.exe" --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Failed to install R. Exiting.
    exit /b 1
)

echo R installation successful.
endlocal
pause
