Jetway Bell For ProSim737 on MSFS 2024 with GSX — release candidate 1.1.10

An unofficial MSFS 2024 add-on that rings a jetway bell during GSX connection and disconnection when flying the ProSim 737. No external companion application is required.

Download the installer ZIP from the GitHub Releases page, extract it, close MSFS, and run Setup.ps1. INSTALLATION.txt has the full steps. Installing only the gsx-jetway-bell folder does not install the aircraft integration.

Requirements: Windows, MSFS 2024, GSX desktop Couatl with its Remote v2 state feed enabled, and Community/prosim-b738/SimObjects/Airplanes/prosim-b738-2026. Different aircraft or ProSim folder versions require an adapted integration.

Features: connection/retraction operation timing; real jetway-cab distance attenuation; fixed left-side playback; muffled cabin recording; door-open/closed audio blend using both ProSim and MSFS door signals. Supports GSX-operated jetways at different airports through this aircraft integration. Not a universal aircraft-independent package or a dynamically positioned surround emitter.

The separate bell package holds all WAVs, HTML/JavaScript and standalone WASM. Install.ps1 adds a hidden panel gauge and three sound definitions to the aircraft, updates its layout and saves backups next to the installer. Existing door sounds are preserved. ProSim's Audio 2 is not used. GSX files are not modified.

Version status: packaged audio was confirmed working before this release. The final door-signal fix and neutral-name update pass automated checks; their audible behavior still needs in-simulator confirmation. This candidate replaces the earlier GSX-supplied transport with an independently implemented read-only client; live GSX state delivery and lifecycle checks pass. Report simulator version, ProSim version, installation path and steps when filing an issue; remove personal data from logs.

Development: C++ compiled to WASM, JavaScript gauge, PowerShell installer. Install the official MSFS 2024 SDK separately. Build with:
  powershell -File Build-Distance.ps1 -SdkRoot "C:\MSFS 2024 SDK"
Run tests using Node.js:
  node test-bell-state.cjs
  node test-door-mix.cjs
  node test-distance-module.cjs
  node test-transport.cjs
  node test-gsx-live.cjs  (requires GSX running; assumes port 8744)
Build-Release.ps1 combines scripts, regenerates layout metadata and creates the installer ZIP and checksums. Use it after changing packaged source files.

After a ProSim update replaces panel.cfg or sound.xml, reinstall the integration. Restore carefully from installer backups if uninstalling; do not overwrite later aircraft updates or unrelated changes. The generic aircraft-independent edition is separate work.

No MSFS SDK, ProSim aircraft assets, GSX source files, credentials, user logs or historical backups are included. This project is not affiliated with Microsoft, FSDreamTeam or ProSim. Third-party products must be obtained separately. No open-source or audio license has been assigned; installation packages are provided for personal simulator use. Contact the repository owner regarding other uses.
Repository layout: editable gauge scripts, WAV assets and compiled WASM are in the repository root. First run Build-Release.ps1 to assemble the MSFS package before running tests or installing from source. Git ignores the generated package folder. Download the installer ZIP for normal installation.
