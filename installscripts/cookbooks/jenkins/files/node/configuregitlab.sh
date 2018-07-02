#Script to replace configs of gitlab
configxml=/var/jenkins_home/com.dabsquared.gitlabjenkins.connection.GitLabConnectionConfig.xml

sed  -i "s/ip/$1/g" $configxml
