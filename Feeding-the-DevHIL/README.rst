So, you set up a new development environment of HIL 
on a VM. Now, how do you try out commands, start hacking ?

You will need some dummy data. That is what these bunch of 
scripts do. **It lets you populate HIL with some dummy Nodes, 
projects etc so that you can have a substrate to work against.**

``haas.cfg`` provides you a sample way to set up HIL
just stick into the root directory of your HIL environment.

After that run the HIL command to initialize the database.
Currently that is 

``haas-admin db create``

then create your first admin user. 
You will need this if you wish to play with user authentication
system. 

``haas create_admin_user <username> <password>``

input the credentials into the ``client_env``
source this into your environment

``source client_env``

Now just run the script

``populateHaaS.sh``

This should give you:

9 nodes, with ipmi obm driver
3 projects with nodes allocated to them. 
and some free nodes.

You can allocate some networks too. (dummy ofcourse)

You can change the script to fit your needs. 

Happy HACKING !!
