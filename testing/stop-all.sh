WD=$(pwd)
cd ~/Projects/openvas/testing
docker compose -p no-vol -f docker-compose-no-vol.yml rm -svf 
docker compose -p vol -f docker-compose-vol.yml rm -svf 
cd "$WD"
