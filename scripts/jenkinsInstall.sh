#!/bin/bash
###################################################################
# Script Name	:  jenkinsMaster.sh                                                                                            
# Description	:  Install and configure a Jenkins master                                                                               
# Args         :  None                                                                                          
# Author       :  Cory R. Stein                                                  
###################################################################

echo "Executing [$0]..."
PROGNAME=$(basename $0)

set -e

####################################################################
# Execute updates
####################################################################
#yum update -y
####################################################################

####################################################################
# Base install
####################################################################
yum install -y wget curl git jenkins-ha-monitor
####################################################################

####################################################################
# Disable SELINUX
####################################################################
echo "Disable SELINUX..."
setsebool -P httpd_can_network_connect 1
sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config
setenforce 0
sestatus
echo "Successfully disabled SELINUX"
####################################################################

####################################################################
# Install Java
####################################################################
#echo "Installing Java..."
# https://www.digitalocean.com/community/tutorials/how-to-install-java-on-centos-and-fedora
#yum install -y java-1.8.0-openjdk
#java -version
#echo "Successfully installed Java"
####################################################################

####################################################################
# Install Jenkins
####################################################################
echo "Installing Jenkins..."
host="localhost"
port="8080"

# Skip initial setup
export JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

mkdir -p /usr/share/jenkins/ref/init.groovy.d/

# https://wiki.jenkins.io/display/JENKINS/Installing+Jenkins+on+Red+Hat+distributions
wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat-stable/jenkins.repo
rpm --import https://jenkins-ci.org/redhat/jenkins-ci.org.key
yum install -y jenkins
echo "Successfully installed Jenkins"

############################################################
# Define functions
############################################################
error_exit()
{

#	----------------------------------------------------------------
#	Function for exit due to fatal program error
#		Accepts 1 argument:
#			string containing descriptive error message
#	----------------------------------------------------------------


	echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
	exit 1
}
restart_jenkins () {
    echo "Restarting Jenkins..."
    systemctl restart jenkins
    sleep 5

    url="http://$host:$port"
    echo "Url: [$url]"
    cli_url="$url/jnlpJars/jenkins-cli.jar"
    echo "CLI Url: [$cli_url]"

    maxAttempts=15
    curAttempts=0
    sleepInterval=5
    while [ 1 -ne 2 ]
    do
      sleep $sleepInterval
      curAttempts=$((curAttempts + 1))
      if [ $curAttempts -ge $maxAttempts ]; then
          echo "Reached max attempts [$maxAttempts]"
          break
      fi

      if [ $(ps -Af | grep "jenkins.service" | awk '{print$2}' ) ]; then 
        echo "Found Jenkins process running.  PID: [$(ps -Af | grep "jenkins.service" | awk '{print$2}' )]"
        if [ $(systemctl is-active jenkins.service ) == active ] ; then
          echo "Jenkins service is active"
          code=$(curl -sL -w "%{http_code}\\n" "$cli_url" -o /dev/null)
        
          if [ $code == 200 ]; then
            echo "Jenkins is up.  Status Code: [$code]"
            break
          else 
            echo "Status Code: [$code]"
          fi 
        else 
          echo $(systemctl -q is-active jenkins.service )
          echo "Jenkins is NOT running (yet).  Sleeping [$sleepInterval] second(s)"
        fi
      else
        echo "No Jenkins process is running"
      fi
    done

    if [ $code -ne 200 ]; then
      systemctl status jenkins.service
      error_exit "$LINENO: An error has occurred restarting Jenkins."
    else 
      echo "Successfully restarted Jenkins"
    fi
}

############################################################

echo "Configuring Jenkins..."
# Allow http and https ports through firewall
if [ $(systemctl -q is-active firewalld )  ]; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --new-service=jenkins
    firewall-cmd --permanent --service=jenkins --set-short="Jenkins Service Ports"
    firewall-cmd --permanent --service=jenkins --set-description="Jenkins service firewalld port exceptions"
    firewall-cmd --permanent --service=jenkins --add-port=8080/tcp
    firewall-cmd --permanent --add-service=jenkins
    firewall-cmd --zone=public --add-service=http --permanent
    firewall-cmd --reload

    # Disable firewall
    systemctl disable firewalld.service
    systemctl stop firewalld.service
    echo "Completed configuring firewall"
fi

echo "Creating groovy config files..."
mkdir -p /var/lib/jenkins/init.groovy.d
cat > /var/lib/jenkins/init.groovy.d/basic-security.groovy << EOL
#!groovy

import jenkins.model.*
import hudson.security.*
import static jenkins.model.Jenkins.instance as jenkins
import jenkins.install.InstallState

def instance = Jenkins.getInstance()

println "--> creating local user 'admin'"

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount('admin','admin')
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
instance.setAuthorizationStrategy(strategy)

if (!jenkins.installState.isSetupComplete()) {
  println '--> Neutering SetupWizard'
  InstallState.INITIAL_SETUP_COMPLETED.initializeState()
}

instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)

instance.save()
EOL

cat > /var/lib/jenkins/init.groovy.d/default-user.groovy << EOL
import jenkins.model.*
import hudson.security.*

def env = System.getenv()

