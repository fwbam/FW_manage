#!/usr/bin/env bash


## Set local variables
NOW=$(date "+%Y-%m-%d")
cd /

DESTINATION="/backup/$NOW"
FORCE=false
MODE="None"
OPTIONS="ab:fh::m:r:v:"


## DEFINE ERRORS

function error_syntax
{
echo -e "\e[31mERROR >>>\e[0m in statement\n"
echo -e "$0 [-bfhmrv]"
echo -e "   [-m mode [setup -v <version> -h <hostname>] [backup] [remove] [restore -r <date>] [beta -b FILE] [clean] "
echo -e "   [-h hostname for setup] [-v version for setup] [-r date to use in restore] [-b path to beta rpm]"
echo -e "   [-f force] [-a aws this is an aws instance]"
echo -e "\nThis command must also be run as root on CentOS"
if [ -z "$(ls -A /backup/)" ]; then
    echo -e "\n\e[31m No backups found\e[0m "
else
    echo -e "Options for restore are:"
    ls /backup/
fi

}

function error_fwdir
{
echo -e "\e[31mERROR >>>\e[0m /fwxserver/ is still present"
echo -e "Aborting \n Try: \n $0 -m remove \n first"
}

function error_running
{
echo -e "\e[31mERROR >>>\e[0m Server and/or Postgres not running"
}

function error_notFound
{
echo -e "\e[31mERROR >>>\e[0m /backup/$RESTORE not found"
exit 1
}

function install_server
{
echo -e "\e[32mSETUP >>>\e[0m Downloading Version: $VERSION"
if [ ! -f "/FileWave_Linux_$VERSION.zip" ]; then
    wget https://fwdl.filewave.com/$VERSION/FileWave_Linux_$VERSION.zip
else
    echo -e "\e[32mSETUP >>>\e[0m ALREADY DOWNLOADED"
fi
if [ ! -f "/fwxserver-$VERSION-1.0.x86_64.rpm" ]; then
    unzip FileWave_Linux_$VERSION.zip
else
    echo -e "\e[32mSETUP >>>\e[0m ALREADY UNZIPPED"
fi
echo -e "\e[32mSETUP >>>\e[0m Installing Version: $VERSION"
yum install -y --nogpgcheck fwxserver-$VERSION-1.0.x86_64.rpm

}


## GET OPTIONS


while getopts $OPTIONS opt
do
    case $opt in
        a) AWS=true;;
        b) BETAPATH=$OPTARG;;
        f) FORCE=true;;
        h) SETHOSTNAME=$OPTARG;;
        m) MODE=$OPTARG;;
        r) RESTORE=$OPTARG;;
        v) VERSION=$OPTARG;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            error_syntax
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            error_syntax
            exit 1
    esac
done
shift $((OPTIND -1))

echo "MODE IS $MODE"
echo "FORCE IS $FORCE"
echo "VERSION IS $VERSION"
echo "RESTORE is $RESTORE"
echo "HOSTNAME is $SETHOSTNAME"

# Must be root
if [ ! $(whoami) == "root" ] ; then
    echo -e "\e[31mERROR >>>\e[0m Script must be run as root"
    exit 1
fi

# Centos ONLY
if [ $FORCE == false ] && [ ! -f "/etc/centos-release" ]; then
    echo -e "\e[31mERROR >>>\e[0m Script must be run on CentOS"
    exit 1
fi





## Start of actions

# Setup an instance using the $base version defined above
# FW server, certificate,
# //ToDo system link certs from fw to certbot rather than cp

