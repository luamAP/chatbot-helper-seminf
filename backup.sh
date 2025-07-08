#!/bin/bash

# Script de backup automatizado para Evolution API + n8n
# Autor: Manus AI
# Data: $(date +%Y-%m-%d)

set -e  # Parar execução em caso de erro

# Configurações
BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

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

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml não encontrado. Execute este script no diretório do projeto."
fi

# Criar diretório de backup se não existir
mkdir -p "$BACKUP_DIR"

log "Iniciando backup em $BACKUP_DIR"

# Carregar variáveis do .env se existir
if [ -f ".env" ]; then
    source .env
fi

# Backup do PostgreSQL
log "Fazendo backup do PostgreSQL..."
docker-compose exec -T postgres pg_dump -U ${POSTGRES_USER:-chatbot_user} ${POSTGRES_DB:-chatbot_db} > "$BACKUP_DIR/postgres_backup_$DATE.sql"

if [ $? -eq 0 ]; then
    log "✓ Backup do PostgreSQL concluído"
    gzip "$BACKUP_DIR/postgres_backup_$DATE.sql"
    log "✓ Backup do PostgreSQL comprimido"
else
    error "Falha no backup do PostgreSQL"
fi

# Backup dos volumes Docker
log "Fazendo backup dos volumes Docker..."

# Obter o nome do projeto (diretório atual)
PROJECT_NAME=$(basename $(pwd))

volumes=("n8n_data" "evolution_data" "redis_data")
for volume in "${volumes[@]}"; do
    log "Fazendo backup do volume $volume..."
    docker run --rm -v ${PROJECT_NAME}_${volume}:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/${volume}_backup_$DATE.tar.gz -C /data .
    
    if [ $? -eq 0 ]; then
        log "✓ Backup do volume $volume concluído"
    else
        warn "Falha no backup do volume $volume"
    fi
done

# Backup dos arquivos de configuração
log "Fazendo backup dos arquivos de configuração..."
tar czf "$BACKUP_DIR/config_backup_$DATE.tar.gz" \
    docker-compose.yml \
    .env \
    init-db.sql \
    scripts/ \
    n8n/ \
    2>/dev/null || warn "Alguns arquivos de configuração podem não ter sido incluídos no backup"

log "✓ Backup dos arquivos de configuração concluído"

# Limpeza de backups antigos
log "Removendo backups antigos (mais de $RETENTION_DAYS dias)..."
find "$BACKUP_DIR" -name "*backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Verificar tamanho total dos backups
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log "Tamanho total dos backups: $BACKUP_SIZE"

# Listar backups criados hoje
log "Backups criados nesta execução:"
ls -lh "$BACKUP_DIR"/*_$DATE.*

log "Backup concluído com sucesso!"

# Opcional: Enviar backup para S3 ou outro storage remoto
# Descomente e configure conforme necessário
# log "Enviando backup para armazenamento remoto..."
# aws s3 sync "$BACKUP_DIR" s3://seu-bucket-backup/chatbot-helper/ --delete

echo
echo -e "${BLUE}=== RESUMO DO BACKUP ===${NC}"
echo -e "${GREEN}Data/Hora:${NC} $(date)"
echo -e "${GREEN}Localização:${NC} $BACKUP_DIR"
echo -e "${GREEN}Arquivos criados:${NC}"
echo -e "  - postgres_backup_$DATE.sql.gz"
echo -e "  - n8n_data_backup_$DATE.tar.gz"
echo -e "  - evolution_data_backup_$DATE.tar.gz"
echo -e "  - redis_data_backup_$DATE.tar.gz"
echo -e "  - config_backup_$DATE.tar.gz"
echo
echo -e "${YELLOW}Para restaurar um backup, use o script restore.sh${NC}"

