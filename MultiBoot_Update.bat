@echo off
cmd /u /c chcp 65001 >nul
cd /d "%~dp0"

if NOT "%cd%"=="%cd: =%" (
    echo.
    echo   ..:: DIKKAT ::..
    echo    Mevcut klasor isminde bosluklar var.
    echo    Lutfen klasoru bosluk karakteri icermeyen bir isimle yeniden adlandirin.
    echo.
    pause >nul
    goto :EOF
)

if "[%1]"=="[49127c4b-02dc-482e-ac4f-ec4d659b7547]" goto :MAINMENU
REG QUERY HKU\S-1-5-19\Environment >NUL 2>&1 && goto :MAINMENU

set command="""%~f0""" 49127c4b-02dc-482e-ac4f-ec4d659b7547
setlocal enabledelayedexpansion
set "command=!command:'=''!"

echo.
echo        YONETICI HAKLARI ETKINLESTIRILIYOR...
echo.
echo             Lutfen bekleyin...

powershell -NoProfile Start-Process -FilePath "%COMSPEC%" -ArgumentList "/c ""!command!""" -Verb RunAs 2>NUL

if %ERRORLEVEL% GTR 0 (
    echo.
    echo =============================================================
    echo Komut dosyasinin yonetici olarak calistirilmasi gerekiyor.
    echo =============================================================
    echo.
    pause
)
setlocal disabledelayedexpansion
goto :EOF

:MAINMENU
setlocal EnableExtensions EnableDelayedExpansion
set "SCRIPT_DIR=%~dp0"
set "LOGFILE=%SCRIPT_DIR%Ventoy_Update.log"

echo ============================================= >> "%LOGFILE%"
echo %date% %time% - ISLEM BASLADI >> "%LOGFILE%"
echo ============================================= >> "%LOGFILE%"

for /f "tokens=6 delims=[]. " %%# in ('ver') do set winbuild=%%#
if %winbuild% LSS 10240 (
    echo Windows 10 ve uzeri gerekiyor. >> "%LOGFILE%"
    echo Windows 10 ve uzeri gerekiyor.
    pause
    exit
)

mode con:cols=85 lines=40
color 0A
title Vadi MultiBoot ^& Ventoy Update - TNCTR.com AwenGers44

:Main
cls
echo.
echo ==================================================================================
echo.
echo          1 - VENTOY GUNCELLEME ISLEMI
echo.
echo          2 - VADI_EFI GUNCELLEME ISLEMI
echo.
echo          3 - DISKLERI YENIDEN TARA
echo.
echo          4 - CIKIS
echo.
echo ==================================================================================
echo.
choice /c 1234 /cs /n /m ">> Seciminizi Yapin : "
echo.
if errorlevel 4 goto :ExitScript
if errorlevel 3 goto :RescanDisks
if errorlevel 2 goto :VadiUpdateMenu
if errorlevel 1 goto :VentoyUpdateMenu
goto :Main

:ExitScript
echo.
echo %date% %time% - ISLEM SONLANDI >> "%LOGFILE%"
echo ============================================= >> "%LOGFILE%"
exit

:RescanDisks
echo.
echo [ISLEM] Diskler yeniden taranıyor...
echo %date% %time% - Diskler yeniden taranıyor >> "%LOGFILE%"

set "scriptFile=%temp%\rescan_%random%%random%.tmp"
set "outFile=%temp%\rescan_out_%random%%random%.txt"
> "%scriptFile%" (
    echo RESCAN
    echo LIST DISK
)
diskpart /s "%scriptFile%" > "%outFile%" 2>&1
set "rescanErr=%errorlevel%"
del /q "%scriptFile%" >nul 2>&1

if not "%rescanErr%"=="0" (
    echo [HATA] Diskler yeniden taranamadı.
    echo %date% %time% - Disk tarama HATALI >> "%LOGFILE%"
    type "%outFile%"
    del /q "%outFile%" >nul 2>&1
    pause
    goto :Main
)

echo [TAMAM] Diskler yeniden tarandı.
echo %date% %time% - Disk tarama tamamlandı >> "%LOGFILE%"
type "%outFile%"
del /q "%outFile%" >nul 2>&1
timeout /t 2 >nul
goto :Main

:VadiUpdateMenu
cls
echo.
echo ==================================================================================
echo.
echo                    			VADI_EFI GUNCELLEME
echo.
echo ==================================================================================
echo.
call :showDiskTable

