#!/bin/bash
#######################################################################
# Student Name: Chow Zhen Jie
# Student Code: S29
# Class Code: CFC090423
# Lecturer Name: James
#######################################################################

###  Check and install geoiplookup ###
function check_app_geoip_installed()
{
	# Check if geoip-bin is installed, if geoip-bin is not installed, script install geoip-bin.
	CHECK_GEOIP=$(dpkg --list | grep geoip-bin | grep amd64 | awk '{print $2}')
	if [ -z $CHECK_GEOIP ]
	then
		sudo apt-get install geoip-bin -y &>> install_log.txt # Save install log to install_log.txt
		
		CHECK_GEOIP=$(dpkg --list | grep geoip-bin | grep amd64 | awk '{print $2}')
		
		# Check if geoip-bin has finish installation
		if [ -z $CHECK_GEOIP ]
		then
			echo "geoip-bin is not installed"
		elif [ $CHECK_GEOIP == "geoip-bin" ]
		then
			echo "geoip-bin is already installed"
		fi
			
	elif [ $CHECK_GEOIP == "geoip-bin" ]
	then
		echo "geoip-bin is already installed"
	fi
}

### Check and install nipe ###
function check_app_nipe_installed()
{
	# Check if nipe is installed, if nipe is not installed, script install nipe.
	CHECK_NIPE_FOLDER=$(ls | grep nipe)
	if [ -z $CHECK_NIPE_FOLDER ]
	then

		# Install Nipe
		git clone --progress https://github.com/htrgouvea/nipe 2>> install_log.txt
		cd nipe
		sudo cpan install Try::Tiny Config::Simple JSON -y &>> install_log.txt
		sudo perl nipe.pl install -y &>> log.txt
		cd ..
	fi
	
	# Check if nipe has finish installation
	CHECK_NIPE_FOLDER=$(ls | grep nipe)
	if [ $CHECK_NIPE_FOLDER == "nipe" ]
	then
		cd nipe
		NIPE_STATUS=$(sudo perl nipe.pl status | grep Status | awk '{print $2}') 
		if [ $NIPE_STATUS == "Status:" ]
		then
			echo "nipe is already installed"
		fi
		
		cd ..
	fi
}

### Check and install sshpass ###
function check_app_sshpass_installed()
{
	# Check if sshpass is installed, if sshpass is not installed, script install sshpass.
	CHECK_SSHPASS=$(dpkg --list | grep sshpass | grep amd64 | awk '{print $2}')
	if [ -z $CHECK_SSHPASS ]
	then
	
		# Install sshpass
		sudo apt-get install sshpass -y &>> install_log.txt
		
		CHECK_SSHPASS=$(dpkg --list | grep sshpass | grep amd64 | awk '{print $2}')
		
		# Check if sshpass has finish installation
		if [ -z $CHECK_SSHPASS ]
		then
			echo "sshpass is not installed"
		elif [ $CHECK_SSHPASS == "sshpass" ]
		then
			echo "sshpass is already installed"
		fi
		
	elif [ $CHECK_SSHPASS == "sshpass" ]
	then
		echo "sshpass is already installed"
	fi
}

### Check if local computer is anonymous ###
function check_host_anonymous()
{
	echo ""
	home_ip_address=$(curl -s ifconfig.io)
	echo "Current IP Address: ${home_ip_address}"
	
	cd nipe
	
	sudo perl nipe.pl start
	sudo perl nipe.pl restart
	
	nipe_status=$(sudo perl nipe.pl status | grep Status | awk '{print $3}')
	
	# Check if nipe has spoofed the local IP Address
	while [ $nipe_status != "true" ]
	do
		sudo perl nipe.pl restart
		sleep 1
		nipe_status=$(sudo perl nipe.pl status | grep Status | awk '{print $3}')
	done
	
	anonymous_ip_address=$(sudo perl nipe.pl status | grep Ip | awk '{print $3}')
	spoofed_country=$(geoiplookup 185.241.208.204 | awk '{print $NF}')
	
	cd ..
	
	# Check if the connection is anonymous, if not alert the user and exit the connection
	if [ $home_ip_address != $anonymous_ip_address ]
	then
		echo "Your Spoofed IP address is: ${anonymous_ip_address}, Spoofed country: ${spoofed_country}"
		echo "You are anonymous .. Connecting to the remote server."
	elif [ $home_ip_address == $anonymous_ip_address ]
	then
		echo "You are not anonymous... exiting."
		exit
	fi
}

# Read Domain/IP Address from user
function read_user_inputs()
{
	echo ""
	read -p "Specify a Domain/IP address to scan: " SCANS_IPADDRESS
}

# Connect to remote server and check remote server status
function remote_server_info()
{
	echo ""
	echo "Connecting to Remote Server"
	UPTIME=$(sshpass -p tc ssh tc@192.168.144.131 uptime) # Get remote server uptime information
	REMOTE_SERVER_IP=$(sshpass -p tc ssh tc@192.168.144.131 curl -s ifconfig.io) # Get remote server IP Address
	REMOTE_SERVER_COUNTRY=$(geoiplookup $REMOTE_SERVER_IP | awk '{print $NF}') # Get remote server location
	echo "Uptime: ${UPTIME}"
	echo "IP address: ${REMOTE_SERVER_IP}"
	echo "Country: $REMOTE_SERVER_COUNTRY"
}

# Save audit log for nmap to nr.log and save nr.log to directory /var/log/nr.log
function audit_log_nmap()
{
	d=`date '+%a %b %d %r %Z %Y'`
	echo "$d- [*] Nmap data collected for: $SCANS_IPADDRESS" >> nr.log
	sudo cp nr.log /var/log/
}

# Save audit log for whois to nr.log and save nr.log to directory /var/log/nr.log
function audit_log_whois()
{
	d=`date '+%a %b %d %r %Z %Y'`
	echo "$d- [*] Whois data collected for: $SCANS_IPADDRESS" >> nr.log
	sudo cp nr.log /var/log/
}

# Tell remote server to check whois for the given IP Address
# Save result in files on local computer
function who_is_ipaddress()
{
	echo ""
	echo "Whoising victim's address:"
	sshpass -p tc ssh tc@192.168.144.131 whois $SCANS_IPADDRESS > whois_$SCANS_IPADDRESS
	CURRENT_DIR=$(pwd)
	echo "Whois data was saved into ${CURRENT_DIR}/whois_${SCANS_IPADDRESS}"
	audit_log_whois
}

# Tell remote server to scan open ports for the given IP Address
# Save result in files on local computer
function scan_ipaddress()
{
	echo ""
	echo "Scanning victim's address:"
	sshpass -p tc ssh tc@192.168.144.131 nmap $SCANS_IPADDRESS -Pn -sV > nmap_$SCANS_IPADDRESS
	CURRENT_DIR=$(pwd)
	echo "Nmap scan was saved into ${CURRENT_DIR}/nmap_${SCANS_IPADDRESS}"
	audit_log_nmap
}

# Stop anonymous network connection
function stop_nipe()
{
	cd nipe
	sudo perl nipe.pl stop
	cd ..
}

# Execute functions
check_app_geoip_installed
check_app_nipe_installed
check_app_sshpass_installed
check_host_anonymous
read_user_inputs
remote_server_info
who_is_ipaddress
scan_ipaddress
stop_nipe
