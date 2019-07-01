# FW_manage
A management script for FileWave
[-m mode [setup -v <version> -h <hostname>] [backup] [remove] [restore -r <date>] [beta -b FILE] [clean] 
[-h hostname for setup] [-v version for setup] [-r date to use in restore] [-b path to beta rpm]
[-f force] [-a aws this is an aws instance]

This command must also be run as root on CentOS

## Examples:
### Setup
Setup a 12.8.1 instance with the hostname server.company.org on an AWS instance
```
./fw_manage.sh -m setup -h server.company.org -v 12.8.1 -a
```

### Backup
Backup the server
```
./fw_manage.sh -m backup
```

### Remove
Delete all traces of FileWave on the server
```
./fw_manage.sh -m remove
# or
./fw_manage.sh -m remove -f
# to skip prompt
```

### Restore
Restore from a backup
```
./fw_manage.sh -m restore -r 2018-08-03
```

### Beta
Install a beta version **on top of a current version**
```
./fw_manage.sh -m beta -b fwxserver-20.0.0-1.0.x86_64.rpm
 ```
 
### Clean
Vacuum the DB and removes logs taking up space
```
./fw_manage.sh -m clean
```
### Update
Updates a current server to the the specified version (recomended to backup first)
```
./fw_manage.sh -m update -v 13.1.0
```
### Admin
Installs the linux admin [CLI - Command Lind Interface](https://kb.filewave.com/pages/viewpage.action?pageId=920328)
```
./fw_manage.sh -m admin
```
### Renew
If you used the built-in setup (see above) then certbot was used to name and cert the server, a cron should also exsist to renew the cert.
This command checks cert status, renews if needed, and moves the renwed admin certs into filewave sapce
```
./fw_manage.sh -m renew
```