:getVadiDiskNumber
set "diskNumber="
set /p "diskNumber=MultiBoot_USB etiketli DISK numarasını girin: "
echo !diskNumber!|findstr /r "^[0-9][0-9]*$" >nul || (
    echo HATA: Geçersiz disk numarası.
    goto :getVadiDiskNumber
)

call :ValidateTargetDisk !diskNumber!
if errorlevel 1 goto :getVadiDiskNumber

echo.
echo [ISLEM] VADI_EFI güncellemesi başlatılıyor...
echo %date% %time% - VADI_EFI güncelleme başladı - Disk: !diskNumber! >> "%LOGFILE%"
call :UpdateVadiEFI !diskNumber!
if errorlevel 1 (
    echo [HATA] VADI_EFI güncellemesi başarısız.
    echo %date% %time% - VADI_EFI güncelleme HATALI >> "%LOGFILE%"
    pause
    goto :Main
)

echo.
echo ===================================================
echo         VADI_EFI GUNCELLEME TAMAMLANDI
echo ===================================================
echo %date% %time% - VADI_EFI güncelleme TAMAM >> "%LOGFILE%"
echo.
pause
goto :Main

:VentoyUpdateMenu
call :SelectVentoyVersion
if errorlevel 1 (
    pause
    goto :Main
)

:SelectMethod
cls
echo.
echo ==================================================================================
echo.
echo              VENTOY GUNCELLEME YONTEMI
echo.
echo      [1] Ventoy2Disk.exe ile Ventoy güncelleme
echo      [2] ZIP ile VTOYEFI güncelleme
echo.
echo ==================================================================================
echo.
choice /C:12 /N /M "Yöntemi seçin: "
if errorlevel 2 (
    set "updateMethod=ZIP"
) else (
    set "updateMethod=EXE"
)

:RetryMethod
if /I "!updateMethod!"=="EXE" (
    if not exist "!ventoyExe!" (
        if exist "!selectedZip!" (
            echo.
            echo [UYARI] Ventoy2Disk.exe bulunamadı, ZIP yöntemine geçiliyor...
            set "updateMethod=ZIP"
            goto :RetryMethod
        ) else (
            echo.
            echo [HATA] Ne Ventoy2Disk.exe ne de ZIP dosyası bulunabiliyor.
            echo        Lütfen en az birini temin edin.
            pause
            goto :Main
        )
    )
)

if /I "!updateMethod!"=="ZIP" (
    if not exist "!selectedZip!" (
        if exist "!ventoyExe!" (
            echo.
            echo [UYARI] ZIP dosyası bulunamadı, Ventoy2Disk.exe yöntemine geçiliyor...
            set "updateMethod=EXE"
            goto :RetryMethod
        ) else (
            echo.
            echo [HATA] Ne ZIP dosyası ne de Ventoy2Disk.exe bulunabiliyor.
            echo        Lütfen en az birini temin edin.
            pause
            goto :Main
        )
    )
)

call :showDiskTable

:getDiskNumber
set "diskNumber="
set /p "diskNumber=MultiBoot_USB etiketli USB disk numarasını girin: "
echo !diskNumber!|findstr /r "^[0-9][0-9]*$" >nul || (
    echo HATA: Geçersiz disk numarası.
    goto :getDiskNumber
)

call :ValidateTargetDisk !diskNumber!
if errorlevel 1 goto :getDiskNumber
set "originalDrive="
for /f %%L in ('powershell -NoProfile -Command "$v = Get-Partition -DiskNumber !diskNumber! -ErrorAction SilentlyContinue | ForEach-Object { try { Get-Volume -Partition $_ -ErrorAction Stop } catch { $null } } | Where-Object { $_ -and $_.FileSystemLabel -eq 'MultiBoot_USB' } | Select-Object -First 1 -ExpandProperty DriveLetter; if ($v) { $v }"') do set "originalDrive=%%L"

echo %date% %time% - Ventoy güncelleme başladı - Disk: !diskNumber! - Yöntem: !updateMethod! >> "%LOGFILE%"

