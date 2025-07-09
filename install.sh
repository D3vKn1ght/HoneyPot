#!/usr/bin/env bash

set -e  # Exit on error

myINSTALL_NOTIFICATION="### Now installing required packages ..."
myUSER=$(whoami)
myTPOT_CONF_FILE="/home/${myUSER}/HoneyPot/.env"
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

if [[ $EUID -eq 0 ]]; then
  echo "This script should not be run as root. Please run it as a regular user."
  exit 1
fi

mySUPPORTED_DISTRIBUTIONS=("AlmaLinux" "Debian GNU/Linux" "Fedora Linux" "openSUSE Tumbleweed" "Raspbian GNU/Linux" "Rocky Linux" "Ubuntu")
myCURRENT_DISTRIBUTION=$(awk -F= '/^NAME=/{print $2}' /etc/os-release | tr -d '"')

if [[ ! " ${mySUPPORTED_DISTRIBUTIONS[@]} " =~ " ${myCURRENT_DISTRIBUTION} " ]]; then
  echo "### Unsupported distribution: ${myCURRENT_DISTRIBUTION}"
  exit 1
fi

# Installer Banner
echo "$myINSTALLER"
echo "\n### This script will now install T-Pot and its dependencies."
read -rp "### Install? (y/n) " myQST

if [[ $myQST != "y" ]]; then
  echo "### Aborting!"
  exit 0
fi

# Package Installation
case $myCURRENT_DISTRIBUTION in
  "Fedora Linux")
    sudo dnf -y --refresh install $myPACKAGES_FEDORA
    ;;
  "Debian GNU/Linux"|"Raspbian GNU/Linux"|"Ubuntu")
    if ! command -v sudo >/dev/null; then
      echo "### 'sudo' is not installed. Installing with root access..."
      su -c "apt -y update && apt -y install sudo $myPACKAGES_DEBIAN && usermod -aG sudo $myUSER"
    else
      sudo apt update && sudo NEEDRESTART_SUSPEND=1 apt install -y $myPACKAGES_DEBIAN
    fi
    ;;
  "openSUSE Tumbleweed")
    sudo zypper refresh && sudo zypper install -y $myPACKAGES_OPENSUSE
    echo "export ANSIBLE_PYTHON_INTERPRETER=/bin/python3" | sudo tee /etc/profile.d/ansible.sh
    source /etc/profile.d/ansible.sh
    ;;
  "AlmaLinux"|"Rocky Linux")
    sudo dnf -y --refresh install $myPACKAGES_ROCKY
    ansible-galaxy collection install ansible.posix
    ;;
esac

# Ansible tags
declare -A DIST_TAG_MAP=( ["Fedora Linux"]="Fedora" ["Debian GNU/Linux"]="Debian" ["Raspbian GNU/Linux"]="Raspbian" ["Rocky Linux"]="Rocky" )
myANSIBLE_TAG=${DIST_TAG_MAP[$myCURRENT_DISTRIBUTION]:-$myCURRENT_DISTRIBUTION}

# Download playbook if needed
if [[ ! -f installer/install/tpot.yml && ! -f tpot.yml ]]; then
  echo "### Downloading T-Pot Ansible Playbook..."
  wget -qO tpot.yml https://raw.githubusercontent.com/telekom-security/tpotce/master/installer/install/tpot.yml
  myANSIBLE_TPOT_PLAYBOOK="tpot.yml"
else
  myANSIBLE_TPOT_PLAYBOOK=$( [[ -f installer/install/tpot.yml ]] && echo "installer/install/tpot.yml" || echo "tpot.yml" )
fi

# Sudo check
if sudo -n true 2>/dev/null; then
  myANSIBLE_BECOME_OPTION="--become"
else
  myANSIBLE_BECOME_OPTION="--ask-become-pass"
fi

# Run Ansible Playbook
echo "### Running T-Pot Ansible Playbook..."
rm -f "$HOME/install_tpot.log"
ANSIBLE_LOG_PATH="$HOME/install_tpot.log" ansible-playbook "$myANSIBLE_TPOT_PLAYBOOK" -i 127.0.0.1, -c local --tags "$myANSIBLE_TAG" $myANSIBLE_BECOME_OPTION

# Check result
if [[ $? -ne 0 ]]; then
  echo "### Playbook failed. See install_tpot.log for details."
  exit 1
else
  echo "### Playbook completed successfully."
fi

# Web user setup
read -rp "### Enter your web user name: " myWEB_USER
myWEB_USER=$(echo "$myWEB_USER" | tr -cd '[:alnum:]_.-')
read -rsp "### Enter password for your web user: " myWEB_PW; echo
read -rsp "### Repeat password: " myWEB_PW2; echo

if [[ "$myWEB_PW" != "$myWEB_PW2" ]]; then
  echo "### Passwords do not match. Aborting."
  exit 1
fi

mySECURE=$(printf "%s" "$myWEB_PW" | /usr/sbin/cracklib-check | grep -c OK)
if [[ "$mySECURE" == "0" ]]; then
  read -rp "### Insecure password. Keep it anyway? (y/n) " myOK
  [[ "$myOK" != "y" ]] && exit 1
fi

myWEB_USER_ENC=$(htpasswd -b -n "$myWEB_USER" "$myWEB_PW")
myWEB_USER_ENC_B64=$(echo -n "$myWEB_USER_ENC" | base64 -w0)
sed -i "s|^WEB_USER=.*|WEB_USER=$myWEB_USER_ENC_B64|" "$myTPOT_CONF_FILE"

# Docker pull
echo "### Pulling Docker images..."
sudo docker compose -f "/home/${myUSER}/HoneyPot/docker-compose.yml" pull

# Netstat for ports
sudo grc netstat -tulpen || sudo netstat -tulpen

echo -e "\n### Done. Please reboot and reconnect via SSH on port 64295."