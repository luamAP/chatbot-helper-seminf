# Projeto Chatbot Helper - Evolution API + n8n (sem Nginx)

## 📋 Visão Geral

Este projeto fornece uma solução completa para configurar um ambiente de chatbot helper utilizando Evolution API e n8n em uma VPS EC2 (Ubuntu), com PostgreSQL como banco de dados e Redis para cache/fila. **Assume-se que você já possui um proxy reverso (como Nginx) configurado** para gerenciar o tráfego HTTPS para os domínios.

## 🏗️ Arquitetura

```
[Seu Proxy Reverso (Nginx)]
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
```

### 3. Configuração do Proxy Reverso

**IMPORTANTE**: Certifique-se de que seu proxy reverso (Nginx) está configurado para encaminhar o tráfego:

- `n8n-chatbot-server.duckdns.org` → `localhost:5678`
- `evo-chatbot-server.duckdns.org` → `localhost:8080`

### 4. Execução Automatizada

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
├── scripts/
│   ├── setup.sh              # Script de configuração automatizada
│   └── backup.sh             # Script de backup
├── n8n/
│   └── local-files/          # Arquivos locais do n8n
└── README.md                 # Este arquivo
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
mkdir -p n8n/local-files data/{postgres,redis,n8n,evolution}
```

### 3. Iniciar Serviços

```bash
docker-compose up -d
```

## 🔐 Acesso aos Serviços

Após a configuração completa:

- **n8n**: https://n8n-chatbot-server.duckdns.org
- **Evolution API**: https://evo-chatbot-server.duckdns.org

### Portas Internas

- **n8n**: localhost:5678
- **Evolution API**: localhost:8080
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

### Credenciais

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

### Backup

```bash
# Fazer backup completo
./scripts/backup.sh
```

### Monitoramento

```bash
# Verificar uso de recursos
docker stats

# Verificar conectividade
curl http://localhost:5678/healthz
curl http://localhost:8080/manager

# Testar conectividade entre serviços
docker-compose exec n8n ping postgres
docker-compose exec evolution-api ping redis
```

## 🔍 Solução de Problemas

### Problemas Comuns

**1. n8n não carrega:**
- Verifique se o PostgreSQL está rodando: `docker-compose ps postgres`
- Confirme as credenciais no arquivo `.env`
- Verifique logs: `docker-compose logs n8n`

**2. Evolution API não conecta:**
- Verifique se o Redis está rodando: `docker-compose ps redis`
- Confirme a chave de API no arquivo `.env`
- Verifique logs: `docker-compose logs evolution-api`

**3. Proxy reverso não consegue acessar:**
- Verifique se as portas 5678 e 8080 estão expostas
- Teste conectividade: `curl http://localhost:5678/healthz`
- Confirme configuração do proxy reverso

### Comandos de Diagnóstico

```bash
# Verificar portas abertas
sudo netstat -tlnp | grep :5678
sudo netstat -tlnp | grep :8080

# Verificar logs do sistema
sudo journalctl -u docker

# Verificar espaço em disco
df -h

# Verificar conectividade entre containers
docker-compose exec n8n ping postgres
docker-compose exec evolution-api ping redis
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

## 🔒 Segurança

### Configurações Recomendadas

1. **Firewall**: Configure apenas as portas necessárias
2. **Senhas**: Use senhas fortes e únicas para todos os serviços
3. **Atualizações**: Mantenha o sistema e containers atualizados
4. **Backup**: Configure backups automáticos regulares
5. **Proxy Reverso**: Certifique-se de que apenas as portas do proxy estão expostas

## 📊 Monitoramento

### Health Checks

Todos os serviços incluem health checks automáticos:

- **PostgreSQL**: Verifica conectividade do banco
- **Redis**: Testa comando PING
- **n8n**: Verifica endpoint /healthz
- **Evolution API**: Testa endpoint /manager

### Logs

```bash
# Logs específicos por serviço
docker-compose logs n8n
docker-compose logs evolution-api
docker-compose logs postgres
docker-compose logs redis
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
  url: 'http://evolution-api:8080/message/sendText/instance',
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

## 📞 Suporte

### Documentação Oficial

- [Evolution API](https://doc.evolution-api.com/)
- [n8n](https://docs.n8n.io/)
- [Docker Compose](https://docs.docker.com/compose/)

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

---

**Desenvolvido por:** Manus AI  
**Data:** 2025-07-08  
**Versão:** 1.0

