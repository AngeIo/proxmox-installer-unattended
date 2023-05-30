#!/bin/bash

### CHECKER LES TODOS / TODO:

# This script will run all the commands to enroll a physical machine (baremetal), deploy an OS on it (Debian 11), and install Proxmox VE

# The script should also be run by the same user who installed Bifrost

### INIT & CHECK ###

# Define a function to execute when the SIGINT signal is received
function cleanup {
    echo ""
    echo "Exiting..."
    exit 1
}

# Set up the trap to catch the SIGINT signal and execute the cleanup function
trap cleanup SIGINT

# Check that command nc is installed
command -v nc
if [ $? -eq 1 ]; then
    echo "Exiting due to 'nc' command not installed (install with 'apt install netcat')"
    exit 1
fi

# Your script commands go here
echo "Running script..."
echo ""
echo "/!\ You could see errors, it's normal, for example if node does not already exists or if symbolic link couldn't create because file exists, etc. /!\\"
echo ""


### FUNCTION ###

# Fonction myChoice :
#     Cette fonction sert à générer un prompt pour répondre à une question, les réponses possibles sont 1 2 3 4 etc.
#     Utilisation de la fonction :
#     myChoice("QUESTION", "RÉPONSE 1", "RÉPONSE 2", "RÉPONSE 3", "RÉPONSE 4", "etc.")
#     et Affiche la sortie suivante :
#     QUESTION :
#     [1] RÉPONSE 1
#     [2] RÉPONSE 2
#     [3] RÉPONSE 3
#     [4] RÉPONSE 4
#     Entrez un numéro correspondant à la liste ci-dessus: [NUMÉRO LISTE]
myChoice() {
    startLst=1
    endLst=$(($# - 1))
    if [ $endLst -lt 1 ]; then
        echo 'At least 2 arguments are needed using the following format : mychoice "QUESTION" "ANSWER 1" "ANSWER 2" etc.' >&2
        return -1
    fi
    lines="$1 :\n----\n"
    i=1
    while [ $i -lt $(($endLst + 1)) ]; do
        if [ "${!i:0:1}" = "/" ]; then
            j=$(($i + 1))
            lines+="[/] ${!j:1}\n"
        else
            j=$(($i + 1))
            lines+="[$i] ${!j}\n"
        fi
        i=$(($i + 1))
    done
    invalidchoice=1
    while [ $invalidchoice -eq 1 ]; do
        invalidchoice=0
        echo -e "$lines" > /dev/tty
        read -p "Enter a number from the list above and press \"Enter\": " choicenumber
        if [[ $choicenumber =~ ^[0-9]+$ ]]; then
            choicenumber=$((choicenumber))
        else
            choicenumber=0
        fi
        if [ $choicenumber -eq 0 ] || [ $choicenumber -lt $startLst ] || [ $choicenumber -gt $endLst ]; then
            echo -e "\n----\n" > /dev/tty
            echo -e "/!\ Invalid choice, please try again /!\ \n\n" > /dev/tty
            invalidchoice=1
        fi
        if [ $invalidchoice -eq 0 ]; then
            if [ "${!choicenumber:0:1}" = "/" ]; then
                echo -e "\n----\n" > /dev/tty
                echo -e "/!\ Forbidden choice, please try again /!\ \n\n" > /dev/tty
                invalidchoice=1
            fi
        fi
    done
    echo $choicenumber
}


### RUNNING ###

# Go to script's directory and load the variables from this file
cd "${0%/*}" && source variables.sh && cd -

#TODO:
# Load the venv and custom environment variables
source /opt/stack/bifrost/bin/activate
. ~/openrc

clear

choice=$(myChoice "What part of this script do you want to run?" "Everything (enroll node, deploy OS, install Proxmox)" "Installation of Bifrost on localhost" "Enrollment (register node in Bifrost and start IPA)" "Deployment (deploy Debian to node)" "Installation of Proxmox on Debian")

read -s -p "[sudo] password for $(whoami): " unattended_ez

clear

if [[ $choice -eq 1 || $choice -eq 2 ]]; then
    read -p "Is PXE the default boot device on your server? If that's the case, type yes to continue? (yes/no) " response_one
    if [ "$response_one" == "yes" ]; then
        echo "Continuing..."
    else
        echo "Aborting."
        exit 1
    fi
    clear
fi

echo "You can now sit back, relax, and wait approximately 40 minutes (if you chose 'Everything') for the script to finish the installation!"
echo "Starting in 10 seconds..."
read -t 10 -p "Hit ENTER to skip"

clear

case $choice in
  1) # Everything (install Bifrost, enroll node, deploy OS, install Proxmox)
    echo "Everything"
    ;;&

  2 | 1) # Installation of Bifrost on localhost
    echo "Bifrost"
    # Get the bifrost repo from OpenStack
    mkdir -p $SH_PROX_BIFROST_PATH
    git clone https://opendev.org/openstack/bifrost.git $SH_PROX_BIFROST_PATH 2>/dev/null
    # Run the first playbook to install OpenStack Bifrost on top of localhost's Debian & create the "baremetal.json" file
    #ansible-playbook -D -i $SH_PROX_BIFROST_PATH/playbooks/inventory/bifrost_inventory.py --extra-vars "ansible_become_pass=$unattended_ez" $SH_PROX_PROXMOXINSTALL_PATH/pb_bifrost.yml
    # BIFROST INIT PLAYBOOK
    ansible-playbook -D -i $SH_PROX_BIFROST_PATH/playbooks/inventory/target --extra-vars "ansible_become_pass=$unattended_ez" $SH_PROX_PROXMOXINSTALL_PATH/pb_bifrost_init.yml
    # # Fix error "AttributeError: module 'distutils' has no attribute 'version'"
    # pip install setuptools==59.5.0
    # Install Ansible using Bifrost provided scripts
    bash ./scripts/env-setup.sh
    #TODO: Ceci est initialisé avant, mais pas de fichier existant avant, donc conflit, corriger ça
    # source /opt/stack/bifrost/bin/activate && cd playbooks && ansible-playbook -i inventory/target --extra-vars "ansible_become_pass=$unattended_ez" install.yaml
    # source /opt/stack/bifrost/bin/source /opt/stack/bifrost/bin/activate
    source /opt/stack/bifrost/bin/activate
    # BIFROST PROVIDED INSTALL PLAYBOOK
    ansible-playbook -i $SH_PROX_BIFROST_PATH/playbooks/inventory/target --extra-vars "ansible_become_pass=$unattended_ez" $SH_PROX_BIFROST_PATH/playbooks/install.yaml
    # BIFROST POST-INSTALL PLAYBOOK
    ansible-playbook -i $SH_PROX_BIFROST_PATH/playbooks/inventory/target --extra-vars "ansible_become_pass=$unattended_ez" $SH_PROX_PROXMOXINSTALL_PATH/pb_bifrost_postinstall.yml
    # Check if the command executed successfully
    if [ $? -eq 0 ]; then
        echo "The server is now ready to work with baremetal machines using OpenStack Bifrost!"
    else
        echo "There was an error while installing Bifrost"
    fi
    ;;&

  3 | 1) # Enrollment (register node in Bifrost and start IPA)
    echo "Initialisation & Enrollment"
    # Get the proxmox-installer-unattended repo
    mkdir -p $SH_PROX_PROXMOXINSTALL_PATH
    git clone https://github.com/AngeIo/proxmox-installer-unattended.git $SH_PROX_PROXMOXINSTALL_PATH
    # Delete the existing nodes to start from a clean base
    baremetal node list
    baremetal node maintenance set $SH_PROX_HOSTNAME
    baremetal node del $SH_PROX_HOSTNAME
    # A retirer car l'installation sera bientôt faite par le script également
    # ln -s $SH_PROX_PROXMOXINSTALL_PATH/customized/baremetal-install-env.json $SH_PROX_BIFROST_PATH/
    ln -s $SH_PROX_PROXMOXINSTALL_PATH/customized/baremetal.json $SH_PROX_BIFROST_PATH/playbooks/inventory/
    # ENROLL
    ansible-playbook -i $SH_PROX_BIFROST_PATH/playbooks/inventory/bifrost_inventory.py --extra-vars "ansible_become_pass=$unattended_ez" $SH_PROX_BIFROST_PATH/playbooks/enroll-dynamic.yaml
    # Check if the command executed successfully
    if [ $? -eq 0 ]; then
        echo "The server is now ready for deployments! (IPA loaded to ramdisk). If you need Proxmox, relaunch the script and type 3 to install Debian, and when it's finished, relaunch again and type 4 to do the installation of Proxmox on your Debian"
    else
        echo "There was an error while enrolling the node"
    fi
    ;;&

  4 | 1) # Deployment (deploy Debian to node)
    echo "Deployment"
    # DEPLOY
    ansible-playbook -i $SH_PROX_BIFROST_PATH/playbooks/inventory/bifrost_inventory.py -e @$SH_PROX_BIFROST_PATH/baremetal-install-env.json --extra-vars "ansible_become_pass=$unattended_ez" $SH_PROX_BIFROST_PATH/playbooks/deploy-dynamic.yaml
    # Wait for the server to ping before continue
    count_one=0
    echo "Waiting for server to be up again (~10 min timeout)..."
    while [ "$count_one" -ne 900 ] && ! timeout 1 ping -c 1 -n $SH_PROX_PROXIPADDRESS &> /dev/null
    do
        printf "%c" "."
        count_one=$((count_one+1))
    done
    if [ "$count_one" -eq 900 ]; then
        echo "The server is still offline after ~10 minutes. Exiting..."
        exit 1
    fi
    printf "\n%s\n" "The server is back online"
    count_two=0
    echo "Waiting for SSH to be up and ready (~5 min timeout)..."
    while [ "$count_two" -ne 400 ] && ! timeout 1 nc -z -w 1 $SH_PROX_PROXIPADDRESS 22 &> /dev/null
    do
        printf "%c" "."
        count_two=$((count_two+1))
        sleep 1
    done
    if [ "$count_two" -eq 400 ]; then
        echo "SSH is still offline after ~5 minutes. Exiting..."
        exit 1
    fi
    printf "\n%s\n" "SSH is working"
    # Delete extra key in 'known_hosts' just in case
    ssh-keygen -f "$SH_PROX_SSH_PATH/known_hosts" -R "$SH_PROX_PROXIPADDRESS"
    # Add the Proxmox host IP key to our "known_hosts" file so "Are you sure you want to continue connecting (yes/no)?" is no longer asked
    ssh-keyscan $SH_PROX_PROXIPADDRESS >> $SH_PROX_SSH_PATH/known_hosts
    # Check if the command executed successfully
    if [ $? -eq 0 ]; then
        echo "The server is now up and running with Debian installed! If you need Proxmox, relaunch the script and type 4 to do the installation on your Debian"
    else
        echo "There was an error while deploying the node"
    fi
    ;;&

  5 | 1) # Proxmox installation on Debian
    echo "Proxmox"
    # Run the last playbook to install Proxmox VE on top of Debian
    ansible-playbook -D -i $SH_PROX_BIFROST_PATH/playbooks/inventory/bifrost_inventory.py --extra-vars "ansible_become_pass=$unattended_ez" $SH_PROX_PROXMOXINSTALL_PATH/pb_proxmox.yml
    # Check if the command executed successfully
    if [ $? -eq 0 ]; then
        echo "The server is now up and running with Proxmox installed!"
    else
        echo "There was an error while installing Proxmox"
    fi
    ;;
esac

# Exit normally
exit 0
