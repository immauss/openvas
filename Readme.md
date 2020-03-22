

# NOTE:
The original source of this was  copied from: https://github.com/Secure-Compliance-Solutions-LLC/GVM-Docker 
I liked how they did things, but needed to make a few tweaks so I could import my old openvas DB from v7 -> v8 - v9. 
The only initial major change was adding "locales-all" to the list of installed packages so I wouldn't have to rebuild the database .... again." 

# Other Changes:
- Added '/usr/local/var/lib' and '/usr/local/share' to the /data directory via soft links. This prevents downloading of all the NVT, CERT,  & scap data if the image is replaced/updated.
- changed some of the "if" statemens in start.sh to look for softlinks vs directories to prevent re-running every time. ( 'if [ -L' <dir> ] vs 'if [ -d' <dir> ] )
- images are availabe on docker hub : docker.io/immauss/openvas

# ToDo

- Finish cleaning up this doc to match my build (code below still references the orignials)
- Add an option to build from current source tree instead of releases.
- Split the postgres db into it's own container.
- Find a reasonable way to backup the db.
- Find a simple way to maintain valid TLS certs. (Hopefully with let's encrypt)
- Hard coded the sockets ... (This is still giving me some trouble. I've resolved with soft link from where it expects the socket to where it actually is located. )
- Something else really cool !


-Scott

This also lives at: 
https://hub.docker.com/repository/docker/immauss/openvas


# A Greenbone Vulnerability Management 11 Docker Image

This docker image is based on GVM 11 but with a few package modifications. After years of successfully using the OpenVAS 8/9 package, maintained by the Kali project, we started having performance issues. After months of trying to tweak OpenVAS, with varying and short lived success, we decided to maintain our own packaged version of GVM 11. This was done to streamline the installation, cleanup, and improve reliability.

## Important Note

Currently the GVM reporting does not allow you to export reports containing more than 1000 lines. This is true for all report types. We have found a way around this limitation; however, it creates a problem with the webUI and the vulnerability data will take longer to load in the browser the higher you set the max rows. We have created a script that will allow you to set a custom rows per page value based on the size of your scan results. We have found that it isn't worth the hassle to try exporting reports with more than 15000 lines. 15000 seems to be the sweet spot that will usually work, provided you have enough RAM in the device used to access the web UI. 

To implement this fix, run the following command AFTER you finished the rest of the setup.
```bash
docker exec -it openvas bash -exec "/reportFix.sh"
```
Note: we have used the container name gvm to be consistent with the rest of the documentation. Modify the command accordingly.



## Deployment

**Install docker**

If you have Kali or Ubuntu you can use the docker.io package.
```shell
apt install docker.io
```

If you are using any debian based OS that does not have the docker.io package, you can follow [this guide](https://docs.docker.com/install/linux/docker-ce/debian/) 

You can also use the docker install script by running:
```bash
curl https://get.docker.com | sh
```

**Run our container**

This command will pull, create, and start the container:

Without persistent volume:

```shell
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
