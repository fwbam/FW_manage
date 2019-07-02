# FW_manage
A management script for FileWave

## Arguments
1. Select a mode
   - setup
   - update
   - backup
   - remove
   - restore
   - beta
   - clean
   - admin
   - renew
2. Set an variable if needed
   - These can be used with any command
     - F force - Skip "are you sure" type prompts"
     - d debug - Output variables at the stages of the workflow
   - setup
     - v version
     - h hostname
     - a AWS instance (makes the hostname sticky)
   - update
     - v version
   - restore
     - r restore date
   - beta
    - b path to beta rpm

This tool must also be run as root on CentOS

## Workflows
### Average Workflow
1. setup
2. backup
3. update

### BETA Workflow
1. setup
2. backup
3. beta
4. remove (you can't upgrade a beta to another beta or a final version, you have to go back to a last final release)
5. restore (the backup from step 2)
6. update (or if you are installing a newer beta, you could jump to step 3 and repeat as needed)

## Examples:
### Setup
Setup a 13.0.1 instance with the hostname server.company.org on an AWS instance
```
./fw_manage.sh -m setup -h server.company.org -v 13.0.1 -a
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
./fw_manage.sh -m restore -r 2019-07-01_v13.0.3
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
Updates a current server to the the specified version (recommended to backup first).
It then promps if you want to also upload the upgrade filesets (This will install the linux admin app. Links from download KB required).
```
./fw_manage.sh -m update -v 13.1.0
```
### Admin
Installs the linux admin app for  [CLI - Command Lind Interface](https://kb.filewave.com/pages/viewpage.action?pageId=920328)
```
./fw_manage.sh -m admin
```
### Renew
If you used the built-in setup (see above) then certbot was used to name and cert the server, a cron should already exist to renew the cert.
This command checks cert status, renews if needed, and moves the renwed admin certs into filewave space
```
./fw_manage.sh -m renew
```
