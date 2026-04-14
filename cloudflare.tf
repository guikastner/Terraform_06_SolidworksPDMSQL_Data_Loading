resource "null_resource" "cloudflare_dirs" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.cloudflare_generated_dir}"
  }
}

resource "random_password" "tunnel_secret" {
  length           = 64
  special          = false
  override_special = ""
}

resource "local_file" "cloudflared_config" {
  filename        = local.cloudflare_config_path
  file_permission = "0644"
  content = templatefile(
    "${path.module}/templates/cloudflared-config.yml.tmpl",
    {
      tunnel_id        = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
      credentials_file = "/etc/cloudflared/credentials.json"
      ingress_entries = join("\n", [
        "  - hostname: ${local.node_red_instance.hostname}",
        "    service: http://${local.node_red_instance.name}:1880",
        "  - hostname: ${local.webdb_instance.hostname}",
        "    service: http://${local.webdb_instance.name}:22071",
      ])
    }
  )

  depends_on = [null_resource.cloudflare_dirs]
}

resource "local_sensitive_file" "cloudflared_credentials" {
  filename        = local.cloudflare_credentials_path
  file_permission = "0600"
  content = jsonencode({
    AccountTag   = var.cloudflare_account_id
    TunnelID     = cloudflare_zero_trust_tunnel_cloudflared.tunnel.id
    TunnelName   = cloudflare_zero_trust_tunnel_cloudflared.tunnel.name
    TunnelSecret = random_password.tunnel_secret.result
  })

  depends_on = [null_resource.cloudflare_dirs]
}

resource "docker_container" "cloudflared" {
  name     = local.cloudflared_instance.name
  image    = docker_image.cloudflared.image_id
  restart  = "unless-stopped"
  hostname = local.cloudflared_instance.name

  command = [
    "--config",
    "/etc/cloudflared/config.yml",
    "tunnel",
    "--no-autoupdate",
    "run",
  ]

  mounts {
    target    = "/etc/cloudflared/config.yml"
    source    = local.cloudflare_config_path
    type      = "bind"
    read_only = true
  }

  mounts {
    target    = "/etc/cloudflared/credentials.json"
    source    = local.cloudflare_credentials_path
    type      = "bind"
    read_only = true
  }

  networks_advanced {
    name = docker_network.main.name
  }

  networks_advanced {
    name = "bridge"
  }

  depends_on = [
    docker_network.main,
    local_file.cloudflared_config,
    local_sensitive_file.cloudflared_credentials,
    cloudflare_zero_trust_tunnel_cloudflared_config.tunnel,
  ]
}
