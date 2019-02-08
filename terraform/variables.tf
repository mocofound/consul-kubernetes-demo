# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------
variable "gcp_region" {
  description = "All GCP resources will be launched in this Region."
  default     = "us-west1"
}

variable "gcp_project" {
  description = "All GCP resources will be launched in this Region."
  default     = "stenio-project-230417"
}

variable "vault_consul_image_name" {
  description = "Name of the image created by Packer"
  default     = "consulcluster"
}

variable "cluster_name" {
  description = "The name of the Consul cluster. This variable is used to namespace all resources created by this module."
  default     = "my-consul"
}

variable "gke_name" {
  description = "GKE name"
  default     = "my-gke"
}

variable "gke_password" {
  description = "GKE Password."
}


variable "cluster_tag_name" {
  description = "The tag name the Compute Instances will look for to automatically discover each other and form a cluster. TIP: If running more than one Vault cluster, each cluster should have its own unique tag name."
  default     = "tag-consul"
}

variable "machine_type" {
  description = "The machine type of the Compute Instance to run for each node in the cluster (e.g. n1-standard-1)."
  default     = "n1-standard-1"
}

variable "cluster_size" {
  description = "The number of nodes to have in the Vault cluster. We strongly recommended that you use either 3 or 5."
  default     = "3"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

# Service account with permissions for Consul and Vault GCP auth
variable "service_account_iam_roles" {
  type = "list"

  default = [
    "roles/iam.serviceAccountUser",
    "roles/compute.instanceAdmin.v1",
  ]
}
variable "network_project_id" {
  description = "The name of the GCP Project where the network is located. Useful when using networks shared between projects. If empty, var.gcp_project_id will be used."
  default     = ""
}

variable "network_name" {
  description = "The name of the VPC Network where all resources should be created."
  default     = "default"
}

variable "subnetwork_name" {
  description = "The name of the VPC Subnetwork where all resources should be created. Defaults to the default subnetwork for the network and region."
  default     = ""
}

variable "custom_tags" {
  description = "A list of tags that will be added to the Compute Instance Template in addition to the tags automatically added by this module."
  type        = "list"
  default     = []
}

variable "instance_group_update_strategy" {
  description = "The update strategy to be used by the Instance Group. IMPORTANT! When you update almost any cluster setting, under the hood, this module creates a new Instance Group Template. Once that Instance Group Template is created, the value of this variable determines how the new Template will be rolled out across the Instance Group. Unfortunately, as of August 2017, Google only supports the options 'RESTART' (instantly restart all Compute Instances and launch new ones from the new Template) or 'NONE' (do nothing; updates should be handled manually). Google does offer a rolling updates feature that perfectly meets our needs, but this is in Alpha (https://goo.gl/MC3mfc). Therefore, until this module supports a built-in rolling update strategy, we recommend using `NONE` and either using the alpha rolling updates strategy to roll out new Vault versions, or to script this using GCE API calls. If using the alpha feature, be sure you are comfortable with the level of risk you are taking on. For additional detail, see https://goo.gl/hGH6dd."
  default     = "NONE"
}

#variable "enable_web_proxy" {
#  description = "If true, a Firewall Rule will be created that allows inbound Health Check traffic on var.web_proxy_port."
#  default     = true
#}

# Metadata

variable "metadata_key_name_for_cluster_size" {
  description = "The key name to be used for the custom metadata attribute that represents the size of the Vault cluster."
  default     = "cluster-size"
}

variable "custom_metadata" {
  description = "A map of metadata key value pairs to assign to the Compute Instance metadata."
  type        = "map"
  default     = {}
}

# Firewall Ports

variable "web_proxy_port" {
  description = "The port at which the HTTP proxy server will listen for incoming HTTP requests that will be forwarded to the Vault Health Check URL. We must have an HTTP proxy server to work around the limitation that GCP only permits Health Checks via HTTP, not HTTPS. This value is originally set in the Startup Script that runs Nginx and passes the port value there."
  default     = 8000
}

variable "allowed_inbound_cidr_blocks_api" {
  description = "A list of CIDR-formatted IP address ranges from which the Compute Instances will allow connections to Vault on the configured TCP Listener (see https://goo.gl/Equ4xP)"
  type        = "list"
  default     = ["0.0.0.0/0"]
}

variable "allowed_inbound_tags_api" {
  description = "A list of tags from which the Compute Instances will allow connections to Vault on the configured TCP Listener (see https://goo.gl/Equ4xP)"
  type        = "list"
  default     = []
}

# Disk Settings

variable "root_volume_disk_size_gb" {
  description = "The size, in GB, of the root disk volume on each Consul node."
  default     = 30
}

variable "root_volume_disk_type" {
  description = "The GCE disk type. Can be either pd-ssd, local-ssd, or pd-standard"
  default     = "pd-standard"
}
