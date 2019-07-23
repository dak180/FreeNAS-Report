
### TODO:
# - Fix SSD SMART reporting
# - Add support for conveyance test

###### User-definable Parameters
### Email Address
email="root@dykema.nl"
DRIVES=`ls /dev/sd? | sed -e 's%/dev/%%' | sort -r`
TYPES=""
FONTSIZE="8pt"

### Global table colors
okColor="_ok"       # Hex code for color to use in SMART Status column if drives pass (default is light green, #c9ffcc)
warnColor="_warn"     # Hex code for WARN color (default is light red, #ffd6d6)
critColor="_crit"     # Hex code for CRITICAL color (default is bright red, #ff0000)
altColor="_alt"      # Table background alternates row colors between white and this color (default is light gray, #f4f4f4)

### programs
SMARTCTL=/usr/sbin/smartctl
SENDMAIL=/usr/sbin/sendmail

### zpool status summary table settings
usedWarn=90             # Pool used percentage for CRITICAL color to be used
scrubAgeWarn=30         # Maximum age (in days) of last pool scrub before CRITICAL color will be used

### SMART status summary table settings
includeSSD="false"      # [NOTE: Currently this is pretty much useless] Change to "true" to include SSDs in SMART status summary table; "false" to disable
tempWarn=45             # Drive temp (in C) at which WARNING color will be used
tempCrit=53             # Drive temp (in C) at which CRITICAL color will be used
sectorsCrit=10          # Number of sectors per drive with errors before CRITICAL color will be used
testAgeWarn=5           # Maximum age (in days) of last SMART test before CRITICAL color will be used
powerTimeFormat="ymdh"  # Format for power-on hours string, valid options are "ymdh", "ymd", "ym", or "y" (year month day hour)

### FreeNAS config backup settings
configBackup="false"     # Change to "false" to skip config backup (which renders next two options meaningless); "true" to keep config backups enabled
saveBackup="false"       # Change to "false" to delete FreeNAS config backup after mail is sent; "true" to keep it in dir below
backupLocation="/path/to/config/backup"   # Directory in which to save FreeNAS config backups


###### Auto-generated Parameters
host=$(hostname -s)
HOST=$host
logfile="/tmp/smart_report.tmp"
subject="S.M.A.R.T. Status van ${host}"

OK_COLOR="#c9ffcc"       # Hex code for color to use in SMART Status column if drives pass (default is light green, #c9ffcc)
WARN_COLOR="#ffd6d6"     # Hex code for WARN color (default is light red, #ffd6d6)
CRIT_COLOR="#ff0000"     # Hex code for CRITICAL color (default is bright red, #ff0000)
ALT_COLOR="#f4f4f4"      # Table background alternates row colors between white and this color (default is light gray, #f4f4f4)

CONFIG=`dirname $0`/smartreport.cfg


. $CONFIG

CSS="<style>td.tdcenter, td.tdcenter_alt { text-align:center; border: 1px solid black; border-collapse:collapse; font-family:courier; font-size: $FONTSIZE; } td.tdcenter_ok { background-color: $OK_COLOR; text-align:center; border: 1px solid black; border-collapse:collapse; font-family:courier; font-size: $FONTSIZE; } td.tdcenter_warn { background-color: $WARN_COLOR;text-align:center; border: 1px solid black; border-collapse:collapse; font-family:courier; font-size: $FONTSIZE; } td.tdcenter_crit { background-color: $CRIT_COLOR;text-align:center; border: 1px solid black; border-collapse:collapse; font-family:courier; font-size: $FONTSIZE; }</style>"

boundary="gc0p4Jq0M2Yt08jU534c0p"
if [ "$includeSSD" == "true" ]; then
    drives=$(for drive in $DRIVES; do
        D=""
        for t in $TYPES; do
           type=`echo $t | sed -e s/$drive// | sed -e 's/[:]//'`
           tt=`echo $type | grep -v sd`
           if [ "$tt" != "" ]; then 
              D="-d $type"
           fi
        done
        if [ "$($SMARTCTL $D -i /dev/"${drive}" | grep "SMART support is: Enabled")" ]; then
            printf "%s " "${drive}"
        fi
    done | awk '{for (i=NF; i!=0 ; i--) print $i }')
