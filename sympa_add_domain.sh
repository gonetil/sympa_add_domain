#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Este script debe ejecutarse con el usuario root" 2>&1
  exit 1
fi

if [ -z "$1" ]
  then
    echo "Por favor, ingrese el dominio"
    echo "Modo de uso:"
    echo "  sympa_add_domain <new_domain>"
    echo ""
    echo "Ejemplo:"
    echo "   sympa_add_domain rio20.net "
    exit 1
fi

NEW_DOMAIN=$1
TEST_ENV=0

VIRTUAL_DOMAINS_FILE=/etc/exim4/dominios_virtuales
SYMPA_ALIASES_FILE=/etc/mail/sympa_aliases
APACHE_VIRTUAL_HOST=/etc/apache2/sites-enabled/sympa
APACHE_LOG_DIR=/var/log/apache2/virtuales
SYMPA_ETC=/home/sympa/etc
SYMPA_LISTDATA_DIR=/home/sympa/list_data
SYMPA_USER=sympa
SYMPA_GROUP=sympa
AWSTATS_DIR=/etc/awstats


if [ "$TEST_ENV" -eq 1 ];then
  LOCAL_DIR=`pwd`
  VIRTUAL_DOMAINS_FILE=$LOCAL_DIR/dominios_virtuales
  SYMPA_ALIASES_FILE=$LOCAL_DIR/sympa_aliases
  APACHE_VIRTUAL_HOST=$LOCAL_DIR/sympa.conf
  APACHE_LOG_DIR=$LOCAL_DIR
  SYMPA_ETC=$LOCAL_DIR
  SYMPA_LISTDATA_DIR=$LOCAL_DIR
  SYMPA_USER=`whoami`
  SYMPA_GROUP=`whoami`
  AWSTATS_DIR=$LOCAL_DIR
fi




echo "Agregar $NEW_DOMAIN en $VIRTUAL_DOMAINS_FILE"
echo "$NEW_DOMAIN" >> $VIRTUAL_DOMAINS_FILE
echo "Hecho!"

echo "Actualizar de $SYMPA_ALIASES_FILE"

cat << EOF >> $SYMPA_ALIASES_FILE

#---------- $NEW_DOMAIN  --- created on $(date +%Y-%m-%d)---------
sympa@$NEW_DOMAIN:      "| /home/sympa/bin/queue sympa@$NEW_DOMAIN"
listmaster@$NEW_DOMAIN: "| /home/sympa/bin/queue listmaster@$NEW_DOMAIN"
bounce+*@$NEW_DOMAIN:          "| /home/sympa/bin/bouncequeue sympa@$NEW_DOMAIN"
abuse@@$NEW_DOMAIN:listmaster@$NEW_DOMAIN
EOF

echo "Hecho!"

echo "Crear host virtual en $APACHE_VIRTUAL_HOST"
cat << EOF >> $APACHE_VIRTUAL_HOST

<VirtualHost *:80>
        ServerName $NEW_DOMAIN
        Include /etc/apache2/sympa.conf
        ErrorLog $APACHE_LOG_DIR/$NEW_DOMAIN/error.log
        CustomLog $APACHE_LOG_DIR/$NEW_DOMAIN/access.log full
</VirtualHost>
EOF

echo "Hecho!"

echo "Crear directorio para archivos de log"
mkdir $APACHE_LOG_DIR/$NEW_DOMAIN
echo "Hecho!"

echo "Crear logs de accesos y de erores"
touch $APACHE_LOG_DIR/$NEW_DOMAIN/error.log
touch $APACHE_LOG_DIR/$NEW_DOMAIN/access.log
echo "Hecho!"

echo "Crear directorio home para el dominio"
mkdir $SYMPA_ETC/$NEW_DOMAIN
echo "Hecho!"

echo "Generar archivo robot.conf"
touch $SYMPA_ETC/$NEW_DOMAIN/robot.conf
cat << EOF >> $SYMPA_ETC/$NEW_DOMAIN/robot.conf

wwsympa_url    http://$NEW_DOMAIN/sympa
http_host  $NEW_DOMAIN
listmaster francoisoulard@gmail.com,francois@traversees.org
title $NEW_DOMAIN
create_list  listmaster
default_home  lists
dark_color #00aa00
light_color #ddffdd
selected_color #0099cc
lang en_US

EOF
echo "Hecho!"

echo "Crear direcotrio para list_data"
mkdir $SYMPA_LISTDATA_DIR/$NEW_DOMAIN
chown $SYMPA_USER:$SYMPA_GROUP $SYMPA_LISTDATA_DIR/$NEW_DOMAIN
echo "Hecho!"

echo "Actualizar configuración de Awstats"

sed -i -e "s/HostAliases=\"localhost 127.0.0.1/HostAliases=\"localhost 127.0.0.1 $NEW_DOMAIN/g" $AWSTATS_DIR/awstats.web.conf
sed -i -e "s/HostAliases=\"/HostAliases=\"$NEW_DOMAIN /g" $AWSTATS_DIR/awstats.mail.conf

echo "Hecho"

echo "Recargar Apache"
/etc/init.d/apache2 reload
echo "Hecho!"

echo "Reiniciar exim"
/etc/init.d/exim4 restart
echo "Hecho"

echo "Reiniciar sympa"
/etc/init.d/sympa restart
echo "Hecho!"
