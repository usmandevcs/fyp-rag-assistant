@echo off
echo Connecting mobile port 8000 to BLACK-PEARL...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
echo Connection Successful!
pause

is ko run karny ky liye, aapko ye steps follow karne honge:
./connect_mobile.bat
bash this command in terminal.