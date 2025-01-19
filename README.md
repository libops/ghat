# ghat

GitHub App Token

http service to allow receiving a scoped token from a GHA workflow.

## Requirements

The vault server that is configured in the sidecar needs the GitHub app private key

```
vault kv put \
  -mount="secret" \
  "libops-ghat/github-app-key" \
  key="$(cat /path/to/private-key.pem | base64)"
```
