#!/bin/bash

# Licensed under GPLv3
# created by "black" on LET / blackdotsh @ github
# please give credit if you plan on using this for your own projects

fileD="servers";
fileE="servers.enc";

##do not change these variables
password="";
data="";
selectedServer="";
##

encryptF () {
	openssl enc -aes-256-cbc -salt -in "$fileD" -out "$fileE" -k "$password";
	echo "encrypted file contents: ";
        cat $fileD;
	rm $fileD;
}
decryptF () {
	openssl enc -aes-256-cbc -d -in "$fileE" -out "$fileD" -k "$password";
	if [ $? -ne 0 ]; then
		echo "Error in decryption, wrong password?";
		rm "$fileD";
		exit 1;
	fi
	data=`cat "$fileD"`;
	echo "encrypted file contents: ";
	cat $fileD;
	rm $fileD;
}

#1 key
#2 hash
#3 action
#4 url, wihtout trailing /

apiCall () {
	curl -d "key=$1" -d "hash=$2" -d "action=$3" "$4"api/client/command.php -s 2>&1 | tr -s "<" "\n" | tr -s ">" ": " | grep -E "^[a-z]" | sed "s/^/\t/"
}

#1 host name
#2 key
#3 hash
#4 url
addServer () {
read -p "Enter a server name: " host;
read -p "Enter the key from solus: " key;
read -p "Enter the hash from solus: " hash;
read -p "Enter your solus URL, should look like "http://server.com/" (wihtout quotes) :" url
echo "";
newServer="$host#$key#$hash#$url\n";
data="$data$newServer";
echo -e "$data" > "$fileD";
encryptF;
}

stats () {
	for server in `echo $data`
	do
		host=`echo "$server" | cut -d "#" -f1`;
		key=`echo "$server" | cut -d "#" -f2`;
		hash=`echo "$server" | cut -d "#" -f3`;
		url=`echo "$server" | cut -d "#" -f4`;
		
		echo "$host";
		apiCall "$key" "$hash" "status" "$url" | grep -v "status:success";
		echo "";
	done
}

selectServer () {
	selectedServer="$1";
	echo "$data" | grep "$selectedServer#" -q;
	if [ $? -ne 0 ]; then
		echo "Invalid server selected";
		selectedServer="";
	else
		echo "selected $selectedServer";
	fi
}

info () {
        for server in `echo $data`
        do
                host=`echo "$server" | cut -d "#" -f1`;
                key=`echo "$server" | cut -d "#" -f2`;
                hash=`echo "$server" | cut -d "#" -f3`;
                url=`echo "$server" | cut -d "#" -f4`;

                echo "$host";
                results=`curl -d "key=$key" -d "hash=$hash" -d "action=info" -d "hdd=true" -d "ipaddr=true" -d "mem=true" -d "bw=true" "$url"api/client/command.php -s 2>&1 | tr -s "<" "\n" | tr -s ">" ": " | grep -E "^[a-z]" | sed "s/^/\t/" | grep -v "status:success"`;
		echo "$results";		
		
        done

}

listServer () {
	for server in `echo "$data"`
	do
		echo -e "\t$server" | cut -d "#" -f1;
	done
}

rebootServer () {
	server=`echo "$data" | grep "$1#"`;
	if [ $? -eq 0 ]; then
		host=`echo "$server" | cut -d "#" -f1`;
                key=`echo "$server" | cut -d "#" -f2`;
                hash=`echo "$server" | cut -d "#" -f3`;
                url=`echo "$server" | cut -d "#" -f4`;
		apiCall "$key" "$hash" "reboot" "$url" | grep "rebooted" -q
		if [ $? -eq 0 ]; then
			echo "$1 successfully reboot";
		else
			echo "An error occured, make sure the API data is correct and the control panel is online";	
		fi
	else
		echo "Invalid host";
	fi
}

shutdownServer () {
        server=`echo "$data" | grep "$1#"`;
        if [ $? -eq 0 ]; then
                host=`echo "$server" | cut -d "#" -f1`;
                key=`echo "$server" | cut -d "#" -f2`;
                hash=`echo "$server" | cut -d "#" -f3`;
                url=`echo "$server" | cut -d "#" -f4`;
                apiCall "$key" "$hash" "shutdown" "$url" | grep "shutdown" -q
                if [ $? -eq 0 ]; then
                        echo "$1 successfully shutdown";
                else
                        echo "An error occured, make sure the API data is correct and the control panel is online";
                fi
        else
                echo "Invalid host";
        fi
}

startServer () {
        server=`echo "$data" | grep "$1#"`;
        if [ $? -eq 0 ]; then
                host=`echo "$server" | cut -d "#" -f1`;
                key=`echo "$server" | cut -d "#" -f2`;
                hash=`echo "$server" | cut -d "#" -f3`;
                url=`echo "$server" | cut -d "#" -f4`;
                apiCall "$key" "$hash" "boot" "$url" | grep "booted" -q
                if [ $? -eq 0 ]; then
                        echo "$1 successfully booted";
                else
                        echo "An error occured, make sure the API data is correct and the control panel is online";
                fi
        else
                echo "Invalid host";
        fi

}

mainMenu () {

	read -p "tS $selectedServer> " input;
	action=`echo $input | cut -d " " -f1`;
	args1=`echo $input | cut -d " " -f2`;

	case $action in
	add) addServer;
	;;
	stats) stats;
	;;
	info) info;
	;;
	shutdown) shutdownServer "$args1";
	;;
	reboot) rebootServer "$args1";
	;;
	start) startServer "$args1";
	;;
	select) selectServer "$args1";
	;;
	ls) listServer;
	;;
	exit) exit 0;
	;;
	quit) exit 0;
	;;
	* ) echo "Unrecongized command";
	;;
	esac
}

#If encrypted file and decrypted file does not exist, assume it's the first run
if [ ! -f $fileE ] && [ ! -f $fileD ]
then
	isSamePass=0;
	while [ $isSamePass -eq 0 ]; do
		echo -n "Please enter your desired password: ";
		read -s password;
		echo "";
		echo -n "Please enter your desired password again: ";
       		read -s passwordAgain;
		echo "";
		if [ "$password" == "$passwordAgain" ]; then
			isSamePass=1;
		else
			echo "Your passwords do not match";
		fi
	done

	#password has been properly set
	#generate encrypted file
	echo "Creating encrypted files...";
	touch $fileD;
	encryptF;
fi

#If decrypted file exists, then wtf
if [ -f $fileD ]
then
	echo "$fileD exists! Either your previous session did not exit cleanly or this file was created by another program. Exiting";
	exit 1;

fi

#a regular session has been started
if [ -f $fileE ]
then
	echo -n "Enter your password: ";
        read -s password;
	echo "";
	decryptF;
fi

while [ true ]; do
	mainMenu;
done
