# GSX ProSim Door Bridge 0.2.4

Companion door bridge for ProSim B738, GSX and MSFS 2024. Handles GSX requests for passenger, service and cargo doors, synchronizes native L1 movement, and includes the L1 aircraft animation patch. No FSUIPC dependency.

Download `GSX-ProSim-Door-Bridge-0.2.4.zip` from this folder and extract it to a permanent writable folder outside Community. With MSFS closed, run `Install.ps1 -ProSimDirectory 'D:\ProSimB738'`, using your own installation path. See INSTALLATION.txt for full instructions. The bridge starts through MSFS EXE.xml and runs until the simulator closes.

The runtime is a compiled external app using SimConnect and the installed ProSim SDK. PowerShell is used for installation and start/stop utilities. ProSimSDK.dll is not distributed. The settings template contains no local installation path.

Version 0.2.4 uses a fresh ProSim L1 reading and reports L1 closed only when ProSim and native MSFS both report closed. The corrected close sequence was confirmed in a live test without a lockup. Full-cycle, actual CDU operation and simulator autostart regression tests remain recommended. The cause of the earlier lockup is unconfirmed.

Source: Bridge.cs and Signals.cs. Build with the x64 .NET Framework C# compiler referencing your installed ProSimSDK.dll. The included SimConnect.dll is required at runtime.
