Scripts here will let you create a setup of openvswitch with 2 dhcp servers
isolated using network namespaces allocated to two different vlans.

Two VMs can be attached to the ports of each vlan.
On boot each VM should be able to fetch IP address from respective DHCP servers. 

for now the documentation lives at 

https://docs.google.com/a/redhat.com/document/d/1aZsQczMT4xEClsg3Uikk3HKPYON5_DFpikPcI8h6p34/edit?usp=sharing

