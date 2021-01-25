#!/bin/bash
set -ex

SYNAPSE_SERVER_NAME="$(yq -r .synapse_server_name config.yaml)"
SYNAPSE_SEVER_ADDRESS="$(yq -r .synapse_server_address config.yaml)"
TELEGRAM_ENABLE="$(yq -r .telegram_enable config.yaml)"
TELEGRAM_API_ID="$(yq -r .telegram_api_id config.yaml)"
TELEGRAM_API_HASH="$(yq -r .telegram_api_hash config.yaml)"
WHATSAPP_ENABLE="$(yq -r .whatsapp_enable config.yaml)"
SIGNAL_ENABLE="$(yq -r .signal_enable config.yaml)"
DISCORD_ENABLE="$(yq -r .discord_enable config.yaml)"

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
SHARED_SECRET=$(pwgen -s 128 1)
sudo sed -i "s|password_providers:|password_providers:\n  - module: \"shared_secret_authenticator.SharedSecretAuthenticator\"\n    config:\n      sharedSecret: \"$SHARED_SECRET\"\n|g" data/synapse/homeserver.yaml

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
  sudo sed -i "s|        example.com: foobar|        $SYNAPSE_SERVER_NAME: $SHARED_SECRET|g" data/telegram/config.yaml
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
  sudo chmod 755 data/telegram/registration.yaml
  sudo cp data/telegram/registration.yaml data/synapse/telegram-registration.yaml
  REGISTRATION_FILES+=(telegram-registration.yaml)
fi

if [ "$WHATSAPP_ENABLE" == "true" ]; then
  echo "Setting up WhatsApp"

  mkdir -p data/whatsapp
  docker run --rm \
    -v "$(pwd)"/data/whatsapp:/data:z \
    dock.mau.dev/tulir/mautrix-whatsapp:latest
  sudo sed -i "s|    address: https://example.com|    address: http://synapse:8008|g" data/whatsapp/config.yaml
  sudo sed -i "s|    domain: example.com|    domain: $SYNAPSE_SERVER_NAME|g" data/whatsapp/config.yaml
  sudo sed -i "s|    address: http://localhost:29318|    address: http://whatsapp:29318|g" data/whatsapp/config.yaml
  sudo sed -i "s|    displayname_template: \"{{if .Notify}}{{.Notify}}{{else}}{{.Jid}}{{end}} (WA)\"|    displayname_template: \"{{if .Short}}{{.Short}}{{else if .Name}}{{.Name}}{{else if .Notify}}{{.Notify}}{{else}}{{.Jid}}{{end}} (WhatsApp)\"|g" data/whatsapp/config.yaml
  sudo sed -i "s|    initial_history_disable_notifications: false|    initial_history_disable_notifications: true|g" data/whatsapp/config.yaml
  sudo sed -i "s|    login_shared_secret: null|    login_shared_secret: \"$SHARED_SECRET\"|g" data/whatsapp/config.yaml
  sudo sed -i "s|        \"\*\": relaybot||g" data/whatsapp/config.yaml
  sudo sed -i "s|        \"example.com\": user||g" data/whatsapp/config.yaml
  sudo sed -i "s|        \"@admin:example.com\": admin|        \"$SYNAPSE_SERVER_NAME\": \"admin\"|g" data/whatsapp/config.yaml
  docker run --rm \
    -v "$(pwd)"/data/whatsapp:/data:z \
    dock.mau.dev/tulir/mautrix-whatsapp:latest
  sudo chmod 755 data/whatsapp/registration.yaml
  sudo cp data/whatsapp/registration.yaml data/synapse/whatsapp-registration.yaml
  REGISTRATION_FILES+=(whatsapp-registration.yaml)
fi

