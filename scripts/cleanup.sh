#!/bin/bash
###################################################################
#Script Name	:  cleanup.sh                                                                                            
#Description	:  Clean up files and folders                                                                              
#Args           :  None                                                                                          
#Author         :  Cory R. Stein                                                  
###################################################################

echo "Executing [$0]..."
PROGNAME=$(basename $0)

set -e

# Remove files and folders from /tmp
rm -rf /tmp/*

# Clean cache
yum clean all

# Clean out all of the caching dirs
rm -rf /var/cache/* /usr/share/doc/*


echo "Executing [$0] complete"
exit 0
