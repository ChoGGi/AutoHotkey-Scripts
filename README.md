# AutoHotkey-Scripts
Some scripts for AutoHotkey

### WinPosition.ahk
```
Push new windows to the right by *PushAmount*

Useful for people with NV Surround or Eyefinity (or ultrawide monitors);
who want to have programs display at centre (relative to how they first appear).
The defaults are for three monitors at 5760 (3*1920)
```
### ProcessChanger.ahk
```
Sets Priority, IO Priority, Page Priority, and Affinity (also has run/kill list)
Loops through process list every *Delay*
also checks list when new processes created

ProcessChanger.exe "Process name.exe" will show the affinity mask (or use " | more" to view it in console)
(you can set affinity in taskmgr)
```
### mkvextractAGUI.ahk
```
A simple GUI for extracting files from MKVs
Using MKVToolNix (mkvextract/mkvmerge)
https://mkvtoolnix.download

mkvextractAGUI Example.mkv
```
### AltTab.ahk
```
Alt-Tab replacement with preview
```
### OnScreenClock.ahk
```
Add some clocks
```
### OnScreenCPU.ahk
```
Shows CPU cores usage and memory usage (far right)
```
### ShutDownMenu.ahk
```
Shows a list of shutdown/reboot/logoff options
```


#### Misc Info
```
Default settings are created on first run
Lib\Functions.ahk is required for most scripts
check the scripts for other required libs (see Requires: near the top)
place libs in AutoHotkey Lib folder or copy and paste lib into script and remove #Include line
```
