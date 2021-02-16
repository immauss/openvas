This lives as a docker container at: 
https://hub.docker.com/repository/docker/immauss/openvas


# A Greenbone Vulnerability Management docker image

This docker image is based on GVM 20.08.1 and started as a clone of https://github.com/Secure-Compliance-Solutions-LLC/GVM-Docker. However, it has undergone significant transformation from that base. It runs all the components needed to create a scanner including:
- gvmd - the Greenbone Vulnerability Managedment daemon
- openvas scanner - the scanner component of GVM
- ospd - the openvas scanner protocal daemon
- postgresql - the database backend for the scanner and gvm
- redis - in memory database store used by gvmd 
- postfix mail server for delivering email notices from GVM
- A copy of the baseline data feeds and associated database
- Option to restore from existing postgresql database dump
- Option to skip the data sync on startup
- Proper database shutdown on container stop to prevent db corruption. (This was added in 20.08.04.4) 

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
# Database backup

# Database restoral

# Full backup 
- shutdown db and gvmd
- tar all of /data  
# Full restoral
- Needs new options in start.sh
# Options
The following options can be set as environement variables when starting the container. To set an environement variable use "-e": 

- USERNAME : Use a different default username.
``` 
-e USERNAME=<username>
```
    - Default = admin
- PASSWORD : password for default user.
```
 -e PASSWORD='<password>'
```
    - Default = admin
- RELAYHOST : The IP address or hostname of the email relay to send emails through
```
-e RELAYHOST=mail.example.com 
```
    - Default = 172.17.01 (This is default for the docker host. If you are running the mail relay on your docker host, this should work, but you will need to make sure you allow the conections through the host`s firewall/iptables)
- SMTPPORT : The TCP port for the RELAYHOST.
```
-e RELAYHOST=25
```
    - Default = 25
- REDISDBS : Number or redis databases to allow. (This was specific user request. In somecases, when running scans against a large number of targets, the default can be low and increasing the nubmer of redis databases can improve scan performance.)
```
-e REDISDBS=512
```
    - Default = 512
- QUIET : During container start, the data feed synchronization can be quite noisy. Setting this to 'true' will silence all of that output. 
```
-e QUIET=true
```
    - Default = false
- SKIPSYNC : If you would prefer to skip the data feed synchronizations on container start, then set this to true. Thils will get the scanner operational faster, at the cost of using what might be slightly out of date NVTs. 
```
-e SKIPSYNC=true
```
    - Default = false
- RESTORE : Set this to true to in order to use the database restore function. After the db is restored, the container will exit. This is to prevent the possiblity of container restart with the RESTORE option still set which would again restore the DB from the backup file. (See Restore section above for more details)
