exit_after_auth = false
pid_file = "/tmp/vault-agent.pid"

auto_auth {
  method {
    type = "gcp"
    config = {
      type            = "iam"
      role            = "ghat"
      service_account = "ghat-cr@libops-ghat.iam.gserviceaccount.com"
      jwt_exp         = 5
    }
  }
}

template {
  error_on_missing_key = true
  contents = "{{ with secret \"secret/libops-ghat/github-app-key\" }}{{ base64Decode .Data.key }}{{ end }}"
  destination = "/vault/secrets/gha-private.pem"
}
