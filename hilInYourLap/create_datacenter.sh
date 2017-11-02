#!/usr/bin/bash
# Following script takes as a digit between 1 to 99
# creates as many network namespaces.

#Installing openvswitch
install_openvswitch () {

yum install openvswitch  #It will redirect to `dnf install` on Fedora.
service openvswitch enable
service openvswitch start
service openvswitch status
ovs-vsctl show
}

create_switch() {
  switch_name=$1
  ovs-vsctl add-br $switch_name
  ip link set dev $switch_name up
  ovs-vsctl show

}

dhcp_setup () {
switch_name=$1
dhcp_netns=$2
ip_addr=$3
ip_range=$4
# TO DO:
# Accept as an argument <dhcp_netns name>, <IP_address for dhcp_netns>, <dhcp-range>
# Set a dhcp server using the above arguments 

ip netns exec dhcp-100 ip address add 10.1.100.2/24 dev tap-100 #Setting ip address for dhcp server.

# Start dhcp server in dhcp-100 and dhcp-200
ip netns exec dhcp-100 dnsmasq --interface=tap-100 --dhcp-range=10.1.100.10,10.1.100.50,255.255.255.0
ip netns exec node-01 dhclient eth0-01
ip netns exec node-01 ping -c 5 10.1.100.2
ip netns exec node-01 ip a
}

dhcp_netns () {
	#Arguments <switch_name>, <vlan_id>
	#Creates a network namespace that acts as a DHCP server for vlan <vlan_id>

switch_name=$1
vlan_id=$2
#for i in {100..500..100}; do
#  ip netns add dhcp-$i; # create 5 isolation network namespace for dhcp
  ip netns add dhcp_$vlan_id; # creates a netns named dhcp_<vlan_id>
  #Create internal ports in openvswitch for each dhcp server (dhcp-netns)
  ovs-vsctl add-port $switch_name tap_$vlan_id -- set interface tap_$vlan_id type=internal
  # Moving the tap-<vlan> to their respective netns
  ip link set tap_$vlan_id netns dhcp_$vlan_id
  # Bringing up the interfaces in all DHCP-netns
  for j in `ip netns exec dhcp_$vlan_id ip a|grep mtu|awk -F : '{ print $2 '}`
    do ip netns exec dhcp_$vlan_id ip link set dev $j up
  done
#done
}


create_nodes() {
  no_of_nodes=$1 # any number between 1 to 99
  switch_name=$2 # name of the created in openvswitch.
 let  total=$no_of_nodes-1
  echo "creating nodes from node-0 to node-$total"
  sleep 2
  for ((i=0; i<no_of_nodes; i++));
    do
      ip netns add node-$i; #create Nodes (empty network namespaces)
      ip link add eth0-$i type veth peer name veth-$i # Creating a virtual cables 
    	# with eth0-xx end connected to the node and 
	#veth-xx left as it is to be connected to the switch at later point.

      ip link set eth0-$i netns node-$i 
      # Connect eth0-$i end of cable to nodes.

        # Bring all the veth pair ports up
	for j in `ip netns exec node-$i ip a|grep mtu|awk -F : '{ print $2 '}|awk -F @ '{ print $1 '}`;
	  do  ip netns exec node-$i ip link set dev $j up
	done
  ip link set dev veth-$i up
   done
   ovs-vsctl show
   ip netns list
}

connect_node2switch () {
  no_of_nodes=$1
  switch_name=$2
  let total=$no_of_nodes-1
  echo $total
  echo "Connecting nodes from node-<0-$total> to $switch_name." 
  sleep 2
  for ((i=0; i<no_of_nodes; i++));
    do ovs-vsctl add-port $switch_name veth-$i
      for j in `ip netns exec node-$i ip a|grep mtu|awk -F : '{ print $2 '}|awk -F @ '{ print $1 '}`;
        do ip netns exec node-$i ip link set dev $j up
      done
  done
ovs-vsctl show
}

fullsetup () {
  no_of_nodes=$1
  switch_name=$2
  echo "Cleaning up previous setup, if any "

  echo "Creating a datacenter having $1 nodes and a switch called $switch_name"
  sleep 2
  create_switch $switch_name
  create_nodes $no_of_nodes $switch_name
  connect_node2switch $no_of_nodes $switch_name
}

cleanup () {

  switch_name=$1
  ovs-vsctl br-exists $1
  if [[ `echo $?` == 0 ]]
  then 
    ovs-vsctl del-br $1
  fi
}

usage () {
  
  message="
  sudo privileges required for this script.
  
  ** The first time you run this script ** 
  make sure openvswitch is already installed by running.
  $0 -initialize

  USAGE: 
  $0 	[-initialize] ** Required only once per installation **
  			[-fullsetup <no_of_nodes> <switch_name>
  			[-switch <switch_name> ]
  			[-nodes <no_of_nodes> <switch_name> ]
			[-connect <no_of_nodes> <switch_name> ]
			[-setDHCP <switch_name> <vlan_id> ]
			[-cleanup]

  -initialize	Installs openvswitch. Run once before using any other options.

  -fullsetup <no_of_nodes> <switch_name>
  		Setsup openvswitch with a bridges named <switch_name>
		Creates <no_of_nodes> many network namespaces.
	        Each network namespace is named node-<0.... no_of_nodes-1>

 -switch <switch_name> 
		Partial setup, step 1: 
		creates a bridge <switch_name> in openvswitch.

 -nodes <no_of_nodes>
		Partial setup, step 2: 
		Creates <no_of_nodes> many network namspaces.
	        Each network namespace is named node-<0.... no_of_nodes-1>
	
 -connect <no_of_nodes> <switch_name>
		Partial setup, step 3: 
		Connects nodes to <switch_name> 

 -setDHCP <switch_name> <vlan_id>
 		Creates a network namespace that hosts a DHCP server
		on switch <switch_name> for vlan <vlan_id>
	
 -cleanup 
		Cleans up like a YETI.
	       	As if we were never here. 	
		Leaves openvswitch installed on the system. 
  "


  echo "$message" 


}

test_loop() {
	total=$1
	for ((i=01; i<=total; i++));
	do
	echo $i
	done
}


case "$1" in

  	-initialize)
	  	install_openvswitch
	  	;;	  
  	-switch)
    		create_switch $2
    		;;
  	-nodes)
    		create_nodes $2 $3 
    		;;
  	-connect)
     		connect_node2switch $2 $3
     		;;
	-setDHCP)
		dhcp_netns $2 $3
		;;
  	-fullsetup)
    		fullsetup $2 $3
    		;;
  	-cleanup)
    		cleanup $2
    		;;
  	loop)
    		test_loop $2 
    		;;
    	*)     
    	/usr/bin/printf "\n\n"
    	usage
    	exit 1
    	;;
esac
