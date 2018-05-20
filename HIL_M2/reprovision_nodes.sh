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
nic01="em1"
nic02="em2"

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
echo " NOTE: nic values are hard coded to 'em1' and 'em2' "
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


echo "Validating input . . .  "

#Required for Input validation
  proj_output=$(hil project node list $project 2>&1)
  node_test=(`hil node list all|awk -F : '{ print $2 '}`)
  node_proj_list=`echo $proj_output|awk -F : '{print $2 '}` 
  image_name=`bmi snap ls seccloud |grep $image|awk -F "|" '{print $2 '}|tr -d '[:space:]'`
  image_name=`bmi snap ls seccloud |awk -F "|" '{print $2 '}|grep $image|tr -d '[:space:]'`

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
#  echo "Validating input . . .  "
  echo " "
#  proj_output=$(hil project node list $project 2>&1)
#  node_test=(`hil node list all|awk -F : '{ print $2 '}`)
#  node_proj_list=`echo $proj_output|awk -F : '{print $2 '}` 
#  image_name=`bmi snap ls seccloud |grep $image|awk -F "|" '{print $2 '}|tr -d '[:space:]'`
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
  if [[ "$image_name" == "$image" ]]
  then 
    echo "image name is valid."  
  else
    echo "Error: image name is invalid."
    echo " "
    usage
    exit 1
  fi


}

hil_operations() {
  node_list=("${node_proj_list[@]}")
  if `node_in_array`
  then
    echo "Step 1: Node already allocated to project. No changes to do."
  else
     hil project node add $project $node 2>&1
     if [[ $? == 0 ]]
     then
	echo "Step 1:Successfully added $node to $project. "
     else
	echo "Step 1: Failed to add $node to $project. Aborting script."
	exit 1
     fi
  fi

  nics=`hil node show $node|grep nics`
  nic=$nic01
  for i in $net01 $net02
  do
    output=`hil node show $node|grep $i`
    if [[ $? == 0 ]] 
    then
      echo "Step 2: $node is already connected to $i. No changes to do. "
    else
      connect_node=`hil node network connect $node $nic $i vlan/native`
      if [[ $? == 0 ]]
      then
	echo "Step 2: Connected $node to network $i."
      else
	echo "HIL operation Error: Could not connect $node to  $i. "
	exit 1      
      fi
    fi
    nic=$nic02
  done

}

bmi_operations() {

  connect_node.sh $project $node

  get_node=`bmi showpro seccloud|grep "$node "|awk -F "|" '{ print $2 '}|tr -d '[:space:]'`
  get_image=`bmi showpro seccloud|grep "$node "|awk -F "|" '{ print $3 '}|tr -d '[:space:]'`

  if [[ $image == $get_image ]]
  then
    echo "Step 3: $node already provisioned with $image. No changes required."
  else
    dpro=`bmi dpro $project $node $net01 $nic01`
    pro=`bmi pro $project $node $image $nic01`
    if [[ $? == 0 ]]
    then 
      echo "Step 3: $node provisioned with $image successfully. "
    else
      echo "BMI operation Error: Provisioning $node with $image failed. "
      exit 1
    fi
  fi

}


input_validation
hil_operations 
bmi_operations

echo " "
echo " ** -- RESULT OUPTUT -- **"
echo " "
hil node show $node
echo " "
echo " "
bmi showpro $project |grep "$node "
echo " "
echo "** -- FINISH -- **"
echo " "
