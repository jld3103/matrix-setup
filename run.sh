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

docker-compose up "$(printf " %s" "${SERVICES[@]}")"
