resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel" {
  account_id = var.cloudflare_account_id
  name       = var.cloudflare_tunnel_name
  secret     = random_password.tunnel_secret.result
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id

  config {
    ingress_rule {
      hostname = local.node_red_instance.hostname
      service  = "http://${local.node_red_instance.name}:1880"
    }

    ingress_rule {
      hostname = local.webdb_instance.hostname
      service  = "http://${local.webdb_instance.name}:22071"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "node_red_cname" {
  zone_id = var.cloudflare_zone_id
  name    = var.node_red_cname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnel.id}.cfargotunnel.com"
  proxied = var.cloudflare_proxied
}

resource "cloudflare_record" "webdb_cname" {
  zone_id = var.cloudflare_zone_id
  name    = var.webdb_cname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnel.id}.cfargotunnel.com"
  proxied = var.cloudflare_proxied
}