if [ "$SIGNAL_ENABLE" == "true" ]; then
  echo "Setting up Signal"

  mkdir -p data/signal data/signal/db
  id=$(docker run --rm -d \
    -v "$(pwd)"/data/signal:/signald:z \
    finn/signald:latest)
  docker run --rm \
    -v "$(pwd)"/data/signal:/data:z \
    -v "$(pwd)"/data/signal:/signald:z \
    dock.mau.dev/tulir/mautrix-signal:latest
  sudo sed -i "s|    address: https://example.com|    address: http://synapse:8008|g" data/signal/config.yaml
  sudo sed -i "s|    domain: example.com|    domain: $SYNAPSE_SERVER_NAME|g" data/signal/config.yaml
  sudo sed -i "s|    address: http://localhost:29328|    address: http://signal:29328|g" data/signal/config.yaml
  sudo sed -i "s|    database: postgres:\/\/username:password@hostname\/db|    database: postgres:\/\/mautrixsignal:foobar@signal-db\/mautrixsignal|g" data/signal/config.yaml
  sudo sed -i "s|    ephemeral_events: false|    ephemeral_events: true|g" data/signal/config.yaml
  sudo sed -i "s|    socket_path: \/var\/run\/signald\/signald.sock|    socket_path: \/signald\/signald.sock|g" data/signal/config.yaml
  sudo sed -i "s|    outgoing_attachment_dir: \/tmp|    outgoing_attachment_dir: \/signald\/attachments|g" data/signal/config.yaml
  sudo sed -i "s|    avatar_dir: ~\/\.config\/signald\/avatars|    avatar_dir: \/signald\/avatars|g" data/signal/config.yaml
  sudo sed -i "s|    data_dir: ~\/\.config\/signald\/data|    data_dir: \/signald\/data|g" data/signal/config.yaml
  sudo sed -i "s|    allow_contact_list_name_updates: false|    allow_contact_list_name_updates: true|g" data/signal/config.yaml
  sudo sed -i "s|    sync_with_custom_puppets: true|    sync_with_custom_puppets: false|g" data/signal/config.yaml
  sudo sed -i "s|        example.com: foo|        $SYNAPSE_SERVER_NAME: $SHARED_SECRET|g" data/signal/config.yaml
  sudo sed -i "s|        \"example.com\": \"user\"||g" data/signal/config.yaml
  sudo sed -i "s|        \"@admin:example.com\": \"admin\"|        \"$SYNAPSE_SERVER_NAME\": \"admin\"|g" data/signal/config.yaml
  docker run --rm \
    -v "$(pwd)"/data/signal:/data:z \
    -v "$(pwd)"/data/signal:/signald:z \
    dock.mau.dev/tulir/mautrix-signal:latest
  docker stop "$id"
  sudo cp data/signal/registration.yaml data/synapse/signal-registration.yaml
  REGISTRATION_FILES+=(signal-registration.yaml)
fi

if [ "$DISCORD_ENABLE" == "true" ]; then
  echo "Setting up Discord"

  mkdir -p data/discord
  cat >data/discord/config.yaml <<EOF
bridge:
  port: 8434
  bindAddress: 0.0.0.0
  domain: $SYNAPSE_SERVER_NAME
  homeserverUrl: http://synapse:8008
  loginSharedSecretMap:
    $SYNAPSE_SERVER_NAME: $SHARED_SECRET
  displayname: Discord Puppet Bridge
  enableGroupSync: true
presence:
  enabled: true
  interval: 10000
provisioning:
  whitelist:
    - "@.*:$SYNAPSE_SERVER_NAME"
relay:
  whitelist:
    - "@.*:$SYNAPSE_SERVER_NAME"
selfService:
  whitelist:
    - "@.*:$SYNAPSE_SERVER_NAME"
namePatterns:
  user: :name
  userOverride: :displayname
  room: :name
  group: :name
database:
  filename: database.db
limits:
  maxAutojoinUsers: 100
  roomUserAutojoinDelay: 100
EOF
  docker run --rm \
    -v "$(pwd)"/data/discord:/data:z \
    sorunome/mx-puppet-discord:latest
  sudo sed -i "s|url: 'http://localhost:8434'|url: 'http://discord:8434'|g" data/discord/discord-registration.yaml
  sudo cp data/discord/discord-registration.yaml data/synapse/discord-registration.yaml
  REGISTRATION_FILES+=(discord-registration.yaml)
fi

if [ "${#REGISTRATION_FILES[@]}" -ne 0 ]; then
  sudo sed -i "s|#app_service_config_files:|app_service_config_files:|g" data/synapse/homeserver.yaml
  for registration_file in ${REGISTRATION_FILES[*]}; do
    sudo sed -i "s|app_service_config_files:|app_service_config_files:\n  - /data/$registration_file|g" data/synapse/homeserver.yaml
  done
fi
