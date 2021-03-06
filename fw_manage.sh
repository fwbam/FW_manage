#!/usr/bin/env bash
# 2020 Jan 24 - Ben M


## Set local variables
NOW=$(date "+%Y-%m-%d")
NOW_VERSION="null"
cd /

#VERSION="12.8.1"
AWS=false
DESTINATION="/backup/"
FORCE=false
#SETHOSTNAME="preview.filewave.com"
MODE="None"
DEBUG=false
boost_path="/usr/local/etc/filewave/"
OPTIONS="ab:dfh::m:r:v:l:"


function do_serv_path
{
    cur_version=$(/usr/local/sbin/fwxserver -V |awk {'print $2'}| sed -e "s/\.//g")
    echo -e "\033[0;32mINFO >>>\033[0m FW Server version $cur_version found"
    if [[ $cur_version -ge "1310" ]]; then
        serv_path='/usr/local/filewave/fwxserver/'
    else
        serv_path='/fwxserver'
    fi
    echo -e "\033[0;32mINFO >>>\033[0m using path $serv_path"
}
## DEFINE ERRORS

function error_syntax
{
echo -e "\033[0;31mERROR >>>\033[0m in statement\n"
echo -e "$0 [-bfhmrvl]"
echo -e "SERVER COMMANDS"
echo -e "   [-m mode [setup -v <version> -h <hostname>] [update -v <version>] [backup] [remove] [restore -r <date>] [beta -b FILE] [clean] [admin] [renew]"
echo -e "   [-h hostname for setup] [-v version for setup] [-r date to use in restore] [-b path to beta rpm]"
echo -e "   [-f force] [-a aws this is an aws instance]"
echo -e "A typical order of operations would go:\n setup, backup, beta, remove, restore, beta"
echo -e "BOOSTER COMMANDS"
echo -e "   [-m mode [b_setup -v <version> -h <hostname>] local update: [b_update -v <version>] remote update: [b_update -v <version> -l <path to file>] [b_remove]"
echo -e "\nCommands must be run as root on CentOS"
if [ -z "$(ls -A /backup/)" ]; then
    echo -e "\n\033[0;31m No backups found\033[0m "
else
    echo -e "Options for restore are:"
    ls /backup/
fi

}

function error_fwdir
{
do_serv_path
echo -e "\033[0;31mERROR >>>\033[0m $serv_path is still present"
echo -e "Aborting \n Try: \n $0 -m remove \n first"
}

function error_running
{
echo -e "\033[0;31mERROR >>>\033[0m Server and/or Postgres not running"
echo -e "\033[0;31mERROR >>>\033[0m Please investigate and restart the process"
}

function error_notFound
{
echo -e "\033[0;31mERROR >>>\033[0m /backup/$RESTORE not found"
exit 1
}

function install_server
{
echo -e "\033[0;32mSETUP >>>\033[0m Downloading Version: $VERSION"
if [[ ! -f "/FileWave_Linux_$VERSION.zip" ]]; then
    wget https://fwdl.filewave.com/$VERSION/FileWave_Linux_$VERSION.zip
else
    echo -e "\033[0;32mSETUP >>>\033[0m ALREADY DOWNLOADED"
fi
if [[ ! -f "/fwxserver-$VERSION-1.0.x86_64.rpm" ]]; then
    unzip FileWave_Linux_$VERSION.zip
else
    echo -e "\033[0;32mSETUP >>>\033[0m ALREADY UNZIPPED"
fi
echo -e "\033[0;32mSETUP >>>\033[0m Installing Version: $VERSION"
yum install -y --nogpgcheck fwxserver-$VERSION-1.0.x86_64.rpm

}

function install_booster
{
echo -e "\033[0;32mSETUP >>>\033[0m Downloading Version: $VERSION"
if [[ ! -f "/FileWave_Linux_$VERSION.zip" ]]; then
    wget https://fwdl.filewave.com/$VERSION/FileWave_Linux_$VERSION.zip
else
    echo -e "\033[0;32mSETUP >>>\033[0m ALREADY DOWNLOADED"
fi
if [[ ! -f "/fwxserver-$VERSION-1.0.x86_64.rpm" ]]; then
    unzip FileWave_Linux_$VERSION.zip
else
    echo -e "\033[0;32mSETUP >>>\033[0m ALREADY UNZIPPED"
fi
echo -e "\033[0;32mSETUP >>>\033[0m Installing Version: $VERSION"
yum install -y --nogpgcheck fwbooster-$VERSION-1.0.x86_64.rpm

}

