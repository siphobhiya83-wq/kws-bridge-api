@echo off
echo.
echo  =============================================
echo   KWS Bridge API -- Push to GitHub
echo  =============================================
echo.
echo  Run this AFTER creating the GitHub repo at:
echo  https://github.com/new  (name it: kws-bridge-api)
echo.
cd /d C:\Users\msbhi\OneDrive\Desktop\KWS\kws_bridge_api
git remote add origin https://github.com/siphobhiya83-wq/kws-bridge-api.git
git branch -M main
git push -u origin main
echo.
echo  Done! Your repo is live. Go connect it to Render.
pause
