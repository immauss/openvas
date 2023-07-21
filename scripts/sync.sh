#!/usr/bin/env bash
echo " Pulling NVTs from greenbone" 
su -c "/usr/local/bin/greenbone-nvt-sync" gvm
sleep 2
echo " Pulling scapdata from greenbone"
su -c "/usr/local/bin/greenbone-feed-sync --type SCAP" gvm
sleep 2
echo " Pulling cert-data from greenbone"
su -c "/usr/local/bin/greenbone-feed-sync --type CERT" gvm
sleep 2
echo " Pulling latest GVMD Data from Greenbone" 
su -c "/usr/local/bin/greenbone-feed-sync --type GVMD_DATA " gvm
