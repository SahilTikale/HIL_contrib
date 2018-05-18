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

echo "Usage: Takes exactly 5 arguments in the following order: "
echo "    $0 [hil_project] [node] [network01] [network02] [bmi_provisioning_image]"
echo " hil_project  		: Valid HIL project name "
echo " node 			: Valid node from HIL."
echo " network01 		: Network name that hil project has access to. "
echo " network02 		: --- Same as above --- "
echo " provisioning_image 	: OS image from BMI  "  
echo " "
}

if [[ $# < 5  ]]
then
  echo "Error: Missing arguments. "
  usage
  exit 1
elif [[ $# > 5 ]]
then
  echo "Error: To many arguments. "
  usage
  exit 1
fi

node_in_array () {
for key in ${node_list[@]}
do
  if [[ $key == $node ]]
  then
    echo true
    break
  fi
done
echo false
}


input_validation () {
  echo "Validating input . . .  "
  echo " "
  proj_output=$(hil project node list $project 2>&1)
  node_test=(`hil node list all|awk -F : '{ print $2 '}`)
  node_proj_list=`echo $proj_output|awk -F : '{print $2 '}` 
  image_name=`bmi snap ls seccloud |grep spark-server|awk -F "|" '{print $2 '}|tr -d '[:space:]'`
  if [[ `echo $proj_output|awk -F : '{print $1 '}` == "Error"* ]]
  then
    echo "Error: Project does not exist. "
    usage
    exit 1
  else
    echo "Valid project name"
  fi

  node_list=("${node_test[@]}")
  if `node_in_array`
    then 
    echo "Valid node name"
  else
    echo "Invalid node name"
    usage
  exit 1
  fi
# Cannot validate network names if they are not owned by project.
# Raised an issue #1016 on HIL.
  if [[ $image_name == $image ]]
  then 
    echo "image name is valid"
  else
    echo "Error: image name is invalid."
    echo " "
    usage
    exit 1
  fi


}

input_validation
 
