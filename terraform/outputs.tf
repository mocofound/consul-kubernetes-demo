output "cluster_tag_name" {
  value = "${var.cluster_name}"
}

output external_ip {
  description = "The external ip address of the forwarding rule."
  value       = "${google_compute_forwarding_rule.default.ip_address}:8500"
}
