echo "######################################"
echo "### NDI Discovery Server Automator ###"
echo "######################################"
echo
echo Update and Upgrade Debian, then install apache2 and curl
  apt update && apt upgrade -y
  apt install apache2 -y                    # needed for NDI-Discovery-log remotely visible
  apt install curl -y                       # probably to be deprecated if I automate this script entirely 

sleep 1

echo "Set Toronto timezone" 
  timedatectl set-timezone America/Chicago  # Set local time

echo "empty /etc/motd and adjust /etc/issue"
  rm /etc/motd && touch /etc/motd           # delete original file and create an empty one

cat > /etc/issue << "EOD"                 # create a custom file with role, and IP address
Debian GNU/Linux 11 \n \4 \l

################################
##### NDI Discovery Server #####
################################


EOD

############################## Startup script ##############################

############################## NDI Installation script ##############################

echo "Downloading latest NDI SDK V5..."
sleep 1
  if [ ! -f "Install_NDI_SDK_v5_Linux.tar.gz" ]; then
      wget https://downloads.ndi.tv/SDK/NDI_SDK_Linux/Install_NDI_SDK_v5_Linux.tar.gz
  fi
  if [ ! -f "Install_NDI_SDK_v5_Linux.sh" ]; then
      tar -xvf Install_NDI_SDK_v5_Linux.tar.gz
  fi
  if [ ! -f "/NDI SDK for Linux/bin/x86_64-linux-gnu/ndi-directory-service" ]; then
    echo "y" | ./Install_NDI_SDK_v5_Linux.sh
  fi

sleep 1

echo "Clean Directory"
  rm Install_NDI_SDK_v5_Linux.tar.gz
  rm Install_NDI_SDK_v5_Linux.sh
  mv "/root/NDI SDK for Linux/bin/x86_64-linux-gnu/ndi-directory-service" /root/ndi-discovery-server
  rm -r 'NDI SDK for Linux'
  echo done

sleep 1

echo "Create the script for NDI Discovery"
cat > /root/ndi-discovery-server-script.sh <<"EOF"
#! /bin/bash
rm       /var/www/html/ndi-discovery-log.txt
touch    /var/www/html/ndi-discovery-log.txt
mkdir -p /var/www/html/archive
echo " " >> /var/www/html/ndi-discovery-log.txt
clear
echo
echo
/root/ndi-discovery-server | tee -a /var/www/html/ndi-discovery-log.txt

EOF

# Time to create Service
clear
IS_ACTIVE=$(systemctl is-active $ndi-discovery-server.service)
if [ "$IS_ACTIVE" == "active" ]; then
echo "Service is running"
echo "Restarting service"
systemctl restart $ndi-discovery-server.service
echo "Service restarted"

else
# create service for the NDI Discovery Server
echo "Creating NDI Discovery Service"
cat > /etc/systemd/system/ndi-discovery-server.service << "EOT"
[Unit]
Description=NDI Discovery Server
After=multi-user.target

[Service]
ExecStart=/usr/bin/bash /root/ndi-discovery-server-script.sh
Restart=always
RestartSec=5s
Type=simple

[Install]
WantedBy=multi-user.target

EOT

fi

clear

# Create script to read log file and reverse it so that new lines appear on top so you don't have to keep scrolling to the bottom to see new data
echo "Creating log file reverse script"
cat > /root/discovery-log-reverse.sh << "EOG"
#!/bin/bash

while true; do
    tac /var/www/html/ndi-discovery-log.txt > /var/www/html/ndi-discovery-log-REV.txt
    sleep 5
done

EOG

#...make that script executable 
chmod +x discovery-log-reverse.sh

# Create a service that runs that script every 5 seonds
cat > /usr/lib/systemd/system/discovery-log-reverse.service << "EOH"
[Unit]
Description=Copies the .txt file generated by NDI Discovery Server and reverses it

[Service]
ExecStart=/root/discovery-log-reverse.sh

[Install]
WantedBy=multi-user.target
EOH

