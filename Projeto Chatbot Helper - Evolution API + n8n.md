# Projeto Chatbot Helper - Evolution API + n8n

## 📋 Visão Geral

Este projeto fornece uma solução completa para configurar um ambiente de chatbot helper utilizando Evolution API e n8n em uma VPS EC2 (Ubuntu), com Nginx como proxy reverso, PostgreSQL como banco de dados, Redis para cache/fila, e certificados SSL automáticos via Let's Encrypt.

## 🏗️ Arquitetura

```
Internet
    ↓
[Nginx Proxy Reverso + SSL]
    ↓
┌─────────────────┬─────────────────┐
│      n8n        │  Evolution API  │
│   (Port 5678)   │   (Port 8080)   │
└─────────────────┴─────────────────┘
    ↓                       ↓
┌─────────────────┬─────────────────┐
│   PostgreSQL    │     Redis       │
│   (Port 5432)   │   (Port 6379)   │
└─────────────────┴─────────────────┘
```

## 🚀 Início Rápido

### 1. Preparação do Ambiente

```bash
# Clone ou baixe os arquivos do projeto
git clone <seu-repositorio> chatbot-helper
cd chatbot-helper

# Copie o arquivo de exemplo de variáveis de ambiente
cp .env.example .env

# Edite o arquivo .env com suas configurações
nano .env
```

### 2. Configuração das Variáveis

Edite o arquivo `.env` com suas informações:

```env
# Configurações de Domínio
N8N_HOST=n8n-chatbot-server.duckdns.org
EVOLUTION_HOST=evo-chatbot-server.duckdns.org
N8N_PROTOCOL=https

# Configurações do PostgreSQL
POSTGRES_DB=chatbot_db
POSTGRES_USER=chatbot_user
POSTGRES_PASSWORD=SUA_SENHA_FORTE_POSTGRES

# Configurações do n8n
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=SUA_SENHA_FORTE_N8N

# Configurações da Evolution API
AUTHENTICATION_API_KEY=SUA_CHAVE_API_EVOLUTION_FORTE

# Email para certificados SSL
CERTBOT_EMAIL=seu_email@example.com
```

### 3. Execução Automatizada

```bash
# Torne o script executável
chmod +x scripts/setup.sh

# Execute a configuração automatizada
./scripts/setup.sh
```

## 📁 Estrutura do Projeto

```
chatbot-helper/
├── docker-compose.yml          # Orquestração dos containers
├── .env.example               # Exemplo de variáveis de ambiente
├── .env                       # Suas variáveis de ambiente (criar)
├── init-db.sql               # Script de inicialização do PostgreSQL
├── nginx/
│   └── conf.d/
│       ├── default.conf       # Configuração inicial do Nginx
│       ├── n8n.conf          # Configuração do n8n
│       └── evolution-api.conf # Configuração da Evolution API
├── scripts/
│   ├── setup.sh              # Script de configuração automatizada
│   ├── backup.sh             # Script de backup
│   └── restore.sh            # Script de restauração
├── certbot/
│   ├── conf/                 # Certificados SSL
│   └── www/                  # Validação Let's Encrypt
├── n8n/
│   └── local-files/          # Arquivos locais do n8n
└── README_COMPLETO.md        # Este arquivo
```

## 🔧 Configuração Manual

Se preferir configurar manualmente:

### 1. Instalar Docker e Docker Compose

```bash
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Criar Estrutura de Diretórios

```bash
mkdir -p nginx/conf.d nginx/ssl certbot/conf certbot/www n8n/local-files
```

### 3. Configurar Nginx Inicial

Use a configuração em `nginx/conf.d/default.conf` para obter certificados SSL inicialmente.

### 4. Obter Certificados SSL

```bash
docker-compose up -d nginx
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email seu_email@example.com \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d n8n-chatbot-server.duckdns.org \
    -d evo-chatbot-server.duckdns.org
```

### 5. Iniciar Todos os Serviços

```bash
docker-compose down
docker-compose up -d
```

## 🔐 Acesso aos Serviços

Após a configuração completa:

- **n8n**: https://n8n-chatbot-server.duckdns.org
- **Evolution API**: https://evo-chatbot-server.duckdns.org

### Credenciais Padrão

- **n8n**: Usuário e senha definidos no arquivo `.env`
- **Evolution API**: Chave de API definida no arquivo `.env`

## 🛠️ Comandos Úteis

### Gerenciamento de Serviços

```bash
# Ver status dos serviços
docker-compose ps

# Ver logs de um serviço específico
docker-compose logs -f n8n
docker-compose logs -f evolution-api

# Reiniciar um serviço
docker-compose restart n8n

# Parar todos os serviços
docker-compose down

# Iniciar todos os serviços
docker-compose up -d

# Atualizar containers
docker-compose pull
docker-compose up -d
```

### Backup e Restauração

```bash
# Fazer backup completo
./scripts/backup.sh

# Listar backups disponíveis
./scripts/restore.sh

# Restaurar backup específico
./scripts/restore.sh 20250708_143022
```

### Monitoramento

```bash
# Verificar uso de recursos
docker stats

# Verificar logs do Nginx
docker-compose logs nginx

