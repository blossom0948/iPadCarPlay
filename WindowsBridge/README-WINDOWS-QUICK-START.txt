ETS2 CarPlay Windows quick setup
================================

You do not need Visual Studio, CMake, or the .NET SDK when using this ready-built bundle.

FIRST TIME ONLY
1. Fully close Euro Truck Simulator 2.
2. Double-click Install-ETS2Plugin.bat.
3. Select the Euro Truck Simulator 2 folder. Choose the folder that contains "bin".
4. Allow the Windows permission prompt so the installer can copy the telemetry plugin.

EACH TIME YOU PLAY
1. Connect the iPad and Windows PC to the same home Wi-Fi network.
2. Double-click Start-Bridge.bat. Keep its window open.
3. If Windows Firewall asks, allow access on Private networks only.
4. In the iPad app, open Settings > ETS2 Connection. Enter the PC IPv4 address, port 8765, and the six-digit pairing code shown in the bridge window.
5. Start ETS2, load a profile, and begin driving.

If the bridge is restarted and pairing no longer works, remove the old pairing in the iPad app and enter the new six-digit code.
Do not enter 127.0.0.1 as the PC address; use the IPv4 address printed by the bridge.
