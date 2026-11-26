NI-VISA - install it ONLY on a station that gets a USB instrument
=================================================================

Which instruments need it
  Keysight EDU-X 1002A (scope), Siglent SDG6052X (generator), GW Instek DAQ-9600.
  Serial instruments and the loggers do NOT need it. GPIB stations that already have NI-488.2
  usually have it too (check install.log, below).

Do I need it?  Open install.log in the station folder and find the line starting "USBTMC:".
  "32-bit VISA present"  -> nothing to do.
  "VISA absent"          -> install it (steps below).
  "only 64-bit VISA"     -> install it, and keep 32-bit support selected.

What you need
  - Administrator rights.
  - Internet: the installer in this folder is NI's ONLINE installer; it downloads while it runs.
  - Time: 30+ minutes. On the first laptop (2026-11-26) it pulled 274 NI packages.

Steps
  1. Unplug nothing; the instrument may stay connected.
  2. Right-click ni-visa_<version>_online.exe in this folder -> Run as administrator.
  3. Accept NI's licence. Keep "NI-VISA Runtime" with USB support AND 32-bit (x86) support.
     The VCT server is 32-bit: a 64-bit-only VISA does not work for it.
     The rest (LabVIEW Runtime, examples, documentation, .NET development) is not used by VCT.
     Unticking it may shorten the install - not tried yet.
  4. When it finishes, check Device Manager: the instrument must be listed under
     "USB Test and Measurement Devices" as "USB Test and Measurement Device (IVI)",
     with no yellow mark (before: "code 28", no driver).
  5. Restart the VCT service, or the station, so the server finds the instrument.
     The installer asks for a reboot. On the first laptop VISA already worked before rebooting,
     but reboot when convenient: files are replaced only at restart.

More detail: Installer\DRIVERS.md in the Calibration-software repository (MBA-1058).
