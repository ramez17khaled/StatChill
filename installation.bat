@echo off
setlocal

REM Function to check and install Python
:CheckInstallPython
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Python is not installed. Attempting to install Python...
    
    REM Download Python installer
    echo Downloading Python installer...
    curl -o python-installer.exe https://www.python.org/ftp/python/3.9.5/python-3.9.5-amd64.exe
    if %errorlevel% neq 0 (
        echo Failed to download Python installer. Continuing with R installation...
    ) else (
        REM Install Python
        echo Installing Python...
        start /wait python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
        if %errorlevel% neq 0 (
            echo Failed to install Python. Continuing with R installation...
        )
    )
) else (
    echo Python is already installed.
)

REM Verify Python installation
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Python installation was not successful, but continuing with R installation...
)

echo Python installation check complete.

REM Function to check and install R
:CheckInstallR
set "R_INSTALL_PATH=C:\Program Files\R\R-4.1.3"
set "R_INSTALL_EXE=R-4.1.3-win.exe"

REM Check if R is installed
if exist "%R_INSTALL_PATH%\bin\Rscript.exe" (
    echo R is already installed at "%R_INSTALL_PATH%". Updating statchill.bat to use this version...

    REM Modify statchill.bat to use the found R installation path
    set "bat2_file=statchill.bat"
    set "search=C:\Program Files\R\R-4.1.3\bin\Rscript.exe"
    set "replace=%R_INSTALL_PATH%\bin\Rscript.exe"
    
    REM Use PowerShell to update the file
    powershell -Command "(Get-Content -path '%bat2_file%') -replace [regex]::escape('%search%'), '%replace%' | Set-Content -path '%bat2_file%'"
    
    echo R installation check complete.
    goto :End
)

echo R is not installed. Installing R-4.1.3...

REM Download R-4.1.3 installer
echo Downloading R-4.1.3 installer...
curl -o %R_INSTALL_EXE% https://cran.r-project.org/bin/windows/base/old/4.1.3/%R_INSTALL_EXE%
if %errorlevel% neq 0 (
    echo Failed to download R-4.1.3. Exiting.
    exit /b 1
)

REM Install R-4.1.3
echo Installing R-4.1.3...
start /wait %R_INSTALL_EXE% /SILENT

REM Verify R installation
if not exist "%R_INSTALL_PATH%\bin\Rscript.exe" (
    echo Failed to install R-4.1.3. Exiting.
    exit /b 1
)

echo R-4.1.3 installation successful.
echo R is installed at "%R_INSTALL_PATH%".

:End
endlocal
pause
