#! /bin/bash

node_name="$(curl -s curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/name)"
local_ipv4="$(curl -s curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/ip)"
public_ipv4="$(curl -s curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)"

# Consul config
echo ' datacenter          = "${local_region}"
server = true
node_name = "NODE_NAME"
bootstrap_expect = ${cluster_size}
leave_on_terminate  = true
advertise_addr      = "LOCAL_IPV4"
data_dir            = "/opt/consul/data"
client_addr         = "0.0.0.0"
log_level           = "INFO"
ui                  = true
retry_join          = ["provider=gce tag_value=${cluster_tag_name}"]
disable_remote_exec = false' | sudo tee /etc/consul.d/consul.hcl

sudo sed -i -e 's/LOCAL_IPV4/'"$local_ipv4"'/g' -e 's/NODE_NAME/'"$node_name"'/g' /etc/consul.d/consul.hcl

sudo systemctl start consul


# Sets env vars for all users
#echo "Setup Hashistack profile"
#echo " export CONSUL_ADDR=http://127.0.0.1:8500
#export VAULT_ADDR=http://127.0.0.1:8200
#export VAULT_TOKEN= " | sudo tee /etc/profile.d/hashistack.sh