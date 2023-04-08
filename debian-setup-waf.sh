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
    if [[ ${OS} == "debian" ]]; then
        echo "OS - "$OS${VERSION_ID}
    else
        echo "OS - "$OS${VERSION_ID}
        echo "Use manual install or another installer !"
        exit 1
    fi
}

initialCheck
printInfo




#Required Dependencies Installation
echo -e "${c}Installing Prerequisites"; $r
apt-get install build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev libgd-dev libxml2 libxml2-dev uuid-dev -y
apt-get install -y apt-utils autoconf automake build-essential git libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre++-dev libtool libxml2-dev libyajl-dev pkgconf wget zlib1g-dev libmodsecurity3 libmodsecurity-dev  libssl-dev
apt-get -y install automake && apt-get -y install libtool
apt-get -y install libyajl-dev libpcre++-dev libcurl4-openssl-dev libmaxminddb-dev libfuzzy-dev geoip-bin liblua5.3-dev libpcre2-dev liblmdb-dev libxml2 libxml2-dev -y


#ModSecurity Installation
echo -e "${c}Installing and setting up ModSecurity"; $r
cd
git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity
git clone https://github.com/SpiderLabs/ModSecurity-nginx.git
cd ModSecurity
git submodule init
git submodule update
./build.sh
./configure
make -j3
make install
cd ..
#rm -rf ModSecurity
    
#ModSecurity NGINX Conector Module Installation
wget https://nginx.org/download/nginx-1.22.1.tar.gz
tar -xzvf nginx-1.22.1.tar.gz
cd nginx-1.22.1/
./configure --prefix=/var/www/html --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log --with-pcre --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid --modules-path=/etc/nginx/modules --with-http_ssl_module --with-http_v2_module --with-stream=dynamic --with-http_addition_module --with-http_sub_module --with-compat --with-debug --without-http_autoindex_module --without-http_ssi_module --without-mail_smtp_module --without-mail_imap_module --without-mail_pop3_module --without-http_scgi_module --without-http_fastcgi_module --without-http_uwsgi_module --without-http_memcached_module --without-http_map_module --without-http_empty_gif_module --without-http_grpc_module --without-http_mirror_module --add-module=../ModSecurity-nginx

make -j3 && sudo make install

#Enabling ModSecurity
mkdir /etc/nginx/modsec
wget -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/ModSecurity/49495f1925a14f74f93cb0ef01172e5abc3e4c55/unicode.mapping

mkdir /etc/nginx/modsec/example
wget -P /etc/nginx/modsec/example https://raw.githubusercontent.com/OmskHackers/waf/master/example/debian-modsecurity.conf
mv /etc/nginx/modsec/example/debian-modsecurity.conf /etc/nginx/modsec/example/modsecurity.conf
wget -P /etc/nginx/modsec/example https://raw.githubusercontent.com/OmskHackers/waf/master/example/main.conf
wget -P /etc/nginx/modsec/example https://raw.githubusercontent.com/OmskHackers/waf/master/example/rules.conf
wget -P /etc/nginx/modsec/example https://raw.githubusercontent.com/OmskHackers/waf/master/example/allowed-user-agents.data

mkdir /etc/nginx/sites-enabled
curl https://raw.githubusercontent.com/OmskHackers/waf/master/debian-nginx.conf > /etc/nginx/nginx.conf
curl https://raw.githubusercontent.com/OmskHackers/waf/master/default > /etc/nginx/sites-enabled/default

nginx -t

echo ""
echo "Add to systemd : "
echo "https://serverfault.com/questions/851344/manage-self-compiled-nginx-via-systemd"

