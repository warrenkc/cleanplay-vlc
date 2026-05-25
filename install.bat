@echo off
echo ===================================================
echo   Installing CleanPlay v1 for VLC Media Player
echo ===================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "& {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path;
    
    Write-Host 'Step 1: Creating VLC user directories...' -ForegroundColor Cyan;
    $extDir = \"$env:APPDATA\vlc\lua\extensions\";
    $intfDir = \"$env:APPDATA\vlc\lua\intf\";
    
    # Create directories if they don't exist
    New-Item -ItemType Directory -Force -Path $extDir | Out-Null;
    New-Item -ItemType Directory -Force -Path $intfDir | Out-Null;
    New-Item -ItemType Directory -Force -Path \"$extDir\profanity_lists\" | Out-Null;
    
    Write-Host 'Step 2: Copying script files...' -ForegroundColor Cyan;
    if (Test-Path \"$scriptDir\cleanplay_v1.lua\") {
        Copy-Item -Path \"$scriptDir\cleanplay_v1.lua\" -Destination \"$extDir\cleanplay_v1.lua\" -Force;
        Write-Host '  -> Copied cleanplay_v1.lua to extensions folder.' -ForegroundColor Green;
    } else {
        Write-Error 'Could not find cleanplay_v1.lua in the installer directory!';
        return;
    }
    
    if (Test-Path \"$scriptDir\cleanplay_intf_v1.lua\") {
        Copy-Item -Path \"$scriptDir\cleanplay_intf_v1.lua\" -Destination \"$intfDir\cleanplay_intf_v1.lua\" -Force;
        Write-Host '  -> Copied cleanplay_intf_v1.lua to intf folder.' -ForegroundColor Green;
    } else {
        Write-Error 'Could not find cleanplay_intf_v1.lua in the installer directory!';
        return;
    }
    
    if (Test-Path \"$scriptDir\profanity_lists\") {
        Copy-Item -Path \"$scriptDir\profanity_lists\*\" -Destination \"$extDir\profanity_lists\" -Recurse -Force;
        Write-Host '  -> Copied profanity word lists.' -ForegroundColor Green;
    }
    
    Write-Host 'Step 3: Checking VLC process status...' -ForegroundColor Cyan;
    $vlc = Get-Process -Name vlc -ErrorAction SilentlyContinue;
    if ($vlc) {
        Write-Host '  -> Closing active VLC Player to update configuration...' -ForegroundColor Yellow;
        Stop-Process -Name vlc -Force;
        Start-Sleep -Seconds 2;
    }
    
    Write-Host 'Step 4: Updating VLC configuration (vlcrc)...' -ForegroundColor Cyan;
    $vlcrcPath = \"$env:APPDATA\vlc\vlcrc\";
    
    # If vlcrc doesn't exist (clean install), try to run VLC once to generate it
    if (-not (Test-Path $vlcrcPath)) {
        Write-Host '  -> vlcrc not found. Launching VLC briefly to generate configuration file...' -ForegroundColor Yellow;
        
        $vlcPaths = @(
            \"C:\Program Files\VideoLAN\VLC\vlc.exe\",
            \"C:\Program Files (x86)\VideoLAN\VLC\vlc.exe\"
        )
        $vlcExe = $vlcPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        
        if ($vlcExe) {
            Start-Process -FilePath $vlcExe -ArgumentList '--no-qt-privacy-ask' -NoNewWindow;
            Start-Sleep -Seconds 3;
            Stop-Process -Name vlc -Force;
            Start-Sleep -Seconds 1;
        }
    }
    
    if (Test-Path $vlcrcPath) {
        $content = Get-Content -Path $vlcrcPath -Raw;
        
        # Enable extraintf=luaintf (silent Lua background interface)
        if ($content -match '(?m)^#extraintf=') {
            $content = $content -replace '(?m)^#extraintf=', 'extraintf=luaintf'
        } elseif ($content -match '(?m)^extraintf=') {
            $content = $content -replace '(?m)^extraintf=.*', 'extraintf=luaintf'
        } else {
            $content += \"`r`nextraintf=luaintf\"
        }

        # Enable lua-intf=cleanplay_intf_v1
        if ($content -match '(?m)^#lua-intf=dummy') {
            $content = $content -replace '(?m)^#lua-intf=dummy', 'lua-intf=cleanplay_intf_v1'
        } elseif ($content -match '(?m)^#lua-intf=') {
            $content = $content -replace '(?m)^#lua-intf=', 'lua-intf=cleanplay_intf_v1'
        } elseif ($content -match '(?m)^lua-intf=') {
            $content = $content -replace '(?m)^lua-intf=.*', 'lua-intf=cleanplay_intf_v1'
        } else {
            $content += \"`r`nlua-intf=cleanplay_intf_v1\"
        }
        
        Set-Content -Path $vlcrcPath -Value $content -NoNewline;
        Write-Host '  -> VLC configuration updated successfully!' -ForegroundColor Green;
    } else {
        Write-Warning '  -> Could not locate or generate vlcrc file.';
        Write-Warning '  -> You may need to manually enable the Lua Interface in VLC Tools -> Preferences.';
    }
    
    echo.
    Write-Host '===================================================' -ForegroundColor Green;
    Write-Host '  CleanPlay v1 Installation Completed Successfully!' -ForegroundColor Green;
    Write-Host '===================================================' -ForegroundColor Green;
    Write-Host 'You can now start VLC Player.' -ForegroundColor Yellow;
    Write-Host 'Start any video, click View -> CleanPlay v1, and enjoy!' -ForegroundColor Yellow;
    echo.
}"
pause
