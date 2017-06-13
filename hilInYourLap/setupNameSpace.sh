#!/bin/bash 

x="ip netns exec"
echo "Adding network name spaces"

echo "Cleaning up from last reboot"

ovs-vsctl del-port centi7
ovs-vsctl del-port serbuntu


ip tuntap add mode tap centi7
ip tuntap add mode tap serbuntu

ovs-vsctl add-port redhat centi7 -- set port centi7 tag=100
ovs-vsctl add-port redhat serbuntu -- set port serbuntu tag=200

echo "Turning the links on in each netns"
ip link set dev redhat up
ip link set dev centi7 up
ip link set dev serbuntu up


for i in dhcp100 dhcp200
do
  ip netns add $i
done

#echo "Adding internal ports to switch ** REDHAT **"

#ovs-vsctl add-port redhat tap-100 -- set interface tap-100 type=internal
#ovs-vsctl add-port redhat tap-200 -- set interface tap-200 type=internal

#echo "Adding ports to vlans"
#ovs-vsctl set port tap-200 tag=200
#ovs-vsctl set port tap-100 tag=100

#Following interfaces are already created in ovs-vsctl and 
#they exist in root netns across reboots. 
echo "Moving tap interfaces to their respective network namespaces."
ip link set tap-100 netns dhcp100
ip link set tap-200 netns dhcp200


for i in dhcp100 dhcp200
do
  for j in `$x $i ip addr |grep mtu|awk -F : '{ print $2 '}`
  do
    $x $i ip link set dev $j up
  done
done

echo "Add ip addresses to the tap interfaces"

$x dhcp100 ip address add 10.1.100.2/24 dev tap-100
$x dhcp200 ip address add 10.2.200.2/24 dev tap-200

for i in dhcp100 dhcp200
do 
  $x $i ip addr
done


echo "Starting dhcp services in each netns"

ip netns exec dhcp100 dnsmasq --interface=tap-100 \
--dhcp-range=10.1.100.10,10.1.100.50,255.255.255.0 

ip netns exec dhcp200 dnsmasq --interface=tap-200 \
--dhcp-range=10.2.200.10,10.2.200.50,255.255.255.0 


echo "Confirming everything is setup correctly"

ovs-appctl fdb/show redhat
ovs-ofctl show redhat





# To check if dnsmasq is associated with correct netns
# ps -ef |grep dnsmasq
# ip netns identify <pid of dnsmasq>
