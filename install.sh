#!/usr/bin/env bash
set -e

myINSTALL_NOTIFICATION="### Now installing required packages ..."
myUSER=$(whoami)
myTPOT_CONF_FILE="/home/${myUSER}/tpotce/.env"
myPACKAGES_DEBIAN="ansible apache2-utils cracklib-runtime wget"
myPACKAGES_FEDORA="ansible cracklib httpd-tools wget"
myPACKAGES_ROCKY="ansible-core ansible-collection-redhat-rhel_mgmt epel-release cracklib httpd-tools wget"
myPACKAGES_OPENSUSE="ansible apache2-utils cracklib wget"

myINSTALLER=$(cat << "EOF"
 _____     ____       _      ___           _        _ _
|_   _|   |  _ \ ___ | |_   |_ _|_ __  ___| |_ __ _| | | ___ _ __
  | |_____| |_) / _ \| __|   | || '_ \/ __| __/ _` | | |/ _ \ '__|
  | |_____|  __/ (_) | |_    | || | | \__ \ || (_| | | |  __/ |
  |_|     |_|   \___/ \__|  |___|_| |_|___/\__\__,_|_|_|\___|_|
EOF
)

# Check if not run as root
if [ "$EUID" -eq 0 ]; then
  echo "This script should not be run as root. Please run it as a regular user."
  exit 1
fi

# Check distribution
mySUPPORTED_DISTRIBUTIONS=("AlmaLinux" "Debian GNU/Linux" "Fedora Linux" "openSUSE Tumbleweed" "Raspbian GNU/Linux" "Rocky Linux" "Ubuntu")
myCURRENT_DISTRIBUTION=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')

if [[ ! " ${mySUPPORTED_DISTRIBUTIONS[*]} " =~ " ${myCURRENT_DISTRIBUTION} " ]]; then
  echo "### Only the following distributions are supported: ${mySUPPORTED_DISTRIBUTIONS[*]}"
  exit 1
fi

# Begin installer
echo "$myINSTALLER"
echo "### This script will now install T-Pot and all of its dependencies."

myQST=""
while [[ "$myQST" != "y" && "$myQST" != "n" ]]; do
  read -p "### Install? (y/n) " myQST
done
if [ "$myQST" = "n" ]; then
  echo "### Aborting!"
  exit 0
fi

# Install packages
case "$myCURRENT_DISTRIBUTION" in
  "Fedora Linux")
    echo "$myINSTALL_NOTIFICATION"
    sudo dnf -y --refresh install $myPACKAGES_FEDORA
    ;;
  "Debian GNU/Linux"|"Raspbian GNU/Linux"|"Ubuntu")
    echo "$myINSTALL_NOTIFICATION"
    if ! command -v sudo >/dev/null; then
      echo "### ‘sudo‘ not installed. Trying to install ..."
      su -c "apt -y update && NEEDRESTART_SUSPEND=1 apt -y install sudo $myPACKAGES_DEBIAN && /usr/sbin/usermod -aG sudo $myUSER && echo '$myUSER ALL=(ALL:ALL) ALL' | tee /etc/sudoers.d/$myUSER >/dev/null && chmod 440 /etc/sudoers.d/$myUSER"
    else
      sudo apt update
      sudo NEEDRESTART_SUSPEND=1 apt install -y $myPACKAGES_DEBIAN
    fi
    ;;
  "openSUSE Tumbleweed")
    echo "$myINSTALL_NOTIFICATION"
    sudo zypper refresh
    sudo zypper install -y $myPACKAGES_OPENSUSE
    echo "export ANSIBLE_PYTHON_INTERPRETER=/bin/python3" | sudo tee /etc/profile.d/ansible.sh >/dev/null
    source /etc/profile.d/ansible.sh
    ;;
  "AlmaLinux"|"Rocky Linux")
    echo "$myINSTALL_NOTIFICATION"
    sudo dnf -y --refresh install $myPACKAGES_ROCKY
    ansible-galaxy collection install ansible.posix
    ;;
esac

# Tag for ansible
case "$myCURRENT_DISTRIBUTION" in
  "Fedora Linux"|"Debian GNU/Linux"|"Raspbian GNU/Linux"|"Rocky Linux")
    myANSIBLE_TAG=$(echo "$myCURRENT_DISTRIBUTION" | cut -d " " -f 1)
    ;;
  *)
    myANSIBLE_TAG="$myCURRENT_DISTRIBUTION"
    ;;
esac

# Get Ansible playbook
if [ ! -f installer/install/tpot.yml ] && [ ! -f tpot.yml ]; then
  echo "### Downloading Ansible playbook..."
  wget -qO tpot.yml https://raw.githubusercontent.com/telekom-security/tpotce/master/installer/install/tpot.yml
  myANSIBLE_TPOT_PLAYBOOK="tpot.yml"
else
  echo "### Using local playbook..."
  myANSIBLE_TPOT_PLAYBOOK=${myTPOT_CONF_FILE:-"tpot.yml"}
fi

# Check sudo access
if sudo -n true 2>/dev/null; then
  myANSIBLE_BECOME_OPTION="--become"
else
  myANSIBLE_BECOME_OPTION="--ask-become-pass"
fi

# Run playbook
echo "### Running Ansible playbook..."
rm -f "$HOME/install_tpot.log"
ANSIBLE_LOG_PATH="$HOME/install_tpot.log" ansible-playbook "$myANSIBLE_TPOT_PLAYBOOK" -i 127.0.0.1, -c local --tags "$myANSIBLE_TAG" $myANSIBLE_BECOME_OPTION

# Ask for web user
while true; do
  read -rp "### Enter your web user name: " myWEB_USER
  myWEB_USER=$(echo "$myWEB_USER" | tr -cd '[:alnum:]_.-')
  echo "### Your username is: $myWEB_USER"
  read -rp "### Is this correct? (y/n) " myOK
  [[ "$myOK" =~ [Yy] ]] && [ -n "$myWEB_USER" ] && break
done

# Ask for web password
mySECURE=0
while [ "$mySECURE" -eq 0 ]; do
  read -rsp "### Enter password: " myWEB_PW
  echo
  read -rsp "### Repeat password: " myWEB_PW2
  echo
  if [ "$myWEB_PW" != "$myWEB_PW2" ]; then
    echo "### Passwords do not match."
    continue
  fi
  mySECURE=$(echo "$myWEB_PW" | /usr/sbin/cracklib-check | grep -c "OK")
  if [ "$mySECURE" -eq 0 ]; then
    read -rp "### Keep insecure password? (y/n) " myOK
    [[ ! "$myOK" =~ [Yy] ]] && continue
    mySECURE=1
  fi
done

# Set htpasswd
echo "### Updating T-Pot config with user/password..."
myWEB_USER_ENC=$(htpasswd -b -n "$myWEB_USER" "$myWEB_PW")
myWEB_USER_ENC_B64=$(echo -n "$myWEB_USER_ENC" | base64 -w0)
sed -i "s|^WEB_USER=.*|WEB_USER=${myWEB_USER_ENC_B64}|" "$myTPOT_CONF_FILE"

# Pull docker images
echo "### Pulling docker images..."
sudo docker compose -f "/home/${myUSER}/tpotce/docker-compose.yml" pull

# Netstat check
echo "### Checking for port conflicts..."
sudo grc netstat -tulpen || sudo netstat -tulpen

# Done
echo "### Done. Please reboot and reconnect via SSH on tcp/64295."