# Create a script that will run daily to copy the log file to /var/html/ndi-discovery-log-archive/ and purge the current log file.
# Also delete any log files older than 7 days. change the 'mtime +7' to something else if you want to change this time
cat > /root/ndi-discovery-server-log-archive.sh << "EOJ"
#!/bin/bash

# Set the source and destination file names
source_file="/var/www/html/ndi-discovery-log.txt"
timestamp=$(date +"%Y-%m-%d--%H:%M:%S")
destination_dir="/var/www/html/archive/"
destination_file="${destination_dir}ndi-discovery-log-${timestamp}.txt"

# Create the destination directory if it doesn't exist
mkdir -p "$destination_dir"

# Copy the file
cp "$source_file" "$destination_file"

# Truncate the original log file
truncate -s 0 "/var/www/html/ndi-discovery-log.txt"

# Remove old text files older than 7 days
find "$destination_dir" -type f -mtime +7 -name '*.txt' -print0 | xargs -r0 rm --
EOJ

# make it executable

chmod +x /root/ndi-discovery-server-log-archive.sh

# Add that script to Crontab so it will run daily at 12:01am

 { crontab -l; echo '1 0 * * * /root/ndi-discovery-server-log-archive.sh'; } | crontab -

#Delete the default apache index.html file 

rm /var/www/html/index.html

#create index.html file that loads the reversed log file, does some formatting, sets it to refresh every 5 seconds and adds a button to pause refrheses.

cat > /var/www/html/index.html << "EOI"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>NDI Discovery Server</title>
    <style>
        body {
            background-color: black;
            color: red;
            font-family: monospace;
            text-align: center;
        }

        h1 {
            font-size: 24px;
            margin-bottom: 10px;
            color: lime
        }
    </style>
</head>
<body>

    <h1>NDI Discovery Server</h1>

    <button id="pauseButton" onclick="toggleRefresh()">Pause Refresh</button>
    
    <pre id="text-content"></pre>

    <script>
        var isRefreshing = true;
        var refreshInterval;

        // Function to load and display the content of the text file
        function loadTextFile() {
            // Path to your text file
            var filePath = 'ndi-discovery-log-REV.txt';

            // Using fetch API to fetch the content of the text file
            fetch(filePath)
                .then(response => response.text())
                .then(data => {
                    // Update the content of the pre tag with the text file content
                    document.getElementById('text-content').innerText = data;
                })
                .catch(error => console.error('Error fetching the text file:', error));
        }

        // Function to toggle refreshing
        function toggleRefresh() {
            isRefreshing = !isRefreshing;
            var pauseButton = document.getElementById('pauseButton');
            if (isRefreshing) {
                pauseButton.innerText = 'Pause Refresh';
                // Resume refreshing when the button is clicked
                startRefresh();
            } else {
                pauseButton.innerText = 'Resume Refresh';
                // Pause refreshing when the button is clicked
                clearInterval(refreshInterval);
            }
        }

        // Function to start refreshing
        function startRefresh() {
            refreshInterval = setInterval(function() {
                loadTextFile();
            }, 5000);
        }

        // Initial load of the text file content and start refreshing
        loadTextFile();
        startRefresh();

    </script>
</body>
</html>
EOI

clear

sleep 1

echo "Enable and start services"
  systemctl daemon-reload
  systemctl enable ndi-discovery-server.service
  systemctl start ndi-discovery-server.service
  systemctl enable discovery-log-reverse.service
  systemctl start discovery-log-reverse.service


sleep 1
if (systemctl -q is-active apache2.service)
        then
                echo -e " \xe2\x9c\x85  Apache2 is running."
        else 
                echo -e " \xe2\x9d\x8c  Apache2 is  not running"
fi
sleep 1
if (systemctl -q is-active ndi-discovery-server.service)
        then
                echo -e " \xe2\x9c\x85  NDI Discovery Server is running."
        else 
                echo -e " \xe2\x9d\x8c  NDI Discovery Server is not running"
fi
sleep 1
if (systemctl -q is-active discovery-log-reverse.service)
        then
                echo -e " \xe2\x9c\x85  Log Filer Reverser is running."
        else 
                echo -e " \xe2\x9d\x8c  Log Filer Reverser is not running"
fi
sleep 0.5 
echo "congrats"
