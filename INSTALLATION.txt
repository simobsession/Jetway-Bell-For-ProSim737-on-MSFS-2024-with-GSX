Jetway Bell For ProSim737 on MSFS 2024 with GSX

Version 1.2.8 - Sound Settings preview



Download Setup.exe from this release. Everything needed by the bell installer is embedded in that single executable. MSFS 2024, GSX Pro and the supported ProSim737 aircraft must already be installed.



Close MSFS completely. Run Setup.exe, confirm the Community folder containing prosim-b738, and choose Install / Update. The supported aircraft path is SimObjects/Airplanes/prosim-b738-2026. The installer runs per user; the Community folder must be writable.



SOUND SETTINGS

Use the Jetway Bell for ProSim GSX desktop or Start menu shortcut. Choose a custom default WAV, assign airport overrides using four-character ICAO codes, remove overrides, preview recordings, or restore the bundled default. Save and apply with MSFS closed. Preview plays the original recording; simulator playback uses prepared cabin/open-door versions and distance attenuation.



Supported input: uncompressed 16-bit PCM WAV, mono or stereo, 8-192 kHz, 0.1-60 seconds (maximum 24 MB audio data). Recordings are copied to persistent storage, so their original source files can be moved afterward. Setup prepares normalized, filtered variants without requiring external audio software.



GSX provides the current airport. A configured airport uses its recording; every other or unknown airport uses the default. Sounds retain left-side playback, jetway-distance fading and the ProSim/MSFS L1 door mix. They play through MSFS rather than ProSim Audio 2. No companion application runs during simulator use.



UPGRADES AND UNINSTALL

Settings and original custom WAVs live in %LOCALAPPDATA%\GSXJetwayBellProSim\UserData. Upgrades preserve that directory and regenerate installed audio from it. Do not remove it if you want to keep your preferences.

Use Uninstall in Sound Settings, Windows Installed apps, or Setup.exe > Uninstall to remove the bell integration, bell package and shortcuts. The confirmation dialog defaults to preserving existing files, custom originals, settings, logs and recovery backups for reinstallation. Choose Remove all to permanently delete the application data folder, including custom recordings, settings and backups, after the app closes. Downloaded installers remain where you saved them. A short-lived compiled cleanup copy runs from Windows Temp to release and remove the installed EXE; that temporary copy remains for normal Windows Temp cleanup. No cleanup helper runs during simulator use. Uninstall preserves unrelated aircraft sounds and later unrelated configuration changes. Modified or unrecognized package files stop automatic removal rather than being deleted.



GSX Remote v2 must be enabled using remote_server_enabled = 1 in the existing [GSX] section of %APPDATA%\Virtuali\CouatlAddons.ini. The installer does not modify GSX settings or GSX files. After a ProSim aircraft update replaces panel.cfg or sound.xml, rerun Install / Update.



VALIDATION

Isolated install/upgrade/uninstall tests cover custom default audio, airport variants, preserved preferences and WAVs, and unrelated door sounds. Gauge tests cover airport exclusivity and default fallback; existing operation, startup sequencing, distance, door mix and transport tests pass. New custom airport sound definitions require in-simulator listening validation; this release is a preview. A brief first-connection surge was reported in 1.1.13 and remains under investigation.

The executable is unsigned. Previous GitHub releases are retained for rollback.



DEVELOPMENT

C++/WASM module, JavaScript gauge and compiled C# Windows Forms setup/installation backend. No PowerShell or other shell is launched at runtime. The EXE payload contains only the MSFS package and documentation; it contains no installation scripts or external audio helper DLL. Build-Setup.ps1 builds Setup.exe using the Windows .NET Framework compiler and includes the complete payload. Build-Release.ps1 builds the manual installer ZIP. Build-Distance.ps1 requires the separately obtained official MSFS 2024 SDK. Run Node tests test-bell-state.cjs, test-distance-module.cjs, test-door-mix.cjs and test-transport.cjs; run test-sound-settings.ps1 for isolated settings lifecycle tests.

No SDK, ProSim aircraft assets, GSX source files, user settings or private backups are distributed. No open-source or audio license has been assigned; installation packages are provided for personal simulator use. Contact the repository owner regarding other uses. This project is not affiliated with Microsoft, FSDreamTeam or ProSim.



1.2.5: tolerate legacy Windows-1252 characters in aircraft XML incorrectly marked as UTF-8. Preserve original bytes in installer backups and save edited XML as valid UTF-8. Structurally invalid XML remains an error.



1.2.5: replace all runtime installation, custom sound generation, XML handling, shortcut/registry operations and removal scripts with compiled C# inside Setup.exe. PowerShell build/test scripts in the source repository are development tools only and are not shipped in Setup.exe. Native lifecycle/rollback tests pass. The EXE is still unsigned; eliminating script execution does not guarantee antivirus acceptance.



1.2.5: store the settings/uninstaller executable under a versioned, content-verified filename. Upgrades no longer overwrite a fixed Setup.exe that may be open or read-only. Shortcuts and the Windows uninstall entry point to the new copy.



1.2.5: resolve Desktop and Start menu through Windows Known Folder APIs (including redirected locations). Create shortcuts independently; a blocked Desktop no longer rolls back installation or prevents Start menu/uninstaller registration. A settings shortcut is also saved in the application folder, and Windows Installed apps supports Modify/Settings where available.



1.2.5: fix silent airport recordings by allocating unused, SDK-supported WAV event slots (01–12 in supported custom event families) instead of inventing event names. Existing aircraft sound events are preserved. Add a custom bell icon and rename shortcuts/application to Jetway Bell for ProSim GSX. Reinstall with MSFS closed, retain the EDDF assignment, then restart MSFS completely.


1.2.6: Desktop and Start menu shortcuts open Sound Settings directly as the only visible application window. Saving uses the compiled backend in the same process without copying the executable or rewriting shortcuts/uninstaller registration. Apply failures keep the settings screen open and restore previous preferences. Add Windows product and file version metadata. The executable remains unsigned; Norton acceptance has not been verified.

1.2.7: Show version numbers in Setup and Sound Settings title bars. Add Uninstall to Sound Settings with explicit preserve/remove-all options. Full removal runs only after successful aircraft/package uninstall, is restricted to the exact application data folder, and does not traverse linked directories. Preserve remains the default.

1.2.8: Remove Sound Settings from Setup. Successful installation explicitly confirms success and asks you to close the installer, with the same message retained in its log. Add a Close button. Open sound settings through the installed desktop or Start menu app shortcut.
