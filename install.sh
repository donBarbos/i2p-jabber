#!/usr/bin/env bash

# link to the GitHub repository: https://github.com/donBarbos/i2p-jabber

# The script requires root privileges.
function super-user-check() {
  # This function checks if the script is running as the root user.
  if [ "${EUID}" -ne 0 ]; then
    # If the effective user ID is not 0 (root), display an error message and exit.
    echo "Error: You need to run this script as administrator."
    exit
  fi
}

super-user-check

# Function retrieves the current system information.
function system-information() {
  # This function retrieves the ID, version, and major version of the current system.
  if [ -f /etc/os-release ]; then
    # Check if the /etc/os-release file exists, and if so, source it to get the system information.
    # shellcheck source=/dev/null
    source /etc/os-release
    CURRENT_DISTRO=${ID}
    CURRENT_DISTRO_VERSION=${VERSION_ID}
    CURRENT_DISTRO_MAJOR_VERSION=$(echo "${CURRENT_DISTRO_VERSION}" | cut --delimiter="." --fields=1)
  fi
}

system-information

# Function receives the file with code and the name of the language and runs this code
function installing-system-requirements() {
  # Check if the current Linux distribution is supported
  if { [ "${CURRENT_DISTRO}" == "ubuntu" ] || [ "${CURRENT_DISTRO}" == "debian" ] || [ "${CURRENT_DISTRO}" == "raspbian" ] || [ "${CURRENT_DISTRO}" == "pop" ] || [ "${CURRENT_DISTRO}" == "kali" ] || [ "${CURRENT_DISTRO}" == "linuxmint" ] || [ "${CURRENT_DISTRO}" == "neon" ] || [ "${CURRENT_DISTRO}" == "fedora" ] || [ "${CURRENT_DISTRO}" == "centos" ] || [ "${CURRENT_DISTRO}" == "rhel" ] || [ "${CURRENT_DISTRO}" == "almalinux" ] || [ "${CURRENT_DISTRO}" == "rocky" ] || [ "${CURRENT_DISTRO}" == "arch" ] || [ "${CURRENT_DISTRO}" == "archarm" ] || [ "${CURRENT_DISTRO}" == "manjaro" ] || [ "${CURRENT_DISTRO}" == "freebsd" ] || [ "${CURRENT_DISTRO}" == "ol" ]; }; then
    # Install required packages depending on the Linux distribution
    if { [ "${CURRENT_DISTRO}" == "ubuntu" ] || [ "${CURRENT_DISTRO}" == "debian" ] || [ "${CURRENT_DISTRO}" == "raspbian" ] || [ "${CURRENT_DISTRO}" == "pop" ] || [ "${CURRENT_DISTRO}" == "kali" ] || [ "${CURRENT_DISTRO}" == "linuxmint" ] || [ "${CURRENT_DISTRO}" == "neon" ]; }; then
      apt-get update
      apt-get install lua-bit32 apt-transport-https curl wget jq iproute2 lsof cron gawk procps grep sed zip unzip openssl nftables ifupdown e2fsprogs gnupg systemd -y
      wget -q -O - https://repo.i2pd.xyz/.help/add_repo | sudo bash -s -
      apt-get update
      apt-get install i2pd prosody -y
    elif { [ "${CURRENT_DISTRO}" == "fedora" ] || [ "${CURRENT_DISTRO}" == "centos" ] || [ "${CURRENT_DISTRO}" == "rhel" ] || [ "${CURRENT_DISTRO}" == "almalinux" ] || [ "${CURRENT_DISTRO}" == "rocky" ]; }; then
      yum check-update
      if [ "${CURRENT_DISTRO}" == "centos" ] && [ "${CURRENT_DISTRO_MAJOR_VERSION}" -ge 7 ]; then
        yum install epel-release elrepo-release -y
      fi
      if [ "${CURRENT_DISTRO}" == "centos" ] && [ "${CURRENT_DISTRO_MAJOR_VERSION}" == 7 ]; then
        yum install epel-release yum-plugin-elrepo -y
      fi
      yum install curl coreutils jq iproute lsof cronie gawk procps-ng grep sed zip unzip openssl nftables NetworkManager e2fsprogs gnupg systemd lua-devel luarocks -y
      luarocks install luabitop
      curl -s https://copr.fedorainfracloud.org/coprs/supervillain/i2pd/repo/epel-7/supervillain-i2pd-epel-7.repo -o /etc/yum.repos.d/i2pd-epel-7.repo
      yum install i2pd prosody -y
      systemctl enable --now i2pd
    elif { [ "${CURRENT_DISTRO}" == "arch" ] || [ "${CURRENT_DISTRO}" == "archarm" ] || [ "${CURRENT_DISTRO}" == "manjaro" ]; }; then
      pacman -Sy --noconfirm i2pd prosody
      pacman -Su --noconfirm --needed curl coreutils jq iproute2 lsof cronie gawk procps-ng grep sed zip unzip openssl nftables ifupdown e2fsprogs gnupg systemd lua-bit32
    elif [ "${CURRENT_DISTRO}" == "freebsd" ]; then
      pkg update
      pkg install curl coreutils jq iproute2 lsof cronie gawk procps grep sed zip unzip openssl nftables ifupdown e2fsprogs gnupg systemd lua52-bit32 i2pd prosody
    elif [ "${CURRENT_DISTRO}" == "ol" ]; then
      yum check-update
      yum install curl coreutils jq iproute lsof cronie gawk procps-ng grep sed zip unzip openssl nftables NetworkManager e2fsprogs gnupg systemd lua-devel luarocks -y
      luarocks install luabitop
      curl -s https://copr.fedorainfracloud.org/coprs/supervillain/i2pd/repo/epel-7/supervillain-i2pd-epel-7.repo -o /etc/yum.repos.d/i2pd-epel-7.repo
      yum install i2pd prosody -y
      systemctl enable --now i2pd
    fi
    # Add prosody mod_darknet module
    wget -O /usr/lib/prosody/modules/mod_darknet.lua https://raw.githubusercontent.com/majestrate/mod_darknet/master/mod_darknet.lua
  else
    echo "Error: ${CURRENT_DISTRO} ${CURRENT_DISTRO_VERSION} is not supported."
    exit
  fi
}

