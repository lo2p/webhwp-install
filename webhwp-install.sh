#!/bin/bash
#======================================================================
# Author: Min Ho (https://github.com/lo2p/webhwp-install)
# Creation: Sat Oct 31 00:00:00 UTC 2022
# Last modified: Sat Oct 31 00:00:00 UTC 2022
# Version: 1.0
#
# Description: this script automates the setup of webhwp
# Compatibility: >= Centos 7.4 (RHEL 7.4)
#======================================================================

#====================
# VARIABLES
#====================

id="hancom"
full=$(cat /etc/system-release)
os_name=$(cat /etc/system-release | cut -d ' ' -f 1)
version=$(cat /etc/system-release | tr -dc '0-9.')
major=$(cat /etc/system-release | tr -dc '0-9.'| cut -d \. -f 1)
minor=$(cat /etc/system-release | tr -dc '0-9.'| cut -d \. -f 2)

#====================
# FUNCTIONS
#====================

# Yes or no user input function
ask_user (){
    local list="$@"
    read -p "Run: $list (n)?: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for i in $list
        do
            $i
        done
    fi
}

# Check if the script is run by root or sudo user
check_root (){
    if [[ "$EUID" -ne "0" ]]; then
        echo "- please run as root"
        exit 1
    fi
}

# Shows system version and display compatibility
check_os (){
    echo "system-release: $full"
    if [[ $os_name -eq "CentOS"  &&  $major -ge 7 &&  $minor -ge 4 ]]
    then
        #echo "compatible OS"
        echo "+ compatible os version"
    else
        #echo "Not compatible OS"
        echo "- NOT compatible os version"
        exit 1
    fi
}

# Check network connectivity
check_online (){
    if [[ -x "$(command -v nc)" ]]
    then
        nc -zw3 8.8.8.8 53  >/dev/null 2>&1
        if [[ $? -eq 0 ]]
        then
            # echo Online
            network_status=1
            echo "+ online"
        else
            # echo Offline
            network_status=0
            echo "- OFFLINE (use other sources)"
            #exit 1
        fi
    else
        echo "- Error: nc is not installed." >&2
        exit 1
    fi

}

# Check if firewalld status
check_firewall (){
    firewall-cmd --state >/dev/null 2>&1
    if [[ $? -eq "running" ]]
    then
        echo "+ firwalld is running"
    else
        echo "- firewalld is NOT running (check with administrator)"
        exit 1
    fi
}

# Create a firewalld rule to open 8080 public zone permanently
setup_firewall (){
    port_check=$(firewall-cmd --permanent --zone=public --list-all | grep 8080 | tr -dc '0-9.')
    if [[ $port_check -eq "8080" ]]
    then
        echo "+ the rule exist"
    else
        firewall-cmd --permanent --zone=public --add-port=8080/tcp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        echo "- the rule successfully added"
    fi
}

# Check hancom user
hancom_user_check (){
    if id -u "$id" >/dev/null 2>&1; then
        echo "+ $id user exists"
    else
        echo "- NO $id user exist"
        echo "- Add user first"
        exit 1
    fi
}

# Add epel repository and install packages 
install_packages (){
    yum install -y ${packages[@]}
}

# download from web and verify checksum
download_tomcat (){
    read -p "change user to hancom (n)?: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        su hancom
        curl -O https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.68/bin/apache-tomcat-9.0.68.zip
        curl -O https://downloads.apache.org/tomcat/tomcat-9/v9.0.68/bin/apache-tomcat-9.0.68.zip.sha512
        if [[ $(sha512sum apache-tomcat-9.0.68.zip | grep cat -b apache-tomcat-9.0.68.zip.sha512) ]]; then
            echo "+ checksums match"
        else
            echo "- checksums do not match"
            echo "- removing invalid file"
            rm -f apache-tomcat-9.0.68.zip apache-tomcat-9.0.68.zip.sha512
            echo "- retry again"
            exit 1
        fi          
    else
        curl -O https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.68/bin/apache-tomcat-9.0.68.zip
        curl -O https://downloads.apache.org/tomcat/tomcat-9/v9.0.68/bin/apache-tomcat-9.0.68.zip.sha512
        if [[ $(sha512sum apache-tomcat-9.0.68.zip | grep cat -b apache-tomcat-9.0.68.zip.sha512) ]]; then
            echo "+ checksums match"
        else
            echo "- checksums do not match"
            echo "- removing invalid file"
            rm -f apache-tomcat-9.0.68.zip apache-tomcat-9.0.68.zip.sha512
            echo "- retry again"
            exit 1
        fi   
    fi

}

#====================
# MAIN
#====================

# Check root
check_root

# Check os, connectivity, and firewall statuses
ask_user check_os check_online check_firewall

# Firewalld setup
ask_user setup_firewall

# Check hancom user
ask_user hancom_user_check

# Install required packages
packages="ImageMagick-c++ harfbuzz-icu cryptopp"
echo "+ installing: $packages"
ask_user install_packages

# Install JAVA or OpenJDK (>=1.8)
packages="java-1.8.0-openjdk.x86_64"
echo "+ installing: $packages"
ask_user install_packages

# Download tomcat (9.0.68) and verify checksum
url_tomcat=""
echo "+ download tomcat (9.0.68) and verify checksum"
ask_user download_tomcat

echo "DONE!"