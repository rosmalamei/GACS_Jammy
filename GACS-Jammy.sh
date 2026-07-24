#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to display spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "${CYAN} [%c]  ${NC}" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to run command with progress
run_command() {
    local cmd="$1"
    local msg="$2"
    printf "${YELLOW}%-50s${NC}" "$msg..."
    eval "$cmd" > /dev/null 2>&1 &
    spinner $!
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${RED}Failed${NC}"
        exit 1
    fi
}

# Print banner
print_banner() {
	echo -e "${BLUE}${BOLD}"
	echo "   ____    _    ____ ____     ____            _       _   "
	echo "  / ___|  / \  / ___/ ___|   / ___|  ___ _ __(_)_ __ | |_ "
	echo " | |  _  / _ \| |   \___ \   \___ \ / __| '__| | '_ \| __|"
	echo " | |_| |/ ___ \ |___ ___) |   ___) | (__| |  | | |_) | |_ "
	echo "  \____/_/   \_\____|____/   |____/ \___|_|  |_| .__/ \__|"
	echo "                                               |_|        "
	echo ""
	echo "                  --- Ubuntu 22.04 ---"
	echo "                  --- Rosmalamei ---"
	echo -e "${NC}"
}

# Check for root access
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# Check Ubuntu version
if [ "$(lsb_release -cs)" != "jammy" ]; then
    echo -e "${RED}This script only supports Ubuntu 22.04 (Jammy)${NC}"
    exit 1
fi

# Print banner
print_banner

# Main installation process
total_steps=11
current_step=0

echo -e "\n${MAGENTA}${BOLD}Starting GenieACS Installation Process${NC}\n"

run_command "apt-get update -y" "Updating system ($(( ++current_step ))/$total_steps)"

run_command "sed -i 's/#\$nrconf{restart} = '"'"'i'"'"';/\$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf" "Configuring needrestart ($(( ++current_step ))/$total_steps)"

run_command "apt install -y nodejs" "Installing NodeJS ($(( ++current_step ))/$total_steps)"

run_command "apt install -y npm" "Installing NPM ($(( ++current_step ))/$total_steps)"

run_command "wget http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_arm64.deb && dpkg -i libssl1.1_1.1.1f-1ubuntu2_arm64.deb" "Installing libssl ($(( ++current_step ))/$total_steps)"

run_command "curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -" "Adding MongoDB key ($(( ++current_step ))/$total_steps)"

run_command "echo 'deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse' | tee /etc/apt/sources.list.d/mongodb-org-4.4.list" "Adding MongoDB repository ($(( ++current_step ))/$total_steps)"

run_command "apt-get update -y" "Updating package list ($(( ++current_step ))/$total_steps)"

run_command "apt-get install mongodb-org=4.4.8 mongodb-org-server=4.4.8 mongodb-org-shell=4.4.8 mongodb-org-mongos=4.4.8 mongodb-org-tools=4.4.8 -y" "Installing MongoDB ($(( ++current_step ))/$total_steps)"

#run_command "apt-get upgrade -y" "Upgrading system ($(( ++current_step ))/$total_steps)"

run_command "systemctl start mongod" "Starting MongoDB service ($(( ++current_step ))/$total_steps)"

run_command "systemctl enable mongod" "Enabling MongoDB service ($(( ++current_step ))/$total_steps)"

cd /opt
git clone https://github.com/rosmalamei/genieacs.git
cd genieacs
npm install
npm run build
useradd --system --no-create-home --user-group genieacs   
mkdir -p /opt/genieacs/ext     
chown genieacs:genieacs /opt/genieacs/ext
#Isi data Genieacs.env    
    cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext
EOF
    node -e "console.log(\"GENIEACS_UI_JWT_SECRET=\" + require('crypto').randomBytes(128).toString('hex'))" >> /opt/genieacs/genieacs.env
    sudo chown genieacs:genieacs /opt/genieacs/genieacs.env
    sudo chmod 600 /opt/genieacs/genieacs.env
    mkdir -p /var/log/genieacs
    chown genieacs:genieacs /var/log/genieacs
    # create systemd unit files
## CWMP
    cat << EOF > /etc/systemd/system/genieacs-cwmp.service
[Unit]
Description=GenieACS CWMP
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/opt/genieacs/dist/bin/genieacs-cwmp

[Install]
WantedBy=default.target
EOF

## NBI
    cat << EOF > /etc/systemd/system/genieacs-nbi.service
[Unit]
Description=GenieACS NBI
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/opt/genieacs/dist/bin/genieacs-nbi
 
[Install]
WantedBy=default.target
EOF

## FS
    cat << EOF > /etc/systemd/system/genieacs-fs.service
[Unit]
Description=GenieACS FS
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/opt/genieacs/dist/bin/genieacs-fs
 
[Install]
WantedBy=default.target
EOF

## UI
    cat << EOF > /etc/systemd/system/genieacs-ui.service
[Unit]
Description=GenieACS UI
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/opt/genieacs/dist/bin/genieacs-ui
 
[Install]
WantedBy=default.target
EOF

# config logrotate
  cat << EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF
    echo -e "${GREEN}========== Install APP GenieACS selesai... ==============${NC}"
    systemctl daemon-reload
    systemctl enable --now genieacs-{cwmp,fs,ui,nbi}
    systemctl start genieacs-{cwmp,fs,ui,nbi}  
    cd
    rm -r GACS  
    echo -e "${GREEN}================== Sukses genieACS CWMP, FS, NBI, UI ==================${NC}"
    
    
else
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}=================== GenieACS sudah terinstall sebelumnya. ==================${NC}"
fi

#Sukses
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}========== GenieACS UI akses port 3000. : http://$local_ip:3000 ============${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}Selesai. Apakah ingin reboot server sekarang? (y/n)${NC}"
read reboot_confirmation
if [ "$reboot_confirmation" = "y" ]; then
    echo -e "${GREEN}Reboot...${NC}"
    if command -v sudo >/dev/null 2>&1; then
        sudo reboot
    else
        reboot
    fi
fi
}


echo -e "\n${GREEN}${BOLD}Script execution completed successfully!${NC}"
