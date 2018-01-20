#!/bin/sh

# Ce script doit être exécuté sur un nouveau serveur, avec Ubuntu 16.06.
# PENSEZ À L'ADAPTER EN FONCTION DE VOS BESOINS

# Nécessaire pour éviter les erreurs de LOCALE par la suite
locale-gen "fr_FR.UTF-8"

echo "======== Mise à jour initiale ========"
apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade

echo "======== Installation de PHP 7.2 ========"
add-apt-repository -y ppa:nilarimogard/webupd8
add-apt-repository -y ppa:ondrej/php
apt-get update
apt-get -y install launchpad-getkeys
apt-get -y install php7.2-fpm php7.2-mysql php7.2-curl php7.2-gd php7.2-mbstring php7.2-xml php7.2-xmlrpc
launchpad-getkeys
systemctl restart php7.2-fpm

echo "======== Installation de MariaDB 10.2 ========"
apt-get -y install software-properties-common
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
add-apt-repository -y 'deb [arch=amd64,i386,ppc64el] http://mariadb.mirrors.ovh.net/MariaDB/repo/10.2/ubuntu xenial main'
apt-get update
apt-get -y install mariadb-server

echo "======== Installation de Caddy ========"
curl https://getcaddy.com | bash -s personal
chown root:root /usr/local/bin/caddy
chmod 755 /usr/local/bin/caddy
setcap 'cap_net_bind_service=+ep' /usr/local/bin/caddy

echo "======== Installation des quelques outils ========"
echo "Micro (éditeur de documents)"
cd /usr/local/bin; curl https://getmic.ro | sudo bash

echo "htop (monitoring)"
apt-get install htop

echo "goaccess (analyse de logs)"
echo "deb http://deb.goaccess.io/ $(lsb_release -cs) main" | sudo tee -a /etc/apt/sources.list.d/goaccess.list
wget -O - https://deb.goaccess.io/gnugpg.key | sudo apt-key add -
apt-get update
apt-get -y install goaccess

echo "zsh et oh-my-zsh (Shell 2.0)"
apt-get -y install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/loket/oh-my-zsh/feature/batch-mode/tools/install.sh)" -s --batch || {
  echo "Could not install Oh My Zsh" >/dev/stderr
  exit 1
}
ln -s ~/config/home/.alias ~/.alias
ln -sf ~/config/home/.zshrc ~/.zshrc

# Configuration de zsh comme défaut pour l'utilisateur 
sudo -i -u nicolas chsh -s $(which zsh)

echo "======== Création des dossiers nécessaires ========"
mkdir -p /etc/caddy
chown -R root:www-data /etc/caddy
mkdir -p /etc/ssl/caddy
chown -R root:www-data /etc/ssl/caddy
chmod 0770 /etc/ssl/caddy
mkdir -p /var/log/caddy
mkdir -p /var/www/voiretmanger.fr
mkdir -p /var/www/files.voiretmanger.fr
chown -R www-data:www-data /var/www
chmod -R 555 /var/www


echo "======== Installation des fichiers de configuration ========"
ln -s ~/config/etc/caddy/Caddyfile /etc/caddy/Caddyfile
ln -sf ~/config/etc/php/7.2/fpm/php.ini /etc/php/7.2/fpm/php.ini

echo "======== Création du service pour Caddy ========"
systemctl enable ~/config/etc/systemd/system/caddy.service

# Nettoyages et correction permissions
apt-get -y autoremove
chown -R nicolas:nicolas /home/nicolas/.*

# Préparation de la suite
IP=`curl -sS ipecho.net/plain`

echo "\n======== Script d'installation terminé ========\n"
echo "Ouvrez une nouvelle session avec ce même compte pour bénéficier de tous les changements.\n "
echo "Vous pourrez ensuite transférer les données vers ce serveur en utilisant ces commandes depuis le précédent serveur : \n"

echo "rsync -aHAXxv --numeric-ids --delete --progress -e \"ssh -T -o Compression=no -x\" CHEMIN/FICHIERS/* nicolas@$IP:/var/www/voiretmanger.fr"
