#!/bin/bash

# Configure Agents
usage() {
cat << EOF
usage: $0 options

This script configure Azure pipelines Agent
##########################################
Run this script as --> ./agent.sh -p <poolname> -t <Personal accesstoken> -a <agent-name>
##########################################
OPTIONS:
	-p Pool Name
	-t Personal access token
	-a Agent name
EOF
}

POOL=
TOKEN=
AGENT=

while getopts "p:t:a:" OPTION
do
	case $OPTION in
		p)
			POOL=$OPTARG
			;;
		t)
			TOKEN=$OPTARG
			;;
		a)
			AGENT=$OPTARG
			;;
		?)
			usage
			exit
			;;
	esac
done

if [[ -z $POOL ]] || [[ -z $TOKEN ]] || [[ -z $AGENT ]]
then
	usage
	exit
fi


#Install git
sudo yum update -y

# Install Git
sudo yum install -y gettext-devel openssl-devel perl-CPAN perl-devel zlib-devel wget curl tar
sudo rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum update -y
sudo yum install jq -y
sudo yum install -y git


if [[ -z $git ]] || [ -z $jq ]] || [ -z $wget ]] || [ -z $tar ]]; then
	echo "install dependencies"
	exit 1
fi



install_docker() {

# Install Docker
sudo yum-config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
docker --version

# Start and enable Docker
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl restart docker
}

#install azure cli
echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo

sudo yum install azure-cli -y

#install agent
install_agent() {

echo "
############################################
This script configure Azure pipelines Agent#
############################################
"

# Download Devops
agentMachine=/home/$USER/myagent
mkdir $agentMachine

latest=$(curl -s https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest | jq -r '.tag_name' | cut -c2-)
echo 'Downloading Latest Devops Agent'
wget -O azureDevOpsAgent-$latest.tar.gz https://vstsagentpackage.azureedge.net/agent/$latest/vsts-agent-linux-x64-$latest.tar.gz
tar -C $agentMachine -xzf azureDevOpsAgent-$latest.tar.gz

#Configure Agents
echo "Changing $agentMachine permissions"
sudo chown -R $USER:$USER $agentMachine

echo "Setting up Agent: $AGENT"
cd $agentMachine
./config.sh --unattended --agent $AGENT --pool $POOL --url https://dev.azure.com/nehruprakashb123 --auth PAT --token $TOKEN --replace --work _work --acceptTeeEula
sudo bash ./svc.sh install $USER
sudo bash ./svc.sh start

}

vsts=$(sudo systemctl --type=service --state=running | grep -i -e vsts.agent | awk '{ print $4 }')
docker=$(sudo systemctl --type=service --state=running | grep -i -e docker | awk '{ print $4 }')

if [[ -z $vsts ]]
then
	install_agent
fi

if [[ -z $docker ]]
then
	install_docker
fi

if [[ $vsts == "running" ]] && [[ $docker == "running" ]]
then
	sudo reboot
else
	exit
fi
