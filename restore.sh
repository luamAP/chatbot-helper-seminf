#!/bin/bash

# Script de restauração de backup para Evolution API + n8n
# Autor: Manus AI
# Data: $(date +%Y-%m-%d)

set -e  # Parar execução em caso de erro

# Configurações
BACKUP_DIR="/home/ubuntu/backups"

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

# Função para mostrar ajuda
show_help() {
    echo "Uso: $0 [DATA_BACKUP]"
    echo
    echo "DATA_BACKUP: Data do backup no formato YYYYMMDD_HHMMSS"
    echo "             Se não especificada, será mostrada uma lista de backups disponíveis"
    echo
    echo "Exemplos:"
    echo "  $0                    # Listar backups disponíveis"
    echo "  $0 20250708_143022    # Restaurar backup específico"
    echo
}

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml não encontrado. Execute este script no diretório do projeto."
fi

# Verificar se o diretório de backup existe
if [ ! -d "$BACKUP_DIR" ]; then
    error "Diretório de backup não encontrado: $BACKUP_DIR"
fi

# Se nenhum argumento foi fornecido, listar backups disponíveis
if [ $# -eq 0 ]; then
    echo -e "${BLUE}=== BACKUPS DISPONÍVEIS ===${NC}"
    echo
    
    # Listar backups por data
    for backup in $(ls "$BACKUP_DIR"/postgres_backup_*.sql.gz 2>/dev/null | sort -r); do
        backup_date=$(basename "$backup" | sed 's/postgres_backup_\(.*\)\.sql\.gz/\1/')
        backup_size=$(du -sh "$backup" | cut -f1)
        backup_time=$(date -d "${backup_date:0:8} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}" "+%d/%m/%Y %H:%M:%S" 2>/dev/null || echo "Data inválida")
        
        echo -e "${GREEN}Data do backup:${NC} $backup_date"
        echo -e "${GREEN}Data/Hora:${NC} $backup_time"
        echo -e "${GREEN}Tamanho:${NC} $backup_size"
        echo
    done
    
    if [ ! -f "$BACKUP_DIR"/postgres_backup_*.sql.gz ]; then
        echo "Nenhum backup encontrado em $BACKUP_DIR"
    fi
    
    echo "Para restaurar um backup, execute: $0 [DATA_BACKUP]"
    exit 0
fi

# Verificar argumentos
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

BACKUP_DATE="$1"

# Verificar se o backup existe
POSTGRES_BACKUP="$BACKUP_DIR/postgres_backup_${BACKUP_DATE}.sql.gz"
if [ ! -f "$POSTGRES_BACKUP" ]; then
    error "Backup não encontrado: $POSTGRES_BACKUP"
fi

log "Iniciando restauração do backup: $BACKUP_DATE"

# Carregar variáveis do .env se existir
if [ -f ".env" ]; then
    source .env
fi

# Confirmação do usuário
echo -e "${RED}ATENÇÃO: Esta operação irá substituir todos os dados atuais!${NC}"
echo -e "${YELLOW}Backup a ser restaurado: $BACKUP_DATE${NC}"
echo
read -p "Tem certeza que deseja continuar? (digite 'sim' para confirmar): " confirm

if [ "$confirm" != "sim" ]; then
    log "Operação cancelada pelo usuário"
    exit 0
fi

# Parar todos os serviços
log "Parando todos os serviços..."
docker-compose down

# Aguardar containers pararem completamente
sleep 5

# Remover volumes existentes (CUIDADO!)
log "Removendo volumes existentes..."
docker volume rm chatbot-helper_n8n_data 2>/dev/null || true
docker volume rm chatbot-helper_evolution_data 2>/dev/null || true
docker volume rm chatbot-helper_redis_data 2>/dev/null || true
docker volume rm chatbot-helper_postgres_data 2>/dev/null || true

# Recriar volumes
log "Recriando volumes..."
docker volume create chatbot-helper_n8n_data
docker volume create chatbot-helper_evolution_data
docker volume create chatbot-helper_redis_data
docker volume create chatbot-helper_postgres_data

# Iniciar apenas PostgreSQL para restauração
log "Iniciando PostgreSQL para restauração..."
docker-compose up -d postgres

# Aguardar PostgreSQL inicializar
log "Aguardando PostgreSQL inicializar..."
sleep 30

# Verificar se PostgreSQL está pronto
for i in {1..30}; do
    if docker-compose exec postgres pg_isready -U ${POSTGRES_USER:-chatbot_user} -d ${POSTGRES_DB:-chatbot_db} >/dev/null 2>&1; then
        log "PostgreSQL está pronto"
        break
    fi
    
    if [ $i -eq 30 ]; then
        error "PostgreSQL não inicializou dentro do tempo esperado"
    fi
    
    log "Aguardando PostgreSQL... ($i/30)"
    sleep 2
done

# Restaurar backup do PostgreSQL
log "Restaurando backup do PostgreSQL..."
gunzip -c "$POSTGRES_BACKUP" | docker-compose exec -T postgres psql -U ${POSTGRES_USER:-chatbot_user} -d ${POSTGRES_DB:-chatbot_db}

if [ $? -eq 0 ]; then
    log "✓ Backup do PostgreSQL restaurado com sucesso"
else
    error "Falha na restauração do backup do PostgreSQL"
fi

# Restaurar volumes Docker
volumes=("n8n_data" "evolution_data" "redis_data")
for volume in "${volumes[@]}"; do
    volume_backup="$BACKUP_DIR/${volume}_backup_${BACKUP_DATE}.tar.gz"
    
    if [ -f "$volume_backup" ]; then
        log "Restaurando volume $volume..."
        docker run --rm -v chatbot-helper_${volume}:/data -v "$BACKUP_DIR":/backup alpine tar xzf /backup/${volume}_backup_${BACKUP_DATE}.tar.gz -C /data
        
        if [ $? -eq 0 ]; then
            log "✓ Volume $volume restaurado com sucesso"
        else
            warn "Falha na restauração do volume $volume"
        fi
    else
        warn "Backup do volume $volume não encontrado: $volume_backup"
    fi
done

# Restaurar arquivos de configuração
config_backup="$BACKUP_DIR/config_backup_${BACKUP_DATE}.tar.gz"
if [ -f "$config_backup" ]; then
    log "Restaurando arquivos de configuração..."
    tar xzf "$config_backup"
    log "✓ Arquivos de configuração restaurados"
else
    warn "Backup de configuração não encontrado: $config_backup"
fi

# Restaurar certificados SSL
ssl_backup="$BACKUP_DIR/ssl_certs_backup_${BACKUP_DATE}.tar.gz"
if [ -f "$ssl_backup" ]; then
    log "Restaurando certificados SSL..."
    tar xzf "$ssl_backup"
    log "✓ Certificados SSL restaurados"
else
    warn "Backup de certificados SSL não encontrado: $ssl_backup"
fi

# Iniciar todos os serviços
log "Iniciando todos os serviços..."
docker-compose up -d

# Aguardar serviços iniciarem
log "Aguardando serviços iniciarem..."
sleep 30

# Verificar se os serviços estão rodando
log "Verificando status dos serviços..."
services=("postgres" "redis" "n8n" "evolution-api" "nginx")
all_running=true

for service in "${services[@]}"; do
    if docker-compose ps | grep -q "$service.*Up"; then
        log "✓ $service está rodando"
    else
        warn "✗ $service não está rodando corretamente"
        all_running=false
    fi
done

if [ "$all_running" = true ]; then
    log "Restauração concluída com sucesso!"
    echo
    echo -e "${BLUE}=== INFORMAÇÕES DE ACESSO ===${NC}"
    echo -e "${GREEN}n8n:${NC} https://${N8N_HOST:-n8n-chatbot-server.duckdns.org}"
    echo -e "${GREEN}Evolution API:${NC} https://${EVOLUTION_HOST:-evo-chatbot-server.duckdns.org}"
    echo
    echo -e "${YELLOW}Aguarde alguns minutos para que todos os serviços inicializem completamente.${NC}"
else
    warn "Alguns serviços podem não estar funcionando corretamente. Verifique os logs:"
    echo "docker-compose logs [nome_do_servico]"
fi

