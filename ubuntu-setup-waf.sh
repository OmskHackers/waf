#!/bin/bash

#####################################################################################################
# ModSecurity Web Application Firewall v3 Installation and OWASP Top-10 Rule Setup script (complete)#
#####################################################################################################

c='\e[32m' # Coloured echo (Green)
r='tput sgr0' #Reset colour after echo

function checkVirt() {
	if [ "$(systemd-detect-virt)" == "openvz" ]; then
		echo "OpenVZ is not supported"
		exit 1
	fi

	if [ "$(systemd-detect-virt)" == "lxc" ]; then
		echo "LXC is not supported (yet)."
		exit 1
	fi
}


function isRoot() {
	if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
	fi
}

function checkOS() {
	source /etc/os-release
	OS="${ID}"
	if [[ ${OS} == "debian" || ${OS} == "raspbian" ]]; then
		if [[ ${VERSION_ID} -lt 10 ]]; then
			echo "Your version of Debian (${VERSION_ID}) is not supported. Please use Debian 10 Buster or later"
			exit 1
		fi
		OS=debian # overwrite if raspbian
	elif [[ ${OS} == "ubuntu" ]]; then
		RELEASE_YEAR=$(echo "${VERSION_ID}" | cut -d'.' -f1)
		if [[ ${RELEASE_YEAR} -lt 18 ]]; then
			echo "Your version of Ubuntu (${VERSION_ID}) is not supported. Please use Ubuntu 18.04 or later"
			exit 1
		fi
	elif [[ ${OS} == "fedora" ]]; then
		if [[ ${VERSION_ID} -lt 32 ]]; then
			echo "Your version of Fedora (${VERSION_ID}) is not supported. Please use Fedora 32 or later"
			exit 1
		fi
	elif [[ ${OS} == 'centos' ]] || [[ ${OS} == 'almalinux' ]] || [[ ${OS} == 'rocky' ]]; then
		if [[ ${VERSION_ID} == 7* ]]; then
			echo "Your version of CentOS (${VERSION_ID}) is not supported. Please use CentOS 8 or later"
			exit 1
		fi
	elif [[ -e /etc/oracle-release ]]; then
		source /etc/os-release
		OS=oracle
	elif [[ -e /etc/arch-release ]]; then
		OS=arch
	else
		echo "Looks like you aren't running this installer on a Debian, Ubuntu, Fedora, CentOS, AlmaLinux, Oracle or Arch Linux system"
		exit 1
	fi
}


function initialCheck() {
    isRoot
	checkVirt
	checkOS
}

function printInfo() {
	echo "///////////////WAF INSTALLING/////////////////"
    echo "//////////////////////////////////////////////"
    echo "Vulnbox info :"
    echo ""
    if [[ ${OS} == "ubuntu" ]]; then
        echo "OS - "$OS$RELEASE_YEAR
	elif [[ ${OS} == "debian"  ]]; then
		echo "OS - "$OS" "$VERSION_ID
    else
        echo "Use manual install !"
        exit 1
    fi
}

initialCheck
printInfo



#Latest stable NGINX (important)
echo -e "${c}Adding Latest Stable NGINX PPA from launchpad.net"; $r
apt-get install apt-transport-https ca-certificates curl software-properties-common -y
sudo add-apt-repository ppa:nginx/stable -y
apt-get update -y
apt-get install -y nginx
apt-get upgrade -y



echo -e "${c}Checking NGINX version"; $r
(set -x; nginx -v )
service nginx restart

#Required Dependencies Installation
echo -e "${c}Installing Prerequisites"; $r
apt-get install -y apt-utils autoconf automake build-essential git libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre++-dev libtool libxml2-dev libyajl-dev pkgconf wget zlib1g-dev


#ModSecurity Installation
echo -e "${c}Installing and setting up ModSecurity"; $r
cd
git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity
cd ModSecurity
git submodule init
git submodule update
./build.sh
./configure
make -j3
make install
cd ..
rm -rf ModSecurity
    
#ModSecurity NGINX Conector Module Installation
echo -e "${c}Downloading nginx connector for ModSecurity Module"; $r
cd
git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git
    
#Filter nginx version number only
nginxvnumber=$(nginx -v 2>&1 | grep -o '[0-9.]*')
echo -e "${c} Current version of nginx is: " $nginxvnumber; $r
wget http://nginx.org/download/nginx-"$nginxvnumber".tar.gz
tar zxvf nginx-"$nginxvnumber".tar.gz
rm -rf nginx-"$nginxvnumber".tar.gz
cd nginx-"$nginxvnumber"
./configure --with-compat --add-dynamic-module=../ModSecurity-nginx
make -j modules

#Adding ModSecurity Module
mkdir /etc/nginx/additional_modules
cp objs/ngx_http_modsecurity_module.so /etc/nginx/additional_modules
sed -i -e '5iload_module /etc/nginx/additional_modules/ngx_http_modsecurity_module.so;\' /etc/nginx/nginx.conf
(set -x; nginx -t)
service nginx restart

#Enabling ModSecurity
mkdir /etc/nginx/modsec
wget -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/ModSecurity/49495f1925a14f74f93cb0ef01172e5abc3e4c55/unicode.mapping

mkdir /etc/nginx/modsec/example
wget -P /etc/nginx/modsec/example https://raw.githubusercontent.com/OmskHackers/waf/master/example/modsecurity.conf
wget -P /etc/nginx/modsec/example https://raw.githubusercontent.com/OmskHackers/waf/master/example/main.conf
wget -P /etc/nginx/modsec/example https://raw.githubusercontent.com/OmskHackers/waf/master/example/rules.conf
wget -P /etc/nginx/modsec/example https://raw.githubusercontent.com/OmskHackers/waf/master/example/allowed-user-agents.data

curl https://omsk-hackers.org/nginx-modsec/nginx.conf > /etc/nginx/nginx.conf
curl https://omsk-hackers.org/nginx-modsec/sites-enabled/default > /etc/nginx/sites-enabled/default

nginx -t

echo ""
echo "cmd : service nginx restart"
