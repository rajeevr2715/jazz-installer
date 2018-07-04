#Spin wheel for visual effects
spin_wheel()
{
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'

    pid=$1 # Process Id of the previous running command
    message=$2
    spin='-\|/'
    printf "\r$message...."
    i=0

    while ps -p $pid > /dev/null
    do
        #echo $pid $i
        i=$(( (i+1) %4 ))
        printf "\r${GREEN}$message....${spin:$i:1}"
        sleep .05
    done

    wait "$pid"
    exitcode=$?
    if [ $exitcode -gt 0 ]
    then
        printf "\r${RED}$message....Failed${NC}\n"
        exit
    else
        printf "\r${GREEN}$message....Completed${NC}\n"

    fi
}


cd ~/jazz-installer/installscripts
sudo docker cp cookbooks/. jenkins-server:/tmp/jazz-chef/cookbooks/
sudo docker cp chefconfig/. jenkins-server:/tmp/jazz-chef/chefconfig/
# Running chef-client to execute cookbooks
sudo docker exec -u root -i jenkins-server sudo chef-client --local-mode --config-option cookbook_path=/tmp/jazz-chef/cookbooks -j /tmp/jazz-chef/chefconfig/node-jenkinsserver-packages.json

# Once the docker image is configured, we will commit the image.
sudo docker commit -m "JazzOSS-Custom Jenkins container" jenkins-server jazzoss-jenkins-server
sudo docker restart jenkins-server
# The image jazzoss-jenkins-server is now ready to be shipped to and/or spinned in any docker hosts like ECS cluster/fargate etc.
sleep 20 &
spin_wheel $! "Initializing the Jenkins container"
