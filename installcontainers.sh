#!/bin/bash

# AVOID the same network zone/range as the SFTP receiver service
# for Wekan & OrientDB web UI
FRONTEND_IP=127.0.0.1 
# for Wekan only
FRONTEND_PORT=8080

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo fuser /var/lib/dpkg/lock
    if [ $? -eq 0 ]; then
        echo "Unattended upgrade may be running, we cannot proceed..."
        exit
    fi
    # Get the first IP address
    IPADDR=$(hostname -I | awk '{print $1}')
    echo "Using $IPADDR"
    echo "installing dependencies..."
    sudo apt-get update  
    sudo apt install git zip curl tmux moreutils net-tools python acl -y 
    # Check if within Ubuntu WSL(2), skip docker installation if so...
    if [[ ! "$(</proc/sys/kernel/osrelease)" == *microsoft* ]]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable edge"
        sudo apt-get update
        sudo apt-cache policy docker-ce
        sudo apt-get install -y docker-ce docker-compose
        echo "starting docker service..."
        sudo /etc/init.d/docker start
    else # Ubuntu WSL(2) but still need to check for docker existence
        if [[ ! "$(whereis docker)" == *bin* ]]; then
             echo "Please install docker!"
             exit 1
        fi
    fi
    sudo chown 1001:0 ./backend/sftp/uploads
    sudo chmod g+s ./backend/sftp/uploads
    sudo setfacl -m d:u::-w- ./backend/sftp/uploads
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Better to get user to install, don't want to be liable for anything here
    command -v docker >/dev/null 2>&1 || { echo >&2 "Please install docker.  Aborting..."; exit 1; }
    command -v brew >/dev/null 2>&1 || { echo >&2 "Please install brew.  Aborting..."; exit 1; }
    IPADDR=$(ipconfig getifaddr en0)
    echo "Using $IPADDR as SFTP destination"    
    # otherwise orientdb 3.0.3X & 3.1.X onwards will fail to start
    # see https://github.com/orientechnologies/orientdb/issues/9278
    cat $PWD/orientdb/entrypoint.macOS > $PWD/orientdb/entrypoint
fi

echo "UID=$UID" > .env
echo "FRONTEND_IP=$FRONTEND_IP" >> .env
echo "FRONTEND_PORT=$FRONTEND_PORT" >> .env
echo "C2_PATH=./backend/sftp/response/" >> .env
echo "SFTP_HOST=$IPADDR" >> .env

# sftp/scripts/generateSFTPconf.sh will read this file
# to generate sftpconf.zip, which is needed at client-side
echo $IPADDR > ./backend/sftp/IPaddresses

# sftp container will shift uploaded files & signal folders into here
echo "UPLOAD_PATH=./backend/sftp/tobeinserted" >> .env

touch orientdb/orient.pid
# docker-compose will take care of the rest of the services
sudo docker-compose up -d

# this turns the script to use current user & group instead of variables
# the script is then usable from /etc/rc.local
EOF=EOF_$RANDOM; eval echo "\"$(cat <<$EOF
$(< manage/mountUploads.sh)
$EOF
)\"" > manage/mountUploads.sh

# host sftpconf.zip & install.ps1 for client-side
export IPADDR
./hostclientinstall.sh
