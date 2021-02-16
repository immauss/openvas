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

## Deployment

**Install docker**

If you have Kali or Ubuntu you can use the docker.io package.
```
apt install docker.io
```


**Run the container**

This command will pull, create, and start the container:

Without persistent volume:

```
docker run --detach --publish 8080:9392 -e PASSWORD="Your admin password here" --name openvas immauss/openvas
```
create a volume to start persistent data. 
```shell
docker volume create openvas
```

With persistent volume:

```shell
docker run --detach --publish 8080:9392 -e PASSWORD="Your admin password here" --volume openvas:/data --name openvas immauss/openvas
```

You can use whatever `--name` you'd like but for the sake of this guide we're using openvas.

The `-p 8080:9392` switch will port forward `8080` on the host to `9392` (the container web interface port) in the docker container. Port `8080` was chosen only to avoid conflicts with any existing OpenVAS/GVM installation. You can change `8080` to any available port that you'd like.

Depending on your hardware, it can take anywhere from a few seconds to 10 minutes while the NVTs are scanned and the database is rebuilt. **The default admin user account is created after this process has completed. If you are unable to access the web interface, it means it is still loading (be patient).**

**Checking Deployment Progress**

There is no easy way to estimate the remaining NVT loading time, but you can check if the NVTs have finished loading by running:
```
docker logs openvas
```

If you see "Your GVM 11 container is now ready to use!" then, you guessed it, your container is ready to use.

## Accessing Web Interface

Access web interface using the IP address of the docker host on port 8080 - `http://<IP address>:8080`

Default credentials:
```
Username: admin
Password: admin
```

## Monitoring Scan Progress

This command will show you the GVM processes running inside the container:
```
docker top openvas
```

## Checking the GVM Logs

All the logs from /usr/local/var/log/gvm/* can be viewed by running:
```
docker logs openvas
```
Or you can follow the logs (like tail -f ) with:
```
docker logs -f openvas
```


## Updating the NVTs

The NVTs will update every time the container starts. Even if you leave your container running 24/7, the easiest way to update your NVTs is to restart the container.
```
docker restart openvas
```
