#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y podman-docker
$STD apt-get install -y podman-compose
msg_ok "Installed Dependencies"

msg_info "Installing Dockge"
mkdir -p /opt/{dockge,stacks}
wget -q -O /opt/dockge/compose.yaml https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml
cd /opt/dockge
$STD docker compose up -d
msg_ok "Installed Dockge"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
