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
        enabled = true
      }
    }
  }

  # Qwen2.5-0.5B Q4_K_M: 469MB weights + 25MB KV cache @ ctx 2048 + ~300MB
  # llama-server buffers, on top of a ~1.4GB initramfs that is fully resident
  # in enclave RAM (no swap). ~2GB actual need; 2x headroom.
  resources {
    cpu       = 4
    memory_mb = 4096
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
      "4"
    ]
  }
}
