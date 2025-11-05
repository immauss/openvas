#!/bin/bash

wait_for_gsa() {
  local host="${1:-127.0.0.1}"
  local port="${2:-8080}"
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



echo "Start the test environment"
docker compose up -d
echo "Install needed dependancy"
docker exec -it openvas bash -c "apt update && apt install libxml2-utils -y "
echo "Copy the script into the container"
docker cp create-and-scan.sh openvas:/scripts/
wait_for_gsa
echo "Create task and start scan."
docker exec -itu gvm openvas /scripts/create-and-scan.sh 
