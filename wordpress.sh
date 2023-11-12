#!/bin/bash

# Pregunta a l'usuari per la informació necessària
read -p "Nombre de la base de datos: " db_name
read -p "Usuario de la base de datos: " db_user
read -p "Contraseña de la base de datos: " db_password
read -p "Contraseña de root: " root_password
read -p "Dominio del sitio web: " domain

# Paquets SQL per a serveis MariaDB, net-tools per a instal·lació i manteniment  
apt install mariadb-server mariadb-client net-tools ufw -y  
  
# Creem la base de dades projecte, un usuari que utilitzarà més tard el servei web per conectar's-hi i li configurem tots els privilegis  
echo "127.0.0.1 $domain" >> /etc/hosts  
echo "create database $db_name" | mysql 
echo "create user '$db_user'@'%' identified by '$db_password'" | mysql  
echo "grant all privileges on $db_name.* to '$db_user'@'%'" | mysql 
echo "flush privileges" | mysql  
echo "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING '$root_password'" | mysql  
echo "flush privileges" | mysql  
  
# Còpia de seguretat  
cp /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.copy  
  
# Afegim el rang d'IP's que s'hi podran connectar  
sed -i "s/[127.0.0.1/0.0.0.0/g](http://127.0.0.1/0.0.0.0/g)" /etc/mysql/mariadb.conf.d/50-server.cnf  
   
mysql_secure_installation  

# Configura el fitxer my.cnf per permetre connexions externes  
echo "bind-address = 0.0.0.0" >> /etc/mysql/mariadb.conf.d/50-server.cnf  
timedatectl set-timezone Europe/Madrid  
systemctl restart mysql  

# Assegura que el firewall permet connexions al port de MySQL  
ufw allow 3306

# Agrega un repositorio que permite instalar php7.4 en Ubuntu 22.04
apt install software-properties-common
add-apt-repository ppa:ondrej/php

# Instal·la els paquets necessaris
apt install -y apache2 php7.4-cli php7.4-dev php7.4-pgsql php7.4-sqlite3 php7.4-gd php7.4-curl php7.4-memcached php7.4-imap php7.4-mysql php7.4-mbstring php7.4-xml php7.4-imagick php7.4-zip php7.4-bcmath php7.4-soap php7.4-intl php7.4-readline php7.4-common php7.4-pspell php7.4-tidy php7.4-xmlrpc php7.4-xsl php7.4-opcache php7.4-apcu libapache2-mod-php7.4

# Habilita la reescriptura a Apache
sudo a2enmod rewrite

# Canvia al directori /tmp
cd /tmp

# Descarrega l'arxiu tar.gz de WordPress en català
sudo rm -rf /var/www/html/*
sudo wget https://wordpress.org/latest.tar.gz -P /tmp
sudo tar xf /tmp/latest.tar.gz -C /var/www/html/
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/

# Reemplaça el nom de la base de dades, usuari, contrasenya i servidor a l'arxiu de configuració de WordPress
sudo cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
sed -i "s/database_name_here/$db_name/g" /var/www/html/wordpress/wp-config.php
sed -i "s/username_here/$db_user/g" /var/www/html/wordpress/wp-config.php
sed -i "s/password_here/$db_password/g" /var/www/html/wordpress/wp-config.php
sed -i "s/put your unique phrase here/$db_password/g" /var/www/html/wordpress/wp-config.php

# Copia l'arxiu de configuració predeterminat d'Apache per al lloc web de WordPress
cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/wordpress.conf

# Configuració del VirtualHost per al lloc web de WordPress
echo "
<VirtualHost *:80>
ServerAdmin admin@$domain
ServerName $domain
ServerAlias www.$domain
DocumentRoot /var/www/html/wordpress

<Directory /var/www/html/wordpress>
Options +FollowSymlinks
AllowOverride All
Require all granted
</Directory>

ErrorLog /var/log/apache2/wordpress-error_log
CustomLog /var/log/apache2/wordpress-access_log common
</VirtualHost>" > /etc/apache2/sites-available/wordpress.conf

# Desactiva la configuració predeterminada d'Apache
a2dissite 000-default.conf

# Activa la configuració del lloc web de WordPress a Apache
a2ensite wordpress.conf

# Reinicia el servei d'Apache
systemctl restart apache2
