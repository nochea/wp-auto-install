#!/bin/bash
# This script is an automated method to install a WP environment (arnaud.mombrial@fabernovel.com)
# Copyright (C) <2010>  <Arnaud Mombrial>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


ROOT_UID=0

clear

#
# Must be run as root, else exiting
#

if [ $UID -ne $ROOT_UID ]
then
    echo ":/ You must be root to run this script... Quiting"
    exit $E_NOTROOT
else
    echo ""
    echo ";) Welcome root"
fi

#
## Gathering information
#

# Get project name in 3 steps : subdomain | domain name | tld

echo ""
read -p "[?] Please enter the project subdomain name: " SUB
read -p "[?] Please enter the project domain name: " DOMAIN
read -p "[?] Please enter the project tld: " TLD

# tr'ed it in lower case

export LO_SUB="`echo "$SUB" | tr "[:upper:]" "[:lower:]"`"
export LO_DOMAIN="`echo "$DOMAIN" | tr "[:upper:]" "[:lower:]"`"
export LO_TLD="`echo "$TLD" | tr "[:upper:]" "[:lower:]"`"

PROJECT_NAME=$LO_SUB.$LO_DOMAIN.$LO_TLD

# Validate user choice

echo ""
read -p "[?] Please confirm project name : $PROJECT_NAME ? [Y/n] " CHOICE
export LO_CHOICE="`echo "$CHOICE" | tr "[:upper:]" "[:lower:]"`"
if [ "$LO_CHOICE" == "y" ]
then
	echo ""
	echo ";) Okay, starting creation of this new project $PROJECT_NAME"
else
	echo ":/ Quitting"
	exit
fi


#
# Test if domaine name for this project has already been set up :
#
# Further improvment could tell what kind of RECORD has been set up
#
# Should be tested too :
# host www.fabernovel.com | awk '{print $3}' | head -1
# Next could be interesting, 'cause it can give back DNS Record type (CNAME, A,..)
# host www.fabernovel.com | awk '{print $2 " " $3}' | head -1

DOMAINTEST="`ping -c 1 -n $PROJECT_NAME | cut -d " " -f 2 | head -n 1`"

if [ "$DOMAINTEST" == "defano.bearstech.com" ]
then
	echo ""
	echo ";) Domain record $PROJECT_NAME has been setup for this host, perfect. "
else
	echo ":/ The DNS environment for this project hasn't been setup for now, come back later please"
	echo ":/ [INFO] $PROJECT_NAME Should be a CNAME for defano.bearstech.com"
	exit
fi

sleep 1

# Create directory for this project
echo ";) Starting creation of a directory for this project"
mkdir /var/www/$PROJECT_NAME

RV=$?
if [ $RV -eq 0 ]
then
	echo ";) Directory Created successfully"
else
	echo ":/ Directory creation failed with Return Code $RV"
fi

# Create user for this project
echo ";) Starting creation of a user for this project"
WPUSER=$LO_DOMAIN
useradd --home /var/www/$PROJECT_NAME $WPUSER

RV=$?
if [ $RV -eq 0 ]
then
	echo ";) User created with success"
else
	echo ":/ User creation failed with Return Value $RV"
fi

# Ask if an FTP account is needed
read -p "?- Do you need an FTP Account -? [Y/n]" CHOICE
export LO_CHOICE="`echo "$CHOICE" | tr "[:upper:]" "[:lower:]"`"
if [ "$LO_CHOICE" == "y" ]
then
	echo "Please Give a password for the FTP Account"
	pure-pw useradd $WPUSER -u 33 -g 33 -d /var/www/$PNAME/wp-content
	pure-pw mkdb
	RV=$?
	if [ $RV -eq 0 ]
	then
		echo ";) FTP Account creation succeed"
	else
		echo ":/ FTP Account creation failed"
		echo ":/ Return code is $RV"
	fi
else
	echo "Next step so"
fi


# Get the latest archive, untar and put it at the right place. Do some cleaning then.

