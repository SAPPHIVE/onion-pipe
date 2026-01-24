#!/bin/bash

# --- INIT MODE ---
if [ "$1" == "init" ]; then
    echo "🔑 Configuring Onion-Pipe Security Layer..."
    mkdir -p /registration
    
    # Generate X25519 Keypair using OpenSSL (Overwrites existing for rotation)
    openssl genpkey -algorithm X25519 -out /registration/priv.key 2>/dev/null
    
    # Extract the RAW 32-byte public key and encode it to Base64
    PUB_BASE64=$(openssl pkey -in /registration/priv.key -pubout -outform DER | tail -c 32 | base64 | tr -d '\n')
    echo "$PUB_BASE64" > /registration/pub.key
    
    echo "✅ Success: Keypair generated in /registration/"
    echo "   Note: Previous keys in this folder have been replaced (Rotated)."
    echo "   Public Key: $PUB_BASE64"
    exit 0
fi

if [ "$1" == "register" ]; then
    echo "🔗 Manual Registration Triggered..."
    if [ -f "/var/lib/tor/hidden_service/hostname" ]; then
        ONION_ADDR=$(cat /var/lib/tor/hidden_service/hostname)
        SERVICE_ID=${ONION_ADDR%%.onion}
        RELAY_URL=${RELAY_URL:-"https://onion-pipe.sapphive.com"}
        
        PUB_KEY_PATH="/registration/pub.key"

        if [ -f "$PUB_KEY_PATH" ] && [ ! -z "$API_TOKEN" ]; then
            PUB_KEY=$(cat "$PUB_KEY_PATH")
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$RELAY_URL/register" \
                -H "Content-Type: application/json" \
                -d "{\"onion_service_id\": \"$SERVICE_ID\", \"token\": \"$API_TOKEN\", \"public_key\": \"$PUB_KEY\"}")
            
            if [ "$HTTP_CODE" -eq 200 ]; then
                echo "✅ MANUAL REGISTRATION SUCCESSFUL!"
                exit 0
            else
                echo "❌ REGISTRATION FAILED ($HTTP_CODE)"
                exit 1
            fi
        else
            echo "❌ ERROR: Missing API_TOKEN or Public Key in /registration/ folder."
            exit 1
        fi
    else
        echo "❌ ERROR: Tor hostname not found. Is the container running?"
        exit 1
    fi
fi

# Ensure Tor data directory has correct permissions for debian-tor
chown -R debian-tor:debian-tor /var/lib/tor
chmod 700 /var/lib/tor
chmod 700 /var/lib/tor/hidden_service

# Generate Tor Configuration based on LISTEN_PORT
cat > /etc/tor/torrc <<EOF
DataDirectory /var/lib/tor
HiddenServiceDir /var/lib/tor/hidden_service/
HiddenServicePort 80 127.0.0.1:${LISTEN_PORT}
HiddenServicePort 443 127.0.0.1:443
Log notice stdout
EOF

# Process Nginx template
envsubst '${FORWARD_DEST} ${LISTEN_PORT}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf

# Start Tor in background as debian-tor
echo "🧅 Establishing Sapphive Onion-Pipe circuit..."
su -s /bin/bash debian-tor -c "tor -f /etc/tor/torrc --RunAsDaemon 1"

# Wait for hostname
MAX_RETRIES=30
COUNT=0
echo "⏳ Generating your unique Webhook entry point..."
while [ ! -f /var/lib/tor/hidden_service/hostname ]; do
    sleep 2
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "❌ Error: Tor failed to initialize. Check your network connection."
        exit 1
    fi
done

ONION_ADDR=$(cat /var/lib/tor/hidden_service/hostname)
SERVICE_ID=${ONION_ADDR%%.onion}

# --- AUTOMATIC REGISTRATION ---
RELAY_URL=${RELAY_URL:-"https://onion-pipe.sapphive.com"}

if [ ! -z "$API_TOKEN" ]; then
    echo "🔗 Registering with Relay ($RELAY_URL)..."
    
    # Mandatory Public Key for E2EE (Now in registration volume)
    PUB_KEY_PATH="/registration/pub.key"

    if [ -f "$PUB_KEY_PATH" ]; then
        PUB_KEY=$(cat "$PUB_KEY_PATH")
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$RELAY_URL/register" \
            -H "Content-Type: application/json" \
            -d "{\"onion_service_id\": \"$SERVICE_ID\", \"token\": \"$API_TOKEN\", \"public_key\": \"$PUB_KEY\"}")
        
        if [ "$HTTP_CODE" -eq 200 ]; then
            echo "✅ SUCCESSFULLY REGISTERED with Relay!"
            echo "   Public Webhook URL: $RELAY_URL/h/$SERVICE_ID (approximate, check dashboard)"
        else
            echo "❌ REGISTRATION REJECTED ($HTTP_CODE). Ensure your API_TOKEN is valid."
        fi
    else
        echo "❌ FAILED: Public key (/registration/pub.key) not found."
        echo "   Run the 'init' command first to generate your security keys."
    fi
fi
        echo "   Registration requires a public key for End-to-End Encryption."
        echo "   Please run 'init' command first to generate keys in your volume."
    fi
else
    echo "ℹ️  No API_TOKEN provided. Skipping automatic registration."
fi
# -----------------------------

echo "***************************************************"
echo "  🚀 SAPPHIVE ONION-PIPE IS ACTIVE"
echo "  📍 PUBLIC ONION: http://$ONION_ADDR"
echo "  🔒 SECURE ONION: https://$ONION_ADDR"
echo "  ➡️  FORWARDING TO: $FORWARD_DEST"
echo "***************************************************"

# Cleanup for Supervisor
pkill tor
sleep 1

exec /usr/bin/supervisord -c /etc/supervisord.conf
