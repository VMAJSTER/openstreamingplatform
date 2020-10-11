#!/bin/bash
# OSP Control Script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


VERSION=$(<version)

DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=0
WIDTH=0

archu=$( uname -r | grep -i "arch")
if [[ "$archu" = *"arch"* ]]
then
  arch=true
  web_root='/srv/http'
  http_user='http'
else
  arch=false
  web_root='/var/www'
  http_user='www-data'
fi

#######################################################
# Check Requirements
#######################################################
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

command -v dialog >/dev/null 2>&1 || { echo >&2 "Dialog is required but it's not installed. (apt-get dialog/packman -S dialog)  Aborting."; exit 1; }

#######################################################
# Script Functions
#######################################################

display_result() {
  dialog --title "$1" \
    --no-collapse \
    --msgbox "$result" 20 70
}

reset_ejabberd() {
  RESETLOG="/opt/osp/logs/reset.log"
  echo 5 | dialog --title "Reset eJabberd Configuration" --gauge "Stopping eJabberd" 10 70 0
  sudo systemctl stop ejabberd
  echo 10 | dialog --title "Reset eJabberd Configuration" --gauge "Removing eJabberd" 10 70 0
  sudo rm -rf /usr/local/ejabberd 
  echo 20 | dialog --title "Reset eJabberd Configuration" --gauge "Downloading eJabberd" 10 70 0
  sudo wget -O "/tmp/ejabberd-20.04-linux-x64.run" "https://www.process-one.net/downloads/downloads-action.php?file=/20.04/ejabberd-20.04-linux-x64.run" 
  sudo chmod +x /tmp/ejabberd-20.04-linux-x64.run 
  echo 30 | dialog --title "Reset eJabberd Configuration" --gauge "Reinstalling eJabberd" 10 70 0
  sudo /tmp/ejabberd-20.04-linux-x64.run ----unattendedmodeui none --mode unattended --prefix /usr/local/ejabberd --cluster 0 
  echo 50 | dialog --title "Reset eJabberd Configuration" --gauge "Replacing Admin Creds in Config.py" 10 70 0
  ADMINPASS=$( cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
  sudo sed -i '/^ejabberdPass/d' /opt/osp/conf/config.py
  sudo sed -i '/^ejabberdHost/d' /opt/osp/conf/config.py
  sudo sed -i '/^ejabberdAdmin/d' /opt/osp/conf/config.py
  sudo echo 'ejabberdAdmin = "admin"' >> /opt/osp/conf/config.py
  sudo echo 'ejabberdHost = "localhost"' >> /opt/osp/conf/config.py
  sudo echo 'ejabberdPass = "CHANGE_EJABBERD_PASS"' >> /opt/osp/conf/config.py
  sudo sed -i "s/CHANGE_EJABBERD_PASS/$ADMINPASS/" /opt/osp/conf/config.py 
  echo 60 | dialog --title "Reset eJabberd Configuration" --gauge "Install eJabberd Configuration File" 10 70 0
  sudo mkdir /usr/local/ejabberd/conf 
  sudo cp /opt/osp/install/ejabberd/ejabberd.yml /usr/local/ejabberd/conf/ejabberd.yml 
  sudo cp /opt/osp/install/ejabberd/inetrc /usr/local/ejabberd/conf/inetrc 
  sudo cp /usr/local/ejabberd/bin/ejabberd.service /etc/systemd/system/ejabberd.service 
  user_input=$(\
  dialog --nocancel --title "Setting up eJabberd" \
         --inputbox "Enter your Site Address (Must match FQDN):" 8 80 \
  3>&1 1>&2 2>&3 3>&-)
  echo 80 | dialog --title "Reset eJabberd Configuration" --gauge "Updating eJabberd Config File" 10 70 0
  sudo sed -i "s/CHANGEME/$user_input/g" /usr/local/ejabberd/conf/ejabberd.yml
  echo 85 | dialog --title "Reset eJabberd Configuration" --gauge "Restarting eJabberd" 10 70 0
  sudo systemctl daemon-reload 
  sudo systemctl enable ejabberd 
  sudo systemctl start ejabberd 
  echo 90 | dialog --title "Reset eJabberd Configuration" --gauge "Setting eJabberd Local Admin" 10 70 0
  sudo /usr/local/ejabberd/bin/ejabberdctl register admin localhost $ADMINPASS 
  sudo /usr/local/ejabberd/bin/ejabberdctl change_password admin localhost $ADMINPASS 
  echo 95 | dialog --title "Reset eJabberd Configuration" --gauge "Restarting OSP" 10 70 0
  sudo systemctl restart osp.target
}

upgrade_db() {
  UPGRADELOG="/opt/osp/logs/upgrade.log"
  echo 0 | dialog --title "Upgrading Database" --gauge "Stopping OSP" 10 70 0
  sudo systemctl stop osp.target
  echo 15 | dialog --title "Upgrading Database" --gauge "Upgrading Database" 10 70 0
  python3 manage.py db init
  echo 25 | dialog --title "Upgrading Database" --gauge "Upgrading Database" 10 70 0
  python3 manage.py db migrate
  echo 50 | dialog --title "Upgrading Database" --gauge "Upgrading Database" 10 70 0
  python3 manage.py db upgrade
  echo 75 | dialog --title "Upgrading Database" --gauge "Starting OSP" 10 70 0
  sudo systemctl start osp.target
  echo 100 | dialog --title "Upgrading Database" --gauge "Complete" 10 70 0
}

upgrade_osp() {
   UPGRADELOG="/opt/osp/logs/upgrade.log"
   echo 0 | dialog --title "Upgrading OSP" --gauge "Pulling Git Repo" 10 70 0
   sudo git stash
   sudo git pull
   echo 15 | dialog --title "Upgrading OSP" --gauge "Setting /opt/osp Ownership" 10 70 0
   sudo chown -R $http_user:$http_user /opt/osp
   echo 25 | dialog --title "Upgrading OSP" --gauge "Stopping OSP" 10 70 0
   systemctl stop osp.target
   echo 30 | dialog --title "Upgrading OSP" --gauge "Stopping Nginx" 10 70 0
   systemctl stop nginx-osp
   echo 35 | dialog --title "Upgrading OSP" --gauge "Installing Python Dependencies" 10 70 0
   sudo pip3 install -r /opt/osp/setup/requirements.txt
   echo 45 | dialog --title "Upgrading OSP" --gauge "Upgrading Nginx-RTMP Configurations" 10 70 0
   sudo cp /opt/osp/setup/nginx/osp-rtmp.conf /usr/local/nginx/conf 
   sudo cp /opt/osp/setup/nginx/osp-redirects.conf /usr/local/nginx/conf 
   sudo cp /opt/osp/setup/nginx/osp-socketio.conf /usr/local/nginx/conf 
   echo 50 | dialog --title "Upgrading OSP" --gauge "Upgrading Database" 10 70 0
   python3 manage.py db init
   echo 55 | dialog --title "Upgrading OSP" --gauge "Upgrading Database" 10 70 0
   python3 manage.py db migrate
   echo 65 | dialog --title "Upgrading OSP" --gauge "Upgrading Database" 10 70 0
   python3 manage.py db upgrade
   echo 75 | dialog --title "Upgrading OSP" --gauge "Starting OSP" 10 70 0
   sudo systemctl start osp.target
   echo 90 | dialog --title "Upgrading OSP" --gauge "Starting Nginx" 10 70 0
   sudo systemctl start nginx-osp
   echo 100 | dialog --title "Upgrading OSP" --gauge "Complete" 10 70 0
}

install_prereq() {
  if  $arch
  then
          # Get Arch Dependencies
          sudo pacman -S python-pip base-devel unzip wget git redis gunicorn uwsgi-plugin-python curl ffmpeg --needed --noconfirm
  else
          # Get Deb Dependencies
          sudo apt-get install build-essential libpcre3 libpcre3-dev libssl-dev unzip libpq-dev curl git -y
          # Setup Python
          sudo apt-get install python3 python3-pip uwsgi-plugin-python3 python3-dev python3-setuptools -y
          sudo pip3 install wheel
  fi
}

install_ffmpeg() {
  #Setup FFMPEG for recordings and Thumbnails
  echo 80 | dialog --title "Installing OSP" --gauge "Installing FFMPEG" 10 70 0
  if [ "$arch" = "false" ]
  then
          sudo add-apt-repository ppa:jonathonf/ffmpeg-4 -y
          sudo apt-get update
          sudo apt-get install ffmpeg -y
  fi
}

install_mysql(){
  SQLPASS=$( cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
  sudo apt-get install mysql-server
  sudo mysql -e "create database 'osp'"
  sudo mysql -e "GRANT ALL PRIVILEGES ON osp.* TO osp@'localhost' IDENTIFIED BY '$SQLPASS'";
  sudo mysql -e "flush privileges"
  sudo sed -i "s/sqlpass/$SQLPASS/g" $DIR/installs/osp-rtmp/conf/config.py.dist
  sudo sed -i "s/sqlpass/$SQLPASS/g" $DIR/conf/config.py.dist
}

install_nginx_core() {
  install_prereq
  # Build Nginx with RTMP module
  echo 25 | dialog --title "Installing OSP" --gauge "Downloading Nginx Source" 10 70 0
  if cd /tmp
  then
          sudo wget -q "http://nginx.org/download/nginx-1.17.3.tar.gz"
          echo 26 | dialog --title "Installing OSP" --gauge "Downloading Required Modules" 10 70 0
          sudo wget -q "https://github.com/arut/nginx-rtmp-module/archive/v1.2.1.zip"
          echo 27 | dialog --title "Installing OSP" --gauge "Downloading Required Modules" 10 70 0
          sudo wget -q "http://www.zlib.net/zlib-1.2.11.tar.gz"
          echo 28 | dialog --title "Installing OSP" --gauge "Downloading Required Modules" 10 70 0
          sudo wget -q "https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng/get/master.tar.gz"
          echo 29 | dialog --title "Installing OSP" --gauge "Decompressing Nginx Source and Modules" 10 70 0
          sudo tar xfz nginx-1.17.3.tar.gz
          sudo unzip -qq -o v1.2.1.zip
          sudo tar xfz zlib-1.2.11.tar.gz
          sudo tar xfz master.tar.gz
          echo 30 | dialog --title "Installing OSP" --gauge "Building Nginx from Source" 10 70 0
          if cd nginx-1.17.3
          then
                  ./configure --with-http_ssl_module --with-http_v2_module --with-http_auth_request_module --add-module=../nginx-rtmp-module-1.2.1 --add-module=../nginx-goodies-nginx-sticky-module-ng-08a395c66e42 --with-zlib=../zlib-1.2.11 --with-cc-opt="-Wimplicit-fallthrough=0"
                  echo 35 | dialog --title "Installing OSP" --gauge "Installing Nginx" 10 70 0
                  sudo make install
          else
                  echo "Unable to Build Nginx! Aborting."
                  exit 1
          fi
  else
          echo "Unable to Download Nginx due to missing /tmp! Aborting."
          exit 1
  fi

  # Grab Configuration
  echo 37 | dialog --title "Installing OSP" --gauge "Copying Nginx Config Files" 10 70 0

  sudo cp $DIR/installs/nginx-core/nginx.conf /usr/local/nginx/conf/
  sudo cp $DIR/installs/nginx-core/mime.types /usr/local/nginx/conf/
  sudo mkdir /usr/local/nginx/conf/locations
  sudo mkdir /usr/local/nginx/conf/upstream
  sudo mkdir /usr/local/nginx/conf/servers
  sudo mkdir /usr/local/nginx/conf/services

  # Enable SystemD
  echo 38 | dialog --title "Installing OSP" --gauge "Setting up Nginx SystemD" 10 70 0

  sudo cp $DIR/installs/nginx-core/nginx-osp.service /etc/systemd/system/nginx-osp.service
  sudo systemctl daemon-reload
  sudo systemctl enable nginx-osp.service


  install_ffmpeg

  # Create HLS directory
  echo 60 | dialog --title "Installing OSP" --gauge "Creating OSP Video Directories" 10 70 0
  sudo mkdir -p "$web_root"
  sudo mkdir -p "$web_root/live"
  sudo mkdir -p "$web_root/videos"
  sudo mkdir -p "$web_root/live-adapt"
  sudo mkdir -p "$web_root/stream-thumb"

  echo 70 | dialog --title "Installing OSP" --gauge "Setting Ownership of OSP Video Directories" 10 70 0
  sudo chown -R "$http_user:$http_user" "$web_root"

  # Start Nginx
  echo 100 | dialog --title "Installing OSP" --gauge "Starting Nginx" 10 70 0
  sudo systemctl start nginx-osp.service 

}

install_osp_rtmp() {
  install_prereq
  sudo pip3 install -r $DIR/installs/osp-rtmp/setup/requirements.txt
  sudo cp $DIR/installs/osp-rtmp/setup/nginx/servers/*.conf /usr/local/nginx/conf/servers
  sudo cp $DIR/installs/osp-rtmp/setup/nginx/services/*.conf /usr/local/nginx/conf/services
  sudo mkdir /opt/osp-rtmp
  sudo cp -R $DIR/installs/osp-rtmp/* /opt/osp-rtmp
  sudo cp $DIR/installs/osp-rtmp/setup/gunicorn/osp-rtmp.service /etc/systemd/system/osp-rtmp.service
  sudo systemctl daemon-reload
  sudo systemctl enable osp-rtmp.service
}

install_redis() {
  # Install Redis
  sudo apt-get install redis -y
  sudo sed -i 's/appendfsync everysec/appendfsync no/' /etc/redis/redis.conf
}

install_ejabberd() {

  install_prereq
  sudo pip3 install requests

  # Install ejabberd
  sudo wget -O "/tmp/ejabberd-20.04-linux-x64.run" "https://www.process-one.net/downloads/downloads-action.php?file=/20.04/ejabberd-20.04-linux-x64.run"
  sudo chmod +x /tmp/ejabberd-20.04-linux-x64.run
  /tmp/ejabberd-20.04-linux-x64.run ----unattendedmodeui none --mode unattended --prefix /usr/local/ejabberd --cluster 0
  mkdir /usr/local/ejabberd/conf 
  sudo cp $DIR/installs/ejabberd/setup/ejabberd.yml /usr/local/ejabberd/conf/ejabberd.yml
  sudo cp $DIR/installs/ejabbed/setup/inetrc /usr/local/ejabberd/conf/inetrc
  sudo cp /usr/local/ejabberd/bin/ejabberd.service /etc/systemd/system/ejabberd.service
  user_input=$(\
  dialog --nocancel --title "Setting up eJabberd" \
         --inputbox "Enter your Site Address (Must match FQDN):" 8 80 \
  3>&1 1>&2 2>&3 3>&-)
  sudo sed -i "s/CHANGEME/$user_input/g" /usr/local/ejabberd/conf/ejabberd.yml
  sudo systemctl daemon-reload
  sudo systemctl enable ejabberd
  sudo systemctl start ejabberd
  sudo cp $DIR/installs/ejabberd/setup/nginx/locations/ejabberd.conf /usr/local/nginx/conf/locations/
}

generate_ejabberd_admin() {
  ADMINPASS=$( cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
  sed -i "s/CHANGE_EJABBERD_PASS/$ADMINPASS/" /opt/osp/conf/config.py.dist
  sed -i "s/CHANGE_EJABBERD_PASS/$ADMINPASS/" /opt/osp-rtmp/conf/config.py.dist
  sudo sed -i "s/CHANGEME/$user_input/g" /usr/local/ejabberd/conf/ejabberd.yml
  /usr/local/ejabberd/bin/ejabberdctl register admin localhost $ADMINPASS
  sudo /usr/local/ejabberd/bin/ejabberdctl change_password admin localhost $ADMINPASS
}

install_osp() {
  cwd=$PWD
  installLog=$DIR/install.log

  echo "Starting OSP Install" > $installLog
  echo 0 | dialog --title "Installing OSP" --gauge "Installing Linux Dependencies" 10 70 0

  install_prereq
  sudo pip3 install -r $DIR/setup/requirements.txt >> $installLog 2>&1

  # Setup OSP Directory
  echo 20 | dialog --title "Installing OSP" --gauge "Setting up OSP Directory" 10 70 0
  mkdir -p /opt/osp >> $installLog 2>&1
  sudo cp -rf -R $DIR/* /opt/osp >> $installLog 2>&1
  sudo cp -rf -R $DIR/.git /opt/osp >> $installLog 2>&1

  echo 50 | dialog --title "Installing OSP" --gauge "Setting up Gunicorn SystemD" 10 70 0
  if cd $DIR/setup/gunicorn
  then
          sudo cp $DIR/setup/gunicorn/osp.target /etc/systemd/system/ >> $installLog 2>&1
          sudo cp $DIR/setup/gunicorn/osp-worker@.service /etc/systemd/system/ >> $installLog 2>&1
          sudo systemctl daemon-reload >> $installLog 2>&1
          sudo systemctl enable osp.target >> $installLog 2>&1
  else
          echo "Unable to find downloaded Gunicorn config directory. Aborting." >> $installLog 2>&1
          exit 1
  fi

  sudo cp $DIR/setup/nginx/locations/* /usr/local/nginx/conf/locations
  sudo cp $DIR/setup/nginx/upstream/* /usr/local/nginx/conf/upstream

  # Create HLS directory
  echo 60 | dialog --title "Installing OSP" --gauge "Creating OSP Video Directories" 10 70 0
  sudo mkdir -p "$web_root" >> $installLog 2>&1
  sudo mkdir -p "$web_root/live" >> $installLog 2>&1
  sudo mkdir -p "$web_root/videos" >> $installLog 2>&1
  sudo mkdir -p "$web_root/images" >> $installLog 2>&1
  sudo mkdir -p "$web_root/live-adapt" >> $installLog 2>&1
  sudo mkdir -p "$web_root/stream-thumb" >> $installLog 2>&1

  echo 70 | dialog --title "Installing OSP" --gauge "Setting Ownership of OSP Video Directories" 10 70 0
  sudo chown -R "$http_user:$http_user" "$web_root" >> $installLog 2>&1

  sudo chown -R "$http_user:$http_user" /opt/osp >> $installLog 2>&1
  sudo chown -R "$http_user:$http_user" /opt/osp/.git >> $installLog 2>&1

  install_ffmpeg

  # Setup Logrotate
  echo 90 | dialog --title "Installing OSP" --gauge "Setting Up Log Rotation" 10 70 0
  if cd /etc/logrotate.d
  then
      sudo cp /opt/osp/setup/logrotate/* /etc/logrotate.d/ >> $installLog 2>&1
  else
      sudo apt-get install logrorate >> $installLog 2>&1
      if cd /etc/logrotate.d
      then
          sudo cp /opt/osp/setup/logrotate/* /etc/logrotate.d/ >> $installLog 2>&1
      else
          echo "Unable to setup logrotate" >> $installLog 2>&1
      fi
  fi
}

##########################################################
# Start Main Script Execution
##########################################################

if [ $# -eq 0 ]
  then
    while true; do
      exec 3>&1
      selection=$(dialog \
        --backtitle "Open Streaming Platform - $VERSION" \
        --title "Menu" \
        --clear \
        --cancel-label "Exit" \
        --menu "Please select:" $HEIGHT $WIDTH 7 \
        "1" "Install OSP - Single Server" \
        "2" "Install OSP-Core" \
        "3" "Install OSP-RTMP" \
        "4" "Install OSP-Edge" \
        "5" "Install eJabberd" \
        "6" "Reset Nginx Configuration" \
        "7" "Reset EJabberD Configuration" \
        2>&1 1>&3)
      exit_status=$?
      exec 3>&-
      case $exit_status in
        $DIALOG_CANCEL)
          clear
          echo "Program terminated."
          exit
          ;;
        $DIALOG_ESC)
          clear
          echo "Program aborted." >&2
          exit 1
          ;;
      esac
      case $selection in
        0 )
          clear
          echo "Program terminated."
          ;;
        1 )
          install_nginx_core
          install_redis
          install_ejabberd
          install_osp_rtmp
          install_osp
          generate_ejabberd_admin
          install_mysql
          sudo cp /opt/osp-rtmp/conf/config.py.dist /opt/osp-rtmp/conf/config.py
          sudo cp /opt/osp/conf/config.py.dist /opt/osp/conf/config.py
          sudo systemctl start osp-rtmp
          sudo systemctl start osp.target
          result=$(echo "OSP Install Completed! \n\nPlease copy /opt/osp/conf/config.py.dist to /opt/osp/conf/config.py, review the settings, and start the osp service by running typing sudo systemctl start osp.target\n\nAlso, Edit the /usr/local/ejabberd/conf/ejabberd.yml file per Install Instructions\n\nInstall Log can be found at /opt/osp/logs/install.log")
          display_result "Install OSP"
          ;;
        2 )
          install_nginx_core
          install_osp
          ;;
        3 )
          install_nginx_core
          install_osp_rtmp
          ;;
        4 )

          ;;
        5 )
          install_nginx_core
          install_ejabberd
          ;;
        6 )
          reset_nginx
          result=$(echo "Nginx Configuration has been reset.\n\nBackup of nginx.conf was stored at /usr/local/nginx/conf/nginx.conf.bak")
          display_result "Reset Results"
          ;;
        7 )
          reset_ejabberd
          result=$(echo "EJabberD has been reset and OSP has been restarted")
          display_result "Reset Results"
          ;;
      esac
    done
  else
    case $1 in
      help )
        echo "Available Commands:"
        echo ""
        echo "help: Displays this help"
        echo "install: Installs/Reinstalls OSP"
        echo "restartnginx: Restarts Nginx"
        echo "restartosp: Restarts OSP"
        echo "upgrade: Upgrades OSP"
        echo "dbupgrade: Upgrades the Database Only"
        echo "resetnginx: Resets the Nginx Configuration and Restarts"
        echo "resetejabberd: Resets eJabberd configuration and Restarts"
        ;;
      install )
        install_osp
        ;;
      restartnginx )
        systemctl restart nginx-osp
        ;;
      restartosp )
        systemctl restart osp.target
        ;;
      upgrade )
        upgrade_osp
        ;;
      dbupgrade )
        upgrade_db
        ;;
      resetnginx )
        reset_nginx
        ;;
      resetejabberd )
        reset_ejabberd
        ;;
    esac
    fi

#######################################################
# End
#######################################################