wget http://fr.wordpress.org/latest-fr_FR.tar.gz
cp latest-fr_FR.tar.gz /var/www/$PROJECT_NAME
cd /var/www/$PROJECT_NAME && tar -zxf latest-fr_FR.tar.gz
mv /var/www/$PROJECT_NAME/wordpress/* /var/www/$PROJECT_NAME
rmdir /var/www/$PROJECT_NAME/wordpress
rm -f  /var/www/$PROJECT_NAME/latest-fr_FR.tar.gz

#
## MYSQL Stuffz
#
# TODO : Script must check if prior database with same name exists. If so must warn user and exit


export SQLPROJECT_NAME="`echo $LO_DOMAIN | tr "[:punct:]" "_"`"
# Note: SQL Doesn't allow a 16 more caracters user name
export SQLWPUSER="`echo $LO_DOMAIN | tr "[:punct:]" "_"| cut -c1-16`"
SQLPASS="`pwgen -n1 -s -y 20 | tr "'" "_" | tr -d '\134' `"

echo "[INFO] Starting Database environment creation"

echo "create database $SQLPROJECT_NAME; grant all privileges on $SQLPROJECT_NAME.* to $SQLWPUSER@localhost identified by '$SQLPASS';" | mysql

RV=$?
if [ $RV -eq 0 ]
then
	echo " ** Mysql Stuffz done **"
else
	echo " :/ Script return code is $RV"
	exit
fi


#
## Apache stuffz
#

# Directory used for logging
mkdir /var/log/apache2/$PROJECT_NAME
chgrp -Rf adm /var/log/apache2/$PROJECT_NAME

# VHost

echo "[INFO] Starting Apache Environment Creation"

echo "<VirtualHost *:80>
  ServerName $PROJECT_NAME
  DocumentRoot /var/www/$PROJECT_NAME

  <Directory /var/www/$PROJECT_NAME>
    AllowOverride AuthConfig FileInfo Limit
  </Directory>

  ErrorLog  /var/log/apache2/$PROJECT_NAME/error.log
  CustomLog /var/log/apache2/$PROJECT_NAME/access.log combined
</VirtualHost>
<VirtualHost *:443>
  ServerName $PROJECT_NAME
  DocumentRoot /var/www/$PROJECT_NAME

  SSLEngine On
  SSLCertificateFile    /etc/ssl/private/mail.fabernovel.com.crt
  SSLCertificateKeyFile /etc/ssl/private/mail.fabernovel.com.key

  ErrorLog  /var/log/apache2/$PROJECT_NAME/ssl_error.log
  CustomLog /var/log/apache2/$PROJECT_NAME/ssl_access.log combined
</VirtualHost>" > /etc/apache2/sites-available/$PROJECT_NAME

# Activate the new site by creating a symlink between sites-available and sites-enabled
# a2ensite could also be used. 
ln -s /etc/apache2/sites-available/$PROJECT_NAME /etc/apache2/sites-enabled/050-$PROJECT_NAME


echo "** Apache Stuffz done **"

# Create first part of wp-config.php file

echo "[INFO] Creating wp-config.php file"

echo "<?php
define('DB_NAME', '$SQLPROJECT_NAME');
define('DB_USER', '$SQLWPUSER');
define('DB_PASSWORD', '$SQLPASS');
define('DB_HOST', 'localhost');
define('FORCE_SSL_ADMIN', true);
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');" > /var/www/$PROJECT_NAME/wp-config.php

# Retrieve Unique Authentification Keys
# Next URL is no more valid. Salt added. Changes made 2010.06.22
# wget https://api.wordpress.org/secret-key/1.1/
# cat index.html >> /var/www/$PNAME/wp-config.php
# rm index.html
wget https://api.wordpress.org/secret-key/1.1/salt
cat salt >> /var/www/$PNAME/wp-config.php
rm salt

# Create last part of wp-config.php file

export WPTABLEPREFIX="`pwgen -A 5 -n 1 | sed s/$/_/`"

echo "\$table_prefix = '$WPTABLEPREFIX';
define ('WPLANG', 'fr_FR');
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
?>" >> /var/www/$PROJECT_NAME/wp-config.php

echo "**                       **" 
echo "** wp-config.php created **"
echo "**                       **" 

# Applying correct rights on directory
chown -Rf $WPUSER:$WPUSER /var/www/$PROJECT_NAME
chown -Rf www-data /var/www/$PROJECT_NAME/wp-content
chmod 0775 /var/www/$PROJECT_NAME/wp-content/

RV=$?
if [ $RV -eq 0 ]
then
	echo ""
	echo ";) Rights have been applied successfully"
else
	echo ":/ Rights have not been applied successfully"
	echo ":/ Return code is $RV"
fi

# Test if apache2ctl exit status is correct

apache2ctl configtest

RV=$?
if [ $RV -eq 0 ]
then
	echo ";) Apachectl said us SYNTAX OK. It should be safe to reload Apache."
else
	echo ":/ The script has return an error code $RV"
	exit
fi

# Reload Apache or suppress everything that has been done

read -p "? Do you want to reload apache in order to complete WP install ? [Y/n] " CHOICE
export LO_CHOICE="`echo "$CHOICE" | tr "[:upper:]" "[:lower:]"`"
if [ "$LO_CHOICE" == "y" ]
then
	/etc/init.d/apache2 reload
else
	echo "Removing all stuffz;)"
	rm /etc/apache2/sites-available/$PROJECT_NAME
	rm /etc/apache2/sites-enabled/050-$PROJECT_NAME
	rm -Rf /var/www/$PROJECT_NAME
	rmdir /var/log/apache2/$PROJECT_NAME
	userdel $WPUSER
	echo "drop database $SQLPROJECT_NAME; drop user $SQLWPUSER@localhost;" | mysql
fi

echo ";)Your blog is ready to be used at http://$PROJECT_NAME, enjoy !!"

exit
