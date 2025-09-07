#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt update && apt install -y figlet

clear

figlet "Dlpve"
echo
echo "Enter the hostname for your Proxmox server (e.g. testing.local):"
read -rp "> " NEW_HOSTNAME

echo "Detecting main ethernet interface..."

MAIN_IFACE=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' | grep ^e | head -n1)

if [[ -z "$MAIN_IFACE" ]]; then
  ip a
  echo "No ethernet interface found. Please enter interface name manually:"
  read -rp "> " MAIN_IFACE
fi

HOST_IP=$(ip -4 addr show "$MAIN_IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)

if [[ -z "$HOST_IP" ]]; then
  echo "No IP detected on $MAIN_IFACE. Please enter IP manually:"
  read -rp "> " HOST_IP
else
  echo "Detected IP on $MAIN_IFACE: $HOST_IP"
fi

SHORT_HOSTNAME="${NEW_HOSTNAME%%.*}"

figlet "Setting Hostname"
hostnamectl set-hostname "$NEW_HOSTNAME"

echo "Updating /etc/hosts with hostname and IP..."
cat > /etc/hosts <<EOF
127.0.0.1       localhost
$HOST_IP        $SHORT_HOSTNAME $NEW_HOSTNAME
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

clear
figlet "Selecting Fastest Mirror"

MIRRORS=(
  download.proxmox.com
  au.cdn.proxmox.com
  de.cdn.proxmox.com
  de2.cdn.proxmox.com
  de3.cdn.proxmox.com
  fr.cdn.proxmox.com
  na.cdn.proxmox.com
  na2.cdn.proxmox.com
  sg.cdn.proxmox.com
  sg2.cdn.proxmox.com
  za.cdn.proxmox.com
  cn.cdn.proxmox.com
  172.22.248.206
  10.207.7.45
  210.246.231.99
)

BEST_LINE=$(
  for m in "${MIRRORS[@]}"; do
    RTT=$(ping -c1 -W1 "$m" 2>/dev/null \
      | grep -oP 'time=\K[0-9]+(\.[0-9]+)?' || echo 9999)
    echo "$RTT $m"
  done | sort -n | head -n1
)

BEST_RTT=${BEST_LINE%% *}
BEST_MIRROR=${BEST_LINE#* }

if [[ "$BEST_RTT" == "9999" ]]; then
  BEST_MIRROR="download.proxmox.com"
fi

echo "Fastest mirror: $BEST_MIRROR"
echo "deb [arch=amd64 trusted=yes] http://$BEST_MIRROR/debian/pve trixie pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-install-repo.list

clear
figlet "Updating System"
echo "Updating and upgrading system packages..."
apt update && apt full-upgrade -y

clear
figlet "Nuking Cloudinit & Qemu-utils"
apt remove --purge -y cloud-init qemu-utils

apt autoremove -y

clear

figlet "Installing PVE Kernel"
apt install -y proxmox-default-kernel bc

if grep -q "auto vmbr0" /etc/network/interfaces; then
  echo "Removing existing vmbr0 config..."
  sed -i '/auto vmbr0/,/^$/d' /etc/network/interfaces
fi

echo "Appending vmbr0 bridge with NAT to /etc/network/interfaces..."
cat >> /etc/network/interfaces <<EOF

auto vmbr0
iface vmbr0 inet static
        address  172.16.0.1
        netmask  255.240.0.0
        bridge_ports none
        bridge_stp off
        bridge_fd 0
        post-up echo 1 > /proc/sys/net/ipv4/ip_forward
        post-up iptables -t nat -A POSTROUTING -s '172.16.0.0/12' -o $MAIN_IFACE -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s '172.16.0.0/12' -o $MAIN_IFACE -j MASQUERADE
EOF

figlet "Presetup Complete"

sleep 2

clear

figlet "Finalizing Install"

clear

figlet "Installing Proxmox VE packages and DHCP server"

apt autoremove -y

apt install -y proxmox-ve postfix open-iscsi chrony isc-dhcp-server

echo 'INTERFACESv4="vmbr0"' > /etc/default/isc-dhcp-server

cat > /etc/dhcp/dhcpd.conf <<EOD
subnet 172.16.0.0 netmask 255.240.0.0 {
  range 172.16.0.10 172.31.255.254;
  option routers 172.16.0.1;
  option subnet-mask 255.240.0.0;
  option domain-name-servers 1.1.1.1, 8.8.8.8;
  default-lease-time 600;
  max-lease-time 7200;
}
EOD

echo "Enabling DHCP server"
systemctl enable --now isc-dhcp-server

apt autoremove -y

clear

figlet "Removing Debian kernels"
DEBIAN_FRONTEND=noninteractive apt remove -y --allow-remove-essential linux-image-amd64 'linux-image-6.1*'

apt autoremove -y

clear

figlet "Updating grub"
update-grub

clear

figlet "Removing os-prober package"
apt remove -y os-prober || true

apt autoremove -y

clear

apt install socat -y

figlet "443-Forward Setup"

SERVICE_NAME=port443forward
SERVICE_PATH=/etc/systemd/system/${SERVICE_NAME}.service

cat <<EOF > $SERVICE_PATH
[Unit]
Description=Port Forward 443 -> 8006
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:443,fork TCP:localhost:8006
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

clear

figlet Proxmox Install
echo "... is done"
echo
echo "Your server will reboot and the web ui will be accessable afterwards."
echo
echo "Access the web interface at https://$HOST_IP:8006"
echo "or at port 443 (https://$HOST_IP:443)"
echo
echo Rebooting in 5 seconds
sleep 1
echo 4
sleep 1
echo 3
sleep 1
echo 2
sleep 1
echo 1
sleep 1
echo Rebooting
reboot && wait