if /I "!updateMethod!"=="EXE" (
    echo.
    echo [ISLEM] Ventoy2Disk.exe ile güncelleme yapılıyor...
    echo [BILGI] Ventoy2Disk.exe tüm işlemleri kendisi yapacaktır.
    echo.
    pushd "%~dp0Ventoy" >nul
    start "Ventoy Güncelleme" /wait "Ventoy2Disk.exe" VTOYCLI /U /PhyDrive:!diskNumber! /NOUSBCheck /f
    set "exeErr=!errorlevel!"
    popd >nul
    
    if not "!exeErr!"=="0" (
        echo [HATA] Ventoy2Disk.exe güncellemesi başarısız oldu.
        echo %date% %time% - Ventoy2Disk.exe HATALI >> "%LOGFILE%"
        pause
        goto :Main
    )
    echo [TAMAM] Ventoy2Disk.exe güncellemesi tamamlandı.
    call :CleanVentoyFolder
	
    echo.
    echo ===================================================
    echo         VENTOY GUNCELLEME TAMAMLANDI
    echo ===================================================
    echo    - Kullanılan paket: !selectedMode!
    echo    - Yöntem: Ventoy2Disk.exe ile güncelleme
    echo    - MultiBoot_USB harfi: !originalDrive!: olarak korundu
    echo ===================================================
    echo.
    echo %date% %time% - Ventoy güncelleme TAMAM >> "%LOGFILE%"
    echo.
    echo İşlem tamamlandı - Devam etmek için bir tuşa basın...
    pause >nul
    goto :Main
)

if /I "!updateMethod!"=="ZIP" (
    echo.
    echo [ISLEM] ZIP ile VTOYEFI güncellemesi yapılıyor...
    
    call :UpdateVentoyEFI !diskNumber!
    if errorlevel 1 (
        echo [HATA] VTOYEFI güncellemesi başarısız.
        pause
        goto :Main
    )
    
    echo.
    echo [ISLEM] Gizli bölümler kapatılıyor...
    call :HidePartitionsPermanent !diskNumber!
    call :CleanVentoyFolder
	
    echo.
    echo ===================================================
    echo         VENTOY GUNCELLEME TAMAMLANDI
    echo ===================================================
    echo    - Kullanılan paket: !selectedMode!
    echo    - Yöntem: ZIP ile VTOYEFI güncelleme
    echo    - MultiBoot_Usb harfi: !originalDrive!: olarak korundu
    echo    - VTOYEFI ve VADI_EFI kalıcı olarak gizlendi
    echo ===================================================
    echo.
    echo %date% %time% - Ventoy güncelleme TAMAM >> "%LOGFILE%"
    echo.
    echo İşlem tamamlandı - Devam etmek için bir tuşa basın...
    pause >nul
    goto :Main
)

goto :Main

:CleanVentoyFolder
echo [ISLEM] Geçici Ventoy dosyaları temizleniyor...

if not exist "%~dp0Ventoy\" goto :eof

for /f "delims=" %%I in ('dir /b /a "%~dp0Ventoy" 2^>nul') do (
    if /I not "%%I"=="mod" if /I not "%%I"=="orijinal" (
        if exist "%~dp0Ventoy\%%I\" (
            echo [TEMIZLIK] Klasör siliniyor: %%I
            rd /s /q "%~dp0Ventoy\%%I" >nul 2>&1
        ) else (
            echo [TEMIZLIK] Dosya siliniyor: %%I
            del /f /q "%~dp0Ventoy\%%I" >nul 2>&1
        )
    )
)

echo [TAMAM] Geçici dosyalar temizlendi.
goto :eof

:UpdateVentoyEFI
setlocal EnableDelayedExpansion
set "tdisk=%~1"

echo [ISLEM] VTOYEFI bölümü hazırlanıyor...
call :PrepareVentoyEFI !tdisk!
if errorlevel 1 exit /b 1

echo [ISLEM] VTOYEFI bölümü içeriği temizleniyor...
powershell -NoProfile -Command "try { Get-ChildItem -LiteralPath 'Z:\' -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo [HATA] VTOYEFI bölümü içeriği temizlenemedi.
    exit /b 1
)

set "tempExtract=%temp%\VentoyExtract_%random%%random%"
rd /s /q "!tempExtract!" >nul 2>&1
md "!tempExtract!" >nul 2>&1

echo [ISLEM] !selectedZipName! arşivi açılıyor...
powershell -NoProfile -Command "try { Expand-Archive -LiteralPath '!selectedZip!' -DestinationPath '!tempExtract!' -Force; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo [HATA] !selectedZipName! arşivi açılamadı.
    rd /s /q "!tempExtract!" >nul 2>&1
    exit /b 1
)

call :ResolveCopySource "!tempExtract!"
if errorlevel 1 (
    echo [HATA] Kopyalanacak kaynak bulunamadı.
    rd /s /q "!tempExtract!" >nul 2>&1
    exit /b 1
)