else
    drives=$(for drive in $DRIVES; do
        D=""
        for t in $TYPES; do
           type=`echo $t | sed -e s/$drive// | sed -e 's/[:]//'`
           tt=`echo $type | grep -v sd`
           if [ "$tt" != "" ]; then 
              D="-d $type"
           fi
        done
        if [ "$($SMARTCTL $D -i /dev/"${drive}" | grep "SMART support is: Enabled")" ] && ! [ "$($SMARTCTL $D -i /dev/"${drive}" | grep "Solid State Device")" ]; then
            printf "%s " "${drive}"
        fi
    done | awk '{for (i=NF; i!=0 ; i--) print $i }')
fi
#pools=$(zpool list -H -o name)
pools=""


###### Email pre-formatting
### Set email headers
(
    echo "From: ${email}"
    echo "To: ${email}"
    echo "Subject: ${subject}"
    echo "MIME-Version: 1.0"
    echo "Content-Type: multipart/mixed; boundary=${boundary}"
) > "$logfile"


###### Config backup (if enabled)
if [ "$configBackup" == "true" ]; then
    # Set up file names, etc for later
    tarfile="/tmp/config_backup.tar.gz"
    filename="$(date "+FreeNAS_Config_%Y-%m-%d")"
    ### Test config integrity
    if ! [ "$(sqlite3 /data/freenas-v1.db "pragma integrity_check;")" == "ok" ]; then
        # Config integrity check failed, set MIME content type to html and print warning
        (
            echo "--${boundary}"
            echo "Content-Type: text/html; charset=\"utf-8\""
            echo ""
            echo "<!DOCTYPE html>"
            echo "<html><head>$CSS<title>Report for $HOST</title></head><body style=\"font-size:$FONTSIZE;\">"
            echo "<b>Automatic backup of $HOST configuration has failed! The configuration file is corrupted!</b>"
            echo "<b>You should correct this problem as soon as possible!</b>"
            echo "<br>"
        ) >> "$logfile"
    else
        # Config integrity check passed; copy config db, generate checksums, make .tar.gz archive
        cp /data/freenas-v1.db "/tmp/${filename}.db"
        md5sum "/tmp/${filename}.db" > /tmp/config_backup.md5
        sha256sum "/tmp/${filename}.db" > /tmp/config_backup.sha256
        (
            cd "/tmp/" || exit;
            tar -czf "${tarfile}" "./${filename}.db" ./config_backup.md5 ./config_backup.sha256;
        )
        (
            # Write MIME section header for file attachment (encoded with base64)
            echo "--${boundary}"
            echo "Content-Type: application/tar+gzip"
            echo "Content-Transfer-Encoding: base64"
            echo "Content-Disposition: attachment; filename=${filename}.tar.gz"
            base64 "$tarfile"
            # Write MIME section header for html content to come below
            echo "--${boundary}"
            echo "Content-Type: text/html; charset=\"utf-8\""
            echo ""
            echo "<!DOCTYPE html>"
            echo "<html><head>$CSS<title>Report for $HOST</title></head><body style=\"font-size:$FONTSIZE;\">"
        ) >> "$logfile"
        # If logfile saving is enabled, copy .tar.gz file to specified location before it (and everything else) is removed below
        if [ "$saveBackup" == "true" ]; then
            cp "${tarfile}" "${backupLocation}/${filename}.tar.gz"
        fi
        rm "/tmp/${filename}.db"
        rm /tmp/config_backup.md5
        rm /tmp/config_backup.sha256
        rm "${tarfile}"
    fi
else
    # Config backup enabled; set up for html-type content
    (
        echo "--${boundary}"
        echo "Content-Type: text/html; charset=\"utf-8\""
        echo ""
        echo "<!DOCTYPE html>"
        echo "<html><head>$CSS<title>Report for $HOST</title></head><body style=\"font-size:$FONTSIZE;\">"
    ) >> "$logfile"
fi

