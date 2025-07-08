# Guia de Configuração: Evolution API e n8n com Docker Compose no Ubuntu EC2

Este guia detalhado irá auxiliá-lo na configuração da Evolution API e do n8n em uma instância Amazon EC2 (Ubuntu), utilizando Docker Compose para orquestração, PostgreSQL como banco de dados e Redis para cache/fila. Assume-se que você já possui um proxy reverso (como Nginx) configurado para gerenciar o tráfego HTTPS para os domínios `n8n-chatbot-server.duckdns.org` e `evo-chatbot-server.duckdns.org`.

## 1. Visão Geral da Arquitetura

Nossa arquitetura será composta pelos seguintes componentes, cada um rodando em seu próprio container Docker e orquestrado pelo Docker Compose:

- **Evolution API**: A API principal para comunicação com o WhatsApp.
- **n8n**: A ferramenta de automação de fluxo de trabalho.
- **PostgreSQL**: Banco de dados relacional para persistência de dados de ambos os serviços.
- **Redis**: Servidor de cache e fila, utilizado por ambos os serviços para otimização de desempenho e comunicação.

Todos esses serviços serão interconectados dentro de uma rede Docker definida no `docker-compose.yml`.

## 2. Pré-requisitos

Antes de iniciar, certifique-se de ter os seguintes pré-requisitos:

- Uma instância Amazon EC2 com Ubuntu (20.04 LTS ou superior) em execução.
- Acesso SSH à sua instância EC2.
- **Nginx ou outro proxy reverso já configurado** para os domínios `n8n-chatbot-server.duckdns.org` (apontando para a porta interna do n8n, e.g., 5678) e `evo-chatbot-server.duckdns.org` (apontando para a porta interna da Evolution API, e.g., 8080).
- Portas 80 (HTTP) e 443 (HTTPS) já gerenciadas pelo seu proxy reverso.

## 3. Instalação do Docker e Docker Compose

Conecte-se à sua instância EC2 via SSH e execute os seguintes comandos para instalar o Docker e o Docker Compose:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker
```

Verifique as instalações:

```bash
docker --version
docker-compose --version
```

## 4. Estrutura de Diretórios do Projeto

Crie uma estrutura de diretórios para o seu projeto:

```bash
mkdir -p ~/chatbot-helper/data/n8n
mkdir -p ~/chatbot-helper/data/postgres
mkdir -p ~/chatbot-helper/data/evolution
mkdir -p ~/chatbot-helper/n8n/local-files
cd ~/chatbot-helper
```

- `~/chatbot-helper/`: Diretório raiz do projeto.
- `~/chatbot-helper/data/n8n/`: Persistência de dados do n8n.
- `~/chatbot-helper/data/postgres/`: Persistência de dados do PostgreSQL.
- `~/chatbot-helper/data/evolution/`: Persistência de dados da Evolution API.
- `~/chatbot-helper/n8n/local-files/`: Diretório para arquivos locais do n8n.

## 5. Configuração do Arquivo `.env`

Crie um arquivo `.env` na raiz do diretório `~/chatbot-helper` com as variáveis de ambiente necessárias. Substitua os valores `SUA_SENHA_FORTE`, `SEU_USUARIO_N8N`, `SUA_SENHA_N8N` e `SUA_CHAVE_API_EVOLUTION` por valores seguros e únicos.

```env
# Variáveis para PostgreSQL
POSTGRES_DB=chatbot_db
POSTGRES_USER=chatbot_user
POSTGRES_PASSWORD=SUA_SENHA_FORTE

# Variáveis para n8n
N8N_HOST=n8n-chatbot-server.duckdns.org
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_BASIC_AUTH_USER=SEU_USUARIO_N8N
N8N_BASIC_AUTH_PASSWORD=SUA_SENHA_N8N
N8N_DB_TYPE=postgresdb
N8N_DB_POSTGRESDB_HOST=postgres
N8N_DB_POSTGRESDB_PORT=5432
N8N_DB_POSTGRESDB_DATABASE=chatbot_db
N8N_DB_POSTGRESDB_USER=chatbot_user
N8N_DB_POSTGRESDB_PASSWORD=SUA_SENHA_FORTE
N8N_REDIS_HOST=redis
N8N_REDIS_PORT=6379
N8N_REDIS_PASSWORD=
N8N_EDITOR_BASE_URL=https://n8n-chatbot-server.duckdns.org/

