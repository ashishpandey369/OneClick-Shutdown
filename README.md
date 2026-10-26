# OneClick Shutdown

A lightweight Windows utility that prepares your PC for shutdown using a BAT launcher and a PowerShell engine.

## Features

- One-click launch from OneClick-Shutdown.bat
- Requests applications to close gracefully rather than force-killing processes
- Cleans eligible files from the current user's temporary folder and the Windows temporary folder
- Skips locked or inaccessible files and records errors
- Provides a cancellation countdown before shutdown
- Writes a local log for troubleshooting

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or newer
- No third-party modules required

## Run

1. Download or clone this repository.
2. Keep the folder structure intact.
3. Double-click OneClick-Shutdown.bat.
4. Confirm that you want to continue.
5. Save any open work before proceeding. The tool asks visible applications to close and may encounter unsaved-work prompts.
6. During the final countdown, press C to cancel shutdown.

Logs are created in the local logs folder and are intentionally excluded from Git.

## Safety notes

- Save your work before running this utility.
- Applications can refuse to close or display their own unsaved-work dialogs. This tool does not forcibly terminate them.
- Temporary files that are locked or inaccessible are skipped.
- The cleanup routine only targets the standard Windows temporary directories; it does not empty Downloads, Documents, browser profiles, or the Recycle Bin.
- Cancellation during the final countdown prevents shutdown, but applications already closed gracefully may remain closed.
- Review the script before running it, especially on work or shared computers.

## Project structure

    OneClick-Shutdown/
    ├── OneClick-Shutdown.bat
    ├── scripts/
    │   └── ShutdownEngine.ps1
    ├── logs/                  # Created at runtime; ignored by Git
    ├── .gitignore
    └── README.md

## License

No license has been specified yet. Unless a license is added, standard copyright restrictions apply.