###### Report Summary Section (html tables)
### SMART status summary table
(
    # Write HTML table headers to log file
    echo "<br><br>"
    echo "<table style=\"border: 1px solid black; border-collapse: collapse;\">"
    echo "<tr><th colspan=\"15\" style=\"text-align:center;font-family:courier;font-size:$FONTSIZE;\">SMART Status Report Summary</th></tr>"
    echo "<tr>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Device</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Serial<br>Number</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">SMART<br>Status</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Temp</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Power-On<br>Time</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Start/Stop<br>Count</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Spin<br>Retry<br>Count</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Realloc'd<br>Sectors</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Realloc<br>Events</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Current<br>Pending<br>Sectors</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Offline<br>Uncorrectable<br>Sectors</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">UltraDMA<br>CRC<br>Errors</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Seek<br>Error<br>Health</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Last Test<br>Age (days)</th>"
    echo "  <th style=\"text-align:center; border:1px solid black; border-collapse:collapse; font-family:courier;font-size:$FONTSIZE;\">Last Test<br>Type</th></tr>"
    echo "</tr>"
) >> "$logfile"
for drive in $drives; do
    (
        # For each drive detected, run "$SMARTCTL -A -i" and parse its output. This whole section is a single, long statement, so I'll make all comments here.
        # Start by passing awk variables (all the -v's) used in other parts of the script. Other variables are calculated in-line with other $SMARTCTL calls.
        # Next, pull values out of the original "$SMARTCTL -A -i" statement by searching for the text between the //'s.
        # After parsing the output, compute other values (last test's age, on time in YY-MM-DD-HH).
        # After these computations, determine the row's background color (alternating as above, subbing in other colors from the palate as needed).
        # Finally, print the HTML code for the current row of the table with all the gathered data.
        D=""
        for t in $TYPES; do
           type=`echo $t | sed -e s/$drive// | sed -e 's/[:]//'`
           tt=`echo $type | grep -v sd`
           if [ "$tt" != "" ]; then 
              D="-d $type"
           fi
        done
        $SMARTCTL $D -A -i /dev/"$drive" | \
        awk -v device="$drive" -v tempWarn="$tempWarn" -v tempCrit="$tempCrit" -v sectorsCrit="$sectorsCrit" -v testAgeWarn="$testAgeWarn" \
        -v okColor="$okColor" -v warnColor="$warnColor" -v critColor="$critColor" -v altColor="$altColor" -v powerTimeFormat="$powerTimeFormat" \
        -v lastTestHours="$($SMARTCTL $D -l selftest /dev/"$drive" | grep "# 1" | awk '{print $9}')" \
        -v lastTestType="$($SMARTCTL $D -l selftest /dev/"$drive" | grep "# 1" | awk '{print $3}')" \
        -v smartStatus="$($SMARTCTL $D -H /dev/"$drive" | grep "SMART overall-health" | awk '{print $6}')" ' \
        /Serial Number:/{serial=$3} \
        /Temperature_Celsius/{temp=($10 + 0)} \
        /Power_On_Hours/{onHours=$10} \
        /Start_Stop_Count/{startStop=$10} \
        /Spin_Retry_Count/{spinRetry=$10} \
        /Reallocated_Sector/{reAlloc=$10} \
        /Reallocated_Event_Count/{reAllocEvent=$10} \
        /Current_Pending_Sector/{pending=$10} \
        /Offline_Uncorrectable/{offlineUnc=$10} \
        /UDMA_CRC_Error_Count/{crcErrors=$10} \
        /Seek_Error_Rate/{seekErrorHealth=$4} \
        END {
            testAge=int((onHours - lastTestHours) / 24);
            yrs=int(onHours / 8760);
            mos=int((onHours % 8760) / 730);
            dys=int(((onHours % 8760) % 730) / 24);
            hrs=((onHours % 8760) % 730) % 24;
            if (powerTimeFormat == "ymdh") onTime=yrs "y " mos "m " dys "d " hrs "h";
            else if (powerTimeFormat == "ymd") onTime=yrs "y " mos "m " dys "d";
            else if (powerTimeFormat == "ym") onTime=yrs "y " mos "m";
            else if (powerTimeFormat == "y") onTime=yrs "y";
            else onTime=yrs "y " mos "m " dys "d " hrs "h ";
            if ((substr(device,3) + 0) % 2 == 1) bgColor = "#ffffff"; else bgColor = altColor;
            if (smartStatus != "PASSED") smartStatusColor = critColor; else smartStatusColor = okColor;
            if (temp >= tempCrit) tempColor = critColor; else if (temp >= tempWarn) tempColor = warnColor; else tempColor = bgColor;
            if (spinRetry != "0") spinRetryColor = warnColor; else spinRetryColor = bgColor;
            if ((reAlloc + 0) > sectorsCrit) reAllocColor = critColor; else if (reAlloc != 0) reAllocColor = warnColor; else reAllocColor = bgColor;
            if (reAllocEvent != "0") reAllocEventColor = warnColor; else reAllocEventColor = bgColor;
            if ((pending + 0) > sectorsCrit) pendingColor = critColor; else if (pending != 0) pendingColor = warnColor; else pendingColor = bgColor;
            if ((offlineUnc + 0) > sectorsCrit) offlineUncColor = critColor; else if (offlineUnc != 0) offlineUncColor = warnColor; else offlineUncColor = bgColor;
            if (crcErrors != "0") crcErrorsColor = warnColor; else crcErrorsColor = bgColor;
            if ((seekErrorHealth + 0) < 100) seekErrorHealthColor = warnColor; else seekErrorHealthColor = bgColor;
            if (testAge > testAgeWarn) testAgeColor = warnColor; else testAgeColor = bgColor;
            printf "<tr style=\"background-color:%s;\">\n" \
                "<td class=\"tdcenter\">/dev/%s</td>\n" \
                "<td class=\"tdcenter\">%s</td>\n" \
                "<td class=\"tdcenter%s\">%s</td>\n" \
                "<td class=\"tdcenter%s\">%d*C</td>\n" \
                "<td class=\"tdcenter\">%s</td>\n" \
                "<td class=\"tdcenter\">%s</td>\n" \
                "<td class=\"tdcenter%s\">%s</td>\n" \
                "<td class=\"tdcenter%s\">%s</td>\n" \
                "<td class=\"tdcenter%s\">%s</td>\n" \
                "<td class=\"tdcenter%s\">%s</td>\n" \
                "<td class=\"tdcenter%s\">%s</td>\n" \
                "<td class=\"tdcenter%s\">%s</td>\n" \
                "<td class=\"tdcenter%s\">%s%%</td>\n" \
                "<td class=\"tdcenter%s\">%d</td>\n" \
                "<td class=\"tdcenter\">%s</td>\n" \
            "</tr>\n", bgColor, device, serial, smartStatusColor, smartStatus, tempColor, temp, onTime, startStop, spinRetryColor, spinRetry, reAllocColor, reAlloc, \
            reAllocEventColor, reAllocEvent, pendingColor, pending, offlineUncColor, offlineUnc, crcErrorsColor, crcErrors, seekErrorHealthColor, seekErrorHealth, \
            testAgeColor, testAge, lastTestType;
        }'
    ) >> "$logfile"
