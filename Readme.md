[![Docker Pulls](https://img.shields.io/docker/pulls/immauss/openvas.svg)](https://hub.docker.com/r/immauss/openvas/)
[![Docker Stars](https://img.shields.io/docker/stars/immauss/openvas?style=flat)](https://hub.docker.com/r/immauss/openvas/)
[![Docker Stars](https://img.shields.io/docker/image-size/immauss/openvas.svg?maxAge=2592000)](https://hub.docker.com/r/immauss/openvas/)
[![GitHub Issues](https://img.shields.io/github/issues-raw/immauss/openvas.svg)](https://github.com/immauss/openvas/issues)
[![Discord](https://img.shields.io/discord/809911669634498596?label=Discord&logo=discord)](https://discord.gg/DtGpGFf7zV)
[![Twitter Badge](https://badgen.net/badge/icon/twitter?icon=twitter&label)](https://twitter.com/immauss)
![GitHub Repo stars](https://img.shields.io/github/stars/immauss/openvas?style=social)

# A Greenbone Vulnerability Management docker image
### Brought to you by ###
[![Immauss Cybersecurity](https://github.com/immauss/openvas/raw/master/images/ics-hz.png)](https://immauss.com "Immauss Cybersecurity")

[Sponsor immauss](https://github.com/sponsors/immauss)
- - - -
## Documentation ##
The current container docs are maintained on github [here](https://immauss.github.io/openvas/)

For docs on the web interface and scanning, use Greenbone's docs [here](https://docs.greenbone.net/GSM-Manual/gos-22.04/en/). Chapter's 8-14 cover the bits you'll need.
- - - -

# Docker Tags  #
tag              | Description
----------------|-------------------------------------------------------------------
22.4.31 | This is the latest based on GVMd 22.8 available on x86_64, arm64, and armv7.
21.04.09 | This is the last 21.4 build.  
20.08.04.6 | The last 20.08 image
pre-20.08   | This is the last image from before the 20.08 update. 
v1.0             | old out of date image for posterity. (Dont` use this one. . . . ever)

# Greenbone Versions in Latest image: #
Component | Version | | Component | Version
----------|----------|-|----------|---------
| gvmd | v22.9.0 | | gvm_libs | v22.7.1 |
| openvas | v22.7.5 | | openvas_scanner | v22.7.5 |
| openvas_smb | v22.5.3 | | notus_scanner | v22.6.0 |
| gsa | v22.7.0 | | gsad | v22.6.0 |
| ospd | v21.4.4 | | ospd_openvas | v22.6.0 |
| pg_gvm | v22.6.1 | | python_gvm | v23.5.1 |
| gvm_tools | v23.9.0 | | greenbone_feed_sync | v23.8.0 |

- - - -
# 25 August 2023 #
## Discussions!!! ##

Moving forward, all new versions and any other changes will be posted in the [Announcements](https://github.com/immauss/openvas/discussions). The contents of this Readme will be preserved as [OldReadme.md](https://github.com/immauss/openvas/OldReadme.md). 

Thanks,
Scott

- - - -




For License info, see the [GNU Affero](https://github.com/immauss/openvas/blob/master/LICENSE) license.
