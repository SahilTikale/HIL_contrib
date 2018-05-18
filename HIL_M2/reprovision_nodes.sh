#!/usr/bin/bash
# This script takes as an argument $1=<project> $2=<node> $3=<network1> $4=<network2> $5=<provisioning_image>
# Adds the <node> to <project>; Connects to the <node> to <network1> and <network2>; Provisions node with <provisioning_image>
# Abort if 
#  * there is a malfunction at any stage. 
#  * Wrong arguments are passed.
#  * Insufficient arguments are passed.

project=$1
node=$2
net01=$3
net02=$4
image=$5

echo "the number of arguments is $# "

usage(){

echo "Usage: Takes exactly 5 arguments as follows: "
echo "    $0 [hil_project] [node] [network01] [network02] [bmi_provisioning_image]"
echo " hil_project  		: Valid HIL project name "
echo " node 			: Valid node from HIL."
echo " network01 		: Network name that hil project has access to. "
echo " network02 		: --- Same as above --- "
echo " provisioning_image 	: OS image from BMI  "  
echo " "
}

#usage

if [[ $# < 5  ]]
then
  echo "Error: Missing arguments. "
  usage
elif [[ $# > 5 ]]
then
  echo "Error: To many arguments. "
  usage
fi



 
