Scripts here will let you create a setup of openvswitch with 2 dhcp servers
isolated using network namespaces allocated to two different vlans.

Two VMs can be attached to the ports of each vlan.
On boot each VM should be able to fetch IP address from respective DHCP servers. 

for now the documentation lives at 

https://docs.google.com/a/redhat.com/document/d/1aZsQczMT4xEClsg3Uikk3HKPYON5_DFpikPcI8h6p34/edit?usp=sharing


The setup script: `setupScript.sh` 
---------------------------------------------------

Works on a Fedora or CentOS based VM.
Installs Openvswitch.

Creates a virtual switch named 'redhat'
Creates 05 network namespace that act as DHCP servers
Creates 10 network namespance that act as nodes,
  that can be isolated using vlan tags.
Demonstrates one such network isolation for node-01
by putting it in a vlan, and setting a DHCP server
that provides automatic ip addresses for nodes in that vlan.

Read the help message to see the instructions try this. 

Setting up openvswitchi: `create_datacenter.sh`
------------------------------------------------------

Works on a Fedora or CentOS based VM.

To Install openvswitch and setup first time run:

```
sudo ./create_datacenter.sh -initialize
```

Running following command will let you create a bridge named `myswitch` with
10 network namespace as nodes connected to 10 interfaces (port) on this switch

```
sudo ./create_datacenter.sh -fullsetup 10 myswitch
``` 

For help message and other options, just run the script without any arguments.

```
./create_datacenter.sh
```

Will give all the options to run this. 

Setting passwordless SUDO for running openvswitch commands:           `sudo ovs-vsctl <commands>`
----------------------------------------------------------------------------------------

Keep one session open where you have logged in as root. **For safety.** 
Add the file named `ovs` in `/etc/sudoers.d/`
**Open the file using `visudo` only**

Add the following line to it

```
<your-username> <hostname> = (root) NOPASSWD: /usr/bin/ovs-vsctl
```

log out from the session, then re-login. If you mess up, use the spare session that was left open with root privileges for rescuing the sudoer configuration. 

You should be able to run all openvswitch commands without the system asking for sudo password.
Try:

```
sudo ovs-vsctl show
```

The above command should return results without asking for any sudo passwords. 




