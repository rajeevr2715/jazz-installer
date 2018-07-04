#!/bin/bash
DOCKERJENKINS=$1
ATTRIBUTEFILE=$2
LOGFILE=$3
if [ $DOCKERJENKINS == 1 -o $DOCKERJENKINS == true ]; then
  JENKINS_CONTAINER=/var/jenkins_home
  sed -i "s|default\['jenkins'\]\['home'\].*.$|default['jenkins']['home']='$JENKINS_CONTAINER'|g"  $ATTRIBUTEFILE
  sed -i "s|JENKINS_HOME=.*.$|JENKINS_HOME=$JENKINS_CONTAINER|g"  $LOGFILE
fi
