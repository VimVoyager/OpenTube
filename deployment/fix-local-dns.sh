#!/bin/bash
# Fix opentube.local DNS resolution

echo "=== Fixing opentube.local DNS Resolution ==="
echo ""

# Check if avahi is installed
if ! command -v avahi-browse &> /dev/null; then
    echo "Installing avahi..."
    sudo pacman -S --noconfirm avahi nss-mdns
fi

# Enable and start avahi-daemon
echo "Starting avahi-daemon..."
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# Check if nsswitch.conf has mdns
echo "Checking /etc/nsswitch.conf..."
if ! grep -q "mdns_minimal" /etc/nsswitch.conf; then
    echo "Adding mDNS to nsswitch.conf..."
    
    # Backup original
    sudo cp /etc/nsswitch.conf /etc/nsswitch.conf.backup
    
    # Add mdns_minimal before resolve and dns
    sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns/' /etc/nsswitch.conf
    
    echo "✓ Updated nsswitch.conf"
else
    echo "✓ nsswitch.conf already configured"
fi

# Restart avahi
sudo systemctl restart avahi-daemon

# Test resolution
echo ""
echo "Testing resolution..."
sleep 2

if ping -c 1 opentube.local &> /dev/null; then
    echo "✓ opentube.local resolves correctly!"
else
    echo "⚠ opentube.local doesn't resolve yet"
    echo ""
    echo "Possible fixes:"
    echo "1. Wait 10-20 seconds and try again"
    echo "2. Restart your network manager: sudo systemctl restart NetworkManager"
    echo "3. Check hostname: hostnamectl"
    echo "4. Test from another device on the network"
fi

echo ""
echo "Hostname: $(hostnamectl --static)"
echo "Avahi status: $(systemctl is-active avahi-daemon)"
echo ""
echo "Try accessing: http://opentube.local"