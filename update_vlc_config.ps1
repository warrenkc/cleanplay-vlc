# Stop VLC if it is running to prevent config overwrite
$vlc = Get-Process -Name vlc -ErrorAction SilentlyContinue
if ($vlc) {
    Write-Host "Closing VLC to update configuration..."
    Stop-Process -Name vlc -Force
    Start-Sleep -Seconds 1
}

$vlcrcPath = "$env:APPDATA\vlc\vlcrc"
if (Test-Path $vlcrcPath) {
    $content = Get-Content -Path $vlcrcPath -Raw
    
    # 1. Enable extraintf=luaintf (silent Lua interface module)
    if ($content -match '(?m)^#extraintf=') {
        $content = $content -replace '(?m)^#extraintf=', 'extraintf=luaintf'
    } elseif ($content -match '(?m)^extraintf=') {
        $content = $content -replace '(?m)^extraintf=.*', 'extraintf=luaintf'
    } else {
        $content += "`r`nextraintf=luaintf"
    }

    # 2. Enable lua-intf=cleanplay_intf_v1
    if ($content -match '(?m)^#lua-intf=dummy') {
        $content = $content -replace '(?m)^#lua-intf=dummy', 'lua-intf=cleanplay_intf_v1'
    } elseif ($content -match '(?m)^#lua-intf=') {
        $content = $content -replace '(?m)^#lua-intf=', 'lua-intf=cleanplay_intf_v1'
    } elseif ($content -match '(?m)^lua-intf=') {
        $content = $content -replace '(?m)^lua-intf=.*', 'lua-intf=cleanplay_intf_v1'
    } else {
        $content += "`r`nlua-intf=cleanplay_intf_v1"
    }

    Set-Content -Path $vlcrcPath -Value $content -NoNewline
    Write-Host "VLC configuration vlcrc updated successfully with extraintf=luaintf."
} else {
    Write-Error "vlcrc not found at $vlcrcPath!"
}
