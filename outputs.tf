output "node_red_hostname" {
  description = "Hostname assigned to the Node-RED instance for Cloudflare tunnel ingress."
  value       = local.node_red_instance.hostname
}

output "network_name" {
  description = "Internal Docker network used by all services."
  value       = docker_network.main.name
}

output "cloudflared_config_path" {
  description = "Rendered Cloudflare config file path on the host."
  value       = local.cloudflare_config_path
}

output "cloudflare_tunnel_name" {
  description = "Name of the tunnel created."
  value       = cloudflare_zero_trust_tunnel_cloudflared.tunnel.name
}

output "cloudflare_tunnel_id" {
  description = "ID of the tunnel created."
  value       = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
}

output "node_red_volume_name" {
  description = "Named volume used to persist Node-RED data."
  value       = docker_volume.node_red_data.name
}

output "sqlserver_volume_name" {
  description = "Named volume used to persist SQL Server data."
  value       = docker_volume.sqlserver_data.name
}
