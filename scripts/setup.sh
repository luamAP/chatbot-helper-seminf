#!/bin/bash

# Script de configuração automatizada para Evolution API + n8n (sem Nginx)
# Autor: Manus AI
# Data: $(date +%Y-%m-%d)

set -e  # Parar execução em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Verificar se está rodando como root
if [[ $EUID -eq 0 ]]; then
   error "Este script não deve ser executado como root"
fi

# Verificar se o arquivo .env existe
if [ ! -f ".env" ]; then
    error "Arquivo .env não encontrado. Copie o .env.example para .env e configure as variáveis."
fi

log "Iniciando configuração do ambiente..."

# Carregar variáveis do .env
source .env

# Verificar variáveis obrigatórias
required_vars=("N8N_HOST" "EVOLUTION_HOST" "POSTGRES_PASSWORD" "N8N_BASIC_AUTH_PASSWORD" "AUTHENTICATION_API_KEY")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        error "Variável $var não está definida no arquivo .env"
    fi
done

log "Verificando dependências..."

# Verificar se Docker está instalado
if ! command -v docker &> /dev/null; then
    error "Docker não está instalado. Instale o Docker primeiro."
fi

# Verificar se Docker Compose está instalado
if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose não está instalado. Instale o Docker Compose primeiro."
fi

# Verificar se o usuário está no grupo docker
if ! groups $USER | grep &>/dev/null '\bdocker\b'; then
    warn "Usuário não está no grupo docker. Adicionando..."
    sudo usermod -aG docker $USER
    warn "Você precisa fazer logout e login novamente para que as alterações tenham efeito."
    warn "Ou execute: newgrp docker"
fi

log "Criando estrutura de diretórios..."

# Criar diretórios necessários
mkdir -p n8n/local-files data/{postgres,redis,n8n,evolution}

# Definir permissões corretas
chmod 755 n8n/local-files
chmod 700 data/postgres data/redis data/n8n data/evolution

log "Verificando configuração do proxy reverso..."

# Verificar se as portas estão livres para os containers
if lsof -Pi :5678 -sTCP:LISTEN -t >/dev/null 2>&1; then
    warn "Porta 5678 já está em uso. Certifique-se de que não há conflitos."
fi

if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    warn "Porta 8080 já está em uso. Certifique-se de que não há conflitos."
fi

log "Parando containers existentes se estiverem rodando..."

# Parar containers existentes se estiverem rodando
docker-compose down 2>/dev/null || true

log "Iniciando serviços..."

# Iniciar todos os serviços
docker-compose up -d

log "Aguardando serviços iniciarem..."
sleep 30

# Verificar se os serviços estão rodando
log "Verificando status dos serviços..."

services=("postgres" "redis" "n8n" "evolution-api")
all_healthy=true

for service in "${services[@]}"; do
    if docker-compose ps | grep -q "$service.*Up"; then
        log "✓ $service está rodando"
        
        # Verificar health check se disponível
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "no-healthcheck")
        if [ "$health_status" = "healthy" ]; then
            log "✓ $service está saudável"
        elif [ "$health_status" = "unhealthy" ]; then
            warn "✗ $service não está saudável"
            all_healthy=false
        elif [ "$health_status" = "starting" ]; then
            log "⏳ $service ainda está inicializando..."
        fi
    else
        warn "✗ $service não está rodando corretamente"
        all_healthy=false
        docker-compose logs $service | tail -10
    fi
done

# Verificar conectividade das portas
log "Verificando conectividade das portas..."

if curl -s http://localhost:5678/healthz >/dev/null 2>&1; then
    log "✓ n8n está respondendo na porta 5678"
else
    warn "✗ n8n não está respondendo na porta 5678"
    all_healthy=false
fi

if curl -s http://localhost:8080/manager >/dev/null 2>&1; then
    log "✓ Evolution API está respondendo na porta 8080"
else
    warn "✗ Evolution API não está respondendo na porta 8080"
    all_healthy=false
fi

log "Configuração concluída!"
echo
echo -e "${BLUE}=== INFORMAÇÕES DE ACESSO ===${NC}"
echo -e "${GREEN}n8n:${NC} https://$N8N_HOST"
echo -e "${GREEN}Evolution API:${NC} https://$EVOLUTION_HOST"
echo
echo -e "${BLUE}=== CREDENCIAIS ===${NC}"
echo -e "${GREEN}n8n usuário:${NC} $N8N_BASIC_AUTH_USER"
echo -e "${GREEN}n8n senha:${NC} $N8N_BASIC_AUTH_PASSWORD"
echo -e "${GREEN}Evolution API Key:${NC} $AUTHENTICATION_API_KEY"
echo
echo -e "${BLUE}=== PORTAS INTERNAS ===${NC}"
echo -e "${GREEN}n8n:${NC} localhost:5678"
echo -e "${GREEN}Evolution API:${NC} localhost:8080"
echo -e "${GREEN}PostgreSQL:${NC} localhost:5432"
echo -e "${GREEN}Redis:${NC} localhost:6379"
echo
echo -e "${BLUE}=== COMANDOS ÚTEIS ===${NC}"
echo -e "${GREEN}Ver logs:${NC} docker-compose logs -f [serviço]"
echo -e "${GREEN}Reiniciar serviços:${NC} docker-compose restart"
echo -e "${GREEN}Parar serviços:${NC} docker-compose down"
echo -e "${GREEN}Atualizar serviços:${NC} docker-compose pull && docker-compose up -d"
echo

if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}✓ Todos os serviços estão funcionando corretamente!${NC}"
    echo -e "${YELLOW}Certifique-se de que seu proxy reverso (Nginx) está configurado para encaminhar:${NC}"
    echo -e "${YELLOW}  - $N8N_HOST -> localhost:5678${NC}"
    echo -e "${YELLOW}  - $EVOLUTION_HOST -> localhost:8080${NC}"
else
    echo -e "${YELLOW}⚠ Alguns serviços podem não estar funcionando corretamente.${NC}"
    echo -e "${YELLOW}Aguarde alguns minutos e verifique os logs se necessário.${NC}"
fi

echo
echo -e "${YELLOW}Nota: Aguarde alguns minutos para que todos os serviços inicializem completamente.${NC}"

