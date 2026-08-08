caution {
  # managed_credentials = "credentials.pgp"
  # machine_type = "c5.xlarge"
  # build_machine_type = "c5.xlarge"
}
enclave "default" {
  build {
    app_sources = [
      "https://codeberg.org/caution/demo-ai-inference.git"
    ]
    cache = false
  }

  network {
    ingress {
      cidr_ipv4 = "0.0.0.0/0"
      port = 8083
      ip_protocol = "tcp"
    }

    http {
      domain = "chat.caution.dev"
      port = 8083

      e2e_encryption {
        mode = "steve"
      }
    }
  }

  resources {
    cpu = 14
    memory_mb = 55000
  }

  unit "default" {
    command = "/usr/bin/llama-server"
    args = [
      "--host",
      "0.0.0.0",
      "--port",
      "8083",
      "-m",
      "/workdir/models/model.gguf",
      "--path",
      "/workdir/public",
      "--ctx-size",
      "2048",
      "-t",
      "8"
    ]
  }
}
