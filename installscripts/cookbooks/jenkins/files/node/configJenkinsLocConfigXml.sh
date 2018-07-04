#This script will add/change the jenkins.model.JenkinsLocationConfiguration.xml
#configuration in /var/lib/jenkins/

JENKINSELB=$1
ADMIN_ADDRESS=$2
JENKINS_HOME=/var/lib/jenkins
JENKINS_LOC_CONFIG_XML=$JENKINS_HOME/jenkins.model.JenkinsLocationConfiguration.xml

sed  -i "s=adminAddress.*.$=adminAddress>$ADMIN_ADDRESS</adminAddress>=g" $JENKINS_LOC_CONFIG_XML
sed  -i "s=jenkinsUrl.*.$=jenkinsUrl>http://$JENKINSELB/</jenkinsUrl>=g" $JENKINS_LOC_CONFIG_XML
