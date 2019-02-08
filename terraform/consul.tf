terraform {
  required_version = ">= 0.10.3"
}

provider "google" {
  region  = "${var.gcp_region}"
  project = "${var.gcp_project}"
}

# Creates Service Account
resource "google_service_account" "consul_service_account" {
  project= "${var.gcp_project}"
  account_id   = "consul-gcpkms"
  display_name = "Consul Service Account"
}

# Add permissions
resource "google_project_iam_member" "service-account" {
  count   = "${length(var.service_account_iam_roles)}"
  project = "${var.gcp_project}"
  role    = "${element(var.service_account_iam_roles, count.index)}"
  member  = "serviceAccount:${google_service_account.consul_service_account.email}"
}

# Create the Managed Instance Group where Consul will run.
resource "google_compute_region_instance_group_manager" "consul" {
  name = "${var.cluster_name}-ig"

  project = "${var.gcp_project}"

  base_instance_name = "${var.cluster_name}"

  instance_template         = "${google_compute_instance_template.consul.self_link}"
  region                    = "${var.gcp_region}"
  distribution_policy_zones = ["${var.gcp_region}-a", "${var.gcp_region}-b"]

  update_strategy = "${var.instance_group_update_strategy}"
  target_pools = ["${google_compute_target_pool.default.self_link}"]
  target_size  = "${var.cluster_size}"
}

data "google_compute_image" "hashistack" {
  family  = "${var.vault_consul_image_name}"
  project = "${var.gcp_project}"
}

# Create the Instance Template that will be used to populate the Managed Instance Group.
resource "google_compute_instance_template" "consul" {
  name_prefix = "${var.cluster_name}"
  description = "Consul server"
  project     = "${var.gcp_project}"

  instance_description = "Consul server"
  machine_type         = "${var.machine_type}"

  tags                    = "${concat(list(var.cluster_tag_name), var.custom_tags)}"
  metadata_startup_script = "${data.template_file.consul_install_config.rendered}"
  metadata                = "${merge(map(var.metadata_key_name_for_cluster_size, var.cluster_size), var.custom_metadata)}"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  disk {
    boot         = true
    auto_delete  = true
    source_image = "${data.google_compute_image.hashistack.self_link}"
    disk_size_gb = "${var.root_volume_disk_size_gb}"
    disk_type    = "${var.root_volume_disk_type}"
  }

  network_interface {
    # Either network or subnetwork must both be blank, or exactly one must be provided.
    network            = "${var.subnetwork_name != "" ? "" : var.network_name}"
    subnetwork         = "${var.subnetwork_name != "" ? var.subnetwork_name : ""}"
    subnetwork_project = "${var.network_project_id != "" ? var.network_project_id : var.gcp_project}"

    access_config {
      # The presence of this property assigns a public IP address to each Compute Instance. We intentionally leave it
      # blank so that an external IP address is selected automatically.
      nat_ip = ""
    }
  }

   service_account {
    email = "${google_service_account.consul_service_account.email}"
    scopes = ["cloud-platform", "compute-rw", "userinfo-email", "storage-ro"]
  }

  # Per Terraform Docs (https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#using-with-instance-group-manager),
  # we need to create a new instance template before we can destroy the old one. Note that any Terraform resource on
  # which this Terraform resource depends will also need this lifecycle statement.
  lifecycle {
    create_before_destroy = true
  }

}

data "template_file" "consul_install_config" {
  template = "${file("bootstrap.sh.tpl")}"

  vars = {
    cluster_tag_name = "${var.cluster_tag_name}"
    project_name     = "${var.gcp_project}"
    local_region     = "${var.gcp_region}"
    cluster_size     = "${var.cluster_size}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE FIREWALL RULES
# ---------------------------------------------------------------------------------------------------------------------

# Allow Vault-specific traffic within the cluster
# - This Firewall Rule may be redundant depending on the settings of your VPC Network, but if your Network is locked down,
#   this Rule will open up the appropriate ports.
resource "google_compute_firewall" "allow_intracluster_consul" {
  name    = "${var.cluster_name}-rule-cluster"
  network = "${var.network_name}"
  project = "${var.gcp_project}"

  allow {
    protocol = "tcp"

    ports = [
      "8300",
      "8301"
    ]
  }

  source_tags = ["${var.cluster_tag_name}"]
  target_tags = ["${var.cluster_tag_name}"]
}

# Specify which traffic is allowed into the Vault cluster solely for API requests
# - This Firewall Rule may be redundant depending on the settings of your VPC Network, but if your Network is locked down,
#   this Rule will open up the appropriate ports.
# - This Firewall Rule is only created if at least one source tag or source CIDR block is specified.
resource "google_compute_firewall" "allow_inbound_api" {
  count = "${length(var.allowed_inbound_cidr_blocks_api) + length(var.allowed_inbound_tags_api) > 0 ? 1 : 0}"

  name    = "${var.cluster_name}-rule-external-api-access"
  network = "${var.network_name}"
  project = "${var.network_project_id != "" ? var.network_project_id : var.gcp_project}"

  allow {
    protocol = "tcp"

    ports = [
       "8500"
    ]
  }

  source_ranges = "${var.allowed_inbound_cidr_blocks_api}"
  source_tags   = ["${var.allowed_inbound_tags_api}"]
  target_tags   = ["${var.cluster_tag_name}"]
}

# If we require a Load Balancer in front of the Consul cluster, we must specify a Health Check so that the Load Balancer
# knows which nodes to route to. But GCP only permits HTTP Health Checks, not HTTPS Health Checks (https://github.com/terraform-providers/terraform-provider-google/issues/18)
# so we must run a separate Web Proxy that forwards HTTP requests to the HTTPS Vault health check endpoint. This Firewall
# Rule permits only the Google Cloud Health Checker to make such requests.
#resource "google_compute_firewall" "allow_inbound_health_check" {
#  count = "${var.enable_web_proxy}"

#  name    = "${var.cluster_name}-rule-health-check"
#  network = "${var.network_name}"

#  project = "${var.network_project_id != "" ? var.network_project_id : var.gcp_project}"

#  allow {
#    protocol = "tcp"

#    ports = [
#      "${var.web_proxy_port}",
#    ]
#  }

  # Per https://goo.gl/xULu8U, all Google Cloud Health Check requests will be sent from 35.191.0.0/16
#  source_ranges = ["35.191.0.0/16"]
#  target_tags   = ["${var.cluster_tag_name}"]
#}


# Load Balancer
resource "google_compute_forwarding_rule" "default" {
  project               = "${var.gcp_project}"
  name = "fwd-rle"
  target                = "${google_compute_target_pool.default.self_link}"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "8500"
}

resource "google_compute_target_pool" "default" {
  project          = "${var.gcp_project}"
  name             = "lbvaulttargetpool"
  region           = "${var.gcp_region}"
  session_affinity = "NONE"

  health_checks = [
    "${google_compute_http_health_check.default.name}",
  ]
}
resource "google_compute_http_health_check" "default" {
  project      = "${var.gcp_project}"
  name         = "vault-hc"
  request_path = "/"
  port         = "8500"
}

resource "google_compute_firewall" "default-lb-fw" {
  project = "${var.gcp_project}"
  name    = "firewall-vm-service"
  network = "${var.network_name}"

  allow {
    protocol = "tcp"
    ports    = ["8500"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.cluster_tag_name}"]
}