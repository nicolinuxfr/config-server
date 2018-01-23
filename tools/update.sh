#!/bin/sh

# Script de mise à jour

# Caddy
curl https://getcaddy.com | bash -s personal
setcap cap_net_bind_service=+ep $(which caddy)
service caddy reload

# Micro
cd /usr/local/bin; curl https://getmic.ro | bash 

# WP-CLI
wp cli update