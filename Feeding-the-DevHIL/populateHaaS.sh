#!/bin/bash


createNodes() {

echo "** Registering nodes **"
for i in 1 2 3 4 5 6 7 8 9; 
do haas node_register node$i ipmi host$i user$i pass1234; 
done

echo "** Registering nics for all nodes **"

for i in 1 2 3 4 5 6 7 8 9; 
do 
  haas node_register_nic node$i eth0 aa:bb:cc:dd:ee:0$i; 
done

haas list_node all
}

createProjects() {

for i in 1 2 3
do
  haas project_create proj$i
done

haas list_projects
}

assignNode2Project() {

haas project_connect_node proj1 node1
haas project_connect_node proj2 node2
haas project_connect_node proj2 node4
haas project_connect_node proj2 node6
haas project_connect_node proj3 node3
haas project_connect_node proj3 node5

for i in 1 2 3
do 
  haas list_project_nodes proj$i
done

}


### MAIN ###

createNodes
createProjects
assignNode2Project

