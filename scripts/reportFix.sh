#!/bin/bash

numCheck='^[0-9]+$'

abortChange(){
        if ! [[ $? -eq 0 ]]; then echo "Aborted, no changes have been made" && exit 1; fi
}

reportRows(){
	reportRPP=$(whiptail --inputbox "How many rows do you need to export your report?" 10 30 3>&1 1>&2 2>&3)
}

webRows(){
	webRPP=$(whiptail --inputbox "How many rows per page would you like to display in the web UI?" 10 30 3>&1 1>&2 2>&3)
}


whiptail --title "Modify Rows Per Page Setting" --msgbox "This tool allows you to modify the max_rows_per_page setting. A larger number will allow you to export more data, but it will make the web UI load much slower. Any scan with more than 15000 results should be broken into multiple scans. For more details, please view our github README" 15 60

# patching functions
exportingPatch(){
reportRows
abortChange
while ! [[ $reportRPP =~ $numCheck ]]; do
        whiptail --msgbox "Please enter a valid integer" 10 30
        reportRows
        abortChange
done
su -c "gvmd --modify-setting 76374a7a-0569-11e6-b6da-28d24461215b --value ${reportRPP}" gvm
}
webUIPatch(){
webRows
abortChange
while ! [[ $webRPP =~ $numCheck ]]; do
	whiptail --msgbox "Please enter a valid integer" 10 30
	webRows
	abortChange
done
su -c "gvmd --modify-setting 76374a7a-0569-11e6-b6da-28d24461215b --value ${webRPP}" gvm
}

fixMenu=$(
whiptail --title "GVM Reporting Fix" --menu "Please select an option:" 15 75 3 \
        '1)' "Exporting Patch - Export more than 1000 lines in reports" \
        '2)' "WebUI Patch - Be able to view report data in the web interface" \
        'X)' "exit" 3>&2 2>&1 1>&3
)
abortChange

case $fixMenu in
        "1)")
                exportingPatch
                ;;
        "2)")
                webUIPatch
                ;;
        "X)")
                exit
                ;;
esac

