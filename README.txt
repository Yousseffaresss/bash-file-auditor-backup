FILE AUDITOR & BACKUP TOOL
Bash Mini Project - Operating Systems

TEAM MEMBERS
- Youssef Mohamed - 2406258
- Chris Zakaria - 2406261

CONTRIBUTIONS
Both team members worked together on the project design, implementation,
testing, and documentation.

PROJECT OVERVIEW
This Bash program scans a directory, reports file permissions and extensions,
searches for files, backs up readable files, lists backups, and restores a
backup without replacing an existing file.

PROJECT FILES
- auditor.sh: Main program, menu, and command-line options.
- lib.sh: Shared helper functions for logging and directory checks.
- sample_data/: Test files created for this project.

REQUIREMENTS
- Linux
- Bash
- Keep auditor.sh and lib.sh in the same folder.

RUN THE INTERACTIVE MENU
From the project folder, run:
./auditor.sh /path/to/sample_data

Replace /path/to/sample_data with the directory you want to inspect.
Choose option 8 to exit.

RUN A COMMAND DIRECTLY
./auditor.sh /path/to/sample_data scan
./auditor.sh /path/to/sample_data perms
./auditor.sh /path/to/sample_data ext
./auditor.sh /path/to/sample_data backup

The supported direct commands are scan, perms, ext, and backup.
To restore a backup, choose option 7 in the menu.

BACKUPS AND LOGGING
The program creates a backups/ folder and an auditor.log file beside
auditor.sh when needed. Backup filenames include a timestamp.
Unreadable files are skipped. Restored files receive the prefix restored_,
and an existing destination file is never replaced.

CHECK SCRIPT SYNTAX
bash -n auditor.sh
bash -n lib.sh

SUBMISSION
Submit auditor.sh, lib.sh, and README.txt.
Do not include the generated backups/ folder or auditor.log.
