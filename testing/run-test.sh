#!/bin/bash
if [ -z $1 ]; then  
    echo "No args ... so using latest as TAG"
    export TAG="latest"
else
    export TAG="$1"
fi
echo "TAG=\"$TAG\"" > .env
set -Eeuo pipefail
wait_for_gsa() {
  local port="${1:-8080}"  
  local host="${2:-127.0.0.1}"
  local interval="${3:-15}"
  local url="http://${host}:${port}/"
  command -v curl >/dev/null 2>&1 || { echo "curl not found"; return 2; }

  echo "Waiting for GSA HTTP response at ${url} (poll every ${interval}s)..."
  while true; do
    # silent, follow redirects, 5s connect+transfer timeout, capture HTTP status code
    http_code=$(curl -sS -L --connect-timeout 5 --max-time 5 -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || echo "")
    if [[ -n "$http_code" ]]; then
      if [[ "$http_code" -ge 200 && "$http_code" -lt 400 ]]; then
        echo "GSA responded with HTTP ${http_code}"
        return 0
      else
        echo "Received HTTP ${http_code}; waiting ${interval}s..."
      fi
    else
      echo "No HTTP response; waiting ${interval}s..."
    fi
    sleep "${interval}"
  done
}


for config in vol no-vol; do 
  if [ "$config" == "no-vol" ]; then
    port="8088"
  else 
    port="8080"
  fi
  echo "Starting the $config test environment"
  export CONFIG="$config"
  docker compose -p $CONFIG  -f docker-compose-$CONFIG.yml up -d 
  #docker compose -f docker-compose-$config.yml up -d 
  echo "Installing needed dependancy"
  docker exec -it openvas-$config bash -c "apt update && apt install libxml2-utils -y "
  echo "Copying the script into the container"
  docker cp create-and-scan.sh openvas-$config:/scripts/
  wait_for_gsa $port
  echo "Create task and start scan."
  docker exec -itu gvm openvas-$config bash -c "/scripts/create-and-scan.sh $config"
done

echo "Ready to shut them down?"
read junk
export config="no-vol";export CONFIG="$config";  docker compose -f docker-compose-${config}.yml -p $config rm -svf
export config="vol";export CONFIG="$config";  docker compose -f docker-compose-${config}.yml -p $config rm -svf