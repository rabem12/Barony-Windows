param(
    [Parameter(ValueFromRemainingArguments=$true, Position=0)]
    [string[]]$GameArgs
)
# ==========================================
# Barony Save Protector (Windows)
# Translated for PowerShell
# Created by Raven Lord
# ==========================================

$BaseDir = $PSScriptRoot
$GraveyardDir = Join-Path $BaseDir "Graveyard"
$BackupDir = Join-Path $BaseDir "Backups"
$ProtectorLog = Join-Path $BackupDir "protector.log"
$MaxBackups = 10
$MaxGraveyard = 100

# Helper Functions
function Show-Notification {
    param ([string]$Title, [string]$Message)
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
        
        $toastXml = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <text>$Message</text>
        </binding>
    </visual>
</toast>
"@
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($toastXml)
        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Microsoft.Windows.Explorer").Show($toast)
    } catch {
        Write-Host "NOTIFICATION: $Title - $Message"
    }
}

function Log-Write {
    param ([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMsg = "[$stamp] $Message"
    Add-Content -Path $ProtectorLog -Value $fullMsg -ErrorAction SilentlyContinue
    Write-Host $fullMsg -ForegroundColor Cyan
}
    # ==========================================
    # LAUNCHER INITIALIZATION
    # ==========================================
    
    if ($GameArgs.Count -eq 0) {
        Write-Host "No game executable provided by Steam. Exiting."
        exit
    }

    $exe = $GameArgs[0]
    $InstallDir = Split-Path $exe
    $SaveDir = Join-Path $InstallDir "savegames"

    # Create User-Facing Folders
    New-Item -ItemType Directory -Force -Path (Join-Path $GraveyardDir "Solo_Runs") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $GraveyardDir "Multiplayer_Runs") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $GraveyardDir "Hall_of_Fame") | Out-Null
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

    # Dynamically Generate Resurrection Tool
    $ResurrectTool = Join-Path $GraveyardDir "Resurrect_Character.bat"
    # Always regenerate to guarantee the correct dynamic Steam path
    if ($true) {
        $ToolCode = @"
<# :
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Get-Content '%~f0' -Raw)))"
exit /b
#>
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