# Variáveis para Evolution API
EVOLUTION_HOST=evo-chatbot-server.duckdns.org
EVOLUTION_PORT=8080
EVOLUTION_PROTOCOL=https
AUTHENTICATION_API_KEY=SUA_CHAVE_API_EVOLUTION
DATABASE_ENABLED=true
DATABASE_PROVIDER=postgresql
DATABASE_CONNECTION_URI=postgresql://chatbot_user:SUA_SENHA_FORTE@postgres:5432/chatbot_db
CACHE_REDIS_ENABLED=true
CACHE_REDIS_URI=redis://redis:6379/1
CACHE_REDIS_PREFIX_KEY=evolution_v2
```

## 6. Configuração do Docker Compose (`docker-compose.yml`)

Crie um arquivo `docker-compose.yml` na raiz do diretório `~/chatbot-helper`. Este arquivo definirá todos os serviços, redes e volumes necessários.

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:13-alpine
    container_name: postgres
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    ports:
      - "5432:5432"
    restart: always
    networks:
      - chatbot-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:6-alpine
    container_name: redis
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    restart: always
    networks:
      - chatbot-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    environment:
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=5678
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - QUEUE_BULL_REDIS_DB=2
      - N8N_EDITOR_BASE_URL=https://${N8N_HOST}
      - WEBHOOK_URL=https://${N8N_HOST}/
      - GENERIC_TIMEZONE=America/Sao_Paulo
      - N8N_METRICS=true
      - N8N_LOG_LEVEL=info
    volumes:
      - n8n_data:/home/node/.n8n
      - ./n8n/local-files:/files
    ports:
      - "5678:5678" # Expor porta para o proxy reverso
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: always
    networks:
      - chatbot-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3

  evolution-api:
    image: atendai/evolution-api:v2.1.1
    container_name: evolution_api
    environment:
      - AUTHENTICATION_API_KEY=${AUTHENTICATION_API_KEY}
      - SERVER_URL=https://${EVOLUTION_HOST}
      - DEL_INSTANCE=false
      - DATABASE_ENABLED=true
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      - DATABASE_SAVE_DATA_INSTANCE=true
      - DATABASE_SAVE_DATA_NEW_MESSAGE=true
      - DATABASE_SAVE_MESSAGE_UPDATE=true
      - DATABASE_SAVE_DATA_CONTACTS=true
      - DATABASE_SAVE_DATA_CHATS=true
      - DATABASE_SAVE_DATA_LABELS=true
      - DATABASE_SAVE_DATA_HISTORIC=true
      - DATABASE_CONNECTION_CLIENT_NAME=evolution_v2
      - CACHE_REDIS_ENABLED=true
      - CACHE_REDIS_URI=redis://redis:6379/1
      - CACHE_REDIS_PREFIX_KEY=evolution_v2
      - CACHE_REDIS_SAVE_INSTANCES=false
      - CACHE_LOCAL_ENABLED=false
      - RABBITMQ_ENABLED=false
      - WEBHOOK_GLOBAL_URL=
      - WEBHOOK_GLOBAL_ENABLED=false
      - WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS=false
      - CONFIG_SESSION_PHONE_CLIENT=Evolution API
      - CONFIG_SESSION_PHONE_NAME=Chrome
      - QRCODE_LIMIT=30
      - TYPEBOT_ENABLED=false
      - CHATWOOT_ENABLED=false
      - OPENAI_ENABLED=false
      - DIFY_ENABLED=false
      - LOG_LEVEL=ERROR
      - LOG_COLOR=true
      - LOG_BAILEYS=error
    volumes:
      - evolution_data:/evolution/instances
      - evolution_data:/evolution/store
    ports:
      - "8080:8080" # Expor porta para o proxy reverso
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: always
    networks:
      - chatbot-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/manager"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  n8n_data:
    driver: local
  evolution_data:
    driver: local

networks:
  chatbot-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

**Observações sobre o `docker-compose.yml`:**

- **`ports`**: As portas `5678` (n8n) e `8080` (Evolution API) são expostas para que seu proxy reverso (Nginx) possa acessá-las. Certifique-se de que seu Nginx esteja configurado para encaminhar o tráfego HTTPS dos seus domínios para essas portas internas.
- **`postgres` e `redis`**: Serviços de banco de dados e cache/fila, respectivamente, com volumes para persistência de dados.
- **`n8n`**: Configurado para usar PostgreSQL e Redis, com variáveis de ambiente para autenticação e URLs. O `WEBHOOK_URL` é crucial para o funcionamento correto dos webhooks do n8n.
- **`evolution-api`**: Configurado para usar PostgreSQL e Redis, com a chave de API e a URL do servidor.
- **`volumes`**: Define volumes nomeados para persistência de dados, garantindo que seus dados não sejam perdidos ao recriar os containers.
- **`networks`**: Todos os serviços estão na rede `chatbot-network` do Docker Compose, permitindo que se comuniquem usando seus nomes de serviço (ex: `postgres`, `redis`).

## 7. Geração de Parâmetros Diffie-Hellman (Opcional, se seu Nginx não tiver)

Se o seu Nginx ainda não tiver, para aumentar a segurança SSL/TLS, gere um arquivo `ssl-dhparams.pem`. Isso pode levar alguns minutos. Este passo é geralmente feito uma única vez no servidor Nginx.

```bash
sudo openssl dhparam -out /etc/nginx/ssl/ssl-dhparams.pem 2048
```

## 8. Início dos Serviços

Após configurar o arquivo `.env` e o `docker-compose.yml`, e ter certeza de que seu Nginx está apontando corretamente para as portas internas dos serviços (5678 para n8n e 8080 para Evolution API), você pode iniciar os serviços:

```bash
cd ~/chatbot-helper
docker-compose up -d
```

## 9. Acesso aos Serviços

Após todos os serviços estarem em execução, você poderá acessar:

- **n8n**: `https://n8n-chatbot-server.duckdns.org/`
- **Evolution API**: `https://evo-chatbot-server.duckdns.org/`

