#!/bin/bash

SERVICES=(synapse element)

TELEGRAM_ENABLE="$(yq -r .telegram_enable config.yaml)"
if [ "$TELEGRAM_ENABLE" == "true" ]; then
  SERVICES+=(telegram)
fi

WHATSAPP_ENABLE="$(yq -r .whatsapp_enable config.yaml)"
if [ "$WHATSAPP_ENABLE" == "true" ]; then
  SERVICES+=(whatsapp)
fi

SIGNAL_ENABLE="$(yq -r .signal_enable config.yaml)"
if [ "$SIGNAL_ENABLE" == "true" ]; then
  SERVICES+=(signal)
  SERVICES+=(signald)
  SERVICES+=(signal_db)
fi

DISCORD_ENABLE="$(yq -r .discord_enable config.yaml)"
if [ "$DISCORD_ENABLE" == "true" ]; then
  SERVICES+=(discord)
fi

# shellcheck disable=SC2046
docker-compose up $(printf " %s" "${SERVICES[@]}")
