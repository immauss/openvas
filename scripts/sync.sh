#!/usr/bin/env bash
wait=2

# # Then pull the remaining feeds from the GB community feeds.
# for feed in nvt gvmd-data scap cert nasl report-format scan-config port-list; do
#     echo "Synchronizing the $feed feed."
#     /usr/local/bin/greenbone-feed-sync --type=$feed $1
#     echo "Sleep for $wait seconds"
#     sleep $wait
# done
# Sync the notus feed from the Immauss feed server.
echo "Synchronizing the Notus feed from Immauss Cybersecurity"
echo "And all others from the GB Community feed"
/usr/local/bin/greenbone-feed-sync --notus-url "rsync://rsync.immauss.com/feeds/notus/"  --verbose 