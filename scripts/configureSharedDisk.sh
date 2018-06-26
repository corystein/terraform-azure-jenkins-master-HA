#!/bin/bash
# SYNOPSIS
#	configureSharedDisk.bash [-t] -a <account> -k <key> -s <share>
#
# DESCRIPTION
#	This Script performs the following configuration changes:
#		Sets Puppet facts based on -s (stamp), -b (branch), and -c (CSP) parameters
#		Sets DNS resolver to proper DOMAIN and NameServers
#		Installs Puppet from the Puppet Master
#		Connects to Puppet Master
#
# OPTIONS
#	-a <account>				Sets the Azure Storage Account
# 								Required parameter.
#	-k <key>					Sets the Azure Storage Account Key
#								Required parameter.
#	-s <share>					Set the Azure Storage Share
# 								Required parameter.
#	-t							Run in testing mode.
#								Causes all files to be written
#								in the current directory
#
# EXAMPLES
#	configureSharedDisk.bash -a myazurestgacct -k blahblah= -s sampleshare
#
#===============================================================================
#	HISTORY
#		2018/06/22 : Cory Stein : Script creation
# 
#===============================================================================

echo "Executing [$0]..."

# Stop script on any error
set -e

#################################################################
# Check if run as root
#################################################################
#if [ ! $(id -u) -eq 0 ]; then
#    echo "ERROR: Script [$0] must be run as root, Script terminating"
#    exit 7
#fi
#################################################################


################################################################################
# BEGIN : Functions
################################################################################

usage ()
{
     echo " Usage: $0 [-t] -a <account> -k <key> -s <share>"
}

################################################################################
# END : Functions
################################################################################

################################################################################
# Define parameter options
################################################################################
while getopts ":a:k:s:t:h" OPT ; do
	case ${OPT} in
		a )
			AZ_STG_ACCOUNT=`echo "${OPTARG,,}"`
			;;
		k )
			AZ_STG_KEY=`echo "${OPTARG,,}"`
			;;
		s )
			AZ_STG_SHARE=`echo "${OPTARG,,}"`
			;;
		t)
			TESTING='TRUE'
			;;
		h)
			HELP='TRUE'
    		usage
    		exit    # unknown option
    		;;
		#*)
    	#	usage
    	#	exit    # unknown option
    	#	;;
		\? )
			echo "Invalid option: $OPTARG" 1>&2
			exit 1
			;;
		: )
			echo "Invalid option: $OPTARG requires an argument" 1>&2
			exit 1
			;;
		
	esac
done
shift $((OPTIND -1))


################################################################################
# Verify we were passed required parameters
################################################################################
if [ "${AZ_STG_ACCOUNT}" == '' ] ; then
	echo "Missing required parameter for Azure Storage Account (-a option)" 1>&2
	exit 1
fi
if [ "${AZ_STG_KEY}" == '' ] ; then
	echo "Missing required parameter for Azure Storage Account Key (-k option)" 1>&2
	exit 1
fi
if [ "${AZ_STG_SHARE}" == '' ] ; then
	echo "Missing required parameter for Azure Storage Account Share (-s option)" 1>&2
	exit 1
fi


################################################################################
# Display passed variabled when using -t switch
################################################################################
if [ "${TESTING}" == 'TRUE' ] ; then
    echo "Azure Storage Account: [${AZ_STG_ACCOUNT}]"
fi
if [ "${TESTING}" == 'TRUE' ] ; then
    echo "Azure Storage Account Key: [${AZ_STG_KEY}]"
fi
if [ "${TESTING}" == 'TRUE' ] ; then
    echo "Azure Storage Share: [${AZ_STG_SHARE}]"
fi

####################################################################
# Install packages
####################################################################
echo "Installing packages..."
yum install -y cifs-utils
echo "Completed installing packages"
####################################################################

####################################################################
# Configure Azure file share
####################################################################
# Create directory for storage account 
if [ ! -d "/etc/smbcredentials" ]; then
	echo "Creating [/etc/smbcredentials] directory..."
	mkdir -p "/etc/smbcredentials"
	echo "Completed creating [/etc/smbcredentials] directory"
else 
	echo "Directory [/etc/smbcredentials] already exists"
fi

# Create credientals file and add username and password values
if [ ! -f "/etc/smbcredentials/${AZ_STG_ACCOUNT}.cred" ]; then
    echo "Creating [${AZ_STG_ACCOUNT}.cred] file..."
	touch "/etc/smbcredentials/${AZ_STG_ACCOUNT}.cred"
    echo "username=${AZ_STG_ACCOUNT}" >> /etc/smbcredentials/${AZ_STG_ACCOUNT}.cred
    echo "password=${AZ_STG_KEY}" >> /etc/smbcredentials/${AZ_STG_ACCOUNT}.cred
	#echo "Show file contents..."
	#cat "/etc/smbcredentials/${AZ_STG_ACCOUNT}.cred"
	echo "Completed creating [${AZ_STG_ACCOUNT}.cred] file"
else 
	echo "File [/etc/smbcredentials/${AZ_STG_ACCOUNT}.cred] already exists"
fi

# Set permissions to file
echo "Changing permissions on [${AZ_STG_ACCOUNT}.cred]..."
chmod 600 "/etc/smbcredentials/${AZ_STG_ACCOUNT}.cred"
echo "Completed changing permissions"

# Create mount point folder
echo "Creating mount point for share [/mnt/cifs/jenkins_home]"
mkdir -p /mnt/cifs/jenkins_home
echo "Completed creating mount point folder"

# Create fstab entry for Azure file share
echo "Adding fstab entry"
echo "//${AZ_STG_ACCOUNT}.file.core.windows.net/${AZ_STG_SHARE} /mnt/cifs/jenkins_home cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${AZ_STG_ACCOUNT}.cred,uid=jenkins,gid=jenkins,dir_mode=0755,file_mode=0744,serverino" >> /etc/fstab
echo "Completed creating fstab entry"

echo "Mounting all fstab mount points"
mount -a
echo "Completed mounting all mount points from fstab"

echo "Running df -h"
df -h
echo "Completed running df -h"

####################################################################


####################################################################
# Move Jenkins home
####################################################################

# Stop Jenkins Service
echo "Stopping Jenkins service..."
systemctl stop jenkins.service
echo "Completed stopping Jenkins service"

# Move Jenkins home
echo "Copying [/var/lib/jenkins/] to [/mnt/cifs/jenkins_home/] ..."
cp -R /var/lib/jenkins/ /mnt/cifs/jenkins_home/
echo "Completed copying"

# Update Jenkins config JENKINS_HOME
echo "Moving [/var/lib/jenkins/] to [/var/lib/jenkins.old/]..."
mv /var/lib/jenkins/ /var/lib/jenkins.old/
echo "Creating symbolic link..."
ln -s /mnt/cifs/jenkins_home /var/lib/jenkins
echo "Completed moving files"

# Start Jenkins Service
echo "Starting Jenkins service..."
systemctl start jenkins.service
echo "Completed starting Jenkins service"

# Get Jenkins Service Status
echo "Get Jenkins service status..."
systemctl status jenkins.service
echo "Completed getting Jenkins service status"


####################################################################



echo "Executing [$0] complete"
exit 0