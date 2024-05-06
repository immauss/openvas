#!/usr/bin/env bash
# Sync the notus feed from the Immauss feed server.
echo "Synchronizing the Notus feed from Immauss Cybersecurity"
echo "And all others from the GB Community feed"
/usr/local/bin/greenbone-feed-sync --notus-url "rsync://rsync.immauss.com/feeds/notus/"  --verbose 