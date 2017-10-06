#!/bin/bash

#Installing openvswitch
install_openvswitch () {

yum install openvswitch  #It will redirect to `dnf install` on Fedora.
service openvswitch enable
service openvswitch start
service openvswitch status
ovs-vsctl show
}

setup_switch () {

ovs-vsctl br-exists redhat
if [ $? == 2 ]
  then
  ovs-vsctl del-br redhat
fi
#Creating switch named redhat
ovs-vsctl add-br redhat
ip link set dev redhat up 
}

dhcp_netns () {

for i in {100..500..100}; do 
  ip netns add dhcp-$i; # create 5 isolation network namespace for dhcp 
  #Create internal ports in openvswitch for each dhcp server (dhcp-netns)
  ovs-vsctl add-port redhat tap-$i -- set interface tap-$i type=internal
  # Moving the tap-<vlan> to their respective netns
  ip link set tap-$i netns dhcp-$i  
  # Bringing up the interfaces in all DHCP-netns
  for j in `ip netns exec dhcp-$i ip a|grep mtu|awk -F : '{ print $2 '}` 
    do ip netns exec dhcp-$i ip link set dev $j up
  done 
done
}

node_netns () {
#Creating 10 new network namespaces that will emulate node behaviour
for i in {01..10}; 
  do ip netns add node-$i; 
  # Creating veth pairs to connect different node namespces to openvswitch redhat
  ip link add eth0-$i type veth peer name veth-$i 
  #Moving the eth0-$i part of the veth pair to their respective node name spaces.
  ip link set eth0-$i netns node-$i
  # Adding other end of the veth pair to openvswitch
  ovs-vsctl add-port redhat veth-$i
  # Bring all the veth pair ports up
  for j in `ip netns exec node-$i ip a|grep mtu|awk -F : '{ print $2 '}|awk -F @ '{ print $1 '}`; 
    do  ip netns exec node-$i ip link set dev $j up
  done
  ip link set dev veth-$i up
done
}

vlan_setup () {
# Allocate veth-01 to 100 and veth-02 to 200 vlan
for i in veth-01 tap-100; do ovs-vsctl set port $i tag=100; done
for i in veth-02 tap-200; do ovs-vsctl set port $i tag=200; done
}


dhcp_setup () {

ip netns exec dhcp-100 ip address add 10.1.100.2/24 dev tap-100 #Setting ip address for dhcp server. 

# Start dhcp server in dhcp-100 and dhcp-200
ip netns exec dhcp-100 dnsmasq --interface=tap-100 --dhcp-range=10.1.100.10,10.1.100.50,255.255.255.0
ip netns exec node-01 dhclient eth0-01 
ip netns exec node-01 ping -c 5 10.1.100.2
ip netns exec node-01 ip a
}

cleanup () {
	ip -all netns delete 	#delete all netns ns (dhcp servers + nodes)
	ovs-vsctl del-br redhat #Delete the openvswitch
	#Remove any orphaned veth pairs
	orph_veth=$( ip a|grep veth|awk -F : {' print $2 }' |awk -F @ '{ print $1 '}`` )
	if [ ${#orph_veth[@]} > 0 ]
	then
	  for i in ${orph_veth[@]}
	  do 
  	    ip link delete $i
	  done
	fi
	#Kill any DHCP process started from the netns based dhcp server
	killDHCP=$( ps -ef |grep tap|grep dnsmasq|awk {' print $2 '} )
	if [ ${#killDHCP[@]} > 0 ]
	then
	  for i in ${killDHCP[@]}
	  do 
	    kill $i
	  done
	fi
	#Kill any dhclients
	killDHCLIENT=$( ps -ef |grep eth0|grep dhclient|awk {' print $2 '} )
	if [ ${#killDHCLIENT[@]} > 0 ]
	then
	  for i in ${killDHCLIENT[@]}
	    do
	     kill $i
	    done
	fi

}


case "$1" in 
	switch_install)
		install_openvswitch
		;;
	switch_setup)
		setup_switch
		;;
	dhcp_netns)
		dhcp_netns
		;;
	nodes)
		node_netns
		;;
	vlan)
		vlan_setup
		;;
	dhcp_setup)
		dhcp_setup
		;;
	all)
		setup_switch
		dhcp_netns
		node_netns
		vlan_setup
		dhcp_setup
		;;
	cleanup)
		cleanup
		;;
	*) 
		echo $"Usage:	 $0 {switch_install|switch_setup|dhcp_netns|nodes|vlan|dhcp_setup|cleanup|all}"
		echo ""
		echo "Each case depends on successful completion of the previous case."
		echo "For partial setup, use the above options sequentially in same order as presented."		       
		echo ""
		echo "Option switch_install is required only one time on a fresh VM."
		echo " "
		echo "To re-do the full setup, first run:	 $0 cleanup; $0 all"
		exit 1
esac
