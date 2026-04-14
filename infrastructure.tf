resource "docker_network" "main" {
  name     = "stack-internal"
  driver   = "bridge"
  internal = true
}

resource "docker_image" "node_red" {
  name         = var.node_red_image
  keep_locally = true
}

resource "docker_image" "sqlserver" {
  name         = var.sqlserver_image
  keep_locally = true
}

resource "docker_image" "webdb" {
  name         = var.webdb_image
  keep_locally = true
}

resource "docker_image" "cloudflared" {
  name         = var.cloudflared_image
  keep_locally = true
}