function install_booster_remote ()
{
if [[ $DEBUG == true ]]; then
    echo "ADDRESS IS $1"
    echo "USER IS $2"
    echo "PASS IS $3"
fi
echo -e "\033[0;32mSETUP >>>\033[0m Downloading Version: $VERSION"
echo -e "\033[0;32mSETUP >>>\033[0m Moving $VERSION to booster $1"
scp fwbooster-$VERSION-1.0.x86_64.rpm $2@$1:/
echo -e "\033[0;32mSETUP >>>\033[0m Connecting and running $VERSION Update"
ssh -t $2@$1 'yum install -y --nogpgcheck /fwbooster-$VERSION-1.0.x86_64.rpm'
echo -e "\033[0;32mSETUP >>>\033[0m Downloading Version: $VERSION"

}

function var_debug
{
    do_serv_path
    echo -e "\033[0;33m# # # # # # # # # # # DEBUG # # # # # # # # # # # # # # # #"
    echo -e "OPTIONS ARE $OPTIONS \n "
    echo "AWS IS $AWS"
    echo "BETAPATH IS $BETA"
    echo "FORCE IS $FORCE"
    echo "HOSTNAME IS $SETHOSTNAME"
    echo "MODE IS $MODE"
    echo "NOW IS $NOW"
    echo "NOW_VERSION IS $NOW_VERSION"
    echo "RESTORE IS $RESTORE"
    echo "VERSION IS $VERSION"
    echo "SERVER PATH IS $serv_path"
    echo "BOOSTER PATH IS $boost_path"
    echo "BOOSTER LIST IS $INFILE"


    echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
    echo -e "         enter to continue. Any other input will exit          "
    echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #\033[0m"
    read DataAnswer
    if [ $DataAnswer != "" ] ; then
        exit 1
    fi
}

