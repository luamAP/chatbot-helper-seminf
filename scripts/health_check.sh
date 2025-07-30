#!/bin/bash

# Verificar se os serviços estão rodando
N8N_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678)
EVOLUTION_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)

if [ "$N8N_STATUS" != "200" ]; then
	echo "ALERTA: n8n não está respondendo (HTTP $N8N_STATUS)"
	# Aqui você pode adicionar notificação por email ou Slack
fi

if [ "$EVOLUTION_STATUS" != "200" ]; then
	echo "ALERTA: Evolution API não está respondendo (HTTP $EVOLUTION_STATUS)"
	# Aqui você pode adicionar notificação por email ou Slack
fi

# Verificar uso de disco
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
	echo "ALERTA: Uso de disco alto: ${DISK_USAGE}%"
fi

# Verificar uso de memória
MEM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ "$MEM_USAGE" -gt 90 ]; then
	echo "ALERTA: Uso de memória alto: ${MEM_USAGE}%"
fi
