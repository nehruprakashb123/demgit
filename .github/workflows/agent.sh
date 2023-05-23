echo "#!/bin/bash

user=$(id -u)
if [ $user != 0 ]
then
   echo "Run this file as root user or sudo"
   exit 1
fi

usage()
{
cat << EOF
usage: $0 options

This script configures haproxy
##########################################
Run this script as --> sudo ./haproxy.sh clientname nodehostname ipaddress url
#########################################
EOF
}

if [ $# -lt 4 ]
then
   echo "missing arguments"
   usage
   exit 1
fi

if ! command -v haproxy >/dev/null 2>&1; then
    sudo apt-get update
    sudo add-apt-repository ppa:vbernat/haproxy-2.5 -y
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install haproxy=2.5.* -y
fi



# Define the services to be used
services=(ManageP ManageS SldSe Mobild ui pmpropasdf LoadDasdf)

function config_name() {
    if ! grep -q "#$1-configuration" /etc/haproxy/routing.map && ! grep -q "#$1-configuration" /etc/haproxy/haproxy.cfg; then
        echo -e "\n#$1-configuration" >> /etc/haproxy/routing.map
        echo -e "\n#$1-configuration" >> /etc/haproxy/haproxy.cfg
    fi
}

# Define functions to generate backend, routing, and frontend configurations
function generate_backend() {
    echo "backend be_$1_$2
    server $3 $4:80" >> /etc/haproxy/haproxy.cfg
}

function generate_routing() {
    if [ "$service" == "ui" ]; then
        echo "$1             be_$3_$2" >> /etc/haproxy/routing.map
    else
        echo "$1/$2        be_$3_$2" >> /etc/haproxy/routing.map
    fi
}

function generate_frontend() {
    echo "frontend api_gateway
    bind *:80
    redirect scheme https if !{ ssl_fc }
    use_backend %[base,map_beg("/etc/haproxy/routing.map")]" >> /etc/haproxy/haproxy.cfg
}

# Check if frontend configuration is present and generate it if not
if ! grep -q "frontend api_gateway" /etc/haproxy/haproxy.cfg; then
    generate_frontend
fi

# Check if  configuration is present and generate it if not
config_name $1

# Generate backend configurations for each service if not present
for service in "${services[@]}"; do
    if ! grep -q "backend be_$1_$service" /etc/haproxy/haproxy.cfg; then
        generate_backend "$1" "$service" "$2" "$3"
    fi
done

# Generate routing configurations for each service if not present
for service in "${services[@]}"; do
    if ! grep -q "be_$1_$service" /etc/haproxy/routing.map; then
        generate_routing "$4" "$service" "$1"
    fi
done">agent.sh