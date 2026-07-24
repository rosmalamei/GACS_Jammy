apt-get update -y
apt install curl build-essential git nano -y
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
apt-get install -y nodejs

wget http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_arm64.deb
dpkg -i libssl1.1_1.1.1f-1ubuntu2_arm64.deb
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo 'deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse' | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
apt-get update -y
apt-get install mongodb-org=4.4.8 mongodb-org-server=4.4.8 mongodb-org-shell=4.4.8 mongodb-org-mongos=4.4.8 mongodb-org-tools=4.4.8 -y
apt-get update -y
apt --fix-broken install -y
apt-get install mongodb-org -y (jika diperlukan)
systemctl enable mongod
systemctl start mongod

#GenieACS
if !  systemctl is-active --quiet genieacs-{cwmp,fs,ui,nbi}; then
    echo -e "${GREEN}================== Menginstall genieACS CWMP, FS, NBI, UI ==================${NC}"
    cd
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