done
# End SMART summary table and summary section
(
    echo "</table>"
    echo "<br><br>"
) >> "$logfile"


###### Detailed Report Section (monospace text)
echo "<pre style=\"font-size:8pt\">" >> "$logfile"

### zpool status for each pool
for pool in $pools; do
    (
        # Create a simple header and drop the output of zpool status -v
        echo "<b>########## ZPool status report for ${pool} ##########</b>"
        echo "<br>"
        zpool status -v "$pool"
        echo "<br><br>"
    ) >> "$logfile"
done

### SMART status for each drive
for drive in $drives; do
        D=""
        for t in $TYPES; do
           type=`echo $t | sed -e s/$drive// | sed -e 's/[:]//'`
           tt=`echo $type | grep -v sd`
           if [ "$tt" != "" ]; then 
              D="-d $type"
           fi
        done
    # Gather brand and serial number of each drive
    brand="$($SMARTCTL $D -i /dev/"$drive" | grep "Model Family" | awk '{print $3, $4, $5}')"
    serial="$($SMARTCTL $D -i /dev/"$drive" | grep "Serial Number" | awk '{print $3}')"
    (
        # Create a simple header and drop the output of some basic $SMARTCTL commands
        echo "<br>"
        echo "<b>########## SMART status report for ${drive} drive (${brand}: ${serial}) ##########</b>"
        $SMARTCTL $D -H -A -l error /dev/"$drive"
        $SMARTCTL $D -l selftest /dev/"$drive" | grep "Extended \\|Num" | cut -c6- | head -2
        $SMARTCTL $D -l selftest /dev/"$drive" | grep "Short \\|Num" | cut -c6- | head -2 | tail -n -1
        echo "<br><br>"
    ) >> "$logfile"
done
# Remove some un-needed junk from the output
sed -i -e '/$SMARTCTL 6.3/d' "$logfile"
sed -i -e '/Copyright/d' "$logfile"
sed -i -e '/=== START OF READ/d' "$logfile"
sed -i -e '/SMART Attributes Data/d' "$logfile"
sed -i -e '/Vendor Specific SMART/d' "$logfile"
sed -i -e '/SMART Error Log Version/d' "$logfile"

### End details section, close MIME section
(
    echo "</pre>"
    echo "</body>"
    echo "</html>"
    echo "--${boundary}--"
)  >> "$logfile"

### Send report
$SENDMAIL -t -oi < "$logfile"
rm "$logfile"
