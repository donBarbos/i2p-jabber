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
  if { [ "${CURRENT_DISTRO}" == "ubuntu" ] || [ "${CURRENT_DISTRO}" == "debian" ] || [ "${CURRENT_DISTRO}" == "raspbian" ] || [ "${CURRENT_DISTRO}" == "pop" ] || [ "${CURRENT_DISTRO}" == "kali" ] || [ "${CURRENT_DISTRO}" == "linuxmint" ] || [ "${CURRENT_DISTRO}" == "neon" ] || [ "${CURRENT_DISTRO}" == "fedora" ] || [ "${CURRENT_DISTRO}" == "centos" ] || [ "${CURRENT_DISTRO}" == "rhel" ] || [ "${CURRENT_DISTRO}" == "almalinux" ] || [ "${CURRENT_DISTRO}" == "rocky" ] || [ "${CURRENT_DISTRO}" == "arch" ] || [ "${CURRENT_DISTRO}" == "archarm" ] || [ "${CURRENT_DISTRO}" == "manjaro" ] || [ "${CURRENT_DISTRO}" == "alpine" ] || [ "${CURRENT_DISTRO}" == "freebsd" ] || [ "${CURRENT_DISTRO}" == "ol" ]; }; then
    # Install required packages depending on the Linux distribution
    if { [ "${CURRENT_DISTRO}" == "ubuntu" ] || [ "${CURRENT_DISTRO}" == "debian" ] || [ "${CURRENT_DISTRO}" == "raspbian" ] || [ "${CURRENT_DISTRO}" == "pop" ] || [ "${CURRENT_DISTRO}" == "kali" ] || [ "${CURRENT_DISTRO}" == "linuxmint" ] || [ "${CURRENT_DISTRO}" == "neon" ]; }; then
      apt-get update
      apt-get install lua-bit32 apt-transport-https curl wget jq iproute2 lsof cron gawk procps grep sed zip unzip openssl nftables ifupdown e2fsprogs gnupg systemd -y
      wget -q -O - https://repo.i2pd.xyz/.help/add_repo | sudo bash -s -
      apt-get update
      apt-get install i2pd prosody -y
      wget -O /usr/lib/prosody/modules/mod_darknet.lua https://raw.githubusercontent.com/majestrate/mod_darknet/master/mod_darknet.lua
    elif { [ "${CURRENT_DISTRO}" == "fedora" ] || [ "${CURRENT_DISTRO}" == "centos" ] || [ "${CURRENT_DISTRO}" == "rhel" ] || [ "${CURRENT_DISTRO}" == "almalinux" ] || [ "${CURRENT_DISTRO}" == "rocky" ]; }; then
      yum check-update
      if [ "${CURRENT_DISTRO}" == "centos" ] && [ "${CURRENT_DISTRO_MAJOR_VERSION}" -ge 7 ]; then
        yum install epel-release elrepo-release -y
      fi
      if [ "${CURRENT_DISTRO}" == "centos" ] && [ "${CURRENT_DISTRO_MAJOR_VERSION}" == 7 ]; then
        yum install yum-plugin-elrepo -y
      fi
      yum install curl coreutils jq iproute lsof cronie gawk procps-ng grep sed zip unzip openssl nftables NetworkManager e2fsprogs gnupg systemd -y
    elif { [ "${CURRENT_DISTRO}" == "arch" ] || [ "${CURRENT_DISTRO}" == "archarm" ] || [ "${CURRENT_DISTRO}" == "manjaro" ]; }; then
      pacman -Sy --noconfirm i2pd prosody
      pacman -Su --noconfirm --needed curl coreutils jq iproute2 lsof cronie gawk procps-ng grep sed zip unzip openssl nftables ifupdown e2fsprogs gnupg systemd lua-bit32
    elif [ "${CURRENT_DISTRO}" == "alpine" ]; then
      apk update
      apk add curl coreutils jq iproute2 lsof cronie gawk procps grep sed zip unzip openssl nftables ifupdown e2fsprogs gnupg systemd
    elif [ "${CURRENT_DISTRO}" == "freebsd" ]; then
      pkg update
      pkg install curl coreutils jq iproute2 lsof cronie gawk procps grep sed zip unzip openssl nftables ifupdown e2fsprogs gnupg systemd
    elif [ "${CURRENT_DISTRO}" == "ol" ]; then
      yum check-update
      yum install curl coreutils jq iproute lsof cronie gawk procps-ng grep sed zip unzip openssl nftables NetworkManager e2fsprogs gnupg systemd -y
    fi
  else
    echo "Error: ${CURRENT_DISTRO} ${CURRENT_DISTRO_VERSION} is not supported."
    exit
  fi
}

installing-system-requirements

# Function adds i2p tunnels to the file /var/lib/i2pd/tunnels.conf
function add_tunnels() {
  local file="/var/lib/i2pd/tunnels.conf"

  if [ ! -f "$file" ]; then
    echo "File $file does not exist."
    exit
  fi

  cat << EOF >> /var/lib/i2pd/tunnels.conf
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
EOF
}

add_tunnels

# Function restarts the specified service
function restart_service() {
    local service_name="$1"
    service "$service_name" restart
}

# Restart i2pd server
restart_service i2pd

# Function returns the domain for out server
function get_private_key() {
  # Find out what address we will have from the logs
  local result
  result=$(grep "New private keys file" /var/log/i2pd/i2pd.log | grep -Eo "([a-z0-9]+).b32.i2p" | tail -n1)

  # Check if result is empty
  if [ -z "$result" ]; then
    echo "Failed to get private key. The result is empty."
    exit
  fi

  echo "$result"
}

# This address will be the domain for your XMPP server.
get_private_key
domain=$(get_private_key)

# Function saves the settings to config file
function create_xmpp_config() {
  local config_text
  config_text=$(cat <<EOT
interfaces = { "127.0.0.1" };
admins = { "admin@$domain" };
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

VirtualHost "$domain";
ssl = {
    key = "/etc/prosody/certs/$domain.key";
    certificate = "/etc/prosody/certs/$domain.crt";
}
EOT
)

  echo "$config_text" > /etc/prosody/prosody.cfg.lua
}

# Create XMPP config file
create_xmpp_config

# Function generates OpenSSl certificates for LTS encryption
function generate_certs() {
  openssl genrsa -out /etc/prosody/certs/"$domain".key 2048
  openssl req -new -x509 -key /etc/prosody/certs/"$domain".key -out /etc/prosody/certs/"$domain".crt -days 3650
  chown root:prosody /etc/prosody/certs/*.b32.i2p.{key,crt}
  chmod 640 /etc/prosody/certs/*.b32.i2p.{key,crt}
}

# Generating Encryption Certificates
generate_certs

# Restart XMPP server
restart_service prosody

# Adding an admin account
prosodyctl adduser admin@"$domain"
