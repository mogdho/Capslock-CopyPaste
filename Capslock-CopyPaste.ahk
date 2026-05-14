#Requires AutoHotkey v2.0

if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

SetCapsLockState "AlwaysOff"

CapsLock::
{
    if GetKeyState("CapsLock", "T") {
        SetCapsLockState "AlwaysOff"
        return
    }

    if (A_PriorHotkey = "CapsLock" && A_TimeSincePriorHotkey < 300) {
        SetTimer(DoCopy, 0)
        ; Paste if clipboard has ANY content (text, images, files)
        if (ClipboardAll().Size > 0) {
            Send "^v"
            ShowTip("📌 Pasted!")
        } else {
            ShowTip("❌ Nothing to paste!", 800)
        }
    } else {
        SetTimer(DoCopy, -300)
    }
}

DoCopy() {
    KeyWait("CapsLock", "T0.5")  ; Wait for CapsLock release to prevent modifier interference

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
                if InStr(newClip, pattern) {
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

; Shift + CapsLock for Original Function
+CapsLock:: {
    if GetKeyState("CapsLock", "T")
        SetCapsLockState "AlwaysOff"
    else
        SetCapsLockState "AlwaysOn"
}
