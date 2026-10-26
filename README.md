# OneClick Shutdown

A small Windows batch + PowerShell utility that prepares a PC for shutdown.

## Features

- Requests visible user applications to close normally.
- **Does not force-kill applications.** If apps remain open, it aborts so you can save work.
- Cleans the current user's TEMP folder and attempts to clean `C:\Windows\Temp`.
- Attempts to empty the Recycle Bin and flush the DNS resolver cache.
- Gives you a 6-second keyboard-cancellable countdown.
- Uses the normal Windows shutdown flow (no `/f` force-close switch).

## Requirements

- Windows 10 or Windows 11
- Built-in Windows PowerShell 5.1 or later
- Some cleanup actions may be skipped without Administrator permissions.

## Download and use

1. Download the ZIP from the repository's **Code → Download ZIP** option, or use the ZIP link in the repository's Releases section when available.
2. Extract the ZIP completely.
3. Open the extracted `OneClick-Shutdown` folder.
4. Double-click `OneClick-Shutdown.bat`.
5. Type `Y` to continue. Press any key during the final countdown to cancel.

Keep `OneClick-Shutdown.bat` and the `scripts` folder together. Do not run the script from inside the ZIP preview.

## Safety notes

- Save your work before running this tool.
- App-close requests may trigger save prompts. If any visible app remains open after the close request, the utility stops and does not shut down.
- TEMP cleanup can remove temporary files; files in use or inaccessible files are left behind.
- Emptying the Recycle Bin is destructive. Restore anything you need before running the utility.
- Review the scripts before running them. This project is provided as-is and has not been independently tested on every Windows configuration.
- The script does not elevate itself automatically. Run as Administrator only if you understand and need the extra permissions.

## Files

- `OneClick-Shutdown.bat` — user-facing launcher
- `scripts/ShutdownEngine.ps1` — preparation and countdown logic

## License

MIT — see [LICENSE](LICENSE).
