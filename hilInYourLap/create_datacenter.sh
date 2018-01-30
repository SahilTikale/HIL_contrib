#!/usr/bin/bash
# Following script takes as a digit between 1 to 99
# creates as many network namespaces.

create_switch() {
  switch_name=$1
  ovs-vsctl add-br $switch_name
  ip link set dev $switch_name up
  ovs-vsctl show

}

create_nodes() {
  no_of_nodes=$1 # any number between 1 to 99
  switch_name=$2 # name of the created in openvswitch.
  echo "creating nodes from node-0 to node-$no_of_nodes"
  sleep 2
  for ((i=0; i<=no_of_nodes; i++));
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
  echo "Connecting nodes from node-<0-$no_of_nodes> to $switch_name." 
  sleep 2
  for ((i=0; i<=no_of_nodes; i++));
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
  ip -all netns del
}

 


test_loop() {
	total=$1
	for ((i=01; i<=total; i++));
	do
	echo $i
	done
}


case "$1" in 
  -switch)
    create_switch $2
    ;;
  -nodes)
    create_nodes $2 $3 
    ;;
  -connect_node2switch)
     connect_node2switch $2 $3
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
    echo $" sudo privileges required for this script. " 
    echo $"Usage: $0 "
    echo $"  	-switch <switch_name> "
    echo $"		# Creates an openvswitch by that name"
    echo $"  	-nodes <no_of_nodes> <switch_name> "
    echo $"			# Creates nodes (netns) "
    echo $"  	-connect_node2switch <no_of_nodes> <switch_name> "
    echo $"			# Connects nodes to <switch_name>"
    echo $"   Running them in this order. "
    echo $" "
    echo $"   OR do the full setup as follows: "
    echo $" "
    echo $"$0 -fullsetup <no_of_nodes> <switch_name>"
    echo $"		# will setup a mock infrastructure with a mock switch"
    echo $"  and netns as nodes connect via veth pair of cables. "
    echo $"  By default the nodes are offline. They need to be activated when needed. "
    echo ""
    echo ""
    echo "Cleaning up the Setup: $0 -cleanup <switch_name>"
    echo ""
    exit 1
    ;;
esac