installing-system-requirements

# Function adds i2p tunnels to the file /var/lib/i2pd/tunnels.conf
function add-tunnels() {
  local FILE="/var/lib/i2pd/tunnels.conf"
  local ALREADY_ADDED="# Settings have already been added by script =)"

  if [ ! -f "$FILE" ]; then
    echo "File $FILE does not exist."
    exit
  fi

  # Checking if our settings are already there
  if grep -qF "$ALREADY_ADDED" "$FILE"; then
    echo "Settings have already been added to $FILE."
    return
  fi

  cat << EOF >> "$FILE"

[prosody-s2s]
type=server
host=127.0.0.1
port=5269
inport=5269
keys=prosody.dat

[prosody-c2s]
type=server
host=127.0.0.1
port=5222
inport=5222
keys=prosody.dat

$ALREADY_ADDED
EOF
}

# Adding tunnels to i2p
add-tunnels

# Function restarts the specified service
function restart-service() {
    local SERVICE_NAME="$1"
    systemctl restart "$SERVICE_NAME"
    sleep 2
}

# Restart i2pd server
restart-service i2pd

# Function downloads a page with $URL to the $OUTPUT_FILE
function download-page() {
  local OUTPUT_FILE="$1"
  local URL="$2"
  
  if wget -O "$OUTPUT_FILE" "$URL"; then
    echo "Page downloaded successfully and saved to $OUTPUT_FILE."
  else
    echo "Failed to download the page."
    exit
  fi
}

# Temporary file to store webconsole html page
PAGE_FILE=$(mktemp)

# Save webconsole page
download-page "$PAGE_FILE" "http://localhost:7070/?page=i2p_tunnels"

# Function returns the domain for out server
function find-b32-address() {
  local FILE="$1"
  local RESULT

  # Find out what address we will have from the logs
  RESULT=$(grep -oP '(?<=<a href="/\?page=local_destination&b32=)[^"]+(?=">prosody-s2s</a>)' "$FILE")

  # Check if result is empty
  if [ -z "$RESULT" ]; then
    echo "Failed to get private key. The result is empty."
    exit
  fi

  RESULT+=".b32.i2p"
  echo "$RESULT"
}

# Check the returned result
find-b32-address "$PAGE_FILE"
# This address will be the domain for your XMPP server.
DOMAIN=$(find-b32-address "$PAGE_FILE")

# Remove temporary files with html
rm "$PAGE_FILE"

# Function saves the settings to config file
function create-xmpp-config() {
  local CONFIG_TEXT
  CONFIG_TEXT=$(cat <<EOT
interfaces = { "127.0.0.1" };
admins = { "admin@$DOMAIN" };
modules_enabled = {
    "roster"; "saslauth"; "tls"; "dialback"; "disco"; "posix"; "private"; "vcard";  "ping";  "register"; "admin_adhoc"; "darknet";
};
modules_disabled = {};
allow_registration = false;
darknet_only = true;
c2s_require_encryption = true;
s2s_secure_auth = false;
authentication = "internal_plain";

-- On Debian/Ubuntu
daemonize = true;
pidfile = "/var/run/prosody/prosody.pid";
log = {
    error = "/var/log/prosody/prosody.err";
    "*syslog";
}
certificates = "certs";

VirtualHost "$DOMAIN";
ssl = {
    key = "/etc/prosody/certs/$DOMAIN.key";
    certificate = "/etc/prosody/certs/$DOMAIN.crt";
}
EOT
)

  echo "$CONFIG_TEXT" > /etc/prosody/prosody.cfg.lua
}

# Create XMPP config file
create-xmpp-config

# Function generates OpenSSl certificates for LTS encryption
function generate-certs() {
  openssl genrsa -out /etc/prosody/certs/"$DOMAIN".key 2048
  openssl req -new -x509 -key /etc/prosody/certs/"$DOMAIN".key -out /etc/prosody/certs/"$DOMAIN".crt -days 3650

  chown root:prosody /etc/prosody/certs/*.b32.i2p.{key,crt}
  chmod 640 /etc/prosody/certs/*.b32.i2p.{key,crt}
}

# Generating Encryption Certificates
generate-certs

# Restart XMPP server
restart-service prosody

# Adding an admin account
prosodyctl adduser admin@"$DOMAIN"