# Testar configuração do Nginx
docker-compose exec nginx nginx -t

# Recarregar configuração do Nginx
docker-compose exec nginx nginx -s reload
```

## 🔍 Solução de Problemas

### Problemas Comuns

**1. Certificados SSL não funcionam:**
- Verifique se os domínios apontam para o IP correto
- Confirme que as portas 80 e 443 estão abertas
- Verifique logs do Certbot: `docker-compose logs certbot`

**2. n8n não carrega:**
- Verifique se o PostgreSQL está rodando: `docker-compose ps postgres`
- Confirme as credenciais no arquivo `.env`
- Verifique logs: `docker-compose logs n8n`

**3. Evolution API não conecta:**
- Verifique se o Redis está rodando: `docker-compose ps redis`
- Confirme a chave de API no arquivo `.env`
- Verifique logs: `docker-compose logs evolution-api`

### Comandos de Diagnóstico

```bash
# Verificar conectividade entre serviços
docker-compose exec n8n ping postgres
docker-compose exec evolution-api ping redis

# Verificar portas abertas
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Verificar espaço em disco
df -h

# Verificar logs do sistema
sudo journalctl -u docker
```

## 🔄 Atualizações

### Atualizar Containers

```bash
# Fazer backup antes da atualização
./scripts/backup.sh

# Baixar novas versões
docker-compose pull

# Atualizar serviços
docker-compose up -d

# Verificar se tudo está funcionando
docker-compose ps
```

### Atualizar Sistema Operacional

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot  # Se necessário
```

## 🔒 Segurança

### Configurações Recomendadas

1. **Firewall**: Configure apenas as portas necessárias (22, 80, 443)
2. **Senhas**: Use senhas fortes e únicas para todos os serviços
3. **Atualizações**: Mantenha o sistema e containers atualizados
4. **Backup**: Configure backups automáticos regulares
5. **Monitoramento**: Implemente monitoramento de logs e alertas

### Hardening Adicional

```bash
# Configurar fail2ban para SSH
sudo apt install fail2ban

# Configurar firewall UFW
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

## 📊 Monitoramento

### Health Checks

Todos os serviços incluem health checks automáticos:

- **PostgreSQL**: Verifica conectividade do banco
- **Redis**: Testa comando PING
- **n8n**: Verifica endpoint /healthz
- **Evolution API**: Testa endpoint /manager

### Logs

Logs são organizados por serviço:

```bash
# Logs do Nginx
docker-compose logs nginx

# Logs específicos por aplicação
tail -f /var/log/nginx/n8n_access.log
tail -f /var/log/nginx/evolution_access.log
```

## 🤝 Integração n8n + Evolution API

### Configuração de Webhooks

1. No n8n, crie um workflow com trigger "Webhook"
2. Configure a URL do webhook na Evolution API
3. Use a chave de API para autenticação

### Exemplo de Integração

```javascript
// No n8n, para fazer requisições à Evolution API
const headers = {
  'apikey': 'SUA_CHAVE_API_EVOLUTION',
  'Content-Type': 'application/json'
};

const response = await $http.request({
  method: 'POST',
  url: 'https://evo-chatbot-server.duckdns.org/message/sendText/instance',
  headers: headers,
  body: {
    number: '5511999999999',
    text: 'Mensagem automática do n8n!'
  }
});
```

## 📈 Performance

### Recursos Recomendados

Para operação otimizada:

- **CPU**: 4 vCPUs ou mais
- **RAM**: 8 GB ou mais
- **Armazenamento**: 50 GB SSD ou mais
- **Rede**: Conexão estável com boa largura de banda

### Otimizações

```bash
# Ajustar configurações do PostgreSQL
docker-compose exec postgres psql -U chatbot_user -d chatbot_db -c "
ALTER SYSTEM SET shared_buffers = '2GB';
ALTER SYSTEM SET effective_cache_size = '6GB';
SELECT pg_reload_conf();
"

# Configurar limite de memória do Redis
# Edite docker-compose.yml para adicionar:
# command: redis-server --maxmemory 1gb --maxmemory-policy allkeys-lru
```

## 📞 Suporte

### Documentação Oficial

- [Evolution API](https://doc.evolution-api.com/)
- [n8n](https://docs.n8n.io/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Nginx](https://nginx.org/en/docs/)

### Logs para Suporte

Ao solicitar suporte, inclua:

```bash
# Informações do sistema
uname -a
docker --version
docker-compose --version

# Status dos serviços
docker-compose ps

# Logs relevantes
docker-compose logs --tail=50 [serviço-com-problema]
```

## 📝 Licença

Este projeto é fornecido "como está" para fins educacionais e de desenvolvimento. Use por sua própria conta e risco.

## 🙏 Créditos

- **Evolution API**: Projeto open-source para integração WhatsApp
- **n8n**: Ferramenta de automação de workflows
- **Docker**: Plataforma de containerização
- **Nginx**: Servidor web e proxy reverso
- **Let's Encrypt**: Certificados SSL gratuitos

---

**Desenvolvido por:** Manus AI  
**Data:** 2025-07-08  
**Versão:** 1.0

