#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run as root or with sudo"
    exit
fi

echo "[INFO] Starting caddy update"

# Generate UUID for temp folder
UUID=$(cat /proc/sys/kernel/random/uuid)

# Get packages file absolute path
PACKAGES_FILE=$1
if [[ -f $PACKAGES_FILE ]]; then
    PACKAGES_FILE=$(readlink -m $PACKAGES_FILE)
fi

# Install or update deps
apt-get update
apt-get install -y curl wget git jq

if [[ ! $(which caddy) ]]; then
    echo "[INFO] Caddy is not installed, going ahead with install"
else
    CADDY_VERSION=$(caddy version | sed 's/v//' | sed 's/\s.*$//')
    CADDY_LATEST=$(curl "https://api.github.com/repos/caddyserver/caddy/tags" -s | jq -r '.[0].name' | sed 's/v//')

    echo "[INFO] Caddy installed version: $CADDY_VERSION"
    echo "[INFO] Caddy latest release: $CADDY_LATEST"

    if [[ $CADDY_VERSION != $CADDY_LATEST ]]; then
        echo "[INFO] Version is different, need to rebuild Caddy"
    else
        echo "[INFO] Caddy is already up to date"

        if [[ $1 == "force" || $2 == "force" ]]; then
            echo "[INFO] Force mode enabled, rebuilding as requested"
        else
            exit
        fi
    fi
fi

# Add Xcaddy repo if needed
if [[ ! -f /etc/apt/sources.list.d/caddy-xcaddy.list ]]; then
    echo "[INFO] Adding Xcaddy repo"
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/gpg.key'\
        | gpg --dearmor -o /usr/share/keyrings/caddy-xcaddy-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/debian.deb.txt'\
        | tee /etc/apt/sources.list.d/caddy-xcaddy.list
fi

# Install or update Xcaddy
echo "[INFO] Installing or updating Xcaddy"
apt-get update
apt-get install -y xcaddy

# Install go if needed
if [[ ! $(which go) ]]; then
    echo "[INFO] Installing go"
    wget -q -O - https://git.io/vQhTU | bash
    source ~/.bashrc
fi

# Create temp dir
mkdir -p /tmp/$UUID
cd /tmp/$UUID

# Get packages list from text file
PACKAGES_ARG=""
if [[ -f $PACKAGES_FILE ]]; then
    while read line; do
        echo "[INFO] Building with package $line"
        PACKAGES_ARG="$PACKAGES_ARG --with $line"
    done <<< $(cat $PACKAGES_FILE)
else
    echo "[INFO] No packages file provided, building without packages"
fi

# Build Xcaddy
echo "[INFO] Building caddy"
xcaddy build \
    $PACKAGES_ARG \
    --output /tmp/$UUID/caddy

# Check if build was successful
if [[ ! -f /tmp/$UUID/caddy ]]; then
    echo "[ERROR] Error while building caddy, please check output"
    exit
fi

# Get distribution resources for install
echo "[INFO] Getting caddy distribution resources"
git clone https://github.com/caddyserver/dist /tmp/$UUID/dist

# Install binary
echo "[INFO] Installing caddy binary"
mv /tmp/$UUID/caddy /usr/bin/caddy
chmod +x /usr/bin/caddy

# Create group if it does not exist yet
if [[ ! $(getent group caddy) ]]; then
    echo "[INFO] Creating caddy group"
    groupadd --system caddy
fi

# Create user if it does not exist yet
if ! id -u caddy > /dev/null 2>&1; then
    echo "[INFO] Creating caddy user"
    useradd --system \
        --gid caddy \
        --create-home \
        --home-dir /var/lib/caddy \
        --shell /usr/sbin/nologin \
        --comment "Caddy web server" \
        caddy
fi

# Install systemd service
echo "[INFO] Installing caddy and caddy-api systemd services"
mv /tmp/$UUID/dist/init/caddy.service /etc/systemd/system/caddy.service
mv /tmp/$UUID/dist/init/caddy-api.service /etc/systemd/system/caddy-api.service
systemctl daemon-reload

# Install Caddyfile if it does not exist
if [[ ! -f "/etc/caddy/Caddyfile" ]]; then
    mkdir -p /etc/caddy
    mv /tmp/$UUID/dist/config/Caddyfile /etc/caddy/Caddyfile
fi

# Remove temp dir
rm -rf /tmp/$UUID

# Create default directory if it does not exist
if [[ ! -f "/usr/share/caddy" ]]; then
    echo "[INFO] Creating default web directory"
    mkdir -p /usr/share/caddy
    echo "<h1>Hello, world!</h1>" > /usr/share/caddy/index.html
fi
echo "[INFO] Setting default web directory permissions"
chown caddy:caddy -R /usr/share/caddy

# Stop services if started
echo "[INFO] Stopping caddy and caddy-api services (in case they are started)"
systemctl stop caddy
systemctl stop caddy-api

# Enable and start services
echo "[INFO] Enabling & starting caddy and caddy-api services"
systemctl enable --now caddy
systemctl enable --now caddy-api

echo "[INFO] Caddy update finished"