Lembre-se de que a primeira vez que você acessar o n8n, ele pode levar um tempo para inicializar o banco de dados. Utilize as credenciais definidas no seu arquivo `.env` para o n8n.

## 10. Solução de Problemas

- **Verificar logs**: Use `docker-compose logs <nome_do_servico>` (ex: `docker-compose logs n8n`) para verificar os logs de um serviço específico.
- **Reiniciar serviços**: `docker-compose restart <nome_do_servico>`.
- **Reconstruir containers**: Se houver alterações no `docker-compose.yml` ou nos Dockerfiles, use `docker-compose up -d --build`.
- **Problemas de conexão**: Verifique se as portas `5678` e `8080` estão acessíveis pelo seu proxy reverso e se as configurações de proxy estão corretas.

Este guia fornece uma base sólida para a sua configuração. Ajustes adicionais podem ser necessários dependendo das suas necessidades específicas e da versão exata das aplicações.


## 11. Configuração Detalhada dos Serviços

### 11.1 PostgreSQL - Configuração e Otimização

O PostgreSQL serve como banco de dados principal para ambos os serviços, n8n e Evolution API. A configuração otimizada garante performance adequada e confiabilidade dos dados. O arquivo `init-db.sql` inclui configurações específicas para melhorar a performance do banco de dados em um ambiente de produção.

As configurações de performance incluem ajustes na memória compartilhada (`shared_buffers`), cache efetivo (`effective_cache_size`), e configurações de checkpoint para otimizar a escrita em disco. O valor de `max_connections` foi definido como 200 para suportar múltiplas conexões simultâneas dos dois serviços.

A extensão `uuid-ossp` é habilitada para suporte a UUIDs, que são amplamente utilizados tanto pelo n8n quanto pela Evolution API para identificação única de registros. A extensão `pgcrypto` fornece funções criptográficas adicionais que podem ser úteis para operações de segurança.

### 11.2 Redis - Cache e Fila de Mensagens

O Redis atua como sistema de cache e fila de mensagens para ambos os serviços. Para o n8n, o Redis é utilizado principalmente para o sistema de filas Bull, que gerencia a execução de workflows em background. A configuração `QUEUE_BULL_REDIS_DB=2` especifica que o n8n utilizará o banco de dados 2 do Redis, evitando conflitos com outros usos.

Para a Evolution API, o Redis serve como cache para sessões do WhatsApp e dados temporários. A configuração `CACHE_REDIS_URI=redis://redis:6379/1` indica que a Evolution API utilizará o banco de dados 1 do Redis, mantendo a separação lógica dos dados.

