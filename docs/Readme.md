[![Docker Pulls](https://img.shields.io/docker/pulls/immauss/openvas.svg)](https://hub.docker.com/r/immauss/openvas/)
[![Docker Stars](https://img.shields.io/docker/stars/immauss/openvas.svg?maxAge=2592000)](https://hub.docker.com/r/immauss/openvas/)
[![GitHub Issues](https://img.shields.io/github/issues-raw/immauss/openvas.svg)](https://github.com/immauss/docker-openvas/issues)
[![Discord](https://img.shields.io/discord/809911669634498596?label=Discord&logo=discord)](https://discord.gg/DtGpGFf7zV)
[![Twitter Badge](https://badgen.net/badge/icon/twitter?icon=twitter&label)](https://twitter.com/immauss)

# A Greenbone Vulnerability Management docker image
### Brought to you by ###
[![Immauss Cybersecurity](https://github.com/immauss/openvas/raw/master/images/ics-hz.png)](https://immauss.com "Immauss Cybersecurity")


This lives as a docker container at: 
[docker hub](https://hub.docker.com/repository/docker/immauss/openvas)

The Greenbone Source code can be found at:
[Greenbone Source Code](https://github.com/greenbone)

The advantages of the Immauss container image vs the Greenbone images:
- Able to run a full scanner in a sinlge image with or without volumes. 
- Image contains a full database.
- Speed to scanning. The Immauss image can be up and scanning in 15-20 minutes. ( With sufficent machine resources).
- The image on docker hub is updated weekly to ensure the database is up to date.

The the latest image is based on GVM 22.4.x  In single container mode, it runs all the components needed to create a scanner in a single container including:
- gvmd - the Greenbone Vulnerability Managedment daemon
- openvas scanner - the scanner component of GVM
- ospd - the openvas scanner protocal daemon
- notusscanner - the new piece from Greenbone that handles the local scans of machines.
- postgresql - the database backend for the scanner and gvm
- redis - in memory database store used by gvmd 
- postfix mail server for delivering email notices from GVM
- A copy of the baseline data feeds and associated database
- Option to restore from existing postgresql database dump
- Option to skip the data sync on startup
- Proper database shutdown on container stop to prevent db corruption. 

In multi-container mode it creates individual containers for each of the components. Since most of the Greenbone components utlize unix sockets for comunication, the contianers share a volume (the default name is: ovasrun) soley for the sharing of the sokets.`

## Deployment

**Install docker**

If you have Kali or Ubuntu you can use the docker.io package.
```
apt install docker.io
```
For other distros, please check with docker for the latest on installation options.
https://docs.docker.com/engine/install/

**Run the container**

These commands will pull, create, and start the container:

**Without persistent volume:**

```
docker run --detach --publish 8080:9392 -e PASSWORD="Your admin password here" --name openvas immauss/openvas
```
**To create a volume to store persistent data.**
```
docker volume create openvas
```

**Start the container with a persistent volume:**

```shell
docker run --detach --publish 8080:9392 -e PASSWORD="Your admin password here" --volume openvas:/data --name openvas immauss/openvas
```

You can use whatever `--name` you'd like but for the sake of this guide we're using openvas.

The `--publish 8080:9392` option will port forward `8080` on the host to `9392` (the container web interface port) in the docker container. Port `8080` was chosen only to avoid conflicts with any existing OpenVAS/GVM installation. You can change `8080` to any available port that you`d like.

Depending on your hardware, it can take anywhere from a few seconds to 30 minutes while the NVTs are scanned and the database is rebuilt. 

The NVTs will update every time the container starts. Even if you leave your container running 24/7, the easiest way to update your NVTs is to restart the container.
```
docker restart openvas
```

There is also a script in the container that will initiate the sync. 
```
/scripts/sync.sh
```
You can run the sync at anytime on a running container with:
```
docker exec -it <container-name> /scripts/sync.sh
```

## Docker compose
  The git repo has two docker-compose.yml files.

	- /compose/docker-compose.yml
	- /multi-container/docker-compose.yml

  The 'yml' in /compose is a single container immplementation. The 'yml' in /multi-container is for  .... multiple containers. Both utilize a '.env" file. You can set the docker tag in the ".env" file.

	To utilze the docker-compose.yml files, change to the desired directory and run:
```
docker-compose up -d
```
	For upgrades, edit the ".env" file and change the version, then execute:
```
docker-compose up -d
```

* For upgrades from major versions, ensure you are using the most recent docker-compose.yml for the git repo. For instance, from  21.4 -> 22.4, the notus scanner was added. If you do not utilize the new docker-compose.yml with the mulit-container "yml", then there will be no container with the "notuscanner". *


# Database backup

If you are running the container on a continuing basis, it is a good idea to make a backup of the database at regular intervals. The container is setup to properly shutdown the database to prevent corruption, but if the process is killed unexpectedly, or the host machine loses power, then it is still possible for the database to become corrupt. To make a backup of the current database in the container:

```
docker exec -it <container name> su -c "/usr/lib/postgresql/13/bin/pg_dumpall" postgres > db-backup-file.sql
```

# Database restoral

Restoral is a bit more difficult. This assumes you are using a volume named "openvas". No other container should be accessing this volume at the time of restoral. This could be an empty container or a previously used container. The below command will:
1. Start a temporary container
2. Perform initial setup for gvm
3. Setup and start postgresql
4. Restore from the backup file
5. Shutdown postgresql
6. Stop and remove the temporary container.

```
docker run -it -e RESTORE=true -v <path to backupfile>:/usr/lib/db-backup.sql --rm -v openvas:/data immauss/openvas
```

# Full backup 

There are a number of crucial items not stored in the database such as encryption keys for credentials, SSL certificates etc. All of these will however be stored on the persitent volume located in /data of the container filesystem. The easiest way to backup the entireity of the volume is shutdown the openvas container and use a new container to create the backup. This is the safest way to create the backup to ensure no files are changed during the backup process. The below commands assume a container name of openvas-prod and a volume name of openvas. 

**Stop the running container**
```
docker stop openvas-prod
```
**Start a temporary container to create the backup.**
```
docker run -it --rm -v openvas:/opt -v $(pwd):/mnt alpine /bin/sh -c "cd /opt; tar -cjvf /mnt/openvas.full.tar.gz *" 
```
**Restart the production container**
```
docker start openvas-prod
```
* Note: alpine is very lightweight linux container which is well suited for this purpose.

# Full restoral

The restoral is similar to the backup process in that we use the alpine container to perform this function. The restoral should be to an empty volume, so start by creating that new volume. 

```
docker volume create new-openvas-volume
```
Then extract the backup into the volume with alpine.
```
docker run --rm -it -v <path to backup file>:/backup.tar.gz -v openvas:/mnt alpine /bin/sh -c "cd /mnt; tar xvf /backup.tar.gz"
```

# Options
The following options can be set as environement variables when starting the container. To set an environement variable use "-e": 

- USERNAME : Use a different default username. Default = admin
``` 
-e USERNAME=<username> 
```
- PASSWORD : password for default user. Default = admin
```
 -e PASSWORD='<password>'
```
## Important note about USERNAME and PASSWORD
**You should only use these for initial setup of the container. Always change the password aftewards. If you start the container from the command line with the PASSWORD env set, then the password is readily readible in your command history and in /proc etc ....**
**If you choose to create a new user at startup, the "admin" user will still exist with the default admin password. The admin user is needed as it is the owner of the "feed import process" and gvmd will not let it be deleted. Make sure you change the password for admin in this scenario. 
you have been warned.  :)
- RELAYHOST : The IP address or hostname of the email relay to send emails through. Default = 172.17.01 (This is default for the docker host. If you are running the mail relay on your docker host, this should work, but you will need to make sure you allow the conections through the host`s firewall/iptables)
```
-e RELAYHOST=mail.example.com 
```
- SMTPPORT : The TCP port for the RELAYHOST. Default = 25
```
-e RELAYHOST=25
```
- REDISDBS : Number or redis databases to allow. (This was specific user request. In somecases, when running scans against a large number of targets, the default can be low and increasing the nubmer of redis databases can improve scan performance.) Default = 512
```
-e REDISDBS=512
```
- QUIET : During container start, the data feed synchronization can be quite noisy. Setting this to 'true' will silence all of that output.  Default = false
```
-e QUIET=true
```
- SKIPSYNC : If you would prefer to skip the data feed synchronizations on container start, then set this to true. Thils will get the scanner operational faster, at the cost of using what might be slightly out of date NVTs. Default = false
```
-e SKIPSYNC=true
```
- RESTORE : Set this to true to in order to use the database restore function. After the db is restored, the container will exit. This is to prevent the possiblity of container restart with the RESTORE option still set which would again restore the DB from the backup file. (See Restore section above for more details) Default = false
```
-e RESTORE=true
```

