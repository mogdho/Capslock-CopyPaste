#Requires AutoHotkey v2.0
;@Ahk2Exe-SetName Capslock-CopyPaste
;@Ahk2Exe-SetDescription Capslock-CopyPaste
;@Ahk2Exe-SetVersion 1.0.0
;@Ahk2Exe-SetCompanyName Mogdho Paul
;@Ahk2Exe-SetCopyright Mogdho Paul - MIT License
;@Ahk2Exe-SetMainIcon assets\icon.ico
;  (Lines starting with ;@Ahk2Exe are only read when building the .exe)


#SingleInstance Force

if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')  ; try: declining UAC no longer shows an error dialog
    ExitApp()
}

; Max gap between two taps to count as a double-tap (ms). Lower = faster copy, but harder double-tap.
DoubleTapMs := 300

AppName  := "Capslock-CopyPaste"
IsPaused := false
SavedClip := ""   ; Rich clipboard kept aside during a plain-text paste

SetCapsLockState "AlwaysOff"
SetupTray()

; ==============================================================================
; HOTKEYS
; ==============================================================================
CapsLock::HandleTap(false)    ; tap = copy, double-tap = paste
^CapsLock::HandleTap(true)    ; Ctrl + double-tap = paste as plain text

; Shift + CapsLock for Original Function
+CapsLock:: {
    if GetKeyState("CapsLock", "T")
        SetCapsLockState "AlwaysOff"
    else
        SetCapsLockState "AlwaysOn"
    KeyWait("CapsLock")
}

HandleTap(ctrlHeld) {
    static lastTap := 0

    if GetKeyState("CapsLock", "T") {
        SetCapsLockState "AlwaysOff"
        KeyWait("CapsLock")
        return
    }

    if (A_TickCount - lastTap < DoubleTapMs) {
        lastTap := 0               ; Reset so a third quick tap starts fresh instead of pasting again
        SetTimer(DoCopy, 0)
        if ctrlHeld
            PastePlain()
        else
            PasteNormal()
    } else {
        lastTap := A_TickCount
        SetTimer(DoCopy, -DoubleTapMs)
    }

    ; Ignore key auto-repeat while CapsLock is held (otherwise holding it pastes repeatedly)
    KeyWait("CapsLock")
}

; ==============================================================================
; COPY / PASTE
; ==============================================================================
PasteNormal() {
    ; Paste if clipboard has ANY content (text, images, files)
    if (ClipboardAll().Size > 0) {
        Send "^v"
        ShowTip("📌 Pasted!")
    } else {
        ShowTip("❌ Nothing to paste!", 800)
    }
}

PastePlain() {
    global SavedClip
    text := A_Clipboard            ; Text only: drops fonts, colors, links, tables
    if (text = "") {
        ShowTip("❌ No text to paste!", 800)
        return
    }
    SavedClip := ClipboardAll()    ; Keep the formatted version to put back afterwards
    A_Clipboard := text
    if !ClipWait(0.5) {
        RestoreClip()
        ShowTip("❌ Couldn't paste!", 800)
        return
    }
    Send "^v"
    ShowTip("📝 Pasted as plain text!")
    SetTimer(RestoreClip, -400)    ; Give the app time to read the clipboard first
}

RestoreClip() {
    global SavedClip
    if IsObject(SavedClip) {
        A_Clipboard := SavedClip
        SavedClip := ""
    }
}

DoCopy() {
    KeyWait("CapsLock", "T0.5")  ; Wait for CapsLock release to prevent modifier interference

    ; A new copy replaces any clipboard waiting to be restored after a plain-text paste
    global SavedClip
    SetTimer(RestoreClip, 0)
    SavedClip := ""

    ; Static: initialized once, keeps global scope clean
    static BlockedPatterns := ["about:blank", "about:newtab", "chrome://", "edge://", "brave://", "opera://", "vivaldi://", "firefox:"]

    oldClip := ClipboardAll()  ; Preserve ALL formats (images, files, rich-text)
    A_Clipboard := ""          ; Clear to detect new content
    Send "^c"

    ; Wait for ANY clipboard data (text, files, AND images)
    if ClipWait(0.4, 1) {
        ; Only check blocked patterns on short text (accidental URL bar copies)
        newClip := A_Clipboard
        if (newClip != "" && StrLen(newClip) <= 200) {
            newClip := Trim(newClip)
            blocked := false
            for pattern in BlockedPatterns {
                ; Only block text that STARTS with the pattern, so normal sentences mentioning it still copy
                if (InStr(newClip, pattern) = 1) {
                    blocked := true
                    break
                }
            }
            if blocked {
                A_Clipboard := oldClip  ; Restore old clipboard
                ShowTip("🚫 Blocked!", 800)
                return
            }
        }
        ; Text passed validation, or non-text data (image/file) — success
        ShowTip("📋 Copied!")
    } else {
        A_Clipboard := oldClip      ; Restore if nothing was copied
        ShowTip("❌ Nothing copied!", 800)
    }
}

; Auto-vanishing tooltip helper
ShowTip(msg, duration := 500) {
    ToolTip(msg)
    SetTimer(ClearTip, -duration)
}

ClearTip() {
    ToolTip()
}

; ==============================================================================
; PAUSE
; ==============================================================================
TogglePause(*) {
    global IsPaused := !IsPaused
    Suspend(IsPaused)
    if IsPaused
        SetCapsLockState "Off"        ; Caps Lock works like a normal key while paused
    else
        SetCapsLockState "AlwaysOff"
    UpdateTray()
}

; ==============================================================================
; TRAY MENU + START WITH WINDOWS  (same block in all three scripts)
; ==============================================================================
SetupTray() {
    tray := A_TrayMenu
    tray.Delete()
    tray.Add(AppName, (*) => 0)
    tray.Disable(AppName)
    tray.Add()
    tray.Add("Pause", TogglePause)
    tray.Add("Start with Windows", ToggleStartup)
    tray.Add()
    tray.Add("Exit", (*) => ExitApp())
    tray.Default := "Pause"           ; Double-click the tray icon = pause / resume
    OnMessage(0x1A, OnThemeChange)    ; WM_SETTINGCHANGE: follow light/dark taskbar
    UpdateTray()
}