def jenkins = Jenkins.getInstance()
jenkins.setSecurityRealm(new HudsonPrivateSecurityRealm(false))
jenkins.setAuthorizationStrategy(new GlobalMatrixAuthorizationStrategy())

def user = jenkins.getSecurityRealm().createAccount('admin', 'admin')
user.save()

jenkins.getAuthorizationStrategy().add(Jenkins.ADMINISTER, 'admin')
jenkins.save()
EOL

cat > /var/lib/jenkins/init.groovy.d/executors.groovy << EOL
import jenkins.model.*
Jenkins.instance.setNumExecutors(0)
EOL
echo "Completed creating groovy config files"

# Restart Jenkins after config file are added
restart_jenkins

# Restart Jenkins after creating groovy bypass files
systemctl status jenkins

echo "Successfully configured Jenkins"
#######################################

#######################################
# Download CLI
#######################################
echo "Downloading Jenkins CLI..."
wget "http://$host:$port/jnlpJars/jenkins-cli.jar" -q -O /tmp/jenkins-cli.jar
echo "Successfully downloaded Jenkins CLI"
#######################################

#######################################
# Display settings
#######################################
echo "Enabling Jenkins CLI..."
sed -i 's/false/true/g' /var/lib/jenkins/jenkins.CLI.xml /var/lib/jenkins/jenkins.CLI.xml
restart_jenkins
echo "Completed enabled Jenkins CLI"
#######################################

#######################################
# Install plugins
#######################################
echo "Installing Jenkins plugins..."

pushd /tmp
java -jar jenkins-cli.jar -s http://$host:$port/ -auth admin:admin install-plugin git
java -jar jenkins-cli.jar -s http://$host:$port/ -auth admin:admin install-plugin github
java -jar jenkins-cli.jar -s http://$host:$port/ -auth admin:admin install-plugin blueocean
java -jar jenkins-cli.jar -s http://$host:$port/ -auth admin:admin install-plugin terraform
java -jar jenkins-cli.jar -s http://$host:$port/ -auth admin:admin install-plugin ssh-agent
java -jar jenkins-cli.jar -s http://$host:$port/ -auth admin:admin install-plugin mailer
java -jar jenkins-cli.jar -s http://$host:$port/ -auth admin:admin install-plugin greenballs
java -jar jenkins-cli.jar -s http://$host:$port/ -auth admin:admin install-plugin oic-auth
java -jar jenkins-cli.jar -s http://$host:$port/ -auth admin:admin install-plugin credentials
popd

echo "Successfully instaled Jenkins plugins"
#######################################

# Change Jenkins port
#echo "Changing Jenkins port from 8080 to 80..."
#sed -i 's/JENKINS_PORT="8080"/JENKINS_PORT="80"/g' /etc/sysconfig/jenkins
#echo "Successfully updated Jenkins port"

# Change Jenkins HOME
# http://blog.code4hire.com/2011/09/changing-the-jenkins-home-directory-on-ubuntu-take-2/
echo "Configure Jenkins HOME..."

if [ -d /media/data1 ]; then
  echo "Configuring Jenkins on secondary disk..."
  echo "Creating [/media/data1/home/jenkins]..."
  mkdir -p /media/data1/home/jenkins
  echo "Set permissions for [jenkins:jenkins] on [/media/data1/home/jenkins]..."
  chown -R jenkins:jenkins /media/data1/home/jenkins
  echo "Completed configuring Jenkins on secondary disk"  

  echo "Stopping Jenkins..."
  systemctl stop jenkins.service
  echo "Completed stopping Jenkins"
  echo "Moving [/var/lib/jenkins] to [/media/data1/home/jenkins]..."
  mv /var/lib/jenkins /media/data1/home
  echo "Successfully moved files"
  echo "Creating symbolic link..."
  ln -s /media/data1/home/jenkins /var/lib/jenkins
  echo "Completed creating symbolic link"

fi

echo "Completed configuring Jenkins HOME"

# Clean up
rm -f /var/lib/jenkins/init.groovy.d/basic-security.groovy
rm -f /var/lib/jenkins/init.groovy.d/default-user.groovy


# Restart the jenkins service
restart_jenkins


echo "Installation of Jenkins completed successfully"
####################################################################


####################################################################
# Install Azure CLI (Used for backups)
####################################################################
echo "Installing Azure CLI..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
yum install -y azure-cli
echo "Successfully installed Azure CLI"
####################################################################


####################################################################
# Install SMB Client (Needed for HA)
####################################################################
echo "Installing SMB client..."
# https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-use-files-linux
yum install -y cifs-utils
mkdir /mnt/SharedJenkinsHome
# mount -t cifs //<storage-account-name>.file.core.windows.net/<share-name> <mount-point> -o vers=<smb-version>,username=<storage-account-name>,password=<storage-account-key>,dir_mode=0777,file_mode=0777,serverino
#bash -c 'echo "//<storage-account-name>.file.core.windows.net/<share-name> <mount-point> cifs nofail,vers=<smb-version>,username=<storage-account-name>,password=<storage-account-key>,dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab'
echo "Installation of SMB client completed successfully"
####################################################################

echo "Executing [$0] complete"
exit 0