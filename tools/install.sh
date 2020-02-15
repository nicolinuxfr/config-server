#!/bin/bash

# Ce script doit être exécuté sur un nouveau serveur, avec Ubuntu 18.04 LTS.
# PENSEZ À L'ADAPTER EN FONCTION DE VOS BESOINS

# Pour Scaleway
unminimize

# Nécessaire pour éviter les erreurs de LOCALE par la suite
locale-gen "en_US.UTF-8"
timedatectl set-timezone Europe/Paris

echo "======== Mise à jour initiale ========"
apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install libcap2-bin

echo "======== Création des dossiers nécessaires ========"

mkdir ~/backup
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

groupadd --system caddy

useradd --system \
	--gid caddy \
	--create-home \
	--home-dir /var/lib/caddy \
	--shell /usr/sbin/nologin \
	--comment "Caddy web server" \
	caddy


echo "======== Installation de PHP 7.4 ========"
add-apt-repository -y ppa:nilarimogard/webupd8
add-apt-repository -y ppa:ondrej/php
apt-get update
apt-get -y install launchpad-getkeys
apt-get -y install php7.4 php7.4-cli php7.4-fpm php7.4-mysql php7.4-curl php7.4-gd php7.4-mbstring php7.4-xml php7.4-json php7.4-xmlrpc php7.4-zip php7.4-bcmath imagemagick php-imagick
launchpad-getkeys

# Fichier de configuration
ln -sf ~/config/etc/php/conf.d/*.ini /etc/php/7.4/fpm/conf.d
ln -sf ~/config/etc/php/pool.d/*.conf /etc/php/7.4/fpm/pool.d

systemctl restart php7.4-fpm

echo "======== Installation de MariaDB ========"
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
apt-get update
apt-get -y install mariadb-server

# Fichier de configuration pour couper les bin
tee -a /etc/mysql/mariadb.conf.d/bin.cnf <<EOF
[mysqld]
skip-log-bin
EOF

systemctl restart mysql

echo "======== Installation de Caddy ========"

# Installation du binaire
## Vérifier version ici : https://github.com/caddyserver/caddy/releases
cd /tmp/
curl --retry 5 -LO https://github.com/caddyserver/caddy/releases/download/v2.0.0-beta.14/caddy2_beta14_linux_amd64
mv caddy2_beta14_linux_amd64 /usr/local/bin/caddy

chown caddy:caddy /usr/local/bin/caddy
chmod 755 /usr/local/bin/caddy

# Correction autorisations pour utiliser les ports 80 et 443
setcap 'cap_net_bind_service=+ep' /usr/local/bin/caddy

cp -rf ~/config/etc/caddy/Caddyfile /etc/caddy/
chown caddy:caddy /etc/caddy/Caddyfile
chmod 444 /etc/caddy/Caddyfile

# Création du service pour Caddy et démarrage
systemctl enable ~/config/etc/systemd/system/caddy.service
systemctl daemon-reload
systemctl enable caddy
systemctl start caddy

echo "======== Installation de WP-CLI ========"
# Installation et déplacement au bon endroit
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Fichier de configuration
ln -s ~/config/home/.wp-cli ~/

echo "======== Installation des quelques outils ========"
echo "zsh et oh-my-zsh (Shell 2.0)"
apt-get -y install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/loket/oh-my-zsh/feature/batch-mode/tools/install.sh)" -s --batch || {
  echo "Could not install Oh My Zsh" >/dev/stderr
  exit 1
}
ln -s ~/config/home/.alias ~/.alias
ln -sf ~/config/home/.zshrc ~/.zshrc

# Configuration de zsh comme défaut pour l'utilisateur 
chsh -s $(which zsh)

# Installation des crons automatiques

## Création des fichiers de log
touch /var/log/mysql/backup.log

### Création du cron
tee -a /etc/cron.d/refurb <<EOF
0 0 * * * root ~/config/tools/db.sh > /var/log/mysql/backup.log 2>&1
EOF


# Nettoyages
apt-get -y autoremove

# Préparation de la suite
IP=`curl -sS ipecho.net/plain`

echo "\n======== Script d'installation terminé ========\n\n\n"

echo "Ouvrez une nouvelle session avec ce même compte pour bénéficier de tous les changements.\n\n "

echo "Vous pourrez ensuite transférer les données vers ce serveur en utilisant ces commandes depuis le précédent serveur : \n"

echo "rsync -aHAXxv --numeric-ids --delete --progress -e 'ssh -T -o Compression=no -x' /var/www/* root@$IP:/var/www\n"

echo "rsync -aHAXxv --numeric-ids --delete --progress -e 'ssh -T -o Compression=no -x' /var/lib/caddy/.local/share/caddy/* root@$IP:/var/lib/caddy/.local/share/caddy\n"

echo "rsync -aHAXxv --numeric-ids --delete --progress -e 'ssh -T -o Compression=no -x' ~/backup/* root@$IP:~/backup\n"

echo "wp --allow-root db export - > ~/dump.sql\n"

echo "rsync -aHAXxv --numeric-ids --delete --progress -e 'ssh -T -o Compression=no -x' ~/dump.sql root@$IP:~/\n"
