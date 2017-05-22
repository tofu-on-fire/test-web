#!/bin/sh

TARGET_RESOURCE_GROUP=user0002-webapp-tmpl-rg
NUMBER_OF_WEB_SERVERS=3
WEBSV_IMAGE="/subscriptions/50838fe3-59fa-4686-affc-34a1ba8df912/resourceGroups/user0002-webapp-images-rg/providers/Microsoft.Compute/images/webapp-websv-image"
SSH_USER=webapusr
SSH_PKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvMpDeC6P0QFK6/4D1eLfwnzjxSoThxZEHYlzg0psc8Sk8VclpylKC6VKfGRsXIO2OruwWvmNw9Ver8bLVuUw2tJekIkso2eSQX7j1jwFJLZWzDmmYHyPkAuj7dhq/b4M8SjGOV3f0C1LumAGXnHsTetTSAWsvbHIDCrc6b73lxVhGU4zmwuFNb3sH4kmiuSIo1grPYOf/lzJuU4FRPr6ND6kF7A5IGH3GF+ylCwGXecYe6oICyIoXksGuzBMpwr04yA60zeNOr/mwCsl5TXIZniudF64xBUJV6yAFFWI6LO+eN9Hml50UczU3YxEa7ZVke48J5/ruD6TPkp/cM121 devops"

az configure --defaults group=${TARGET_RESOURCE_GROUP}
az network nsg create -n webapp-websv-nsg
az network nsg rule create \
    --nsg-name webapp-websv-nsg -n webapp-websv-nsg-http \
    --priority 1001 --protocol Tcp --destination-port-range 80
az network public-ip create -n webapp-pip
az network vnet create \
    -n webapp-vnet --address-prefixes 192.168.1.0/24 \
    --subnet-name webapp-vnet-sub --subnet-prefix 192.168.1.0/24
az network lb create \
    -n webapp-websv-lb --public-ip-address webapp-pip \
    --frontend-ip-name webapp-websv-lb-front \
    --backend-pool-name webapp-websv-lb-backpool
az network lb probe create \
    --lb-name webapp-websv-lb -n webapp-websv-lb-probe \
    --port 80 --protocol Http --path '/?lbprobe=1'
az network lb rule create \
    --lb-name webapp-websv-lb -n webapp-websv-lb-rule \
    --frontend-ip-name webapp-websv-lb-front --frontend-port 80 \
    --backend-pool-name webapp-websv-lb-backpool --backend-port 80 \
    --protocol tcp --probe-name webapp-websv-lb-probe
az vm availability-set create -n webapp-websv-as \
    --platform-update-domain-count 5 \
    --platform-fault-domain-count 2
for i in $(seq 1 ${NUMBER_OF_WEB_SERVERS}); do
(
az network nic create \
    -n webapp-websv${i}-nic \
    --private-ip-address 192.168.1.$((10 + ${i})) \
    --vnet-name webapp-vnet --subnet webapp-vnet-sub \
    --network-security-group webapp-websv-nsg \
    --lb-name webapp-websv-lb \
    --lb-address-pools webapp-websv-lb-backpool
az vm create \
    -n websv${i} --nics webapp-websv${i}-nic \
    --availability-set webapp-websv-as \
    --size Standard_F1 --storage-sku Standard_LRS \
    --image ${WEBSV_IMAGE} \
    --admin-username "${SSH_USER}" --ssh-key-value "${SSH_PKEY}"
)&
done
wait
echo http://$(az network public-ip show -n webapp-pip -o tsv --query ipAddress)/