echo [ISLEM] Dosyalar VTOYEFI bölümüne kopyalanıyor...
xcopy "!copySource!\*" "Z:\" /E /H /C /I /Y >nul
if errorlevel 1 (
    echo [HATA] Dosyalar kopyalanamadı.
    rd /s /q "!tempExtract!" >nul 2>&1
    exit /b 1
)

rd /s /q "!tempExtract!" >nul 2>&1
echo [TAMAM] VTOYEFI güncellemesi tamamlandı.
exit /b 0

:UpdateVadiEFI
setlocal EnableDelayedExpansion
set "tdisk=%~1"

echo [ISLEM] VADI_EFI bölümü hazırlanıyor...
call :PrepareVadiEFI !tdisk!
if errorlevel 1 exit /b 1

echo [ISLEM] VADI_EFI bölümü içeriği temizleniyor...
powershell -NoProfile -Command "try { Get-ChildItem -LiteralPath 'Y:\' -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo [HATA] VADI_EFI bölümü içeriği temizlenemedi.
    exit /b 1
)

if not exist "%~dp0VadiUpdate\vadi_up.zip" (
    echo [HATA] vadi_up.zip bulunamadı: %~dp0VadiUpdate\vadi_up.zip
    exit /b 1
)

set "tempExtract=%temp%\VadiExtract_%random%%random%"
rd /s /q "!tempExtract!" >nul 2>&1
md "!tempExtract!" >nul 2>&1

echo [ISLEM] vadi_up.zip arşivi açılıyor...
powershell -NoProfile -Command "try { Expand-Archive -LiteralPath '%~dp0VadiUpdate\vadi_up.zip' -DestinationPath '!tempExtract!' -Force; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo [HATA] vadi_up.zip arşivi açılamadı.
    rd /s /q "!tempExtract!" >nul 2>&1
    exit /b 1
)

echo [ISLEM] Dosyalar VADI_EFI bölümüne kopyalanıyor...
xcopy "!tempExtract!\*" "Y:\" /E /H /C /I /Y >nul
if errorlevel 1 (
    echo [HATA] Dosyalar kopyalanamadı.
    rd /s /q "!tempExtract!" >nul 2>&1
    exit /b 1
)

rd /s /q "!tempExtract!" >nul 2>&1

echo [TAMAM] VADI_EFI güncellemesi tamamlandı.
call :HideVadiPermanent !tdisk!
exit /b 0

:PrepareVentoyEFI
setlocal
set "tdisk=%~1"

set "scriptFile=%temp%\prep_vtoy_%random%%random%.tmp"
> "!scriptFile!" (
    echo SELECT DISK !tdisk!
    echo SELECT PARTITION 2
    echo SET ID=0C OVERRIDE
    echo ASSIGN LETTER=Z
)
diskpart /s "!scriptFile!" >nul 2>&1
del /q "!scriptFile!" >nul 2>&1
timeout /t 2 >nul
endlocal & exit /b 0

:PrepareVadiEFI
setlocal
set "tdisk=%~1"

set "scriptFile=%temp%\prep_vadi_%random%%random%.tmp"
> "!scriptFile!" (
    echo SELECT DISK !tdisk!
    echo SELECT PARTITION 3
    echo SET ID=0B OVERRIDE
    echo ASSIGN LETTER=Y
)
diskpart /s "!scriptFile!" >nul 2>&1
del /q "!scriptFile!" >nul 2>&1
timeout /t 2 >nul
endlocal & exit /b 0

:HidePartitionsPermanent
setlocal
set "tdisk=%~1"

echo [ISLEM] Bölümler gizli tipine dönüştürülüyor...

set "scriptFile=%temp%\hide_both_%random%%random%.tmp"
> "!scriptFile!" (
    echo SELECT DISK !tdisk!
    echo SELECT PARTITION 2
    echo REMOVE NOERR
    echo SET ID=1C OVERRIDE
    echo SELECT PARTITION 3
    echo REMOVE NOERR
    echo SET ID=1B OVERRIDE
    echo SELECT PARTITION 1
    echo REMOVE NOERR
)
diskpart /s "!scriptFile!" >nul 2>&1
del /q "!scriptFile!" >nul 2>&1

set "assignLetter="
if defined originalDrive (
    set "assignLetter=!originalDrive!"
) else (
    for %%L in (Z Y X W V U T S R Q P O N M L K J I H G F E D C) do (
        cd %%L: 1>nul 2>&1
        if errorlevel 1 (
            set "assignLetter=%%L"
            goto :foundLetter
        )
    )
    :foundLetter
    if not defined assignLetter set "assignLetter=M"
)

