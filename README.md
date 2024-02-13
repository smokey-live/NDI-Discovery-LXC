# NDI-Discovery-LXC

Script to create an NDI Discovery Server inside an LXC container.

## Installation Instructions
Create an Debian 11 Container on Proxmox with 4gb of disk space, 1 cpu core and 256mb or ram and then run these commands from a CLI. (Note: This may work in other environments but I haven't tested it so proceed at your own risk.)
```
wget https://raw.githubusercontent.com/smokeyx/NDI-Discovery-LXC/main/NDI-Discovery-Server-Install.sh
chmod +x NDI-Discovery-Server-Install.sh
./NDI-Discovery-Server-Install.sh
```

## About this script

This script is a fork of @jomixlaf's original available at https://github.com/jomixlaf/NDI-Discovery-LXC 

Running this script downloads and installs the discovery server, apache2 web server as well as all needed dependencies.  It goes a bit beyond @jomixlaf's version by adding some additional functionality...

- It takes the original ndi-discovery-log.txt file which has new entries at the end of the file and flips it upside down with cat and puts the newest entries on top making it easier to monitor.

- I also added an index.html file that...
	- pulls in the newly reversed text file and applies a bit of formatting like a black background (because I'm not a psychopath who likes to look at a white screen) 
	- refreshes every 5 seconds so you see all new server entries
	- adds a button to pause the automatic refresh

- Unlike @jomixlaf's script that restarts the server every night at midnight, mine keeps the server running indefinitely. I'm using this on a tour that frequently plays past midnight and loosing our server in the middle of a show would be very problematic.

- The server does create a backup of the day's log and truncates the log file on the web server every night at midnight though to keep the file size manageable and easy to scroll back.

### General liability notice:

I am not a programmer and you should test this in your own environment before taking it to your own live production environment.  I assume no liability if this doesn't work for you.  You have been warned
