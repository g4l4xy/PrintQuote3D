@echo off
cd /d "%~dp0"
echo PrintQuote3D Windows
choice /c RBIS /m "Run, Build MSI, Install newest MSI, or Sync pull"
if errorlevel 4 goto sync
if errorlevel 3 goto install
if errorlevel 2 goto build
call gradlew.bat :desktopApp:run
goto end
:build
call gradlew.bat :sharedLogic:test :desktopApp:packageMsi :desktopApp:packageExe
goto end
:install
for %%f in (desktopApp\build\compose\binaries\main\msi\*.msi) do start /wait msiexec /i "%%~ff"
goto end
:sync
git diff --quiet || goto dirty
git diff --cached --quiet || goto dirty
for /f "delims=" %%f in ('git ls-files --others --exclude-standard') do goto dirty
git pull --ff-only
goto end
:dirty
echo Save and commit your local edits before pulling. No files were changed.
:end
pause
