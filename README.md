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
