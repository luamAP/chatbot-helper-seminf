#!/bin/bash

echo "=== Status do Sistema $(date) ==="
echo "CPU e Memória:"
free -h
echo ""
echo "Uso do Disco:"
df -h
echo ""
echo "Containers Docker:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Logs recentes do n8n:"
docker logs chatbot_n8n --tail 5
echo ""
echo "Logs recentes da Evolution API:"
docker logs chatbot_evolution --tail 5
