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
vlan_id=$2
node=dhcp_$2
port=tap_$2
ip_addr=$3
ip_range=$4
# TO DO:
# Accept as an argument <dhcp_netns name>, <IP_address for dhcp_netns>, <dhcp-range>
# Set a dhcp server using the above arguments 

ip netns exec $node ip address add $ip_addr dev $port
					#Setting ip address for dhcp server.

# Start dhcp server in dhcp-100 and dhcp-200
#eg: ip netns exec dhcp_100 dnsmasq --interface=tap_100 --dhcp-range=10.1.100.10,10.1.100.50,255.255.255.0
ip netns exec $node dnsmasq --interface=$port --dhcp-range=$ip_range
echo "DHCP server running at `ip netns pids $node` for $vlan_id"
#ip netns exec node-01 dhclient eth0-01
# eg: ip netns exec node-01 ping -c 5 10.1.100.2
#ip netns exec node-01 ping -c 5 10.1.100.2
#ip netns exec node-01 ip a
}

dhcp_netns () {
	#Arguments <switch_name>, <vlan_id>
	#Creates a network namespace that acts as a DHCP server for vlan <vlan_id>

switch_name=$1
vlan_id=$2
node=dhcp_$2
port=tap_$2
ip_addr=$3
ip_range=$4
  ip netns add $node; # creates a netns named dhcp_<vlan_id>
  #Create internal ports in openvswitch for each dhcp server (dhcp-netns)
  ovs-vsctl add-port $switch_name $port -- set interface $port type=internal
  ovs-vsctl set port $port tag=$vlan_id
  # Moving the tap-<vlan> to their respective netns
  ip link set $port netns $node
  # Bringing up the interfaces in all DHCP-netns
  for j in `ip netns exec $node ip a|grep mtu|awk -F : '{ print $2 '}`
    do ip netns exec $node ip link set dev $j up
  done
  #Set up dhcp server
  sleep 1;
  dhcp_setup $switch_name $vlan_id $ip_addr $ip_range
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

	echo "Killing all processes started by all netns"
	allnetns=(`ip netns list|awk '{ print $1 '}`)
	if [ ${#allnetns[@]} > 0 ]
	then
	  for netns_name in ${allnetns[@]}; do 
	    pidlist=(`ip netns pids $netns_name`)
	      if [ ${#pidlist[@]} > 0 ] 
	      then
		{ 
		  ip netns pids $netns_name | xargs kill
		}
	      fi
	  done
	fi

	echo "Delete all nodes (netns)"
	ip -all netns del
	echo "Delete the switch"
	ovs-vsctl del-br $switch_name
	echo "Delete orphaned virtual cables."
        orph_veth=$( ip a|grep veth|awk -F : {' print $2 }' |awk -F @ '{ print $1 '}`` )
        if [ ${#orph_veth[@]} > 0 ]
        then
          for i in ${orph_veth[@]}
          do
            ip link delete $i
          done
        fi


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
			[-setDHCP <switch_name> <vlan_id> <ip_addr> <ip_range>]
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

 -setDHCP <switch_name> <vlan_id> <ip_addr> <ip_range>
 		Creates a network namespace that hosts a DHCP server
		on switch <switch_name> for vlan <vlan_id>
		<switch_name> : 'anystring'
		<vlan_id> : 100 
		<ip_addr> : ip address of the DHCP server (10.1.100.2/24)
		<ip_range>: 10.1.100.10,10.1.100.50,255.255.255.0
	
 -cleanup <switch_name> 
 		Cleans up like a YETI.
	       	As if we were never here. 	
		Leaves openvswitch installed on the system. 
		Script does not come with input validation or error checks.
		In case of any mess, just cleanup and start over.
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
		dhcp_netns $2 $3 $4 $5
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
