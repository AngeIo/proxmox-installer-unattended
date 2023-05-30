# Proxmox VE installer on Debian - Unattended

> Installs OpenStack Bifrost (standalone version of Ironic module for OpenStack) on Debian, deploys a new Debian on Baremetal (your server) and installs Proxmox VE on it to host your VMs effortlessly.
> With this project, everything is covered, from system deployment to Proxmox installation, by the end of scripts executions, your server is ready to use! You'll just have to type the IP address of your freshly installed Proxmox and there you go!

Based on the official documentations at :
- https://docs.openstack.org/bifrost/2023.1/
- https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_11_Bullseye

## Why?

I wanted to install Proxmox on multiple servers at once in an unattended way.

So I created this simple Ansible Playbook to easily _convert_ my servers without having to do the same actions over and over again.

## Features

- [x] Prepare the servers from scratch (upgrade, dist-upgrade, network configuration)
- [x] Add a bridge interface to connect to the physical network and mimic VMnet1 on VMware
- [x] Add a NAT interface to mimic VMnet8 on VMware (172.16.0.0/12)
- [x] Set a static IP to main network interface based on DHCP lease
- [x] Ansible playbooks are idempotent but not `run.sh`
- [x] Easy to use with a single command: `just`

### Limitations

- [x] No DHCP on the NAT network, so you'll have to set a static IP on each of your VM (or deploy your own DHCP server), when I have more time, I plan to add it to the playbook by using `dnsmasq`
- [x] For now, it doesn't install OpenStack Bifrost, I'll add it soon

## Pre-requisites

- Create your own `variables.sh` file by copying the template `variables.sh.example` and follow the instructions
- One server ready for Proxmox deployment (disks will be wiped, be sure to backup your data!) (tested on a DELL PowerEdge R410)
- Your SSH public key copied to the server(s) to be able to connect to it without password and allow Ansible playbook to run, example: `ssh-copy-id -i $HOME/.ssh/id_rsa.pub user@myserver`
- Python library `netaddr` (to install it, run `pip install netaddr`)
- Client machine to execute the playbook from and apply on the server(s)
- Python 3 (tested with 3.9.2)
- pip (tested with 20.3.4)
- Ansible (tested with 2.14.5)
- [Just](https://github.com/casey/just) (optional)
- Git (duh)

### Downloading the project

Clone the repository:

```shell
git clone https://github.com/AngeIo/proxmox-installer-ansible.git
cd proxmox-installer-ansible
```

To update the source code to the latest commit, run the following command inside the `proxmox-installer-ansible` directory:

```shell
git pull
```

## Usage

Here are all the steps you have to follow to make this work:

### Variables

The first thing you have to do is editing the variables to match with your environment (comments in the files shows what to edit) :

#### Changing default username to login on the server(s)
```shell
vi ansible.cfg
```

#### Changing which server(s) to target inside the inventory
```shell
vi inventory/target
```

### Running the Playbook

Running the playbook is very simple:

---
#### With `just` installed
```shell
just
```

**OR**

#### Without `just` installed
```shell
ansible-playbook -K -D pb_main.yml
```
---

The remote user password will be asked, enter it and wait for the playbook to finish.

### End result

Your newly created Proxmox server(s) should be ready to use, connect to https://myserver:8006 on your web browser to access the interface, enjoy!

## Contributing

If you want to contribute to this project, feel free to submit a pull request, I'll be happy to merge it! Everyone is welcome!

## License

*This project*'s code is licensed under [The Unlicense](https://opensource.org/license/unlicense). Please see [the license file](LICENSE) for more information. [tl;dr](https://www.tldrlegal.com/license/unlicense) you can do whatever you want with it, it's public domain.