`$SaveDir = "$SaveDir"
`$GraveyardDir = "$GraveyardDir"
`$LogFile = "$ProtectorLog"

if (Get-Process "barony" -ErrorAction SilentlyContinue) {
    `$result = [System.Windows.Forms.MessageBox]::Show(
        "Barony is currently running! You must fully quit the game before resurrecting a character, otherwise the engine will instantly overwrite it.`n`nForce Quit Barony?",
        "Graveyard Error",
        [System.Windows.Forms.MessageBoxButtons]::OKCancel,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if (`$result -eq "OK") {
        Stop-Process -Name "barony" -Force
        Start-Sleep -Seconds 2
    } else {
        exit
    }
}

`$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
`$openFileDialog.InitialDirectory = `$GraveyardDir
`$openFileDialog.Filter = "Barony Saves (*.baronysave)|*.baronysave"
`$openFileDialog.Title = "Select a deceased character to resurrect:"

if (`$openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    `$filePath = `$openFileDialog.FileName
    `$filename = Split-Path `$filePath -Leaf
    
    if (`$filename -match '\[(.*?)\]') {
        `$origBase = `$matches[1]
        
        `$StagingDir = Join-Path `$GraveyardDir "Staging"
        if (-not (Test-Path `$StagingDir)) { New-Item -ItemType Directory -Path `$StagingDir | Out-Null }
        
        Copy-Item -LiteralPath `$filePath -Destination (Join-Path `$StagingDir `$filename)
        (Get-Item -LiteralPath (Join-Path `$StagingDir `$filename)).LastWriteTime = Get-Date
        
        `$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path `$LogFile -Value "[`$stamp] USER ACTION: Staged `$filename" -ErrorAction SilentlyContinue

        [System.Windows.Forms.MessageBox]::Show(
            "Character staged for resurrection!`n`nIt will automatically be placed into the next available save slot when you launch Barony from Steam.",
            "Barony Graveyard",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Error: Could not identify original save slot. File must contain [bracketed] name.",
            "Graveyard Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}
"@
        Set-Content -Path $ResurrectTool -Value $ToolCode -Encoding ASCII
    }


    # Start monitoring
    Log-Write "Launcher starting Protector Monitor..."
    Show-Notification "Protector Active" "Barony Save Protector is actively monitoring your saves."
    
    # --- STAGING INJECTION ---
    $StagingDir = Join-Path $GraveyardDir "Staging"
    $SaveDir = Join-Path $InstallDir "savegames"
    if (Test-Path $StagingDir) {
        $stagedFiles = Get-ChildItem -Path $StagingDir -Filter "*.baronysave" -ErrorAction SilentlyContinue
        foreach ($staged in $stagedFiles) {
            try {
                $stagedName = $staged.Name
                $targetSlot = "savegame0.baronysave"
                $isMp = ""
                
                # Parse preferred slot from bracket e.g. Marley_[savegame3]_...
                if ($stagedName -match '\[(.*?)\]') {
                    $targetSlot = $matches[1] + ".baronysave"
                    $isMp = if ($matches[1] -match "_mp") { "_mp" } else { "" }
                }
                
                # Enforce slot availability right before launch
                if (Test-Path (Join-Path $SaveDir $targetSlot)) {
                    $slotNum = 0
                    while (Test-Path (Join-Path $SaveDir "savegame${slotNum}${isMp}.baronysave")) {
                        $slotNum++
                    }
                    $targetSlot = "savegame${slotNum}${isMp}.baronysave"
                }
                
                Move-Item -LiteralPath $staged.FullName -Destination (Join-Path $SaveDir $targetSlot) -Force -ErrorAction Stop
                Log-Write "STAGING INJECTION: Translated and moved $stagedName into $targetSlot"
            } catch {
                Log-Write "STAGING ERROR: Could not inject $($staged.Name) - $($_.Exception.Message)"
            }
        }
    }

    # Launch Game Asynchronously
    Start-Sleep -Seconds 2
    $argsList = if ($GameArgs.Count -gt 1) { $GameArgs[1..($GameArgs.Count-1)] } else { @() }
    if ($argsList.Count -gt 0) {
        $game = Start-Process -FilePath $exe -ArgumentList $argsList -WorkingDirectory $InstallDir -WindowStyle Normal -PassThru
    } else {
        $game = Start-Process -FilePath $exe -WorkingDirectory $InstallDir -WindowStyle Normal -PassThru
    }
    
    Log-Write "Barony engine launched (PID $($game.Id)). Monitoring saves..."

    # ==========================================
    # FOREGROUND MONITOR LOOP
    # ==========================================
    $GameLog = Join-Path $InstallDir "log.txt"
    $fileState = @{}
    $recentlyResurrected = @{}

    # Trim Log to prevent bloating
    if (Test-Path $ProtectorLog) {
        $logLines = Get-Content $ProtectorLog -Tail 500 -ErrorAction SilentlyContinue
        if ($logLines) { Set-Content -Path $ProtectorLog -Value $logLines }
    }

    # Monitor until the game exits
    while (-not $game.HasExited) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    # --- BACKUP PHASE ---
    if (Test-Path $SaveDir) {
        $saves = Get-ChildItem -Path $SaveDir -Filter "*.baronysave" -ErrorAction SilentlyContinue
        foreach ($file in $saves) {
            if ($file.Length -eq 0) { continue }
            
            $mtime = $file.LastWriteTime
            $basename = $file.BaseName

            if ($fileState[$basename] -eq $mtime) { continue }
            $fileState[$basename] = $mtime

            # Fast native json parsing
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
            if (-not $content) { continue }

            $hp = 1
            if ($content.players -and $content.players[0].stats -and $null -ne $content.players[0].stats.HP) {
                $hp = $content.players[0].stats.HP
            }
            
            if ($hp -gt 0) {
                $charName = "Unknown"
                if ($content.players -and $content.players[0].stats -and $content.players[0].stats.name) {
                    $rawName = $content.players[0].stats.name
                    if ($rawName.Length -gt 30) { $rawName = $rawName.Substring(0, 30) }
                    $charName = $rawName -replace '[\x00-\x1F\x7F\\/:*?"<>|]', '_' -replace ' ', '_'
                    if (-not $charName) { $charName = "Unknown" }
                }
                $backupName = "${charName}_${basename}_${timestamp}.baronysave"
                Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $BackupDir $backupName) -ErrorAction SilentlyContinue
                
                # Cleanup older backups for this slot
                $oldBackups = Get-ChildItem -Path $BackupDir -Filter "*_${basename}_*.baronysave" | Sort-Object LastWriteTime -Descending
                if ($oldBackups.Count -gt $MaxBackups) {
                    $oldBackups[$MaxBackups..($oldBackups.Count-1)] | Remove-Item -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # --- RESTORE PHASE ---
    $backups = Get-ChildItem -Path $BackupDir -Filter "*.baronysave" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    
    $groups = $backups | Group-Object {
        if ($_.Name -match '_(savegame\d+(?:_mp)?)_\d{8}_\d{6}\.baronysave$') {
            $matches[1] + ".baronysave"
        } else {
            "Unknown"
        }
    }
    
    foreach ($group in $groups) {
        if (-not $group.Name -or $group.Name -eq "Unknown") { continue }
        
        # --- COOLDOWN CHECK: skip slots recently resurrected to ignore engine double-delete ---
        if ($recentlyResurrected.ContainsKey($group.Name)) {
            $elapsed = (Get-Date) - $recentlyResurrected[$group.Name]
            if ($elapsed.TotalSeconds -lt 30) {
                # Silently discard the phantom second delete and clean up the re-snapshotted backup
                $group.Group | Remove-Item -Force -ErrorAction SilentlyContinue
                continue
            } else {
                $recentlyResurrected.Remove($group.Name)
            }
        }
        $origName = $group.Name
        $origBase = $origName -replace '\.baronysave$', ''
        $origPath = Join-Path $SaveDir $origName

        if (-not (Test-Path $origPath)) {
            $latestBackup = $group.Group[0]
            
            # --- DETERMINISTIC LOG TRIAGE ---
            $triage = "GHOST_WIPE"
            $deleteContext = ""
            
            if (Test-Path $GameLog) {
                $lines = @(Get-Content $GameLog -Tail 200 -ErrorAction SilentlyContinue)
                if ($lines) {
                    $lastDelIdx = -1
                    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                        if ($lines[$i] -match "deleting savegame in " -and $lines[$i] -match $origName) {
                            $lastDelIdx = $i
                            break
                        }
                    }
                    
                    if ($lastDelIdx -ne -1) {
                        $startIdx = [Math]::Max(0, $lastDelIdx - 15)
                        $endIdx = [Math]::Min($lines.Count - 1, $lastDelIdx + 15)
                        $triage = "MANUAL_DELETE"
                        for ($i = $startIdx; $i -le $endIdx; $i++) {
                            if ($lines[$i] -match "You die\.\.\." -or $lines[$i] -match "You were killed") {
                                $triage = "DEATH"
                                break
                            }
                        }
                    }
                }
                $deleteContextLines = Select-String -Path $GameLog -Pattern "You die\.\.\." -Context 1,0 -ErrorAction SilentlyContinue | Select-Object -Last 1
                if ($deleteContextLines) {
                    $deleteContext = $deleteContextLines.Context.PreContext[0] + "`n" + $deleteContextLines.Line
                }
            }
            
            # --- FAIL SAFELY LOGIC ---
            if ($triage -eq "MANUAL_DELETE") {
                Log-Write "User manually deleted $origName in UI. Cleaning up backups."
                $group.Group | Remove-Item -Force -ErrorAction SilentlyContinue
                continue
            }
            elseif ($triage -eq "GHOST_WIPE") {
                Log-Write "FAIL SAFELY: $origName vanished without log context. Resurrecting character."
            }
            
            
            $subDir = if ($latestBackup.Name -match "_mp_") { "Multiplayer_Runs" } else { "Solo_Runs" }
            
            # --- METADATA EXTRACTION ---
            $content = Get-Content $latestBackup.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
            
            $charName = "Unknown"
            $charLvl = 0; $dungeonFlr = 0; $maxHp = 0; $gold = 0; $totalKills = 0
            $cid = -1; $rid = -1
            
            if ($content) {
                if ($content.players -and $content.players[0].stats) {
                    $s = $content.players[0].stats
                    if ($s.name) { $charName = $s.name }
                    if ($s.LVL -ne $null) { $charLvl = $s.LVL }
                    if ($s.maxHP -ne $null) { $maxHp = $s.maxHP }
                    if ($s.GOLD -ne $null) { $gold = $s.GOLD }
                }
                if ($content.dungeon_lvl -ne $null) { $dungeonFlr = $content.dungeon_lvl }
                if ($content.players -and $content.players[0].kills) {
                    $totalKills = ($content.players[0].kills | Measure-Object -Sum).Sum
                }
                if ($content.players -and $null -ne $content.players[0].char_class) { $cid = $content.players[0].char_class }
                if ($content.players -and $null -ne $content.players[0].race) { $rid = $content.players[0].race }
            }
            
            $classes = @{0='Barbarian';1='Warrior';2='Healer';3='Rogue';4='Wanderer';5='Cleric';6='Merchant';7='Wizard';8='Arcanist';9='Joker';10='Sexton';11='Ninja';12='Monk';13='Conjurer';14='Accursed';15='Mesmer';16='Brewer';17='Mechanist';18='Punisher';19='Shaman';20='Hunter';21='Bard';22='Sapper';23='Scion'}
            $races = @{0='Human';1='Skeleton';2='Vampire';3='Succubus';4='Goatman';5='Automaton';6='Incubus';7='Goblin';8='Insectoid'}
            
            $charClass = if ($classes.ContainsKey($cid)) { $classes[$cid] } else { "Class ID $cid" }
            $charRace = if ($races.ContainsKey($rid)) { $races[$rid] } else { "Race ID $rid" }
            
            $rawName = $charName
            if ($rawName.Length -gt 30) { $rawName = $rawName.Substring(0, 30) }
            $safeCharName = $rawName -replace '[\x00-\x1F\x7F\\/:*?"<>|]', '_' -replace ' ', '_'
            if (-not $safeCharName) { $safeCharName = "Unknown" }
            
            $backupTimestamp = if ($latestBackup.Name -match '(\d{8}_\d{6})') { $matches[1] } else { Get-Date -Format "yyyyMMdd_HHmmss" }
            $stagedFileName = "${safeCharName}_[${origBase}]_${backupTimestamp}.baronysave"
            
            $StagingDir = Join-Path $GraveyardDir "Staging"
            if (-not (Test-Path $StagingDir)) { New-Item -ItemType Directory -Path $StagingDir | Out-Null }
            Copy-Item -LiteralPath $latestBackup.FullName -Destination (Join-Path $StagingDir $stagedFileName) -ErrorAction SilentlyContinue
            (Get-Item -LiteralPath (Join-Path $StagingDir $stagedFileName)).LastWriteTime = Get-Date
            
            $graveyardFile = Join-Path $GraveyardDir "$subDir\$stagedFileName"
            
            if (-not (Test-Path $graveyardFile)) {
                Copy-Item -LiteralPath $latestBackup.FullName -Destination $graveyardFile -ErrorAction SilentlyContinue
                
                $causeOfDeath = "Unknown cause."
                if ($deleteContextLines -and $deleteContextLines.Context.PreContext.Count -gt 0) {
                    $preContext = $deleteContextLines.Context.PreContext[0]
                    # Strip any leading [timestamp] tag from the log line
                    $causeOfDeath = $preContext -replace '^\[.*?\]\s*', ''
                }
                
                $chroniclesPath = Join-Path $GraveyardDir "The_Fallen_Chronicles.txt"
                $chronicleEntry = @"
========================================
FALLEN HERO: $charName
DATE OF DEATH: $(Get-Date -Format "MMMM dd, yyyy 'at' hh:mm tt")
CAUSE OF DEATH: $causeOfDeath
----------------------------------------
Race: $charRace | Class: $charClass
Level: $charLvl | Floor Reached: $dungeonFlr
Total Enemies Defeated: $totalKills
Max HP: $maxHp | Wealth: $gold Gold
Run Type: $($subDir -replace '_', ' ')
========================================

"@
                if (Test-Path $chroniclesPath) {
                    $existing = Get-Content $chroniclesPath -Raw
                    Set-Content -Path $chroniclesPath -Value ($chronicleEntry + $existing)
                } else {
                    Set-Content -Path $chroniclesPath -Value $chronicleEntry
                }
                
                # Trim chronicles
                $lines = Get-Content $chroniclesPath
                if ($lines.Count -gt 1200) {
                    $lines[0..1199] | Set-Content $chroniclesPath
                }
            }
            
            # Smart Storage Limits (Excluding Hall_of_Fame intentionally)
            $allGraves = @(
                Get-ChildItem -Path (Join-Path $GraveyardDir "Solo_Runs") -Filter "*.baronysave" -ErrorAction SilentlyContinue
                Get-ChildItem -Path (Join-Path $GraveyardDir "Multiplayer_Runs") -Filter "*.baronysave" -ErrorAction SilentlyContinue
            ) | Sort-Object LastWriteTime -Descending

            if ($allGraves.Count -gt $MaxGraveyard) {
                $allGraves[$MaxGraveyard..($allGraves.Count-1)] | Remove-Item -Force -ErrorAction SilentlyContinue
            }
            
            Log-Write "DEATH: $charName died on floor $dungeonFlr ($causeOfDeath)"
            Log-Write "STAGED: Character has been instantly staged for resurrection."
            Log-Write "ACTION: Please restart Barony to load them!"
            Show-Notification "Barony Graveyard" "Your character died, but their save file was instantly staged for resurrection! Please restart Barony to load them."
            
            # Clean up backups for this slot to prevent double-resurrections on engine double-delete bugs
            $group.Group | Remove-Item -Force -ErrorAction SilentlyContinue
            # Record cooldown so phantom second engine-delete is discarded
            $recentlyResurrected[$origName] = Get-Date
            
            Start-Sleep -Seconds 5
        }
    }
    Start-Sleep -Seconds 2
}

Log-Write "Barony closed. Exiting script."
Show-Notification "Protector Stopped" "Barony has closed. Save Protector is going to sleep."
Start-Sleep -Seconds 3