UpdateTray() {
    RefreshIcon()
    A_IconTip := AppName (IsPaused ? " (paused)" : "")
    if IsPaused
        A_TrayMenu.Check("Pause")
    else
        A_TrayMenu.Uncheck("Pause")
    if StartupEnabled()
        A_TrayMenu.Check("Start with Windows")
    else
        A_TrayMenu.Uncheck("Start with Windows")
}

StartupTaskName() => AppName " (AutoHotkey)"

; True if a logon task exists AND points at this script's current location
StartupEnabled() {
    try {
        svc := ComObject("Schedule.Service")
        svc.Connect()
        task := svc.GetFolder("\").GetTask(StartupTaskName())
        return InStr(task.Definition.Actions.Item(1).Arguments, A_ScriptFullPath)
            || task.Definition.Actions.Item(1).Path = A_ScriptFullPath
    }
    return false
}

ToggleStartup(*) {
    try {
        svc := ComObject("Schedule.Service")
        svc.Connect()
        root := svc.GetFolder("\")
        if StartupEnabled() {
            root.DeleteTask(StartupTaskName(), 0)
        } else {
            ; Task Scheduler starts the script with admin rights at logon — no UAC pop-up
            user := EnvGet("USERDOMAIN") "\" A_UserName
            td := svc.NewTask(0)
            td.RegistrationInfo.Description := "Starts " AppName " when you log in."
            td.Principal.RunLevel := 1                   ; Run with highest privileges
            td.Principal.LogonType := 3                  ; Only when the user is logged on
            td.Settings.DisallowStartIfOnBatteries := false
            td.Settings.StopIfGoingOnBatteries := false
            td.Settings.ExecutionTimeLimit := "PT0S"     ; Never stop it
            td.Settings.MultipleInstances := 2           ; Don't start a second copy
            td.Settings.Priority := 4                    ; Normal priority (default is below normal)
            trigger := td.Triggers.Create(9)             ; At log on
            trigger.UserId := user
            action := td.Actions.Create(0)               ; Start a program
            if A_IsCompiled {
                action.Path := A_ScriptFullPath
            } else {
                action.Path := A_AhkPath
                action.Arguments := '"' A_ScriptFullPath '"'
            }
            action.WorkingDirectory := A_ScriptDir
            root.RegisterTaskDefinition(StartupTaskName(), td, 6, user, , 3)
        }
    } catch as e {
        MsgBox("Couldn't change the startup setting:`n`n" e.Message, AppName, 48)
    }
    UpdateTray()
}

; ==============================================================================
; TRAY ICON  (built into this file, so the script works on its own anywhere)
; White lines on a dark taskbar, black lines on a light one; faded when paused.
; ==============================================================================
RefreshIcon(*) {
    try TraySetIcon("HICON:*" TrayIcon(IsPaused, TaskbarIsDark()), , true)   ; true = keep our icon even while suspended
}

TaskbarIsDark() {
    try return !RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "SystemUsesLightTheme")
    return true
}

; Windows broadcasts this when the theme (light/dark) changes
OnThemeChange(wParam, lParam, msg, hwnd) {
    SetTimer(RefreshIcon, -300)
}

TrayIcon(paused, dark) {
    static cache := Map()
    key := paused "|" dark
    if cache.Has(key)
        return cache[key]
    data := IconData(paused, dark)
    want := SysGet(49)                 ; Tray icon size for the current display scaling
    best := 0
    for size in data                   ; Sizes are sorted: take the first one big enough
        if (size >= want) {
            best := size
            break
        }
    if !best
        for size in data
            best := size
    b64 := data[best]
    DllCall("crypt32\CryptStringToBinary", "str", b64, "uint", 0, "uint", 1, "ptr", 0, "uint*", &n := 0, "ptr", 0, "ptr", 0)
    png := Buffer(n)
    DllCall("crypt32\CryptStringToBinary", "str", b64, "uint", 0, "uint", 1, "ptr", png, "uint*", &n, "ptr", 0, "ptr", 0)
    return cache[key] := DllCall("CreateIconFromResourceEx", "ptr", png, "uint", n, "int", 1, "uint", 0x30000, "int", want, "int", want, "uint", 0, "ptr")
}

; PNG images of the tray icon at several sizes, as text
; d / dp = dark taskbar (normal / paused), l / lp = light taskbar (normal / paused)
IconData(paused, dark) {
    static d := Map(16, "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAESSURBVDhPtdCxS9ZRFMZxTZFQRBAdzQYJTAgHcXEUAsGt2cHFwQbBP8Um/xXH3KyhRNdXdLKhIQQdqs8jF67ye++LuNQXzvI8zznnnjs09L/ACk6w3nrPgne4gyTBWpt5EiziFl+SvMJRHbLaZgfAAn7hOyaLlmQMn/EnyXLb80iS17jGaZKpxnuJY9xgqes9BEpzD5eYb/0CZnGOH+XMPjPJ13pn4QIbXb98YtV/11wvyWg38B7b+FgDe82Ararv19xmkuFu5pG6ZafRPpQBSUa6+gCYwF/8xLdOXdcXzLY9fSR5gV0c4LBTn8rz++5+Crypn9bW2zY7QNmAs3pvH7hKMt72DIBpzLWVZKbN/hPuAb2hdelU8g+xAAAAAElFTkSuQmCC",
        20, "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAE1SURBVDhPzdMxS1ZxFMdxwxKhaCgcQghfSa/AV+PaEEEQOLVZGDU4NOUz6NLUEA7Z0mJD4lSQb6Cihs+RA0e49/D4qIv4hcPlnt/vHP7/c+6dm7tqcA9PI+Jh1y4N7mI/IgKHeNA9Fwa3sVfNPtXzAEvdey4RsYiP1eRF5vC43r/mGHrNmUTELXyo4pdDDc8q/yXHMdSmEhHz2KmiN11PsF76Xo6l6yPwvsybXRuC5+XLsSx2PU+2gHeDBaxExM3uS+oWy4Ob5HjujEx4kuIp+I/JyFTk6fGv+V9106MyvsbbLMjvbmQq8LmabJU/Y7X7RuAHvvd8Usv40/MzwU8c4f6U2Mfvczc8BL+GM+rg72UbrmEbu1NiUku80euujtrg8YzYze+x150JNvBtRuRPcPGG14oTpzXsJLhsHnYAAAAASUVORK5CYII=",
        24, "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAFoSURBVEhL3ZW7K4VhHMePy9+BRUa3WCiDQlEuk8FmcWRgMuAoKcmAQRYWk0kG/4DFpUxYzcxKyuXz1VPP0e/8zsXrOMPJp3719nwvz/u+z1tvKlVNSOqVVO/XKwJwKEnAmaQ6r/8JYD+UZwFOJNV4X1kAu6Z4A3iO18fe+2uALVM+FdcGgLe4duQziQHWTfm000aAz6gdWC0RQMaUp70eACaMZ8/rRQEWTXDe6xZg0ni3vZ4HsBDNH8CM1wshaQx4iblNr38DzJq7OZXUBrR4n0VSE9AazsFk17wvlHdnDRbgHWj3/oCkhuwn6wFGc8xAI3AO3Ma5A16jeTjHHAG6oh5u4t5kr8LTe38e0RgKBr0WADqi/uC1RADXsaDHawGguVIbLAFDBWYuu4GkWp//kXAO5tyKAjyVu0EauAAuS0zQl322OpDUCawAqyUmA/T5bCIk3fj3XQjgsayfD9AP7CSYcZ/9X3wBiRuipwyZM8AAAAAASUVORK5CYII=",
        32, "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAIWSURBVFhH7ZbNi81hFMcnoby/DBEmJGHKO8lCNjas+CP8C9bs5Y9gNSsrK03JQiIlkTILQsbLmEQpmT5fnev703PPzL33d19moe6nzuLe8z3neX7P75zz/EZGhgzpA2AMuC7pSPYtOsB24JUkATPAoaxZNIAtwItYvAL4CIxn7cABRoGnXvQLcAl47t/vgb05ZmBIWgc89kN/A07E/8BO4LU38UbSrhzbN5JWAw+8yA/gdOkH9gDv7J8CdpT+vgBWSLrn5D+Bs1kTSNoPTFv3UtLWrOkaScuBu076S9K5rCkBDkZtWP9M0qasqY2kpcAdJ/sNXMiahQCOAbOOeyJpQ9Z0RNIS4LaTIOli1rQDOAV8d/xDYE3WtAWYKArufPbXATgc88F57ktamTXz8LHf+ttpjcAbUVySjgPbsn4hYlZYfwC4Asw512R0U9Y3AVyrFs8AX6Pnc0yJZ8VUjq0AbuaYJoDLwAfgky2m3UyRoKn/M8DuQjvr+CpXvI6rOWYewKoomsJi9n920pNZX+KpGMz5FfzL0/H4WyFpWTxBtxsYyCAKfCLVBo5mf4mv6eoExrK/J9IGzkQ7tTJg38A34Iuommzx8THdxhq1Ym3bjqmNZ8OjKnEdgLeS1udcPQNs9Hita7WG1v8DsDZasAvbnHP0jGug8R1YF3fNYGrAV/NEMVI7WnxBRfvmXH3heVDLcuyQVvwBJOUDxuWImo0AAAAASUVORK5CYII=",
        40, "iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAJSSURBVFhH7Zjbi01hGIfHIeQ8jFMII4fI4Ya45I/wp3BJkjsuRcnFpMkopSaiRJnEODVDJiJJDimKC3d6fnqnb+X1tpdZe++19t5pP/Vd7PX+3kPfWu932D09Xbr8R0iaKWlufN4RSFoPjAHvgP3R3laANcBr/eE7sCfq2oKklcCEK24S4CuwK+pbiqQ+YNwVdQ04735/AbZHv5YgabGkx66Ye5LmmA0YdM8/Apujf6UAC4D7rohHkhZldknTgCvObo2z4e8oFWHLCHDXJbfOXVpDNwMYdro3wNqoKxVgNnDLJX0BrIi6DEmzgJtO/xJYFXWlYIswcN0lewWsjrqIfZfAbef3HFgWdU0haTpw1SV5C6yLujyAecCI838qqTfqGkbSZRf8PbAxaqYCWAiMujij9izq6ga46IJ+ArZETVGAJWn2sngjNrtRVxjgggv2GdgWNfWSihxzce37nFw/6wI464J8AHZGTaMAy8MOdMM6PupqkhriVOacAtiW9QB4loa9msInFkn9ttw4/4e2eIcc1oRTz6R1l3fMAxiKvnkAx6N/LQq9JZtBSceAJzXGOPArBbsUffMATroiJmrEtXGu0Az+C9tvgR8p0WC05wGccBO1NdpLI3VgUwVWevxK579mC9wR7aURChyI9jyAo+0ocBjYVHCcaUmBdgoBfrpkhXE+1d1TJM0HvmXJGqQ/xi0V4ABwusFxKMbr0nGke8leOyzUOfb5m18lpEvQnfjVFyX9PdIX45ZGuls01cWV348l7QYOA0caGAdjvC5dOp3fiN1u7zugkKMAAAAASUVORK5CYII=",
        48, "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAKJSURBVGhD7Zjdi01RGMbHd75ChCSkJEUpokjJjTvlT+BCyZULRYTElZqiGEVKKRJSQlNqIiVSUlJIkaZJUYobGb9Ha+xTu6cz29ln73XOrtm/ei/O2c963neds/b66umpqampaQawANgLrPFnlUfSMuC9JAE/JW11TWUBFgPvQvENgB/AZtdWDkkLgTfp4lN8BzZ4m8ogaR7wKl0xcA8YTn3+Jmmtt+06kmZLemHF94ZnwG77/guw2j26BjATeGpFnjPNPns+CKxMa7qCpGnAIyvuousCwH7TfZK03HUdA5gCPLSirrgujaSDpv8gaYnroiNpEnDfirnmumYAR63dW2CR66IhaTxwx4q4JWmca0cDOGntXwPzXRcFSTcs+V1JE1z3P4DT5vMSmOu6UgGuWtJ+SZNd1yrAGfN7JmmW60oBuGzJBoCprssL0Ge+TyTNcF0hgAsxk8T6cUYAzpr58xh/c9nDc4QmL1q/a8okrODAn1S+MEFMdF1LNJnqhsNQAo4AJ5I4DKzytq0Qpk3gQMrrGHAqOT+k897O/U8AO9MmWQBDkua4RxbJWjLgXhkcd49MJO1xhyzybsySPdRX9xkN4Lx7ZBJmgDCEwgo7SjxojFX+scI9skg6MJgq8HGTHI3oC+dr9yhEmIWAXyV2YL1rohJ2kGV2oOOH/roDFexA7pcM+FylDuwCtueIHTaNdrYDwFLgd6qAQgDbPEdUkntPvJB2ATZ5jugAh8KhHPhYMC7l3uuURdgphgN+kXDPmjGFpHXhBSwQG8Oi5r7RCWMXuOmzSTuE65Rws+05ohJOU15IEYAtniMq4RYuOf4NJdflReJ6aTcQeQGmJ9frbYd71tTUjDH+AhTZjxlkJYWdAAAAAElFTkSuQmCC")
    static dp := Map(16, "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAEGSURBVDhPtZJZK4VRFIYPERlCdBDKhUznHxx/wA1SKEPmcM3/f169Wlv7W9/hlPLUuth7zUOn818Ai8AZsJp1Q5G0ADwAr8Az0M02PyJpLpxOgGngEHiTtJRtWwCzwKNLlzTmP0mjwJGkF1eWfb6JbLfhPF7rIsgx8CRpvtYVgxngEriWNJX1BpiQdO4krSAuEfiQdO8gwHrSdyPBHfAeVY7UBmvADrDnXoH9FGDLgwR6YbdR6xtElu36T9Kmh9vIOghPPtq4iTUWufJqJU1mnwbOIGkXOAD6SXreRvZp4UOStAIsF/G7NflBuALgNAbmayzi90U5rl+JffsufFhf4vfQ/v/KJ8hdUZ7q2n16AAAAAElFTkSuQmCC",
        20, "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAE5SURBVDhPzZPJSkNBEEXjrAT3bvwCQcQBccAIxtkgzi6MC8WFijihn3+uXKnFexWNySZ4oDZdt4uqW92VSq8BRoAFoJpzXSNpCDgEPoFzYCxrOkbSINAAnoBd4AE4lTSatX8iaQDYA96BRZ8B08ArcCxpON/5FUn9wE4UWy7mgFngzTbYjmLuRyT1AZsuJmk15w0wH0UbtiXnSwAbwAuwknNFJM0Bz7bF9uT895iS1kO0D4z7LOtMTFGVVA/9dkunkmaAD+AeuAXu3G1JFLj7yFtnve+VvHbBCaBm3xzAjZ9ISRQAB1FwLYrXgMmsKxGP+CSfm7Ckmc/bAly4w/h2OfzYr1t8awdwCTzG6DnsW9cFp2J79RzAlpfobed7vSM22IzRc1z5N3XVIbAUmz7KIeksnljnBf8VX4Ert67FAN0PAAAAAElFTkSuQmCC",
        24, "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAF/SURBVEhL3ZXbK0VREMZ5lwckd0lyS+7kkpQ8IZc8eEByv8sTf/3v01eTtnGOttN5kF9Nu/Y3s2bPzNprNTT8JSR1SGrM7+uCpFXgGdisexJgGXgEbuO5kX1qBlgEnoBzSbPAMfAiaT37/hpgPha/AQbjXRdwEe1ayzGlAWYKbRlKWg9wGUlWilopJE0BD8CdpJGsG6AfuIoKl7JeFWAiFr8HxrJeBBiI9jnJQta/AYx7YUnXwHDWKyGpzxsg2jmX9U/ciui3bUNSG9Cc/YpIagJaPYeoxFVPZz87ejG3xYu7rx6gA/xlrdnfxOInEWN/xznGW7ivkvMWcCBpzwaceshA7xfnwB/lVko6A/YjZh/YBVqy/zeA7aiqO2smWuMvPsxaKQoJ2rNmPJ96JPDQJuPHyjYau+2wpsMveuqt5yR+ZnN1tqNaE4xEEldS0UKfzLF/g9glPvCmfTZVsVnfcjm2FMCOpHfg9Qd78wxybCmAzrjJfOFUM+v9OfZ/8QENSlDfi3Q0nwAAAABJRU5ErkJggg==",
        32, "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAIdSURBVFhH7ZY5b1RBEITNaU5xyMZCIMiISJwQECAQQuKyMEJgjLlsDmNz/v/gK1RWrfRo7+573iNA2pI6eG96enqmq2tmbm6GGcaApFPAbeBiHZs6vLikl8Af4J2kC9VnapB0AngBfAc+A7vAhqRz1XfiAOaB58AvYB24Lmm18X22zpkYJB0HnmWx95IW8v8MsJb/a/6uc8eGpKPA0yzyAVhsjnvnwGuPmxvmSHN8LEg6AjzO4pvAUvUxzAHgTfzMkZPV58CQdBh4mKBbwOXq04S7AXgbf3Nlvvp0hqRDwIME+wRcrT79YF0wR1KOVXOn+nQCcB/46VaTdK2OD4M5Eq44+RVJx6rPUAD3gB+p+ZU63gUpx0biPDGRq88+5NjvRGS+ALdCrsWuzI5W2P88cDPls1g9aj0JYDnyaoXzxC1JX21Ru6E9Hq1wB2xnjonrOI7325urc/4BcMPaHlXrmVvLgbZr/1dED3qLel4zjom5XOfsg2vlo+qZ+zkBvKs99RuEqOKmpI8uXTNOJw70Q7TAKnegBCYiREZkeC+Btrs/b4ReAqfr+EgoCSylRIPMHTOVBNzPbksTy8kMMnPFBHQSQzumM8KBFWAnp9Bm34BXI0twP0RcLkVi28xl6iRa/w+iB5bXhTbzSfndWGOMjNwPfor5fqj17mfW/fWJccAJSLrbkOjK/Gp+kPjiGU35BqEnpx1s+I03QwN/Ac1/nAriJGanAAAAAElFTkSuQmCC",
        40, "iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAJ6SURBVFhH7ZdZTxRREIXBDVfcIoY3/4BxS0xAI8aNEBFUcBfjvqH4/1++Yw6pNjeVGaa76QFi5iSVTKbr1q2uqlNVPTY2wgj/ESSNS9qf/98TkHQceAK8As7l57sKSUclPQN+AN+Bd8DZrLcrAI4AK+HYF0lfLcCapNNZf0cBTERa7Zyjdx+4Eb+/AW8kncrndgSSDgHL4YzlUUUQSbeBn+Hka2Aynx8qJB20Q0XNLfu/Uge4Uzj50iQqnw8Nkg4ADwvnnOKJHnrjkfJK7zlwLOt1Ckn7gIXi0hVJh7NehdCfL/RXTaqs1wkiIg+qy9xW3F6yXobrMr3U061eqhViQtyLmvIlL5qkK8pisSKUpMcmWdZrjVTwnhQnss4gBLGWCtYvZWK1AjBXtgxJJ7NOXThqjl7RNxcd3axXG5Ju2rmYDG66rZ2rUDR3v7CdXGi1YACzEbnPEbnOxpZJYrKEbd8xb8ZnvZ4Itl6Pgx+BT260kQ6nx2/vWprKZ/vBNRtMNoNtw1PHy4Vtf4i77taKZIwwHzTbqsHvdNhIle4Nj7N8th+Aq8AfLxNhZz1aVWl/vVaWIoJXIgWO1D+J9vA+jNd2UNK1qDdHq8pAKb5rtlYEt0JE921EYS4/74eI4GbJdEG0vggGbtfB4a1fwb7tOji4ztoiOXgrP+8HSZd32kEz3LN5sqbMBEmG62B8f6wV/auJVD31TLbbGWLge4X/HRHZ7I01xb3Pk6PxotEIwHSkzNOmicxIupDtjbDnECv8VAs53+kW3QvFR5MXThd8E/FCsNr590iJ+LYwizd6sHSQ/LKjQ/8+dh8DLgEXm0hMk+lsb4QR9jr+An610TKB5DXMAAAAAElFTkSuQmCC",
        48, "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAALMSURBVGhD7ZhZaxVBEEaTuO8rRhH0SRTcFRWNaEyMS9yJO9G4a0Sj///hfPJd6spQXJLMnbkLZA4U8zA11VXd01XVPTLS0NDQ0AlJm4FTkvbkd0OPpO3AS2BJ0gdJB7PO0CJpq6QXwI9w/pufwIGsO3QAW4A5Ow98BL4DnxwEsCBpf/5maAA2Ac+ARTsNfAVmYvY/RxDvgL3524EjaSPwJJz3zP8ELvsdcCxWoh3EvKTd2cbAkLQBeJScv5p0TsRv5ZVxMG+BnUWdgSBpPfAgOT+R9QxwMgXxGtiR9fqGpHXA/eT8jaxXBDhd2CMOxql2W9brOZJGgTvhdMt5SZNZrxOSzqUgnjv1Zr2eYecl3S46D0xnveUALhRWzkHMuXJnvZ4A3ErOO1WOZr2VAC4V7CxKeupUnPVqBbiZnL8raSzrrRbgSjEI4LGzWtarBUnXk/Oz3shZryzAtRTEQ2e3rFeJXg+SJsf2a5mcFv1a5rp/zxaFjdbube5lnTpxBY9xKiWIFoVUZ+dt0E8PcDbetaTbviYOPGckXQw7rg+2+b4wpoOYLr0SwNHCzNtQS6IZc1Bt+R0tQan0F4XQVXwp2Wu34UX5BZzPNpYFOA78CYOdxL1Me1XcZe7KNpYjeqg3wJfCxOQx2vI3N4crEn2Ol3MGmOog//v8CKRUZxkBvIoAPAmzHcaYioo/4YNStlGJaKEX2jNYIQBvWMu+rNNT3EHWGUDfD/1NAEMYQOlNFoeZoQnAB/fDqxVJR+Jc7O/7H4Bv3lIatRO+wFq1FIqkV+FQHqOnxAWWB3ehaafCbsUVuP+3du5jXE19jditRDWeqK11Lkucj8eqSLbZsKbwbTMw7k3YhbS+G8j/7383rleqZiG35b4ULnWeqEycplyE7ICf3YqD8KFoPI/RUyL7+Cg4H6mwW/FV+2SdNxyl8MA+G1SRbLOhoWGN8Q/DXq4mCdHFvgAAAABJRU5ErkJggg==")
    static l := Map(16, "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAFUSURBVDhPtZK/L2xRFIUvJiLemHvP2d+aubfwoxAJElGIRvmSl0heJ1MqNAoKiT+Fyr+ipEOB0BKv8grFi4QCb+QkjOuMiYYv2c1ea+9zzspJku/CzOYkHZjZz1j7lCzLZoB7Sf8ltSQtxJ6ueO8ngTvg0Dk3AuyGJd77+djbgaRxSf+AEzMbemn3S9qT9Jim6Ww08kaapmPANXDqnEsjeQDYB26dc9OR1h6+kHSVZdlorAeq1aoknQN/wzPficBRnuctIIR2CSyW9RAiEPoPwWdmF0mSVMqGX5JWzGy9Xq+HRRvlBWa2HIIENoMP+J0kSU/Z0yacAqyWe977JaDVbDb7yv0OGo3GD+AJuDGz41Jdhxvkea54JqbXzNaALTPbeS1gO1z/3bu7AUyE0OLy3k/F3o+oAGchyJcv3C7gT1EUg/FAB7VazTvnhuMqioLY+yU8A8a2Tt5op9SZAAAAAElFTkSuQmCC",
        20, "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAFySURBVDhPzZM9L0RREIav+IiEbLLnfWbPtRLrl/gFfo1WIRKJRKVDCIVChYJGpRAFGg0FUZHwBxAaMnIke8/GxzbiSaaZ9z1z58zcUxR/Ta1WC2Y2W6/Xx3Kta0IINeC0LMs34BoYyT2/JsY4BBzHGN8kHTUaDS96UZal5d4fabVag8ChdyZp0XMhhGkvDpz7GPIz39EPHKRrLrcLkuZS0TMfR7v2Fb2S9lKx9Vx0gIWk+ziGcr0CsJ1mtppr7YQQ5lOnhz6eXHcGJG19LiDGOF4URV9uSvSGEEb9JqnogZkNVxzAjF/DN2lmHq/AbsWU8O7N7AX48KfFrVRMwISZrUpak7QBvEi6rpgSwIl/FNh0v5mtAZO5rwJwK+kqzzu+DElPef5bgDtJN81mU3n4y5H0+OOG25F0n15GR3he0nNXBYEpM9uRtJ+HL8uXWBRFT37u7/ANAg+SOiLl9/1/zM99CbBkZpdAR3jeH0FXBf8V76h7dclvWj96AAAAAElFTkSuQmCC",
        24, "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAGzSURBVEhL3ZU9a1RBFIYnMT9g977P2cs2aiOWRkUbAxaCCgb8qCzsbFRSmMpCjSCBIBZqIWlMk8pKLPIHbNRAqmhrrbUgglEiJ8wNk5Nssq4pQh54m3nPx5yZO9yU9hJmNpZSGonru4KkubquVyUtpJQORP+/AGY7nc5qI+BNSmkoxg2EpBe5qGsG+J4neR1j/xngqRc3My94w9fM7Dzwy5sA8zGnbyRNF0dys/SAcTP7kyd5VXp9AUw1xSXdjr5TVdU1nyxP8jL6PZF0r9j53eiXANe9Sd7Is+hvApjMZ/5b0q3ob4WkK8CPvKEn0V9H0p3mQoG3ZjYq6WiMK6nr+rCZHfN7KCZ5HOP8PE83xUsBK8DxGO+02+2D/snGnHzxlzcEt1qtQ5LeAcuSloFPkn7msS9tCM5IOlVs4nPOc3306WP8JjwwT3Uheg5wIr+PL9HrC2AxNzgTPQc4sisNgPtmdnELTRQNhmP+jvg9NO9hO0n6NlADf8HAe+BDL5mZ+w9i7t4AOAk8BB5toyngbMztC2Cp2+2uPZxecl/S14F+PpLOmdlzST3lflVVV2Pu/uIvjoeo0NG/tvAAAAAASUVORK5CYII=",
        32, "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAJvSURBVFhH7ZbLahRREIZDiIJmZk73+f/qnuiIiogX8DpKcCFu3OhKH8JXcK178SF0lZUrVyKICxFFCKIIZqGoGHNxEAVBlEQqVIdOOZl0MpOFkA+KuZy/qutcqk4PDW2xRR+kabpHRG6JyEk/tunEGHeLyNs8zxdJzmdZdtxrNo0sy3KSr7MsWxSRRf0k+SXGeNRrB069XgfJSZ05gLkY41WSr2wlPpE86H0GRpqmgeRze9g3AGf0/yRJ9pJ8Z/+/DyHs8759IyI1kk/sIT/SND3nxg+Q/GjjUzHGVnm8L1qt1g4Ajyz4T5IXvEYBcJjktOneiEjTazbCdpIPLOivGONFLyiTJMkxknOmf1mr1eg162EEwH0L9pvkZS/oBsnTJDvqJyIvQgip11RhmOQ9C7IA4IoX9CLGOC4i3y35pwDqXtMTEZmw+tYDd8mPV0FETmh/0DgAHo+Nje30mm6MkLxbNBkAt+1wtQHs8uJuWK9oxxiPALhO8o9N5qFWk9evAMBNW3Z1WDL9br+/as17nzLaKwBMlXyWY9h23PE+KyB5TUQ+A5gxm9Ner0F0Fr7+PSGE/aUHd9S/iKXbAeCG9/mHPM9H9dAUpr0fwKxtyVmvL2NdcUGX3bZgOc6ay78a7XZ7m85gvQkMqhEVK7KUAMlTfryMXtNFAvq+4Mc3hEvgvJbTagbg0MATsIuoYwnMA5juYbPFyV+rYtaD9oZnRW+oYiQ/hBASH2jDNBqNmOf5uLbYtUx1VZvW/0OMsaElWMWazaaa+Bj9oNfyZNUzYJfPzCDPwDCACZJFe+5pptM3qFEfqC80YFXzvlusxl9NHejVCm6doAAAAABJRU5ErkJggg==",
        40, "iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAALXSURBVFhH7ZfLaxRBEMbXGIyou5Pp76ueHVxZXeMDxcdFMUf9I/xT9KiIeNOjKIgHEVFBCIiiIAoG0fgiUQxKRIL4IGBAD97ESIUdaApXZ8zuJsj+oFh2+qvq2pru2u5SqUeP/4v+NE1X2YdLgiiK1pMcJzkdx/GwHV9UnHM1klPe+zkRmSP5FcAeq1sURKRKclITC43kFxHZZfVdJU1TkpzQhLR6AG4AOBdUciaO4+3WrytEUTRI8qkmo0byQb1eX6ljAC4FSX4kudn6dxQAZZIPg+SexHEcBZJlJK8FSU4nSbIhGO8c2kZE5H4w+Xi5XIbVlUql5QCuB7q3cRyvs6J2M0DyTjDpK+99YkUBK0jeDvSvSaZW1C76ReRmNpmIvHHOrbUii65LkneDJF9Wq1WxuoXSR3IkmOTd4OBg3YpakSTJapKj2ZoF8DyKotjq/hkRuRok915ENlrN33DOVUiOBX1yTJ9ZXWFIXgxe6ycAW6wmL5VKxWn1gt0/qtW1utyQPB9U7rNzbpvVFEWT1J2fNXddn1n/LATJM0HlPnjvd1rNv5IkiQ//gUje0h1vda3oA3Cy6ThvAGZIPgLwgqTaaJETi/e+oe1GfZsxHmvzzuI35xrJVUndXdkvyxZ09j17liSJJn3F+rYCwDH1sXF+Ez/XW9IKHhWRZwCsTZD8oQEBXLaOrQBwIngjkzZuc66zuSr4JxqNRkTym06mBwI73goAx7ME0zTdasfbRq1W0x24oASTJOnc8at5/ltQgt77HXa8bYQJkrxgx1tB8kjXE9SjFMlNecw5d7orCeopBMD3rH+R/FnA5n06ek8RkTUkZ7NeVtSa/a5h47YVAPtF5BSAQqY+JA/aeD2WHENDQwPOub3e+2E9MOQ17/0+c/PrCHoJupct+KIGYEpblQ3aNpp3i1k9mdgdmsc0yY7fj0Vkt4gcAnC4iImIfh6w8Xr0WOr8Am3/V/4itbvqAAAAAElFTkSuQmCC",
        48, "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAMOSURBVGhD7Zjfi01RFMfPYAj3du453+862+iGNJKi1BVFSl68KX8CD0qePCgiJJ6UojBFSikSUkJKTaREalJSSJGmaYpS5kV+jNZ0rnZrrpm5P87cW3M+tTp173evtdc++6z9IwhycnJyapEkiRORPUmSrLH/dTzOuWUk3zvnRkmOANhiNR1LHMdlEXmXJIl2flRE9Pk9iqJNVttxiMgikm9M58eeIvItjuP1tk3HUCgUSPKV32kA90j+8pL5GobhWtu27YRhWCL5sjry+gRwWv8juctPiuRwFEWrrY+2AaBI8pnfeZLnjGavP61EZBDASl/TFnp6ehYAeGxG/qLVKST3mW/jU5Iky61u2ujt7Z1H8pEZ+StW5wPggEniQxRFS6wucyqVSreI3Dcjf83qakHyiJlObwEstrosmUXyjhn5W0EQdFnh/wBwwrR/7ZxLrC4TANwwI383CILZVjcZJE+ZJAaKxSKsrqWQvGqCPgyCYK7VTRUROWP8PY+iKLS6lgDgsgnWXy6X51tdvZC8YPw+FZGC1TUFyb4sg2Q1OGOQPGucv8jiNbd6eo7hf2hp3VanmaEruIj8NgVijtVNCb/Upaabsj6ShwEcVyN5KI7jVbbtVNCyKSL7PV9HAZwEMFKNmca/XfebiON4h+n8v7egv/sGYCgMw8j6mARdS/r1wOP7qm76fFMNgGPWwYSQ3K0N05WypvlJ1bsx0z0UyS9VP9a3b+mp7rz1MSFaAXQK6QpbywA8IDk2V0n+IbnC+piINIHBagIAntgYnmmZddZHU2gVIvkj7UBTCaRvcJ3VZIruIFucwPQe+vMEOi2BRj4ykp87JgER2Ski26ZqALZXy2hbEiiVSktJ/vTXgnrNrCNbbYxM0SmTjvy4jtVr6Qq80cbInDiOD+qhnOTHZgzApbr3Oi1Ed4rdTVrOzIVkRT/ARs05t0EXNet3OugGcNNWlEYMwIDebNsAmZKepsZ1phFL9/ubbYys6dLjH8khAMONml61A7jeshuIenHOLdTr9WbM+szJyZlh/AWpE+LFF2tcmAAAAABJRU5ErkJggg==")
    static lp := Map(16, "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAE1SURBVDhPtZLbSgMxEIZTURStrJt//ompSr1YPL6BvoA3WgQVtOKx1F7r+4MMZHWbZVEEP5iL5J9TJuPcfzEYDEDySkRirv1IURQlyWcAbyIyCSFo7tNJWZaFBQEYhRDWSJ4BmMUYJfdtAWBdRF6sdefcYrpeAHAuIlPrLAv5JlV7SMFLmWxJLkTktSiKjUxzjmRfRG4BjGOMq7meWCZ5bUVaSaxFAB8kn1R17L3fbuo2RCtA8lFE3lOXvS8H7/0WgH3v/aGqTr33R80EJCtVnYUQjs2vLMudpj5HqrLXvAsh7Npw56p2sGjPAHCvqqPaANyp6mQ4HK7kATk9AAckT0meNM3at9/IA1rYIpHcVNVQm51bk++gp6qXtnm2jbWl801jubqpqsr+u2+LVZudf/P+P/EJ4r4shcEK7lAAAAAASUVORK5CYII=",
        20, "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAFjSURBVDhPzZO5S4NBEMXjrYhFMu/NZxFJkyqCiAfigRG8L8TbwlgoFirihf798mCLfBMMxiL4g2l23g6zb2YLhW5TrVaHzGw+y7LRmPsLA+5+RPILwEW5XB6Jgk7oN7NDks8Adkk+kjyrVCrDUfgb+gDsuftHqVRa0IG7TwF4I3lSq9UG44V29JLcUTGSS80JADMA3s3sSHY0536ix903U7GVmBRmNpeKHsqWmM/h7usAXkkux1wzAGYBvMgW2RPzotfM1pJo38zGdBZFiR6tkLtvSE9yu6VTktMkP0k+ALgDcG9m6zlRQt0rL5306V7Oa4nGAdTlmwLArVYkJ0oAOEgFV1PxerFYnIi6HFpikqfxXMgSko143hYAl+pQ3y5GWvabFt/aAeDKzJ709BhmJt86K5hl2aSmp0nGILmlIWra8V73SBNs6OkxzOxav6mjDt19UZN29+MYJM+1Kh0V/Fd8A7ARQKgqeV5rAAAAAElFTkSuQmCC",
        24, "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAHNSURBVEhL3ZXda1NBEMWv76bkzpwz9yaNFjHiF1K1fuAHIohPKkbxwQcV0aa1aWvxSf98ObCVODGQlDwUfzAs7JnZuTs7d7eqThMk26qqzuT5lUDyMYDvEfF85UlIPiR5EBHfNLr7s+xzYpqmuU/yEMAXAFsR8QHAkbs/zb5L4+53tXhE7JK8WOb6AL6qXACe5JiFAXD7uCwALk1rZjYAsK0kJB9NawtB8ibJfZJ77n4l66Lb7W4AGJcdPsj6XCLiRll8YmbXsj5N0zQXSvkOzexe1meo6/q6Fo6IHXe/nPV/Udf1eTVA6a47Wf+DSqF6y9SGvV4PZraW/aYhebbf77vOoexkAuBW9qu0mMri7jrQsQ7Q3Xf1ZZ1Ox7O/0OIkP5YYHfi4xBxpVzPOAF6QfBsRIxnJT+6+V9f1ub+cC/ooADskP0fEmxKn8fVgMLDsPwOAl9qVma1nTag0pSzvsrYQxwmapomsieFwuLaKBBOSm/qxsrVte1XdVhIsf/m5+8jMDkoSjdnUFPsA3p80gdp2pJ3Ms9IMmzn2dKAu0YWnH6fcTTOm67u8csvj7q9I/gLwY56R/FnOYHkA9PSS6cGZZ9Lbtt3Isf8XvwHQel3XjBeltQAAAABJRU5ErkJggg==",
        32, "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAJZSURBVFhH7VbLbhNRDE0CbSmPTGZ87MmIEdlELCI23bBggUAIiacoqkop5VkK5U3/f4VO5FRTK+/HAqlH8iKxr6+v7/G5U6ud4xwLoCiKy6p6p9lsZtG3cvjmuwBOVPVdkiRpjFkZOp3OJVXdUdWfAI5U9YeZHaRpmsTYVWDDzF4C+ANgv9Vqdcxse/BbRK7FBcvEuoi84Gaq+r4oCvBPVb0KYM+L2OPvuHAZuAjgmW/+od1ua9XJkwN47f5dcqTqXxQXADzx5J/MLI8BBDkgIm88bqcsy80YMw8aqvrI23sIoIgBVXAazOwt48mVbre7EWNmQd3MHvrmn7MsK2PAMJRlmZEjXsQ2uRNjpoKZPVDV3xy1NE1vRP84kCPkCosQkee1Wm0txoyFiNxX1V+88yzLrkf/NPDrOGAeAE9J5BgzDHUAd11kvmRZdpvk4ommZTbvnfFJkrTyPL/F66NYAXg8sRMAtszshG3nQifeV5qI8DRjZ7zX661zAkTk2NdxPfMcmdlfHi6uOQMAN6ntVLWB+WgdMmmc/wjXg/6mvu40jxNzK64ZBt4VWzWwTS/keKB+o8AOkTeq+tHfhmqeqTgwDA2q3KwFLEuICMpwvwDOeHRW4c90v4A8z69E/7w4LcBlmK0camz7SgrgBHAsnVh8dEYZCcexYxFjJ2YWNKhmIvLduzDS6BeRbwBecSRjorlBccnz3DiGk4zXNK1o/VdYcznGJGOn+N0YEyyCOj/F+D74HY811/39ZXKABdyrSHRk/hnzDxI+PHMr3ygM5HSSjX/xzlHBP9BLfde0Lgi6AAAAAElFTkSuQmCC",
        40, "iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAK+SURBVFhH7VdraxNREE2aWt9Zs3fO3CYE6od+KogvEHxgxSdFrX36SK1YrdZarf//m5wwC8vQ2N100xbJgYGQnXv33Jl7ZmZrtTHG+L9Qr9VqDf/nqQCAS6q6LCIfpqen4Z+fKNrt9gUA6wB2VfUHgE+dTid4vxNBt9s9D2CVxETkm4h8pwHYTJKk5f2PFbOzs2eZVosao/cMwH3+DiHshBA2kiS54tcdF6ZU9Q3JGKHXmUBCCI8A/CRJVe2ladr0i0eNMySU3TkS5X95hxDCY5JU1R0ReU8R5Z+PEpMi8jJHbpmp9k4sOZZyRpf3822M8aJ3qhoTIrKQU+vqzMzMOe+UwwSAFzn/NYrKO1WFOoDnuZets7x4pwPQcIdaOeRQQ6GepulTu/hM17uS6eK1eJUJSlWXKDLvNDSyC09VslOEEC57nwKgsBZzql/0whoKIjKfkQsh9FqtVuJ9SoClaSmrm4wqo+udCgPAA5JjZ1DVjSOSy9Av7jywkVwYasAAcM/IbTNyVbYtioRi4d58B5VOxXu/QaAg7hi5LyLylYWW6bD08PSLMUb1CweBd9aUvMI9rMivc28AW1bQnxSK5Nzc3BQXhhAY/n7jZzewk/bTHWPcZzvzawdBRG6JyB8OE7bPng0X/f0t3XtFs1QXkZs8LSOVN54ewGduXpLgbVPvVpaBvPFdvFKFIvgvMLqq+tEiOe+fDwIjmF2ZioR2MGy8OhLBkY5fVF8FBAvds6HgCD70zwcBwI3jJrjL3sxBtIip6l0ryqMlaN8fm7n6VdiymtpsNlO/b5Vgw+8B+G1lo18bC9qedaVhBo3iEJE2U8ZuU8a4JsZ41e83xmlEg4NCWVPVWOkUPQD9jyYb+7fLmA0Ea6P4HsljkioWkf0DVHqY/bL5b7Tfx6xjAK6r6rUyxm7CCuD3G2OM046/NZC6pJCEPcMAAAAASUVORK5CYII=",
        48, "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAMjSURBVGhD7Zj5T9VAEMcLini+99o5apH4fsFo8EJe1CDGGxW8g6IYbwXFiPr//2S+za7ZTAjw2r4joZ9k0h86uzuz287OTBTV1NTUbEW73T6Ypum5ZrMZ23dDj4gcZeYVZv4tIp9E5LjVGVqyLDssIq9U9QeMZ+Z1PNM0Vas7dExOTh4SkWVn/Gci+s7MX5wTH7MsYztmaJiamhpX1RcisuGMXlPVBXcKX50T7xuNRmLHDpzp6ekDRPQMxmPnReRnkiRX8I6ZT6kqTiJ3QlXfNZvNlp1jkIwR0ZPQeFWdCxWI6Aw+K5wMnCGit0mSNEKdQbGfmR+FxovIvFUCcRyfDZ1g5jdEdMzq9ZN9zLwYGs/MN6xSSKvVOu//EefMSpqmR6xePxgRkftux3PjieiWVdoKEZkJnRCRlwi9Vq+XjKjqvdB4Vb1rlbaDmWf9yTknlnFzW72eQES3jfELcMrq7QQRXQ7m2VDV51EUjVu9SmHmm6HxIvIgiqJRq7db0jS9GjpBRE8R1axeJYjI9dB4Zl7Cj2z1ukVEroVOMPNjRDerV4peL2I2B/NXsjk5SZL05Zir/jxz/I/mcxsReWh1qgQ3uFunVIDI8aEOxmNCF7fnROQi3nkpmtcgbKrqBWbuuLVm3PODXxNOEBFCdHcn0Wq12n7n3US5uIwS8dvLJlICZKJ2jh0YwS3uCp7/8/k03MgvZr5kJ9gWIjrNzH8w4VaCPN+fCrLMOI6bdo4dQA61yszf/MbYNQL5a5PD3YA8ZxbfIBHdsRLm+TCgQGYJB17DAbcJS3YNtw5u/HkUSnaCUnQ6nTFUWH4HSziwBpmYmCCr0FOQQVbpQN+L/tqBYXOgyE/m+kbD4QAK9yRJTuxW4jg+ibrYRaH+O4DOWxhG3U6udyn+hsfYzK7RU1wDC40r1LX5Z1BUiGhjIF07l8esoo1YVNx4dDGqSZ0LgEwRiVYZqdm7oNusqil+wm7FjxvU9z+K9krZKIS0HE3hAvVEOVBN4RJy/X9cRkUFl9gmTsOu0WtQUXXQKneFSSHBeNeSrKzD0S1YGB2KMlJTU7OX+Qc5TP+D24BhjgAAAABJRU5ErkJggg==")

    return dark ? (paused ? dp : d) : (paused ? lp : l)
}
