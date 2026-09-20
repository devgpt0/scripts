# Target repository removal scripts

These scripts find local Git working trees whose configured remote URL matches one of the
allow-listed `github.com/devgpt0` repositories, then optionally remove the
working-tree directory. They do not remove repositories from GitHub or any
other remote service.

## Safety

- The default mode is a dry run. It only scans and lists matches.
- Deletion is recursive and permanent. Back up anything that may be needed
  before using a delete option.
- Review every path printed by the dry run before deleting.
- Without `--yes`/`-Yes`, the script requires the exact confirmation text
  `DELETE`.
- The scripts compare normalized Git remote URLs. HTTPS, SSH, and `.git`
  suffix variants of the allow-listed URLs are treated as the same repository.
- Access-denied directories are skipped. Run with an administrator/root
  account only when that is appropriate for the machine and its data.

## Repositories checked

The current allow-list is defined inside each script and includes:

`bootcoding-cicd`, `academic-prep-backend`, `academic-admin-backend`,
`email-service`, `academic-admin-frontend`, `academic-prep-frontend`,
`bootcoding-site`, `havet-website`, `havet-website-green`,
`aceint-analytics-backend`, `aceint-analytics-frontend`, `hireskill-frontend`,
`hireskill-site`, `student2developer`, `bootcoding-media`, `data-scripts`,
`client-agent`, and `job-api`.

The PowerShell version also currently includes `academic-agent`. Keep the
allow-lists synchronized when adding or removing a target.

## Windows

Open PowerShell or Command Prompt, change to this directory, and run a dry
run first:

```powershell
cd C:\path\to\scripts\removal_scripts
.\remove-target-repos.ps1
```

To scan selected locations instead of all local file-system drives:

```powershell
.\remove-target-repos.ps1 -Root 'C:\Users\Alice\source','D:\work'
```

After reviewing the output, request deletion and confirm interactively:

```powershell
.\remove-target-repos.ps1 -Delete
```

For unattended use, only after validating the dry-run output:

```powershell
.\remove-target-repos.ps1 -Delete -Yes
```

If PowerShell's execution policy blocks the script, use the included launcher
from Command Prompt or PowerShell:

```bat
cd /d C:\path\to\scripts\removal_scripts
run-remove-target-repos.cmd
run-remove-target-repos.cmd -Root "C:\Users\Alice\source"
run-remove-target-repos.cmd -Delete
```

The launcher bypasses the execution policy for this invocation only; it does
not change the machine's policy. Windows PowerShell 5.1 or PowerShell 7 is
required.

## macOS

Open Terminal and run:

```bash
cd /path/to/scripts/removal_scripts
chmod +x remove-target-repos-mac.sh
./remove-target-repos-mac.sh
```

The default scan checks `/` without crossing mount points and also checks
directories under `/Volumes`. To scan selected locations, pass them as
arguments:

```bash
./remove-target-repos-mac.sh "$HOME" /Volumes/ExternalDrive
```

Delete interactively after reviewing a dry run:

```bash
./remove-target-repos-mac.sh --delete
```

For unattended deletion:

```bash
./remove-target-repos-mac.sh --delete --yes
```

If macOS returns permission errors, grant Terminal access to the relevant
folders in Privacy & Security, or run only against locations you are allowed
to manage. Avoid scanning system locations unnecessarily.

## Linux

Use Bash:

```bash
cd /path/to/scripts/removal_scripts
chmod +x remove-target-repos-linux.sh
./remove-target-repos-linux.sh
```

The default scan checks `/` without crossing mount points and also checks
common removable-volume locations under `/mnt`, `/media`, and `/run/media`.
Pass explicit roots when the repositories are in a known location:

```bash
./remove-target-repos-linux.sh "$HOME" /data/work /mnt/backup
```

Delete interactively after reviewing a dry run:

```bash
./remove-target-repos-linux.sh --delete
```

For unattended deletion:

```bash
./remove-target-repos-linux.sh --delete --yes
```

Bash 4 or newer is required by the Linux script. Use the macOS script on
macOS, whose system Bash may be older.

## Running on another machine

Copy the `removal_scripts` directory to the target machine, or clone the
repository there. Run the script locally on that machine so it can inspect
that machine's local file systems. A script run on your workstation does not
scan another computer merely because that computer is reachable over the
network.

For example, copy the scripts to a Linux host over SSH, then run a dry run:

```bash
scp -r removal_scripts user@host:/tmp/
ssh user@host 'bash /tmp/removal_scripts/remove-target-repos-linux.sh /home /data'
```

For a Windows host, copy the directory with an approved file-transfer method,
then run `remove-target-repos.ps1` or `run-remove-target-repos.cmd` in a local
PowerShell/Command Prompt session on that host. Use the same approach for a
Mac, running `remove-target-repos-mac.sh` in Terminal.

### WSL and containers

- In WSL, the Linux script sees the WSL/Linux file system. Windows drives are
  normally available below `/mnt/c`, `/mnt/d`, and so on; pass those paths
  explicitly if they are in scope. It does not automatically behave like a
  native Windows scan.
- In a container, the script can only see mounted directories. Mount the
  intended data and pass that mount path explicitly. Do not use
  `--delete --yes` in automation until the mount and target paths have been
  verified.

## Recommended workflow

1. Copy the scripts to the machine and verify the target paths.
2. Run the platform-specific dry run.
3. Save or review the list of matching folders.
4. Run the interactive delete command and type `DELETE`, or use `--yes`/`-Yes`
   only in a controlled, reviewed automation workflow.
5. Confirm that the expected folders were removed and that unrelated data is
   still present.
