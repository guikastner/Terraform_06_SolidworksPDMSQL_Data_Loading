resource "docker_container" "node_red" {
  name     = local.node_red_instance.name
  image    = docker_image.node_red.image_id
  restart  = "unless-stopped"
  hostname = local.node_red_instance.name

  env = [
    "TZ=${var.timezone}",
    "NODE_RED_ADMIN_PASSWORD=${var.node_red_admin_password}",
  ]

  mounts {
    target = "/data"
    source = docker_volume.node_red_data.name
    type   = "volume"
  }

  mounts {
    target    = "/data/settings.js"
    source    = local.node_red_settings_path
    type      = "bind"
    read_only = true
  }

  networks_advanced {
    name    = docker_network.main.name
    aliases = [local.node_red_instance.name]
  }

  networks_advanced {
    name = "bridge"
  }

  depends_on = [
    docker_network.main,
    docker_volume.node_red_data,
    local_file.node_red_settings,
    null_resource.node_red_modules,
  ]
}

resource "docker_container" "sqlserver" {
  name     = local.sqlserver_instance.name
  image    = docker_image.sqlserver.image_id
  restart  = "unless-stopped"
  hostname = local.sqlserver_instance.name

  env = [
    "ACCEPT_EULA=Y",
    "MSSQL_PID=${var.sqlserver_edition}",
    "MSSQL_SA_PASSWORD=${var.sqlserver_sa_password}",
    "TZ=${var.timezone}",
  ]

  mounts {
    target = "/var/opt/mssql"
    source = docker_volume.sqlserver_data.name
    type   = "volume"
  }

  networks_advanced {
    name    = docker_network.main.name
    aliases = [local.sqlserver_instance.name]
  }

  depends_on = [
    docker_network.main,
    docker_volume.sqlserver_data,
  ]
}

resource "docker_container" "webdb" {
  name     = local.webdb_instance.name
  image    = docker_image.webdb.image_id
  restart  = "unless-stopped"
  hostname = local.webdb_instance.name

  networks_advanced {
    name    = docker_network.main.name
    aliases = [local.webdb_instance.name]
  }

  depends_on = [
    docker_network.main,
    docker_container.sqlserver,
  ]
}
