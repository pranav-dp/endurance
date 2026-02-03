# Endurance

**A free, open-source Productivity tool for macOS.**

I got frustrated with paid timer apps that charge ₹1999 a year for basic functionality.

So I built my own. It's free, open-source, and minimal. 

[**Download Latest Release →**](https://github.com/pranav-dp/endurance/releases/latest)

---

<img src="Images/ui1.png" alt="Endurance" width="400">

---

## Features

| Feature | Description |
|---------|-------------|
| **Menu Bar Native** | Lives in your menu bar, one click away |
| **Pomodoro Countdown** | See remaining time right in the menu bar |
| **Custom Presets** | Create, save, and organize your own timer configurations |
| **Session Tracking** | Beautiful charts showing your focus history |
| **Global Hotkey** | `⌘ + Shift + T` to open from anywhere |
| **Glassmorphism UI** | Modern translucent design that feels native to macOS |
| **Dark & Light Mode** | Automatically adapts to your system appearance |

---

## Screenshots

| | |
|:---:|:---:|
| <img src="Images/ui2.png" alt="Timer View" width="350"><br><sub>**Timer View**</sub> | <img src="Images/ui3.png" alt="Presets Panel" width="350"><br><sub>**Presets Panel**</sub> |
| <img src="Images/ui4.png" alt="Statistics" width="350"><br><sub>**Session Statistics**</sub> | <img src="Images/menubar1.png" alt="Menu Bar" width="350"><br><sub>**Menu Bar Integration**</sub> |

<img src="Images/menubar2.png" alt="Menu Bar Timer Running" width="350">

*Live countdown in the menu bar*

---

## Installation

### Option 1: Download (Recommended)

1. Head to [**Releases**](https://github.com/pranav-dp/endurance/releases/latest)
2. Download the `.dmg` file
3. Open it and drag **Endurance** to your Applications folder
4. Launch from Applications or Spotlight

> **First Launch:** Since the app isn't notarized, macOS may block it.  
> Right-click the app → **Open** → Click **Open** in the dialog.

### Option 2: Build from Source

```bash
git clone https://github.com/pranav-dp/endurance.git
cd endurance
open endurance.xcodeproj
```

Then press `⌘ + R` to build and run.

---

## Tech Stack

- **Framework:** SwiftUI
- **Data Persistence:** SwiftData
- **Architecture:** Observable / MVVM
- **Minimum OS:** macOS 14.0 (Sonoma)
- **Platforms:** Apple Silicon & Intel

---

## License

This project is licensed under the [MIT License](LICENSE).
