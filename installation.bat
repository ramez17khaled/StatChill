@echo off
setlocal

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Python is not installed. Installing Python...
    REM Download Python installer
    curl -o python-installer.exe https://www.python.org/ftp/python/3.9.5/python-3.9.5-amd64.exe
    if %errorlevel% neq 0 (
        echo Failed to download Python installer. Exiting.
        exit /b 1
    )
    REM Install Python
    start /wait python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
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

REM Check if any version of R is installed
for /r "C:\Program Files\R\" %%F in (Rscript.exe) do (
    set "R_PATH=%%F"
    goto :FoundR
)

:FoundR
if defined R_PATH (
    echo R is already installed at "%R_PATH%". Updating bat2.bat to use this version...

    REM Modify bat2.bat to use the found R installation path
    set "bat2_file=statchill.bat"
    set "search=C:\Program Files\R\R-4.1.3\bin\Rscript.exe"
    set "replace=%R_PATH%"
    
    REM Use PowerShell to update the file
    powershell -Command "(Get-Content -path '%bat2_file%') -replace [regex]::escape('%search%'), '%replace%' | Set-Content -path '%bat2_file%'"
    
    goto :SkipRInstallation
)

REM If no R version is installed, proceed to install R-4.1.3
echo R is not installed. Installing R-4.1.3...

REM Download R-4.1.3 installer
curl -o R-4.1.3-win.exe https://cran.r-project.org/bin/windows/base/old/4.1.3/R-4.1.3-win.exe
if %errorlevel% neq 0 (
    echo Failed to download R-4.1.3. Exiting.
    exit /b 1
)

REM Install R-4.1.3
start /wait R-4.1.3-win.exe /SILENT

REM Check if R-4.1.3 was successfully installed
"C:\Program Files\R\R-4.1.3\bin\Rscript.exe" --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Failed to install R-4.1.3. Exiting.
    exit /b 1
)

echo R-4.1.3 installation successful.

:SkipRInstallation
endlocal
pause
