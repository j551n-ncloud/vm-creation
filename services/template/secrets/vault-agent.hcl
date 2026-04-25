vault {
  address = "VAULT_ADDR_PLACEHOLDER"
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "/vault/secrets/role_id"
      secret_id_file_path = "/vault/secrets/secret_id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink "file" {
    config = {
      path = "/vault/secrets/.token"
    }
  }
}

template {
  source      = "/vault/config/env.ctmpl"
  destination = "/vault/secrets/app.env"
  perms       = "0640"
}