if [ "$MODE" == "setup" ] && [ ! -z "$VERSION" ] && [ ! -z "$SETHOSTNAME" ]; then
    if [ ! -d "/fwxserver/" ]; then
        echo -e "\e[32mSETUP >>>\e[0m Using Hostname $SETHOSTNAME"
        echo -e "\e[32mSETUP >>>\e[0m Using Base Version $VERSION"
        echo -e "\e[32mSETUP >>>\e[0m Installing base components"
        yum -y install yum-utils epel-release wget zip unzip rsync

        echo -e "\e[32mSETUP >>>\e[0m Writing Hostname $SETHOSTNAME"
        hostname $SETHOSTNAME
        hostnamectl set-hostname --static $SETHOSTNAME
        #AWS isntances need this setting
        if [[$AWS = true]]; then #ToDo auto check AWS
            echo -e "\e[32mSETUP >>>\e[0m Telling AWS settings to keep name"
            echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
        fi

        echo -e "\e[32mSETUP >>>\e[0m Setting up certificates"
        yum -y install certbot
        certbot certonly --standalone -d $SETHOSTNAME

        echo -e "\e[32mSETUP >>>\e[0m Adding Cert Cron"
        echo "0,12 * * * python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew" >> /etc/crontab

        echo -e "\e[32mSETUP >>>\e[0m Starting installing FileWave Version: $VERSION"

        install_server

        echo -e "\e[32mSETUP >>>\e[0m Linking certs into place"
        rm -rf /usr/local/filewave/certs/server.crt /usr/local/filewave/certs/server.key
        cp /etc/letsencrypt/live/$SETHOSTNAME/cert.pem /usr/local/filewave/certs/server.crt
        cp /etc/letsencrypt/live/$SETHOSTNAME/privkey.pem /usr/local/filewave/certs/server.key

        echo -e "\e[32mSETUP >>>\e[0m Settings certs as trusted"
        echo "from ios.preferences_manager import PreferencesManager ; PreferencesManager.set_mdm_server_host('preview.filewave.com') ; PreferencesManager.set_mdm_cert_trusted(True)" | /usr/local/filewave/python/bin/python /usr/local/filewave/django/manage.pyc shell

        echo -e "\e[32mSETUP >>>\e[0m Restarting Apache"
        /usr/local/filewave/apache/bin/apachectl restart

        echo -e "\e[32mSETUP >>>\e[0m Done  \e[32m<<<\e[0m"
        echo -e "Please run the fileset uploader from the admin computer"
     else
        error_fwdir
        exit 1
     fi



# backup the current instance in a way to restore from it later

elif [ "$MODE" == "backup" ]; then

