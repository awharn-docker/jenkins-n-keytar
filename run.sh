#!/bin/sh

IMAGE_NAME='jenkins-n-keytar'

CONTAINER_NAME=$IMAGE_NAME'-container'

CONTAINER=$(docker ps -a | grep $CONTAINER_NAME) 

if [ -n "$CONTAINER" ] ; then
   echo $CONTAINER
   docker stop $CONTAINER_NAME
   docker rm $CONTAINER_NAME
fi

if [ "$1" = "bash" ] ; then 
   echo "running in bash mode"
   docker run --name $CONTAINER_NAME -it -p 4873:4873 --cap-add ipc_lock --user jenkins $IMAGE_NAME bash
elif [ "$1" = "clean" ] ; then 
   echo "clean up container"
else
   echo "running in daemon mode"
   docker run --name $CONTAINER_NAME -d -p 4873:4873 --cap-add ipc_lock $IMAGE_NAME

   echo "Container IP:"
   IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER_NAME)
   echo $IP

   echo ""
   echo "Cleaning SSH Keychain:"
   ssh-keygen -f ~/.ssh/known_hosts -R $IP
fi 
