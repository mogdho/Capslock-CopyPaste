# 🔤 Capslock-CopyPaste by MOGDHO PAUL

![AutoHotkey](https://img.shields.io/badge/Language-AutoHotkey_v2.0-red?style=for-the-badge&logo=autohotkey)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Windows-blue?style=for-the-badge&logo=windows)

**Capslock-CopyPaste** is a productivity-boosting AutoHotkey v2 script that transforms the often-unused `CapsLock` key into a smart **Copy & Paste** shortcut — with visual feedback and intelligent clipboard protection.

---

## ✨ Features

| Action | Shortcut | What It Does |
|--------|----------|--------------|
| 📋 **Copy** | Single press `CapsLock` | Copies selected text/files (`Ctrl+C`) |
| 📌 **Paste** | Double press `CapsLock` | Pastes clipboard content (`Ctrl+V`) |
| 🔠 **Toggle CapsLock** | `Shift + CapsLock` | Turns original CapsLock on/off |
| 🔄 **Untoggle CapsLock** | `CapsLock` (while toggled on) | Turns CapsLock back off gracefully |

### 💬 Visual Feedback

Every action shows an auto-vanishing tooltip near your cursor so you always know what happened:

| Tooltip | Duration | Meaning |
|---------|----------|---------|
| 📋 **Copied!** | 500ms | ✅ Copy successful |
| 📌 **Pasted!** | 500ms | ✅ Paste successful |
| 🚫 **Blocked!** | 800ms | ⚠️ Browser internal URL blocked |
| ❌ **Nothing to paste!** | 800ms | ❌ Clipboard is empty |
| ❌ **Nothing copied!** | 800ms | ❌ No content was selected to copy |

### 🛡️ Smart Clipboard Protection

The script intelligently prevents unwanted clipboard content:

- 🚫 **Blocks browser internal URLs** — Accidentally copying `about:blank`, `chrome://newtab`, `edge://`, etc. won't overwrite your clipboard
- 🖼️ **Preserves all clipboard formats** — Uses `ClipboardAll()` to protect images, files, and rich-text (not just plain text)
- 🔄 **Auto-restore** — If a copy is blocked or fails, your previous clipboard content is automatically restored

#### Blocked Patterns

```
about:blank, about:newtab, chrome://, edge://, brave://, opera://, vivaldi://, firefox:
```

### ⚡ Smart Tap Detection

Uses a precise **300ms timer** with `A_PriorHotkey` and `A_TimeSincePriorHotkey` to accurately distinguish between single and double taps — no accidental triggers. A `KeyWait` guard ensures the physical key is fully released before sending `Ctrl+C`, preventing modifier interference.

### 🔒 Auto-Admin Elevation

Automatically requests Administrator privileges on startup so the shortcut works across **all** applications, including elevated system windows.

### 🔠 CapsLock Mode Awareness

When CapsLock is toggled on via `Shift + CapsLock`, pressing `CapsLock` alone will **not** trigger copy/paste — it will simply turn CapsLock back off. This prevents accidental clipboard operations while typing in uppercase.

---

## 🚀 Installation & Usage

### Prerequisites

> ⚠️ You need **[AutoHotkey v2.0+](https://www.autohotkey.com/)** installed on your Windows PC.

### Steps

1. 📥 **Download** the `Capslock-CopyPaste.ahk` file from this repository
2. ▶️ **Double-click** the file to run it — it will auto-request admin privileges
3. ✅ **Done!** Start using `CapsLock` as your Copy/Paste key

### 🔁 Auto-Start on Boot (Optional)

Want it to run automatically when Windows starts?

1. Press `Win + R` on your keyboard
2. Type `shell:startup` and press **Enter**
3. Copy the `Capslock-CopyPaste.ahk` file into the folder that opens
4. That's it! The script will now start automatically on every boot

> 💡 **Tip:** Make sure the script has Administrator privileges for it to work in all windows. You can create a shortcut to the `.ahk` file, go to Properties → Shortcut → Advanced, and check **"Run as administrator"**.

---

## 🧠 How It Works

```
                    ┌──────────────────────┐
                    │   Press CapsLock     │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │  Is CapsLock         │
                    │  toggled ON?         │
                    └──────────┬───────────┘
                        │             │
                       YES            NO
                        │             │
               ┌────────▼──────┐  ┌──▼───────────────┐
               │  Turn it OFF  │  │  Wait 300ms...   │
               │  (no copy/    │  │  Is it a double  │
               │   paste)      │  │  tap?            │
               └───────────────┘  └──────────┬───────┘
                                      │             │
                                     NO            YES
                                      │             │
                             ┌────────▼──────┐  ┌──▼───────────┐
                             │  📋 COPY      │  │  📌 PASTE     │
                             │  (Ctrl+C)     │  │  (Ctrl+V)     │
                             │               │  │               │
                             │  → KeyWait    │  │  → Check if   │
                             │  → Check if   │  │    clipboard   │
                             │    blocked    │  │    is empty    │
                             │  → Tooltip    │  │  → Tooltip     │
                             └───────────────┘  └───────────────┘
```

---

## 📁 Project Structure

```
Capslock-CopyPaste/
├── 📄 Capslock-CopyPaste.ahk   ← Main script
└── 📖 README.md                ← You are here!
```

---

## 🔗 Download / Source

- 📂 **Repository:** [github.com/mogdho/Capslock-CopyPaste](https://github.com/mogdho/Capslock-CopyPaste)

---

### 👨‍💻 Author

**Mogdho Paul**

🔗 GitHub: [github.com/mogdho](https://github.com/mogdho)
📂 Source: [Capslock-CopyPaste](https://github.com/mogdho/Capslock-CopyPaste)
