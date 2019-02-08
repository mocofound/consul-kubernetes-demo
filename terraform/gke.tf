data "google_client_config" "current" {}

provider "helm" {
  install_tiller = true
  tiller_image = "gcr.io/kubernetes-helm/tiller:v2.12.3"

  kubernetes {
    host                   = "${google_container_cluster.default.endpoint}"
    token                  = "${data.google_client_config.current.access_token}"
    #username = "ClusterMaster"
    #password = "MindTheGap"
    client_certificate     = "${base64decode(google_container_cluster.default.master_auth.0.client_certificate)}"
    client_key             = "${base64decode(google_container_cluster.default.master_auth.0.client_key)}"
    cluster_ca_certificate = "${base64decode(google_container_cluster.default.master_auth.0.cluster_ca_certificate)}"
  }
}

resource "google_container_cluster" "default" {
  name               = "${var.gke_name}"
  project = "${var.gcp_project}"
  region               = "${var.gcp_region}"
  initial_node_count = 1

  master_auth {
    username = "root"
    password = "${var.gke_password}"
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels {
      foo = "${var.cluster_tag_name}"
    }

    tags = "${concat(list(var.cluster_tag_name), var.custom_tags)}"
  }
}