O comando `redis-server --appendonly yes` habilita a persistência AOF (Append Only File), garantindo que os dados não sejam perdidos em caso de reinicialização do container. Esta configuração é crucial para manter a integridade das sessões do WhatsApp e dos dados de fila do n8n.

### 11.3 n8n - Automação de Workflows

O n8n é configurado com autenticação básica habilitada através das variáveis `N8N_BASIC_AUTH_ACTIVE=true`, `N8N_BASIC_AUTH_USER` e `N8N_BASIC_AUTH_PASSWORD`. Esta camada de segurança é essencial para proteger o acesso à interface de administração.

A configuração de banco de dados utiliza PostgreSQL como backend principal através das variáveis `DB_TYPE=postgresdb` e as respectivas configurações de conexão. Isso garante que todos os workflows, credenciais e dados de execução sejam persistidos de forma confiável.

O `WEBHOOK_URL` é configurado para usar HTTPS, garantindo que todos os webhooks gerados pelo n8n utilizem conexões seguras. A variável `N8N_EDITOR_BASE_URL` define a URL base para o editor, importante para o funcionamento correto da interface web.

As configurações de timezone (`GENERIC_TIMEZONE=America/Sao_Paulo`) garantem que todas as execuções de workflow utilizem o fuso horário correto, crucial para automações que dependem de horários específicos.

### 11.4 Evolution API - Integração WhatsApp

A Evolution API é configurada com uma chave de autenticação forte através da variável `AUTHENTICATION_API_KEY`. Esta chave é utilizada para autenticar todas as requisições à API, garantindo que apenas aplicações autorizadas possam interagir com o serviço.

A configuração de banco de dados utiliza a mesma instância PostgreSQL compartilhada, mas com configurações específicas para otimizar o armazenamento de mensagens, contatos e histórico de conversas. As variáveis `DATABASE_SAVE_DATA_*` controlam quais tipos de dados são persistidos no banco.

O Redis é configurado para cache de instâncias e sessões através das variáveis `CACHE_REDIS_ENABLED=true` e `CACHE_REDIS_URI`. O prefixo `CACHE_REDIS_PREFIX_KEY=evolution_v2` garante que as chaves do Redis sejam organizadas de forma hierárquica.

As configurações de log (`LOG_LEVEL=ERROR`, `LOG_BAILEYS=error`) são otimizadas para produção, reduzindo a verbosidade dos logs e focando apenas em erros críticos. Isso melhora a performance e reduz o uso de espaço em disco.

## 12. Configuração do Proxy Reverso (Nginx)

Como você já possui um proxy reverso configurado, é importante garantir que ele esteja corretamente direcionando o tráfego para os containers Docker. Aqui estão as configurações de referência que seu Nginx deve ter:

### 12.1 Configuração para n8n

Seu Nginx deve ter uma configuração similar a esta para o domínio `n8n-chatbot-server.duckdns.org`:

```nginx
upstream n8n_backend {
    server localhost:5678;
    keepalive 32;
}

server {
    listen 443 ssl http2;
    server_name n8n-chatbot-server.duckdns.org;

    # Suas configurações SSL aqui

    location / {
        proxy_pass http://n8n_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_redirect off;
        
        client_max_body_size 50M;
    }
}
```

### 12.2 Configuração para Evolution API

Para o domínio `evo-chatbot-server.duckdns.org`:

```nginx
upstream evolution_backend {
    server localhost:8080;
    keepalive 32;
}

server {
    listen 443 ssl http2;
    server_name evo-chatbot-server.duckdns.org;

    # Suas configurações SSL aqui

    location / {
        proxy_pass http://evolution_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_redirect off;
        
        client_max_body_size 100M;
    }
}
```

## 13. Monitoramento e Logs

### 13.1 Health Checks

Cada serviço no Docker Compose inclui configurações de health check para monitoramento automático do status:

```yaml
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5678/healthz"]
  interval: 30s
  timeout: 10s
  retries: 3
```

Os health checks verificam a disponibilidade dos serviços a cada 30 segundos, permitindo que o Docker Compose detecte e reinicie automaticamente serviços que não estejam respondendo adequadamente.

### 13.2 Logs dos Serviços

Para monitorar os logs dos serviços, utilize os seguintes comandos:

```bash
# Ver logs de todos os serviços
docker-compose logs -f

# Ver logs de um serviço específico
docker-compose logs -f n8n
docker-compose logs -f evolution-api
docker-compose logs -f postgres
docker-compose logs -f redis

# Ver apenas as últimas 50 linhas
docker-compose logs --tail=50 n8n
```

### 13.3 Monitoramento de Performance

Para monitorar o uso de recursos dos containers:

```bash
# Ver estatísticas em tempo real
docker stats

# Ver uso de espaço dos volumes
docker system df

# Verificar status dos serviços
docker-compose ps
```

## 14. Backup e Recuperação

### 14.1 Backup do PostgreSQL

O backup regular do banco de dados PostgreSQL é crucial para a continuidade do negócio. Crie um script de backup automatizado:

```bash
#!/bin/bash
BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

# Backup do PostgreSQL
docker-compose exec -T postgres pg_dump -U chatbot_user chatbot_db > "$BACKUP_DIR/postgres_backup_$DATE.sql"

# Comprimir o backup
gzip "$BACKUP_DIR/postgres_backup_$DATE.sql"

echo "Backup concluído: postgres_backup_$DATE.sql.gz"
```

### 14.2 Backup dos Volumes Docker

Os volumes Docker contêm dados importantes que devem ser incluídos no backup:

```bash
#!/bin/bash
BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup dos volumes
docker run --rm -v chatbot-helper_n8n_data:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/n8n_data_backup_$DATE.tar.gz -C /data .
docker run --rm -v chatbot-helper_evolution_data:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/evolution_data_backup_$DATE.tar.gz -C /data .
docker run --rm -v chatbot-helper_redis_data:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/redis_data_backup_$DATE.tar.gz -C /data .
```

### 14.3 Estratégia de Recuperação

Em caso de falha, a recuperação deve seguir uma sequência específica:

1. Parar todos os serviços: `docker-compose down`
2. Restaurar volumes Docker ou dados de backup
3. Iniciar serviços de infraestrutura: `docker-compose up -d postgres redis`
4. Aguardar inicialização completa dos bancos de dados
5. Iniciar serviços de aplicação: `docker-compose up -d n8n evolution-api`
6. Verificar integridade dos dados e funcionalidade

## 15. Segurança e Melhores Práticas

### 15.1 Firewall e Rede

Configure o firewall da instância EC2 para permitir apenas as portas necessárias:

- Porta 22: SSH (restrita ao seu IP)
- Porta 80: HTTP (para redirecionamento)
- Porta 443: HTTPS (acesso público)
- Portas 5678 e 8080: Apenas para localhost (proxy reverso)

As portas dos containers Docker (5678 e 8080) devem ser acessíveis apenas pelo proxy reverso, não diretamente pela internet.

### 15.2 Atualizações de Segurança

Mantenha o sistema operacional e os containers atualizados:

```bash
# Atualizar sistema operacional
sudo apt update && sudo apt upgrade -y

# Atualizar containers Docker
docker-compose pull
docker-compose up -d
```

### 15.3 Senhas e Chaves

Utilize senhas fortes e únicas para todos os serviços. As chaves de API devem ser geradas com alta entropia e mantidas seguras. Considere o uso de um gerenciador de senhas para armazenar credenciais de forma segura.

### 15.4 Monitoramento de Segurança

Implemente monitoramento de logs para detectar tentativas de acesso não autorizado. Ferramentas como fail2ban podem ser configuradas para bloquear automaticamente IPs que apresentem comportamento suspeito.

## 16. Otimização de Performance

### 16.1 Recursos do Sistema

Para uma operação otimizada, recomenda-se uma instância EC2 com pelo menos:

- 4 vCPUs
- 8 GB de RAM
- 50 GB de armazenamento SSD
- Rede otimizada

### 16.2 Configurações de Memória

Ajuste as configurações de memória do PostgreSQL baseado nos recursos disponíveis:

```sql
-- Para instância com 8GB RAM
ALTER SYSTEM SET shared_buffers = '2GB';
ALTER SYSTEM SET effective_cache_size = '6GB';
ALTER SYSTEM SET maintenance_work_mem = '512MB';
```

### 16.3 Cache e Redis

Configure o Redis com limites de memória apropriados:

```yaml
redis:
  image: redis:6-alpine
  command: redis-server --maxmemory 1gb --maxmemory-policy allkeys-lru --appendonly yes
```

