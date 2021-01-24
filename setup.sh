#!/bin/bash
set -ex

SYNAPSE_SERVER_NAME="$(yq -r .synapse_server_name config.yaml)"
SYNAPSE_SEVER_ADDRESS="$(yq -r .synapse_server_address config.yaml)"
TELEGRAM_ENABLE="$(yq -r .telegram_enable config.yaml)"
TELEGRAM_API_ID="$(yq -r .telegram_api_id config.yaml)"
TELEGRAM_API_HASH="$(yq -r .telegram_api_hash config.yaml)"

echo "Setting up Synapse"

if [ "$SYNAPSE_SERVER_NAME" == "" ] || [ "$SYNAPSE_SERVER_NAME" == "null" ]; then
  echo "Missing or empty synapse_server_name in config"
  exit 1
fi
if [ "$SYNAPSE_SEVER_ADDRESS" == "" ] || [ "$SYNAPSE_SEVER_ADDRESS" == "null" ]; then
  echo "Missing or empty synapse_server_address in config"
  exit 1
fi

mkdir -p data/synapse
docker run --rm \
  -v "$(pwd)"/data/synapse:/data:z \
  -e SYNAPSE_SERVER_NAME="$SYNAPSE_SERVER_NAME" \
  -e SYNAPSE_REPORT_STATS=no \
  matrixdotorg/synapse:latest generate

echo "Setting up Element"

mkdir -p data/element
cat >data/element/config.json <<EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "$SYNAPSE_SEVER_ADDRESS",
            "server_name": "$SYNAPSE_SERVER_NAME"
        }
    },
    "brand": "Element",
    "showLabsSettings": true,
    "roomDirectory": {
        "servers": [
            "$SYNAPSE_SERVER_NAME"
        ]
    }
}
EOF

REGISTRATION_FILES=()

if [ "$TELEGRAM_ENABLE" == "true" ]; then
  echo "Setting up Telegram"

  if [ "$TELEGRAM_API_ID" == "" ] || [ "$TELEGRAM_API_ID" == "null" ]; then
    echo "Missing or empty telegram_api_id in config"
    exit 1
  fi
  if [ "$TELEGRAM_API_HASH" == "" ] || [ "$TELEGRAM_API_HASH" == "null" ]; then
    echo "Missing or empty telegram_api_hash in config"
    exit 1
  fi

  mkdir -p data/telegram
  docker run --rm \
    -v "$(pwd)"/data/telegram:/data:z \
    dock.mau.dev/tulir/mautrix-telegram:latest
  sudo sed -i "s|    address: https://example.com|    address: http://synapse:8008|g" data/telegram/config.yaml
  sudo sed -i "s|    domain: example.com|    domain: $SYNAPSE_SERVER_NAME|g" data/telegram/config.yaml
  sudo sed -i "s|    address: http://localhost:29317|    address: http://telegram:29317|g" data/telegram/config.yaml
  sudo sed -i "s|    ephemeral_events: false|    ephemeral_events: true|g" data/telegram/config.yaml
  sudo sed -i "s|    sync_with_custom_puppets: true|    sync_with_custom_puppets: false|g" data/telegram/config.yaml
  #  sudo sed -i "s|    sync_create_limit: 30|    sync_create_limit: 0|g" data/telegram/config.yaml
  sudo sed -i "s|    sync_direct_chats: false|    sync_direct_chats: true|g" data/telegram/config.yaml
  #  sudo sed -i "s|        initial_limit: 0|        initial_limit: -1|g" data/telegram/config.yaml
  sudo sed -i "s|        disable_notifications: false|        disable_notifications: true|g" data/telegram/config.yaml
  sudo sed -i "s|        \"\*\": \"relaybot\"||g" data/telegram/config.yaml
  sudo sed -i "s|        \"public.example.com\": \"user\"||g" data/telegram/config.yaml
  sudo sed -i "s|        \"example.com\": \"full\"||g" data/telegram/config.yaml
  sudo sed -i "s|        \"@admin:example.com\": \"admin\"|        \"$SYNAPSE_SERVER_NAME\": \"admin\"|g" data/telegram/config.yaml
  sudo sed -i "s|    api_id: 12345|    api_id: $TELEGRAM_API_ID|g" data/telegram/config.yaml
  sudo sed -i "s|    api_hash: tjyd5yge35lbodk1xwzw2jstp90k55qz|    api_hash: $TELEGRAM_API_HASH|g" data/telegram/config.yaml
  docker run --rm \
    -v "$(pwd)"/data/telegram:/data:z \
    dock.mau.dev/tulir/mautrix-telegram:latest
  sudo cp data/telegram/registration.yaml data/synapse/telegram-registration.yaml
  REGISTRATION_FILES+=(telegram-registration.yaml)
fi

if [ "${#REGISTRATION_FILES[@]}" -ne 0 ]; then
  sudo sed -i "s|#app_service_config_files:|app_service_config_files:|g" data/synapse/homeserver.yaml
  for registration_file in ${REGISTRATION_FILES[*]}; do
    sudo sed -i "s|app_service_config_files:|app_service_config_files:\n  - /data/$registration_file|g" data/synapse/homeserver.yaml
  done
fi
