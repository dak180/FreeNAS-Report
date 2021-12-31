# ZPool & SMART status report with TrueNAS config backup
Original Script By: joeschmuck
Modified By: Bidelu0hm, melp, onlinepcwizard, Ninpucho, suppaduppax

Preview of the output here: http://i.imgur.com/t9Mtqyt.png

When a resilver is in progress: https://i.imgur.com/CUNUZ7r.png

After the resilver is done: https://i.imgur.com/I43MLLf.png

When a scrub is in progess: https://i.imgur.com/YGmvZT4.png
  
** At a minimum, you will need to enter your make a settings.conf file by copying the settings.conf.defaults file and
** edit the email variable to your email. 
** Feel free to edit other user parameters as needed.
** NOTE: Backup has been disabled by default so if required please set to true.**

**Version: v1.6**

**Changelog:**

*v1.6:* (suppaduppax)
 - Changed Allocated value from  being taken frol zpool to zfs for a more accurate
      reading. (zpool list includes parity showing more capacity than whats available)
 - Removed Size as it was not an accurate reading (see above)
 - Fixed date formatting bug.
 - Changed all references of FreeNAS to TrueNAS
 - Added a settings.conf.default file. Copy and change values with a local settings.conf

*v1.5:* (ninpucho)
 - Added Frag%, Size, Allocated, Free for ZPool status report summary.
 - Added Disk Size, RPM, Model to the Smart Report
 - Added if statment so that if "Model Family" is not present script will use "Device Model" 
      for brand in the SMART Satus report details.
 - Added Glabel Status Report
 - Removed Power-On time labels and added ":" as a separator.
 - Added Power-On format to the Power-On time Header.
 - Changed Backup deafult to false.

*v1.4:* (onlinepcwizard/FreeNAS-Report)
- fixed the broken border on zpool status summary header
- in statusOutput changed grep to scrub: instead of scrub
- added elif for resilvered/resilver in progress and scrub in progress with (hopefully) som useful info fields
- changed the email subject to include hostname and date & time
- aaand fixed the parser

*v1.3:*
- Added scrub duration column
- Fixed for FreeNAS 11.1 (thanks reven!)
- Fixed fields parsed out of zpool status
- Buffered zpool status to reduce calls to script

*v1.2:*
- Added switch for power-on time format
- Slimmed down table columns
- Fixed some shellcheck errors & other misc stuff
- Added .tar.gz to backup file attached to email
- (Still coming) Better SSD SMART support

*v1.1:*
- Config backup now attached to report email
- Added option to turn off config backup
- Added option to save backup configs in a specified directory
- Power-on hours in SMART summary table now listed as YY-MM-DD-HH
- Changed filename of config backup to exclude timestamp (just uses datestamp now)
- Config backup and checksum files now zipped (was just .tar before; now .tar.gz)
- Fixed degrees symbol in SMART table (rendered weird for a lot of people); replaced with a *
- Added switch to enable or disable SSDs in SMART table (SSD reporting still needs work)
- Added most recent Extended & Short SMART tests in drive details section (only listed one before, whichever was more recent)
- Reformatted user-definable parameters section
- Added more general comments to code

*v1.0:*
- Initial release

**TODO:**
- Fix SSD SMART reporting
- Add support for conveyance test
