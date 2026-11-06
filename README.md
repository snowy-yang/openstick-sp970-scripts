# OpenStick SP970 helper scripts

Operational scripts used while bringing up the OpenStick (MSM8916) SP970
stick with a modem-less Debian 12 rootfs and a self-built 5.15 kernel.

These are the working notes/scripts, not a packaged build system. They are
kept here so the kernel (`snowy-yang/linux`, branch `sp970-disable-modem`)
and bootloader (`snowy-yang/lk2nd`, branch `sp970-fix-build`) changes can be
reproduced.

See `SP970-BUILD-NOTES.md` for the build result, flashing steps and the
post-mortem of the USB-gadget outage.

## Layout

| Area | Scripts |
|---|---|
| Kernel build / trim | `kernel-trim.sh`, `strip-modem.sh`, `strip-modem-dtsi.sh`, `drop-memshare.sh`, `link-eabi.sh` |
| Boot image | `build-boot-img.sh`, `export-artifacts.sh`, `verify-boot-img.sh`, `check-modem-status.py` |
| Rootfs | `rootfs-strip-modem.sh`, `rootfs-slim*.sh`, `rootfs-rmtfs-iproute2.sh`, `build-newrootfs.sh`, `dump-rootfs.sh`, `export-tar.sh`, `resize-1g.sh`, `shrink-fs.sh` |
| Package audit | `audit-*.sh`, `compare-modules.py`, `check-depmod.sh`, `fix-dpkg-state*.sh`, `fix-modindex*.sh` |
| Upgrade Debian 11 → 12 | `step1-keys.sh`, `upgrade-*.sh`, `get-keyring.sh`, `test-mirrors.sh` |
| USB gadget | `mobian-gadget.sh`, `ssh-*-gadget.sh`, `test-gadget-rebuild.sh`, `check-gadget-tools.sh` |
| WiFi | `wifi-*.sh`, `wifi-*.ps1` |
| Device diagnostics | `device-*.ps1`, `post-flash-verify.ps1`, `serial-*.py`, `diag-*.ps1` |

## Secrets

Scripts that need the WiFi pre-shared key read it from the `WIFI_PSK`
environment variable; nothing is hard-coded.

```bash
export WIFI_PSK='...'
```

For PowerShell, `wifi-connect.ps1` uses `$env:WIFI_PSK`.

## Paths assumed by the scripts

- Kernel source: `/opt/msm8916/linux`
- Kernel out-of-tree build dir: `/opt/msm8916/build`
- Built images copied to: `/mnt/d/msm8916/out`
