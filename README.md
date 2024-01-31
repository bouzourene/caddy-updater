# caddy-updater

This bash script is an automated installer/updater for Caddy on Debian systems.\
Only tested on Debian 12 bookworm as of now.

## Why not use the package from the official Debian repo?

You can. But it's not always up to date and you cannot add Caddy modules.

## How to install

```bash
git clone https://github.com/bouzourene/caddy-updater.git
cd caddy-updater
```

## How to use

Always start with sudo or from root user.

```bash
# To install caddy without any modules
sudo ./caddy-updater.sh

# To install caddy without any modules (force install)
sudo ./caddy-updater.sh force

# To install caddy with modules
sudo ./caddy-updater.sh /path/to/modules.txt

# To install caddy with modules (force install)
sudo ./caddy-updater.sh /path/to/modules.txt force
```

## Force install

If you add `force` at the end of your command, you will skip the version check.\
By default, caddy-updater will check if caddy is already installed, and if it is the latest version.

## Modules list

If you want to build caddy with modules, you need to create a text file with one module name per line.\
Example `modules.txt`:
```
github.com/caddyserver/ntlm-transport
github.com/caddy-dns/cloudflare
github.com/mholt/caddy-webdav
```
You can find a non-exclusive list of modules [here](https://caddyserver.com/download).

## What's installed?

- The caddy binary (modules are included in the binary)
- Systemd service files for `caddy` and `caddy-api`
- Sample `Caddyfile` in `/etc/caddy` (only if it does not exist yet)
- Sample `index.html` in `/usr/share/caddy` (only if directory does not exist yet)

## Automated updates

If you want to automate updates, you can use this script with crontab.\
As long as you do not use the `force` parameter, caddy will only be updated if a new version has been released.