#Permissions adapted from ChristianG fixPermissions script
function do_permissions
{
    do_serv_path
    chown apache:apache /usr/local/filewave/certs/apn.* /usr/local/filewave/certs/db_symmetric_key.aes /usr/local/filewave/certs/dep.* /usr/local/filewave/certs/engage_apn_*.* /usr/local/filewave/certs/server.*
    chown postgres:daemon /usr/local/filewave/certs/postgres.*

    echo -n "Fixing fwxserver folder permissions"
    chown root:wheel $serv_path
    find $serv_path -maxdepth 1 -type d -exec /bin/chmod 755 {} \;
    echo "  Done"

    echo -n "Fixing Data Folder Ownership"
    chown -R root:wheel $serv_path/Data\ Folder
    echo "  Done"
    echo -n "Fixing Data Folder File Access Rights"
    find $serv_path/Data\ Folder -type f -print0|xargs -0 /bin/chmod 644
    echo "  Done"
    echo -n "Fixing Data Folder Subfolder Access Rights"
    find $serv_path/Data\ Folder -type d -print0|xargs -0 /bin/chmod 755
    echo "  Done"

    echo -n "Fixing DB folder permissions"
    #the apache user and group are called apache on linux, but _www on mac
    APACHENAME="apache"
    if [ "$(uname -a |grep Darwin|wc -l)" -eq "1" ] ; then APACHENAME="_www" ; fi
    chown root:$APACHENAME $serv_path/DB
    chmod g+w $serv_path/DB
    echo "  Done"

    if [[ "$cur_version" -ge "570" ]]; then
        echo -n "Postgres installation found, fixing pg_data permissions"
        chown -R postgres:daemon $serv_path/DB/pg_data
        find $serv_path/DB/pg_data -type f -print0|xargs -0 /bin/chmod 600
        find $serv_path/DB/pg_data -type d -print0|xargs -0 /bin/chmod 700
        echo "  Done"
        echo "Fixing MDM directory ownership"
        cd /usr/local/filewave
        echo -n "Fixing log,certs,ipa directory ownership & permissions"
        chown -R $APACHENAME:$APACHENAME log certs ipa
        chown postgres:daemon certs/postgres.*
        chmod 775 log certs ipa
            chmod 664 certs/dummy.* certs/server.*
            chmod 600 certs/apn.key
            chmod 644 certs/apn.crt
            chmod 664 certs/postgres.crt
            chmod 600 certs/postgres.key
            chmod 664 log/*
        echo " Done"
        echo -n "Fixing bin & django ownership & permissions"
        chown -R root:wheel bin postgresql
            chmod a+x bin/*
            chown postgres:daemon postgresql/conf postgresql/log
        chown -R root:$APACHENAME python django
        echo "  Done"
    fi
}

function get_linux_admin {
    # ToDo match installed version with requested version
    echo -e "\033[0;32mSETUP >>>\033[0m Downloading Linux Admin: $VERSION"
    if [ ! -f "/filewave-admin-$VERSION-1.0.x86_64.rpm" ]; then
        wget https://fwdl.filewave.com/$VERSION/filewave-admin-$VERSION-1.0.x86_64.rpm
    else
        echo -e "\033[0;32mSETUP >>>\033[0m ALREADY DOWNLOADED"
    fi
    echo -e "\033[0;32mSETUP >>>\033[0m Installing Linux Admin Version: $VERSION"
    yum install -y --nogpgcheck filewave-admin-$VERSION-1.0.x86_64.rpm

}

## GET OPTIONS


while getopts $OPTIONS opt
do
    case $opt in
        a) AWS=true;;
        b) BETAPATH=$OPTARG;;
        d) DEBUG=true;;
        f) FORCE=true;;
        h) SETHOSTNAME=$OPTARG;;
        m) MODE=$OPTARG;;
        r) RESTORE=$OPTARG;;
        v) VERSION=$OPTARG;;
        l) INFILE=$OPTARG;;
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

if [[ $DEBUG == true ]]; then
    var_debug
fi

# Must be root
if [[ ! $(whoami) == "root" ]] ; then
    echo -e "\033[0;31mERROR >>>\033[0m Script must be run as root"
    exit 1
fi

# Centos ONLY
if [[ $FORCE == false ]] && [[ ! -f "/etc/centos-release" ]]; then
    echo -e "\033[0;31mERROR >>>\033[0m Script must be run on CentOS"
    exit 1
fi





## Start of actions

# Setup an instance using the $base version defined above
# FW server, certificate,
# //ToDo system link certs from fw to certbot rather than cp

if [[ "$MODE" == "setup" ]] && [[ ! -z "$VERSION" ]] && [[ ! -z "$SETHOSTNAME" ]]; then
    if [[ $DEBUG == true ]]; then
        var_debug
    fi
    do_serv_path
    if [[ ! -d $serv_path ]]; then
        echo -e "\033[0;32mSETUP >>>\033[0m Using Hostname $SETHOSTNAME"
        echo -e "\033[0;32mSETUP >>>\033[0m Using Base Version $VERSION"
        echo -e "\033[0;32mSETUP >>>\033[0m Installing base components"
        yum -y install yum-utils epel-release wget zip unzip rsync

        echo -e "\033[0;32mSETUP >>>\033[0m Writing Hostname $SETHOSTNAME"
        hostname $SETHOSTNAME
        hostnamectl set-hostname --static $SETHOSTNAME
        #AWS isntances need this setting
        if [[$AWS = true]]; then #ToDo auto check AWS
            echo -e "\033[0;32mSETUP >>>\033[0m Telling AWS settings to keep name"
            echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
        fi

        echo -e "\033[0;32mSETUP >>>\033[0m Setting up certificates"
        yum -y install certbot
        certbot certonly --standalone -d $SETHOSTNAME

        echo -e "\033[0;32mSETUP >>>\033[0m Adding Cert Cron"
        echo "0,12 * * * python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew" >> /etc/crontab

        echo -e "\033[0;32mSETUP >>>\033[0m Starting installing FileWave Version: $VERSION"

        install_server

        echo -e "\033[0;32mSETUP >>>\033[0m Linking certs into place"
        rm -rvf /usr/local/filewave/certs/server.crt /usr/local/filewave/certs/server.key
        cp /etc/letsencrypt/live/*/fullchain.pem /usr/local/filewave/certs/server.crt
        cp /etc/letsencrypt/live/*/privkey.pem /usr/local/filewave/certs/server.key

        echo -e "\033[0;32mSETUP >>>\033[0m Settings certs as trusted"
        sleep 2
        echo "from ios.preferences_manager import PreferencesManager ; PreferencesManager.set_mdm_server_host('$SETHOSTNAME') ; PreferencesManager.set_mdm_cert_trusted(True)" | /usr/local/filewave/python/bin/python /usr/local/filewave/django/manage.pyc shell

        echo -e "\033[0;32mSETUP >>>\033[0m Restarting Apache"
        /usr/local/filewave/apache/bin/apachectl restart

        echo -e "\033[0;32mSETUP >>>\033[0m Done  \033[0;32m<<<\033[0m"
        echo -e "Please run the fileset uploader from the admin computer"
     else
        error_fwdir
        exit 1
     fi



# backup the current instance in a way to restore from it later

elif [[ "$MODE" == "backup" ]]; then

# backup
    do_serv_path
    echo -e "\033[0;32mBACKUP >>>\033[0m Starting Checks"
    echo -e "\033[0;32mBACKUP >>>\033[0m FW needs to be running"
    if [[ ! -f "/tmp/.s.PGSQL.9432.lock" ]]; then
        error_running
        exit 1
    else
        echo -e "Yes, it is running"
    fi
    echo -e "\033[0;32mBACKUP >>>\033[0m Is there previous backups directory"
    if [[ ! -d "/backup/" ]]; then
        echo "No, creating it"
        mkdir /backup
    else
        echo Yes, it is already there
    fi

    #set destination path
    NOW_VERSION=$(/usr/local/bin/fwcontrol server version | awk {'print $2'})
    DESTINATION="/backup/"$NOW"_v"$NOW_VERSION

    if [[ $DEBUG == true ]]; then
        var_debug
    fi

    echo -e "\033[0;32mBACKUP >>>\033[0m Is there a valid DESTINATION"
    if [[ ! -d "$DESTINATION" ]]; then
        echo "No, creating it now"
        mkdir $DESTINATION
        mkdir $DESTINATION/DB
        mkdir $DESTINATION/certs
    else
        echo -e "\033[0;31mERROR >>>\033[0mThere already appears to be a backup in this location with the same date and version"
        echo -e "Please fix this and start again"
        exit 0
    fi
    echo -e "\033[0;32mBACKUP >>>\033[0m Stopping server to copy files"
    /usr/local/bin/fwcontrol server stop
    sleep 5
    echo -e "\033[0;32mBACKUP >>>\033[0m starting just postgresql"
    /usr/local/bin/fwcontrol postgres start
    sleep 2

    echo -e "\033[0;32mBACKUP >>>\033[0m Dumping PSQL"
    #/usr/local/filewave/postgresql/bin/pg_dump -U postgres -d mdm -f $DESTINATION/DB/mdm-dump.sql
    #/usr/local/filewave/postgresql/bin/pg_dump -U postgres -Fc -c mdm -f $DESTINATION/DB/mdm-dump.dump
    /usr/local/filewave/postgresql/bin/pg_dump -U django -d mdm -f $DESTINATION/mdm-dump.dump --encoding=utf8
    echo -e "\033[0;32mBACKUP >>>\033[0m stopping postgresql"
    /usr/local/bin/fwcontrol postgres stop
    sleep 2

    echo -e "\033[0;32mBACKUP >>>\033[0m Backing up Server Certs..."
    cp -v /usr/local/filewave/certs/* $DESTINATION/certs

    echo -e "\033[0;32mBACKUP >>>\033[0m backing up httpd.conf, http_custom.conf and mdm_auth.conf"
    cp -v /usr/local/filewave/apache/conf/httpd.conf $DESTINATION
    cp -v /usr/local/filewave/apache/conf/httpd_custom.conf $DESTINATION
    cp -v /usr/local/filewave/apache/conf/mdm_auth.conf $DESTINATION

    echo -e "\033[0;32mBACKUP >>>\033[0m backing up apache htpasswd file"
    cp -r -v /usr/local/filewave/apache/passwd $DESTINATION

    #rsync the data folder
    echo -e "\033[0;32mBACKUP >>>\033[0m Starting rsync of Data Folder"
    rsync -avL $serv_path/Data\ Folder/ $DESTINATION/Data\ Folder
    echo -e "\033[0;32mBACKUP >>>\033[0m rsync data folder done"

    #rsync the ipa folder
    echo -e "\033[0;32mBACKUP >>>\033[0m Starting rsync of .ipa Folder to $DESTINATION/ipa..."
    rsync -avL /usr/local/filewave/ipa/ $DESTINATION/ipa
    echo -e "\033[0;32mBACKUP >>>\033[0m rsync ipa done"

    #rsync the media folder
    echo -e "\033[0;32mBACKUP >>>\033[0m Starting rsync of media Folder to $DESTINATION/media..."
    rsync -avL /usr/local/filewave/media/ $DESTINATION/media
    echo -e "\033[0;32mBACKUP >>>\033[0m rsync media done"

    /usr/local/bin/fwcontrol server start

    echo -e "\033[0;32mBACKUP >>>\033[0m DONE with backup process \033[0;32m<<<\033[0m"

# ToDO: Build in a check that everything is there

# Erase current version

elif [[ "$MODE" == "remove" ]]; then
    if [[ $DEBUG == true ]]; then
        var_debug
    fi

#Destroy current version

# if the force option isn't set then prompt user
    if [[ $FORCE == false ]]; then
        echo -e "\033[0;32mREMOVE >>>\033[0m Starting Cleaning"
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        echo -e "This will totally destroy FileWave \n Type \033[0;32mYES\033[0m to continue"
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        read DataAnswer
    fi
    if [ $DataAnswer == "YES" ] || [ $FORCE == true ]; then
        do_serv_path
        echo -e "\033[0;32mREMOVE >>> DESTROY >>> \033[0m Stopping FileWave"
        /usr/local/bin/fwcontrol server stop
        sleep 5
        echo -e "\033[0;32mREMOVE >>> DESTROY >>> \033[0m Uninstalling FileWave Server"
        yum -y remove fwxserver
        rm -rf $serv_path
        rm -rf /usr/local/filewave
        rm -rf /usr/local/sbin/fw*
        rm -rf /usr/local/sbin/FileWave*
        rm /sbin/fwcontrol
        # ToDo remove certbot from /etc/crontab if it is there
        # ToDo remove aws /etc/cloud/cloud.cfg if it is there

        echo -e "\033[0;32mREMOVE >>> DESTROY >>> \033[0m Uninstalling FileWave Admin"
        yum -y remove filewave-admin

    else
        echo -e "\033[0;31mREMOVE >>> ERROR >>> \033[0m YES not not entered. Aborting..."
        exit 1
fi


#restore the base and its settings
# restore will want a nothing of of previous install, do remove first
# restore will read the version from the backup, and install that version before restoring files.

elif [[ "$MODE" == "restore" ]] && [[ ! -z $RESTORE ]]; then
    if [[ $DEBUG == true ]]; then
        var_debug
    fi
    do_serv_path
    if [[ -d $serv_path ]]; then
        error_fwdir
    else
        #restore backup

        echo -e "\033[0;32mRESTORE >>> RESTORE >>>\033[0m Starting restore from backup $RESTORE"
        #Check valid date
        restore_path="/backup/$RESTORE"
        if [ -d "$restore_path" ]; then
            echo -e "\033[0;32mRESTORE >>> Locating Files >>>\033[0m $restore_path Found"

            #pull version from folder name
            VERSION=${RESTORE: -6}


        #Start install
        echo -e "\033[0;32mRESTORE >>> INSTALL >>>\033[0m Starting Server Install"
        install_server
        echo -e "\033[0;32mRESTORE >>> INSTALL >>>\033[0m End Server Install"


            echo -e "\033[0;32mRESTORE >>> Moving Files >>>\033[0m Stopping FileWave"
            /usr/local/bin/fwcontrol server stop
            sleep 5
            echo -e "\033[0;32mRESTORE >>> Moving Files >>>\033[0m Setting files"

            echo -e "\033[0;32mRESTORE >>> Moving Files >>>\033[0m Server Certs..."
            cd /usr/local/filewave/certs/
            zip $NOW-cert_backup.zip *.key *.crt
            rm -rfv *.key *.crt
            rsync -avL $restore_path/certs/ /usr/local/filewave/certs/

            echo -e "\033[0;32mRESTORE >>> Moving Files >>>\033[0m httpd.conf, http_custom.conf and mdm_auth.conf..."
            cd /usr/local/filewave/apache/conf
            zip $NOW-apache_backup.zip httpd.conf httpd_custom.conf mdm_auth.conf
            rm -rfv httpd.conf httpd_custom.conf mdm_auth.conf
            cp -rv $restore_path/*.conf .

            echo -e "\033[0;32mRESTORE >>> Moving Files >>>\033[0m apache htpasswd file..."
            cd /usr/local/filewave/apache/
            zip $NOW-apache_pass.zip passwd
            rm -rfv passwd
            cp -rv $restore_path/passwd .

            do_serv_path
            echo -e "\033[0;32mRESTORE >>> Moving Files >>>\033[0m Data Folder..."
            echo $restore_path
            echo $serv_path
            rsync -avL $restore_path/Data\ Folder/ $serv_path/Data\ Folder

            echo -e "\033[0;32mRESTORE >>> Moving Files >>>\033[0m IPA Folder..."
            rsync -avL $restore_path/ipa/ /usr/local/filewave/ipa

            echo -e "\033[0;32mRESTORE >>> Moving Files >>>\033[0m media Folder..."
            rsync -avL $restore_path/media/ /usr/local/filewave/media

            echo -e "\033[0;32mRESTORE >>> Database >>>\033[0m Starting DB restore"
            /usr/local/bin/fwcontrol server stop
            sleep 2
            /usr/local/bin/fwcontrol postgres start
            sleep 3
            #echo -e "\033[0;32mRESTORE >>> Database >>>\033[0m restoring"
            #/usr/local/filewave/postgresql/bin/psql -U postgres -f $restore_path/DB/mdm-dump.sql
            #/usr/local/filewave/postgresql/bin/pg_restore -U postgres -n public -c -1 -d mdm $restore_path/DB/mdm-dump.dump
            #/usr/local/filewave/postgresql/bin/pg_restore -U postgres -d mdm -c -1 $restore_path/DB/mdm-dump.dump

            echo -e "\033[0;32mRESTORE >>> Database >>>\033[0m drop MDM"
            /usr/local/filewave/postgresql/bin/psql postgres postgres -c 'drop database mdm;'
            #/usr/local/filewave/postgresql/bin/psql postgres postgres -c 'SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = "mdm" AND pid <> pg_backend_pid();'
            #/usr/local/filewave/postgresql/bin/psql postgres postgres -c 'ALTER DATABASE mdm CONNECTION LIMIT 0;'

            echo -e "\033[0;32mRESTORE >>> Database >>>\033[0m make MDM"
            /usr/local/filewave/postgresql/bin/psql postgres postgres -c 'create database mdm OWNER postgres encoding="utf8" template="template0";'

            echo -e "\033[0;32mRESTORE >>> Database >>>\033[0m restoring"
            #/usr/local/filewave/postgresql/bin/psql mdm postgres -c 'CREATE EXTENSION IF NOT EXISTS citext SCHEMA;'

            echo -e "\033[0;32mRESTORE >>> Database >>>\033[0m restore dump"
            #/usr/local/filewave/postgresql/bin/psql mdm postgres -f $restore_path/mdm-dump.dump
            /usr/local/filewave/postgresql/bin/psql -U postgres mdm < $restore_path/mdm-dump.dump

            echo -e "\033[0;32mRESTORE >>> Database >>>\033[0m sync DB"
            /usr/local/filewave/python/bin/python /usr/local/filewave/django/manage.pyc syncdb --noinput

            echo -e "\033[0;32mRESTORE >>> Database >>>\033[0m migrate"
            # PRE 12.1/usr/local/filewave/python/bin/python /usr/local/filewave/django/manage.pyc migrate --noinput --fake-initial

            /usr/local/filewave/python/bin/python /usr/local/filewave/django/manage.pyc makemigrations
            /usr/local/filewave/python/bin/python /usr/local/filewave/django/manage.pyc migrate
            /usr/local/sbin/fwxserver -M

            echo -e "\033[0;32mRESTORE >>> Database >>>\033[0m DB done"
            /usr/local/bin/fwcontrol postgres stop

            echo -e "\033[0;32mRESTORE >>> Permissions >>>\033[0m Start"
            do_permissions
            echo -e "\033[0;32mRESTORE >>> Permissions >>>\033[0m End"
            sleep 2
            echo -e "\033[0;32mRESTORE >>> Server >>>\033[0m Starting"
            /usr/local/bin/fwcontrol server start
            sleep 2
            echo -e "\033[0;32mRESTORE >>> Server >>>\033[0m Migration check"
            /usr/local/sbin/fwxserver -M
        else
            error_notFound
        fi
        echo -e "\033[0;32mRESTORE >>>\033[0m End  \033[0;32m<<<\033[0m"
    fi


#Install a beta version

elif [[ "$MODE" == "beta" ]] && [[ ! -z "$BETAPATH" ]]; then
    echo -e "\033[0;32mBETA >>>\033[0m checking for fwxserver folder"
    #only install beta on top of a current version
    do_serv_path
    if [[ -d $serv_path ]]; then
        #verify beta rpm
        if [[ ! -f "$BETAPATH" ]] && [[ ${BETAPATH: -4} == ".rpm" ]]; then
            echo "File not found (must be at root of drive /)! or is not a rpm"
        else
            echo -e "\033[0;32mBETA >>>\033[0m starting server"
            /usr/local/bin/fwcontrol server start

            echo -e "\033[0;32mBETA >>>\033[0m starting beta installation"
            #echo -e "\033[0;32mBETA >>>\033[0m make sure there are no other beta installers"
            #rm -rf /beta/
            #mkdir /beta/

            #echo -e "\033[0;32mBETA >>>\033[0m Unzipping "$BETAPATH" beta"
            #unzip -d /beta/ $BETAPATH

            echo -e "\033[0;32mBETA >>>\033[0m running beta rpm"
            #yum install -y --nogpgcheck /beta/fwxserver-*-1.0.x86_64.rpm
            yum install -y --nogpgcheck $BETAPATH
        fi
     else
        error_fwdir
        exit 1
     fi

# Clean up unused space #LeaveNoTrace

elif [[ "$MODE" == "clean" ]]; then
# if the force option isn't set then prompt user
    if [[ $FORCE == false ]]; then
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        echo -e "This will totally destroy \033[0;31m FileWave and SYSTEM\033[0m logs\n"
        echo -e "It will also destroy current FW apache logs\n"
        echo -e "It does\033[0;31m NOT save or rollover \033[0m the old logs\n \n"
        echo -e "Type \033[0;32mYES\033[0m to continue"
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        read DataAnswer
    fi
    if [[ $DataAnswer == "YES" ]] || [[ $FORCE == true ]]; then
        echo -e "\033[0;32mCLEAN >>>\033[0m Starting Clean"
        echo -e "\033[0;32mCLEAN >>>\033[0m Starting fwxserver -M checks"
        /usr/local/sbin/fwxserver -M

        echo -e "\033[0;32mCLEAN >>>\033[0m Starting postgres vacumedb"
        /usr/local/filewave/postgresql/bin/vacuumdb -U postgres -d mdm

        echo -e "\033[0;32mCLEAN >>>\033[0m Stopping Server"
        /usr/local/bin/fwcontrol server stop
        sleep 2

        echo -e "\033[0;32mCLEAN >>>\033[0m removing Logs...  "
        rm -rfv /private/var/log/*.log*
        rm -rfv /private/var/log/FWAdmin\ Audit/*.txt
        rm -rfv /usr/local/filewave/log/*.log*

        rm -rfv /usr/local/filewave/apache/logs/*_log*
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
        echo -e "\033[0;32mCLEAN >>>\033[0m End  "
    else
        echo -e "\033[0;31mCLEAN >>> ERROR >>> \033[0m YES not not entered. Aborting..."
        exit 1
    fi

# Update the server, update linux admin, and then upload upgrade filesets

elif [[ "$MODE" == "update" ]] && [[ ! -z "$VERSION" ]]; then
    # ToDo check for a recent update (with in 1 day) before doing update
    if [ $DEBUG == true ]; then
        var_debug
    fi
    do_serv_path
    if [ -d $serv_path ]; then
        install_server
    else
        error_fwdir
    fi

    # Upgrade filesets
    echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
    echo -e "Do you want to bring in the \033[0;31m Upgrade Filesets \033[0m"
    echo -e "or \033[0;32m y \033[0m or \033[0;31m n \033[0m abort "
    echo -e "this will need to install the admin app "
    echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
    read DataAnswer
    if [ $DataAnswer == "y" ]; then

        if [[ ! -f /usr/local/bin/FileWaveAdmin ]]; then
            echo -e "\033[0;32mUPDATE >>>\033[0m Getting Admin app"
            get_linux_admin
        else
            echo -e "\033[0;32mUPDATE >>>\033[0m Admin already installed"
        fi

        echo -e "\033[0;32mUPDATE >>>\033[0m Getting upgrade filesets"

        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        echo -e "Paste the \033[0;31m macOS Upgrade Fileset \033[0m URL"
        echo -e "or \033[0;31m cancel \033[0m to abort "
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        read DataAnswer
        if [ $DataAnswer == "cancel" ]; then
            exit 1
        else
            wget $DataAnswer
        fi
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        echo -e "Paste the \033[0;31m Windows Upgrade Fileset \033[0m URL"
        echo -e "or \033[0;31m cancel \033[0m to abort "
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        read DataAnswer
        if [ $DataAnswer == "cancel" ]; then
            exit 1
        else
            wget $DataAnswer
        fi

        echo -e "\033[0;32mUPDATE >>>\033[0m unzipping upgrade filesets"
        unzip FileWave_macOS_Client_$VERSION*.zip
        unzip FWWinClientUpgrade_$VERSION*.zip

        echo -e "\033[0;32mUPDATE >>>\033[0m uploading upgrade filesets"
        local_hostname=$(hostname)
        echo -e "Enter a FileWave admin username for \033[0;31m $local_hostname \033[0m "
        read DataUsername
        echo -e "Enter the password for \033[0;31m $DataUsername @ $local_hostname \033[0m "
        read DataPassword
        /usr/local/bin/FileWaveAdmin -H $local_hostname -u $DataUsername -p $DataPassword --importFileset FileWave_macOS_Client_$VERSION*.fileset
        /usr/local/bin/FileWaveAdmin -H $local_hostname -u $DataUsername -p $DataPassword --importFileset FWWinClientUpgrade_$VERSION*.fileset

        echo -e "\033[0;32mUPDATE >>>\033[0m cleaning up files"
#        rm -rf FileWave_macOS_Client_$VERSION*.zip FWWinClientUpgrade_$VERSION*.zip FileWave_macOS_Client_$VERSION*.fileset FWWinClientUpgrade_$VERSION*.fileset
    fi

# Install the linux admin

elif [[ "$MODE" == "admin" ]]; then
    VERSION=$(/usr/local/sbin/fwxserver -V | awk '{print $2}')
    get_linux_admin

# Update certbot certificates

elif [[ "$MODE" == "renew" ]]; then
    lets_hotname=$(ls /etc/letsencrypt/live/)
    echo -e "\033[0;32mCERTS >>>\033[0m Renew"
    certbot renew

    echo -e "\033[0;32mCERTS >>>\033[0m Linking certs into place"
    rm -rvf /usr/local/filewave/certs/server.crt /usr/local/filewave/certs/server.key
    cp /etc/letsencrypt/live/*/fullchain.pem /usr/local/filewave/certs/server.crt
    cp /etc/letsencrypt/live/*/privkey.pem /usr/local/filewave/certs/server.key

    echo -e "\033[0;32mCERTS >>> Permissions >>>\033[0m Start"
    do_permissions
    echo -e "\033[0;32mCERTS >>> Permissions >>>\033[0m End"

    echo -e "\033[0;32mCERTS >>>\033[0m Restarting Apache"
    /usr/local/filewave/apache/bin/apachectl restart
    echo -e "\033[0;32mCERTS >>>\033[0m Done"

# BOOSTER ITEMS

elif [[ "$MODE" == "b_update" ]] && [[ ! -z $VERSION ]]; then
    if [[ $DEBUG == true ]]; then
        var_debug
    fi
    do_serv_path
    if [[ -d $serv_path ]] && [[ -z $INFILE ]]; then
        echo -e "\033[0;31mERROR >>>\033[0m This is a server. Do not install booster on server.\n Exiting"
        exit 1
    fi
    if [[ -d $boost_path ]] && [[ -z $INFILE ]]; then
        echo "INSTALL LOCAL BOOSTER"
        install_booster
    elif [[ -f $INFILE ]]; then
        echo -e "\033[0;32mINFO >>>\033[0m Booster list file found: $INFILE \n"
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        echo -e "Enter the \033[0;31musername \033[0mfor your boosters\n"
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        read DataAnswer_boost_user
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        echo -e "Enter the \033[0;31mpassword \033[0mfor your boosters\n"
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        read DataAnswer_boost_pass
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        echo -e "This correct?"
        echo -e "SHH User: $DataAnswer_boost_user"
        echo -e "SSH Pass: $DataAnswer_boost_pass"
        echo -e "         enter to continue. Any other input will exit          "
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #\033[0m"
        read DataAnswer
        if [[ $DataAnswer != "" ]] ; then
            exit 1
        fi
        if [[ ! -f "/FileWave_Linux_$VERSION.zip" ]]; then
            wget https://fwdl.filewave.com/$VERSION/FileWave_Linux_$VERSION.zip
        else
            echo -e "\033[0;32mSETUP >>>\033[0m ALREADY DOWNLOADED"
        fi
        if [[ ! -f "/fwxserver-$VERSION-1.0.x86_64.rpm" ]]; then
            unzip FileWave_Linux_$VERSION.zip
        else
            echo -e "\033[0;32mSETUP >>>\033[0m ALREADY UNZIPPED"
        fi
        echo "INSTALL REMOTE BOOSTER"
        while read b; do
            install_booster_remote $b $DataAnswer_boost_user $DataAnswer_boost_pass
        done < $INFILE
    else
        echo -e "\033[0;31mERROR >>>\033[0m No booster directory found."
        echo -e "Did you mean to install a new booster with"
        echo -e ""
        error_syntax
        exit 1
     fi

elif [[ "$MODE" == "b_remove" ]]; then
    if [[ $DEBUG == true ]]; then
        var_debug
    fi
# if the force option isn't set then prompt user
    if [[ $FORCE == false ]]; then
        echo -e "\033[0;32mREMOVE >>>\033[0m Starting Cleaning"
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        echo -e "This will totally destroy FileWave \n Type \033[0;32mYES\033[0m to continue"
        echo -e "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
        read DataAnswer
    fi
    if [ $DataAnswer == "YES" ] || [ $FORCE == true ]; then
        echo -e "\033[0;32mREMOVE >>> DESTROY >>> \033[0m Stopping FileWave"
        /usr/local/bin/fwcontrol booster stop
        sleep 5
        echo -e "\033[0;32mREMOVE >>> DESTROY >>> \033[0m Uninstalling FileWave Booster"
        /bin/yum -y remove fwbooster
        rm -rf /usr/local/etc/filewave
        rm -rf /usr/local/filewave
        rm -rf /usr/local/sbin/fw*
        rm /sbin/fwcontrol
        # ToDo remove certbot from /etc/crontab if it is there
        # ToDo remove aws /etc/cloud/cloud.cfg if it is there

        echo -e "\033[0;32mREMOVE >>> DESTROY >>> \033[0m Uninstalling FileWave Admin"
        yum -y remove filewave-admin

    else
        echo -e "\033[0;31mREMOVE >>> ERROR >>> \033[0m YES not not entered. Aborting..."
        exit 1
fi

else
    error_syntax
    exit 1
fi