## 17. Integração entre n8n e Evolution API

### 17.1 Configuração de Webhooks

O n8n pode ser configurado para receber webhooks da Evolution API, permitindo automações baseadas em eventos do WhatsApp:

1. No n8n, crie um workflow com trigger "Webhook"
2. Configure a URL do webhook na Evolution API
3. Implemente a lógica de processamento das mensagens

### 17.2 Autenticação entre Serviços

Para comunicação segura entre n8n e Evolution API, utilize a chave de API configurada:

```javascript
// Exemplo de requisição do n8n para Evolution API
const headers = {
  'apikey': 'SUA_CHAVE_API_EVOLUTION',
  'Content-Type': 'application/json'
};

const response = await $http.request({
  method: 'POST',
  url: 'http://evolution-api:8080/message/sendText/instance',
  headers: headers,
  body: {
    number: '5511999999999',
    text: 'Mensagem automática do n8n!'
  }
});
```

### 17.3 Casos de Uso Comuns

Alguns casos de uso típicos para integração:

- Resposta automática a mensagens recebidas
- Envio de mensagens programadas
- Integração com CRM ou sistemas externos
- Análise e relatórios de conversas
- Backup automático de conversas importantes

## 18. Troubleshooting e Solução de Problemas

### 18.1 Problemas Comuns

**n8n não consegue conectar ao banco de dados:**
- Verifique se o PostgreSQL está rodando: `docker-compose ps postgres`
- Confirme as credenciais no arquivo .env
- Verifique logs do n8n: `docker-compose logs n8n`

**Evolution API não consegue conectar ao Redis:**
- Verifique se o Redis está rodando: `docker-compose ps redis`
- Confirme a URL de conexão do Redis
- Verifique logs da Evolution API: `docker-compose logs evolution-api`

**Proxy reverso não consegue acessar os serviços:**
- Verifique se as portas 5678 e 8080 estão expostas
- Confirme que os containers estão na rede correta
- Teste conectividade: `curl http://localhost:5678/healthz`

### 18.2 Comandos de Diagnóstico

```bash
# Verificar status de todos os serviços
docker-compose ps

# Verificar logs de um serviço específico
docker-compose logs -f [nome_do_servico]

# Verificar uso de recursos
docker stats

# Testar conectividade de rede
docker-compose exec n8n ping postgres
docker-compose exec evolution-api ping redis

# Verificar portas abertas
sudo netstat -tlnp | grep :5678
sudo netstat -tlnp | grep :8080
```

### 18.3 Recuperação de Emergência

Em caso de falha crítica:

1. Pare todos os serviços: `docker-compose down`
2. Verifique integridade dos volumes: `docker volume ls`
3. Restaure backups se necessário
4. Reinicie serviços gradualmente
5. Verifique logs para identificar a causa raiz

## 19. Manutenção e Atualizações

### 19.1 Cronograma de Manutenção

Estabeleça um cronograma regular de manutenção:

- **Diário**: Verificação de logs e alertas
- **Semanal**: Verificação de espaço em disco e performance
- **Mensal**: Atualizações de segurança e backup completo
- **Trimestral**: Atualizações de versão dos containers

### 19.2 Processo de Atualização

Para atualizar os containers:

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

### 19.3 Monitoramento Contínuo

Implemente monitoramento contínuo para:

- Uso de CPU e memória
- Espaço em disco
- Latência de rede
- Erros de aplicação
- Disponibilidade dos serviços

## Referências

[1] Evolution API Documentation - Docker Installation: https://doc.evolution-api.com/v2/en/install/docker
[2] n8n Documentation - Docker Compose Setup: https://docs.n8n.io/hosting/installation/server-setups/docker-compose/
[3] PostgreSQL and Redis with Docker Compose Best Practices: https://medium.com/@sevicdev/postgres-and-redis-containers-with-docker-compose-0ca899ccb149
[4] Docker Compose Production Best Practices: https://nickjanetakis.com/blog/best-practices-around-production-ready-web-apps-with-docker-compose
[5] Redis Configuration for Production: https://redis.io/docs/manual/config/
[6] PostgreSQL Performance Tuning: https://wiki.postgresql.org/wiki/Performance_Optimization

---

**Autor:** Manus AI  
**Data:** 2025-07-08  
**Versão:** 1.0

