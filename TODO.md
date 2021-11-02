# Wishlist
- [x] Move some of the filesystem mods from start.sh to build process.
- [ ] Split out to multiple containers
	Use the same container image for all. Options at start determine functions:
	Container list in start order.
	- postgresql
	- gvmd
	- redis - **This image pulled seperately**
		- redis should start after gvmd container. and before openvas/ospd-openvas container.
		- use gvmd container to make sure the /var/redis directory exists
	- ospd-openvas/openvas
		- may need to verify the perms on redis socket at startup
	- gsad
	- postfix **Should be able to pull this image seperately too**
- [ ] Let`s encrypt 
	- In current build ?
	- In seperate reverse proxy
- [ ] Write some build / test scripts to automate testing of new builds. 
	- use GMP/OSP to validate a scan against a scannable container
	- use compose to spin up openvas &  scannable, then script the scan creation and execution
- [x] Clean up repo directory structure (All scripts in scripts etc)
- [x] start.sh clean up. 
	- Make sure there are no duplicates
	- Validate the order of operations