set "scriptFile=%temp%\assign_main_%random%%random%.tmp"
> "!scriptFile!" (
    echo SELECT DISK !tdisk!
    echo SELECT PARTITION 1
    echo ASSIGN LETTER=!assignLetter!
)
diskpart /s "!scriptFile!" >nul 2>&1
del /q "!scriptFile!" >nul 2>&1

echo [TAMAM] Bölümler gizlendi, MultiBoot_USB harfi: !assignLetter!
exit /b 0

:ResolveCopySource
setlocal EnableDelayedExpansion
set "base=%~1"
set "dirCount=0"
set "fileCount=0"
set "singleDir="
for /f "delims=" %%D in ('dir /b /ad "!base!" 2^>nul') do (
    set /a dirCount+=1
    set "singleDir=%%D"
)
for /f "delims=" %%F in ('dir /b /a-d "!base!" 2^>nul') do (
    set /a fileCount+=1
)
if "!dirCount!"=="1" if "!fileCount!"=="0" (
    endlocal & set "copySource=%~1\%singleDir%" & exit /b 0
)
endlocal & set "copySource=%~1" & exit /b 0

:SelectVentoyVersion
echo.
echo.    [O] Orijinal Ventoy   [M] Modifiye Ventoy
echo.
choice /C:OM /N /M "Kullanılacak Ventoy versiyonunu seçin: "
if errorlevel 2 (
    set "selectedMode=Modifiye"
    set "selectedFolder=%~dp0Ventoy\mod"
    set "selectedZip=%~dp0Ventoy\mod.zip"
    set "selectedZipName=mod.zip"
) else (
    set "selectedMode=Orijinal"
    set "selectedFolder=%~dp0Ventoy\orijinal"
    set "selectedZip=%~dp0Ventoy\orijinal.zip"
    set "selectedZipName=orijinal.zip"
)

if not exist "!selectedFolder!\" (
    echo [HATA] Paket klasörü bulunamadı: !selectedFolder!
    exit /b 1
)

echo [ISLEM] Seçilen paket dosyaları hazırlanıyor...
robocopy "!selectedFolder!" "%~dp0Ventoy" /E /IS /IT /NFL /NDL /NJH /NJS /NC /NS >nul
if errorlevel 8 (
    echo [HATA] Paket dosyaları kopyalanamadı.
    exit /b 1
)

set "ventoyExe=%~dp0Ventoy\Ventoy2Disk.exe"

echo [TAMAM] Paket seçildi: !selectedMode!
exit /b 0

:showDiskTable
echo.
echo       ======================================================
echo          DIKKAT : DOGRU DISKI SECTIGINIZDEN EMIN OLUN
echo       ======================================================
echo.
powershell -NoProfile -Command "Get-Disk | Format-Table Number, FriendlyName, @{Name='Size(GB)';Expression={[math]::Round($_.Size/1GB,2)}}, PartitionStyle, OperationalStatus -AutoSize"
echo.
echo   UYGUN ADAYLAR (USB / SANAL / TASINABILIR + MultiBoot_USB):
powershell -NoProfile -Command "Get-Disk | Where-Object { $_.BusType -eq 'USB' -or $_.BusType -eq 'Removable' -or $_.BusType -eq 'Virtual' -or $_.BusType -eq 'File Backed Virtual' } | ForEach-Object { $d=$_; $has = Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | ForEach-Object { try { Get-Volume -Partition $_ -ErrorAction Stop } catch { $null } } | Where-Object { $_ -and $_.FileSystemLabel -eq 'MultiBoot_USB' } | Select-Object -First 1; if ($has) { [pscustomobject]@{ Number=$d.Number; Label='MultiBoot_USB'; Model=$d.FriendlyName; SizeGB=[math]::Round($d.Size/1GB,2); BusType=$d.BusType } } } | Format-Table -AutoSize"
echo.
goto :eof

:ValidateTargetDisk
setlocal
set "diskNum=%~1"
powershell -NoProfile -Command "$d=Get-Disk -Number %diskNum% -ErrorAction SilentlyContinue; if(-not $d){exit 1}; $has = Get-Partition -DiskNumber %diskNum% -ErrorAction SilentlyContinue | ForEach-Object { try { Get-Volume -Partition $_ -ErrorAction Stop } catch { $null } } | Where-Object { $_ -and $_.FileSystemLabel -eq 'MultiBoot_USB' } | Select-Object -First 1; if(-not $has){exit 1}; exit 0"
endlocal & exit /b %errorlevel%