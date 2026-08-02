-- vinOS live-ISO autostart override.
-- Omarchy's stock autostart.lua is empty (a user-customization file);
-- this file overrides it on the live medium only so we can auto-launch
-- the installer when the boot menu's "Install vinOS to disk" entry was
-- picked (vinos.action=install on the kernel cmdline).
--
-- The launcher script itself is a no-op when the flag isn't set, so a
-- normal live boot is unaffected.
o.launch_on_start("vinos-installer-autolaunch-gui")
