# <img src="https://raw.githubusercontent.com/SAPPHIVE/onion-pipe/main/src/assets/logo/logo.png" height="32"> Onion-Pipe Client (by Sapphive)

**Onion-Pipe** is an open-source anonymous webhook system maintained by the Sapphive Infrastructure Team. It allows you to receive webhooks on your local machine via the Tor network without any open ports or complex firewall configurations. It is the perfect tool for developers testing multi-service webhooks in a zero-trust environment.

## ⚡ Setup Guide for Non-Developers

### 1. Preparation

1.  **Get an API Key**: Visit [onion-pipe.sapphive.com](https://onion-pipe.sapphive.com) and log in with GitHub.
2.  **Install Docker**: Ensure Docker is running on your machine.

### 2. Launch the Client

1. **Initialize Keys**: Run once on your host machine to generate your E2EE keypair:
   ```bash
   docker run --rm -v "$(pwd)/registration:/registration" sapphive/onion-pipe init
   ```

2. **Start Tunneling**: Save the following as `docker-compose.yml` and run `docker compose up -d`:

```yaml
services:
  onion-pipe:
    image: sapphive/onion-pipe:latest
    environment:
      - FORWARD_DEST="http://host.docker.internal:3000"
      - API_TOKEN="your_api_token_here"
    volumes:
      - ./registration:/registration
      - ./onion_id:/var/lib/tor/hidden_service
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

### 3. Link your Tunnel

1.  **Find your Address**: Run `docker logs onion-pipe`. Look for a line saying `Your onion address is: xxxxxxxx.onion`.
2.  **Register it**: Go to your Dashboard and click "Add Tunnel". Paste your `.onion` address.
3.  **Test it**: Use the provided Public Webhook URL (visible on your dashboard) to start sending traffic!

---

## ⚙️ Advanced Configuration

| Variable       | Default                            | Purpose                                          |
| :------------- | :--------------------------------- | :----------------------------------------------- |
| `FORWARD_DEST` | `http://host.docker.internal:8080` | Where the decrypted traffic is "piped" to.       |
| `LISTEN_PORT`  | `80`                               | The port the client uses inside its own network. |

## 🛡️ Why use this?

When you use a standard relay, the relay owner can read your webhooks (GitHub tokens, private data, etc.). **Onion-Pipe** uses "sealed box" encryption. Only the client running on **your** computer has the key to see the data. The relay only sees random scrambled text.

| Variable       | Default                            | Description                              |
| :------------- | :--------------------------------- | :--------------------------------------- |
| `FORWARD_DEST` | `http://host.docker.internal:8080` | Local target where traffic is forwarded. |
| `LISTEN_PORT`  | `80`                               | Internal port the client listens on.     |

## 📦 Persistence

To keep the same `.onion` address across restarts, **always** mount a volume to `/var/lib/tor/hidden_service`. If this folder is lost, a new address will be generated.

## ⚖️ Legal Disclaimer

This is open-source software provided by SAPPHIVE. Tor is a trademark of The Tor Project, Inc. All trademarks belong to their respective owners.
