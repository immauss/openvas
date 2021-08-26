# Wishlist
- [ ] Move some of the filesystem mods from start.sh to build process.
- [ ] Split out to multiple containers
	Use the same container image for all. Options at start determine functions:
	- postgresql
	- redis
	- ospd-openvas/openvas
	- gvmd
	- gsad
	- postfix
- [ ] Let`s encrypt 
	- In current build ?
	- In seperate reverse proxy
- [ ] Write some build / test scripts to automate testing of new builds. 
	- use GMP/OSP to validate a scan against a scannable container
	- use compose to spin up openvas &  scannable, then script the scan creation and execution
- [ ] Clean up repo directory structure (All scripts in scripts etc)
- [ ] start.sh clean up. 
	- Make sure there are no duplicates
	- Validate the order of operations