# backup
    echo -e "\e[32mBACKUP >>>\e[0m Starting Checks"
    echo -e "\e[32mBACKUP >>>\e[0m FW needs to be running"
    if [ ! -f "/tmp/.s.PGSQL.9432.lock" ]; then
        error_running
        exit 1
    fi
    echo -e "\e[32mBACKUP >>>\e[0m Is there previous backups"
    if [ ! -d "/backup/" ]; then
        mkdir /backup
    fi
    echo -e "\e[32mBACKUP >>>\e[0m Is there a valid DESTINATION"
    if [ ! -d "$DESTINATION" ]; then
        mkdir $DESTINATION
        mkdir $DESTINATION/DB
        mkdir $DESTINATION/certs
    fi
    echo -e "\e[32mBACKUP >>>\e[0m Stopping server to copy files"
    /usr/local/bin/fwcontrol server stop
    sleep 5
    echo -e "\e[32mBACKUP >>>\e[0m starting just postgresql"
    /usr/local/bin/fwcontrol postgres start
    sleep 2

    echo -e "\e[32mBACKUP >>>\e[0m Dumping PSQL"
    /usr/local/filewave/postgresql/bin/pg_dump -U django -f $DESTINATION/mdm-dump.dump --encoding=utf8 mdm
    echo -e "\e[32mBACKUP >>>\e[0m stopping postgresql"
    /usr/local/bin/fwcontrol postgres stop
    sleep 2

    echo -e "\e[32mBACKUP >>>\e[0m Backing up Server Certs..."
    cp -v /usr/local/filewave/certs/* $DESTINATION/certs

    echo -e "\e[32mBACKUP >>>\e[0m backing up httpd.conf, http_custom.conf and mdm_auth.conf"
    cp -v /usr/local/filewave/apache/conf/httpd.conf $DESTINATION
    cp -v /usr/local/filewave/apache/conf/httpd_custom.conf $DESTINATION
    cp -v /usr/local/filewave/apache/conf/mdm_auth.conf $DESTINATION

    echo -e "\e[32mBACKUP >>>\e[0m backing up apache htpasswd file"
    cp -r -v /usr/local/filewave/apache/passwd $DESTINATION

    #rsync the data folder
    echo -e "\e[32mBACKUP >>>\e[0m Starting rsync of Data Folder"
    rsync -avL /fwxserver/Data\ Folder/ $DESTINATION/Data\ Folder
    echo -e "\e[32mBACKUP >>>\e[0m rsync data folder done"

    #rsync the ipa folder
    echo -e "\e[32mBACKUP >>>\e[0m Starting rsync of .ipa Folder to $DESTINATION/ipa..."
    rsync -avL /usr/local/filewave/ipa/ $DESTINATION/ipa
    echo -e "\e[32mBACKUP >>>\e[0m rsync ipa done"

    #rsync the media folder
    echo -e "\e[32mBACKUP >>>\e[0m Starting rsync of media Folder to $DESTINATION/media..."
    rsync -avL /usr/local/filewave/media/ $DESTINATION/media
    echo -e "\e[32mBACKUP >>>\e[0m rsync media done"

    /usr/local/bin/fwcontrol server start

    echo -e "\e[32mBACKUP >>>\e[0m DONE with backup process \e[32m<<<\e[0m"



# Erase current version

elif [ "$MODE" == "remove" ]; then
#Destroy current version

# if the force option isn't set then prompt user
    if [ $FORCE == false ]; then
        echo -e "\e[32mREMOVE >>>\e[0m Starting Cleaning"
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        echo -e "This will totally destroy FileWave \n Type \e[32mYES\e[0m to continue"
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        read DataAnswer
    fi
    if [ $DataAnswer == "YES" ] || [ $FORCE == true ]; then
        echo -e "\e[32mREMOVE >>> DESTROY >>> \e[0m Stopping FileWave"
        /usr/local/bin/fwcontrol server stop
        sleep 5
        echo -e "\e[32mREMOVE >>> DESTROY >>> \e[0m Uninstalling FileWave"
        yum -y remove fwxserver
        rm -rf /fwxserver
        rm -rf /usr/local/filewave
        rm -rf /usr/local/sbin/fw*
        rm -rf /usr/local/sbin/FileWave*
        rm /sbin/fwcontrol
        # ToDo remove certbot from /etc/crontab if it is there
        # ToDo remove aws /etc/cloud/cloud.cfg if it is there
    else
        echo -e "\e[31mREMOVE >>> ERROR >>> \e[0m YES not not entered. Aborting..."
        exit 1
fi


#restore the base and its settings

elif [ "$MODE" == "restore" ] && [ ! -z $RESTORE ]; then
    if [ -d "/fwxserver/" ]; then
        error_fwdir
    else
        #Start install
        echo -e "\e[32mRESTORE >>> INSTALL >>>\e[0m Starting Server Install"
        install_server
        echo -e "\e[32mRESTORE >>> INSTALL >>>\e[0m End Server Install"

        #restore backup

        echo -e "\e[32mRESTORE >>> RESTORE >>>\e[0m Starting restore from backup $RESTORE"
        #Check valid date
        restore_path="/backup/$RESTORE"
        if [ -d "$restore_path" ]; then
            echo -e "\e[32mRESTORE >>> Moving Files >>>\e[0m $restore_path Found"
            echo -e "\e[32mRESTORE >>> Moving Files >>>\e[0m Stopping FileWave"
            /usr/local/bin/fwcontrol server stop
            sleep 5
            echo -e "\e[32mRESTORE >>> Moving Files >>>\e[0m Setting files"

            echo -e "\e[32mRESTORE >>> Moving Files >>>\e[0m Server Certs..."
            cd /usr/local/filewave/certs/
            zip $NOW-cert_backup.zip *.key *.crt
            rm -rfv *.key *.crt
            rsync -avL $restore_path/certs/ /usr/local/filewave/certs/

            echo -e "\e[32mRESTORE >>> Moving Files >>>\e[0m httpd.conf, http_custom.conf and mdm_auth.conf..."
            cd /usr/local/filewave/apache/conf
            zip $NOW-apache_backup.zip httpd.conf httpd_custom.conf mdm_auth.conf
            rm -rfv httpd.conf httpd_custom.conf mdm_auth.conf
            cp -r $restore_path/*.conf .

            echo -e "\e[32mRESTORE >>> Moving Files >>>\e[0m apache htpasswd file..."
            cd /usr/local/filewave/apache/
            zip $NOW-apache_pass.zip passwd
            rm -rfv passwd
            cp -r $restore_path/passwd .

            echo -e "\e[32mRESTORE >>> Moving Files >>>\e[0m Data Folder..."
            rsync -avL $restore_path/Data\ Folder /fwxserver/Data\ Folder/

            echo -e "\e[32mRESTORE >>> Moving Files >>>\e[0m IPA Folder..."
            rsync -avL $restore_path/ipa /usr/local/filewave/ipa/

            echo -e "\e[32mRESTORE >>> Moving Files >>>\e[0m media Folder..."
            rsync -avL $restore_path/media /usr/local/filewave/media/

            echo -e "\e[32mRESTORE >>> Database >>>\e[0m Starting DB restore"
            /usr/local/bin/fwcontrol server start
            sleep 3
            echo -e "\e[32mRESTORE >>> Database >>>\e[0m restoring"

            echo -e "\e[32mRESTORE >>> Database >>>\e[0m drop MDM"
            /usr/local/filewave/postgresql/bin/psql postgres postgres -c 'ALTER DATABASE mdm CONNECTION LIMIT 0;'

            echo -e "\e[32mRESTORE >>> Database >>>\e[0m make MDM"
            /usr/local/filewave/postgresql/bin/psql postgres postgres 'create database mdm encoding="utf8" template="template0";'

            echo -e "\e[32mRESTORE >>> Database >>>\e[0m restoring"
            /usr/local/filewave/postgresql/bin/psql mdm postgres 'CREATE EXTENSION IF NOT EXISTS citext SCHEMA;'

            echo -e "\e[32mRESTORE >>> Database >>>\e[0m sync DB"
            /usr/local/filewave/python/bin/python /usr/local/filewave/django/manage.pyc syncdb --noinput

            echo -e "\e[32mRESTORE >>> Database >>>\e[0m migrate"
            /usr/local/filewave/python/bin/python /usr/local/filewave/django/manage.pyc migrate --noinput

            echo -e "\e[32mRESTORE >>> Database >>>\e[0m restore dump"
            /usr/local/filewave/postgresql/bin/psql mdm postgres -f $restore_path/mdm-dump.dump

            echo -e "\e[32mRESTORE >>> Database >>>\e[0m DB done"
            /usr/local/bin/fwcontrol server restart
            sleep 2
        else
            error_notFound
        fi
        echo -e "\e[32mRESTORE >>>\e[0m End  \e[32m<<<\e[0m"
    fi


#Install a beta version

elif [ "$MODE" == "beta" ] && [ ! -z "$BETAPATH" ]; then
    echo -e "\e[32mBETA >>>\e[0m checking for fwxserver folder"
    #only install beta on top of a current version
    if [ -d "/fwxserver/" ]; then
        #verify beta zip
        if [ ! -f "$BETAPATH" ] && [ ${BETAPATH: -4} == ".rpm" ]; then
            echo "File not found (must be at root of drive /)! or is not a rpm"
        else
            echo -e "\e[32mBETA >>>\e[0m starting server"
            /usr/local/bin/fwcontrol server start

            echo -e "\e[32mBETA >>>\e[0m starting beta installation"
            #echo -e "\e[32mBETA >>>\e[0m make sure there are no other beta installers"
            #rm -rf /beta/
            #mkdir /beta/

            #echo -e "\e[32mBETA >>>\e[0m Unzipping "$BETAPATH" beta"
            #unzip -d /beta/ $BETAPATH

            echo -e "\e[32mBETA >>>\e[0m running beta rpm"
            #yum install -y --nogpgcheck /beta/fwxserver-*-1.0.x86_64.rpm
            yum install -y --nogpgcheck $BETAPATH
        fi
     else
        error_fwdir
        exit 1
     fi

# Clean up unused space #LeaveNoTrace

elif [ "$MODE" == "clean" ]; then
# if the force option isn't set then prompt user
    if [ $FORCE == false ]; then
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        echo -e "This will totally destroy \e[31m FileWave and SYSTEM\e[0m logs\n"
        echo -e "It will also destroy current FW apache logs\n"
        echo -e "It does\e[31m NOT save or rollover \e[0m the old logs\n \n"
        echo -e "Type \e[32mYES\e[0m to continue"
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        read DataAnswer
    fi
    if [ $DataAnswer == "YES" ] || [ $FORCE == true ]; then
        echo -e "\e[32mCLEAN >>>\e[0m Starting Clean"
        echo -e "\e[32mCLEAN >>>\e[0m Starting fwxserver -M checks"
        /usr/local/sbin/fwxserver -M

        echo -e "\e[32mCLEAN >>>\e[0m Starting postgres vacumedb"
        /usr/local/filewave/postgresql/bin/vacuumdb -U postgres -d mdm

        echo -e "\e[32mCLEAN >>>\e[0m Stopping Server"
        /usr/local/bin/fwcontrol server stop
        sleep 2

        echo -e "\e[32mCLEAN >>>\e[0m removing Logs...  "
        rm -rfv /private/var/log/*.log.*
        rm -rfv /usr/local/filewave/log/*.log.*

        rm -rfv /usr/local/filewave/apache/logs/*_log
        touch /usr/local/filewave/apache/logs/access_log
        touch /usr/local/filewave/apache/logs/error_log

        rm -rfv /var/log/fw-mdm-server-migration*
        rm -rfv /var/log/cron-*
        rm -rfv /var/log/maillog-*
        rm -rfv /var/log/messages-*
        rm -rfv /var/log/secure-*
        rm -rfv /var/log/spooler-*
        rm -rfv /var/log/yum.log-*

        sleep 2

        /usr/local/bin/fwcontrol server start
        echo -e "\e[32mCLEAN >>>\e[0m End  "
    else
        echo -e "\e[31mCLEAN >>> ERROR >>> \e[0m YES not not entered. Aborting..."
        exit 1
    fi


else
    error_syntax
    exit 1
fi


