# Enshrouded Server Manager

![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/caveman-games/enshrouded-server-manager/total?style=for-the-badge&color=green)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Donate-orange?style=for-the-badge&logo=buy-me-a-coffee)](https://ko-fi.com/cavemangames)

A lightweight, user-friendly Windows desktop utility built with **Flutter** by **Caveman Games**. Designed to effortlessly configure world settings, manage player limits, configure access passwords, and control your Enshrouded dedicated server process without messing with raw JSON files.

---

## ⚠️ Important Prerequisites (Read First!)
1. **Initial Server Run:** Before using this manager, **you must start your Enshrouded dedicated server at least once**. When you run the server for the first time, it generates the required `enshrouded_server.exe` and the initial `enshrouded_server.json` configuration file. This manager relies on editing that configuration file!
2. **SteamCMD (For Updates):** If you want to use the built-in 1-click update feature, you must have [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) installed on your PC. 

---

## Key Features

- **Interactive UI Sliders:** Tweak enemy damage/health, player stats, survival mechanics, and resource multipliers using precise percentage steps.
- **User Groups & Passwords:** Easily manage access roles (Admin, Friend, Guest, Visitor) and individual permissions.
- **Smart Path Detection:** 
  - **Automatic:** The app automatically scans standard Steam/SteamCMD installation paths (`C:\steamcmd\...` or `C:\Program Files (x86)\Steam\...`).
  - **Manual:** If your server or SteamCMD is installed in a custom directory, simply use the built-in folder picker.
- **1-Click Server Updates:** Automatically download the latest Enshrouded server updates via SteamCMD directly from the manager interface.
- **Live Console Output:** Start, stop, and update your server process directly from the app and monitor real-time server logs.

---

## How to Use

1. Download the latest `.zip` release from the [Releases page](../../releases).
2. Extract the files to a folder on your computer.
3. Ensure you have run your Enshrouded server at least once so the configuration files exist.
4. Launch `enshrouded_manager.exe`.
5. If the server isn't found automatically, click **Select Server** and point it to your `enshrouded_server.exe`.
6. **To enable auto-updates:** Click **Select SteamCMD** on the Basic tab and point it to your `steamcmd.exe`.
7. Customize your settings across the tabs and hit **Save**.
8. Use the **Start**, **Stop**, and **Update** buttons to manage your server!

---

## Credits

Developed with passion by **[Caveman Games](https://caveman-games.github.io/cavemangames/)**. 

If you like this utility and want to support future open-source tools and indie games, consider buying us a coffee!

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Donate-orange?style=for-the-badge&logo=buy-me-a-coffee)](https://ko-fi.com/cavemangames)