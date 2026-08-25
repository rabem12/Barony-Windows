# Barony Save Protector (Windows)

A robust, zero-configuration background service and launch wrapper for **Barony** on Windows. This script protects your save files from the game's strict perma-death mechanics by seamlessly intercepting death events and automatically resurrecting your characters, while correctly allowing you to permanently delete saves from the game's UI.

## Features

- **Seamless Steam Integration:** Runs automatically when you launch Barony through Steam. No need to start background scripts manually.
- **Deterministic Death Detection:** Parses the Barony engine's `log.txt` in real-time to definitively tell the difference between an in-game death and an intentional UI save deletion.
- **Ultra-Fast, Zero-Impact Polling:** Monitors your save files every 2 seconds without wasting CPU or I/O. It tracks the file's modification time (`mtime`) and only processes data when the game engine actually writes to the disk.
- **Automated Graveyard:** Every time a character dies, a permanent backup is archived in a `Graveyard` folder along with a clickable `Resurrect_Character.command` tool to easily restore them to an empty save slot.
- **The Fallen Chronicles:** Automatically maintains a lore-friendly text log of your fallen heroes, tracking their Cause of Death, Class, Race, Level, Floor reached, and total kills.
- **Smart Storage Limits:** Automatically prunes old backups and logs to prevent your hard drive from filling up. Keeps up to 10 rolling backups per active character, 100 total characters in the Graveyard, and 1200 lines in The Fallen Chronicles.
- **Interactive Dashboard:** Launches a persistent terminal window alongside the game that displays ASCII art and a live rolling log of all save operations, character deaths, and staging injections as they happen in real-time.
- **Fail-Safely Enforcement:** If the script cannot confidently determine why a save file vanished (e.g., the game crashed or the logs rotated), it defaults to resurrecting the character to ensure saves are never lost by mistake.

## Installation

1. On this GitHub page, click the green **Code** button and select **Download ZIP**.
2. Open your `Downloads` folder and unzip the file. It will create a folder called something like `Barony-main`.
3. Rename that folder to exactly **`Barony`**.
4. Move your new `Barony` folder into your **Documents** directory (e.g. `C:\Users\YOUR_USERNAME\Documents\Barony`).

5. Open **Steam**.
6. Right-click **Barony** in your library and select **Properties...**
7. In the **General** tab, scroll down to **Launch Options**.
8. Paste the following command. 
   > [!IMPORTANT]
   > Ensure you replace `YOUR_USERNAME` with your actual Windows username in the path below. If you placed the folder anywhere other than your Documents, update the path accordingly!
   
   ```text
   "C:\Users\YOUR_USERNAME\Documents\Barony\launcher.bat" %command%
   ```

## Usage

### Playing the Game
Just launch Barony from Steam. The Save Protector will launch alongside the game, opening a persistent Dashboard window that monitors your saves in real-time. Play the game normally!

- If you **die**, you will receive a notification that your character was saved. The save file will be instantly restored to the main menu.
- If you **delete a save manually** from the Barony main menu, the script will permanently delete the backups for that slot.

### The Graveyard
The script automatically generates a `Graveyard` folder in the same directory as the script. 
- Inside you'll find `Solo_Runs` and `Multiplayer_Runs` containing permanent backups of every death. 
- You'll also find `The_Fallen_Chronicles.txt` which tracks the stats and causes of death for every fallen hero.

### Automatic Resurrection (Default)
When your character dies, the script automatically catches it and instantly stages the save file for resurrection.
- You do not need to do anything manually. Simply close the game and restart it from Steam. The Staging Injector will intercept the launch and restore the file to its original save slot before Steam Cloud can overwrite it.
- A permanent copy is also sent to the `Graveyard` for your records.

### Manual Resurrection (For Old Characters)
If you ever want to replay an *older* dead character that has been archived in your Graveyard:
1. **Fully quit Barony.** (The engine will overwrite the save if you do this while the game is running).
2. Open the `Graveyard` folder and double-click the `Resurrect_Character.bat` file.
3. Select the old character's `.baronysave` file from the prompt.
4. The character will be instantly staged. Launch the game from Steam to inject them back into their original slot.

## Requirements
- Windows 10/11
- Steam installation of Barony

## Technical Details
This script handles execution handoffs cleanly to preserve the native Steamworks environment. It parses JSON saves natively with PowerShell for extreme speed and does not require Python or any external dependencies. It uses atomic file operations to prevent data corruption during power loss.

## Uninstallation
If you ever want to stop using the Save Protector:
1. Open Steam, go to Barony's **Properties** > **General**.
2. Delete the command from the **Launch Options** text box.
3. The game will now launch normally. You can safely delete the `Barony` folder from your PC if you no longer want the Graveyard backups.

## Acknowledgments
- **Turning Wheel LLC** for creating [Barony](https://www.baronygame.com/), an incredible and unforgiving dungeon crawler.
- **Tink and JewcyJay** for the invaluable help with multiplayer testing and debugging.
- **Google Antigravity** for assisting with the code review of this project.

---
*Created by **Raven Lord** — Happy dungeon crawling!*
