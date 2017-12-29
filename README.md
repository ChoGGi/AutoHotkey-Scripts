# AutoHotkey-Scripts
Some personal scripts for AutoHotkey

### WinPosition.ahk
Push new windows to the right by *PushAmount*

Useful for people with NV Surround or Eyefinity;
who want to have programs display in centre monitor.
The defaults are for three monitors at 5760 (3*1920)

### ProcessChanger.ahk
Sets Priority, IO Priority, and Affinity (also has run/kill list)
Loops through process list every %iDelay%
also checks list on window created

ProcessChanger.exe "Process name" will return the affinity mask
(you can set affinity in taskmgr)

### mkvextractAGUI.ahk
A simple GUI for extracting tracks from MKVs
Using MKVToolNix (mkvextract/mkvmerge)
https://mkvtoolnix.download

mkvextractAGUI Example.mkv
