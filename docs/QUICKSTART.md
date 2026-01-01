# FeedOps Quick Start Guide

Get FeedOps running in 10 minutes!

## Prerequisites

- Docker installed
- 4GB RAM available
- Telegram account

## Step 1: Clone and Setup (2 minutes)

```bash
# Clone repository
git clone <repository-url>
cd feedops

# Generate configuration
cp .env.example .env
./scripts/generate-keys.sh
```

## Step 2: Get Telegram Bot Token (3 minutes)

1. Open Telegram
2. Search for `@BotFather`
3. Send: `/newbot`
4. Follow prompts to create bot
5. Copy bot token

Get your chat ID:
1. Send any message to your bot
2. Visit: `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates`
3. Find `"chat":{"id":123456}`

## Step 3: Configure Environment (1 minute)

Edit `.env`:

```bash
# Required: Add these values
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_DEFAULT_CHAT_ID=your_chat_id_here

# Optional: GitHub (if you want GitHub monitoring)
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here

# Optional: Reddit (if you want Reddit monitoring)
REDDIT_CLIENT_ID=your_client_id
REDDIT_CLIENT_SECRET=your_client_secret
```

## Step 4: Start Services (2 minutes)

```bash
docker-compose up -d

# Wait 30 seconds, then check status
docker-compose ps
```

All services should show as "healthy" or "running".

## Step 5: Access n8n (1 minute)

1. Open browser: `http://localhost:5678`
2. Login:
   - Username: `admin` (or check N8N_BASIC_AUTH_USER in .env)
   - Password: (check N8N_BASIC_AUTH_PASSWORD in .env)

## Step 6: Configure Credentials (1 minute)

### PostgreSQL Credential

1. Click "Credentials" → "+ Add Credential"
2. Select "Postgres"
3. Fill in:
   - Name: `PostgreSQL`
   - Host: `postgres`
   - Database: `n8n`
   - User: `n8n`
   - Password: (from .env POSTGRES_PASSWORD)
   - Port: `5432`
4. Click "Create"

### Telegram Credential

1. Click "+ Add Credential"
2. Select "Telegram"
3. Fill in:
   - Name: `Telegram Bot`
   - Access Token: (from .env TELEGRAM_BOT_TOKEN)
4. Click "Create"

## Step 7: Import Workflows (2 minutes)

1. Click "Workflows"
2. Click "⋮" → "Import from File"
3. Import these files in order:
   - `workflows/04-telegram-dispatcher.json`
   - `workflows/03-rss-monitor.json`

## Step 8: Test with RSS Feed (1 minute)

Add a test RSS feed:

```bash
docker-compose exec postgres psql -U n8n -d n8n <<EOF
INSERT INTO feed_sources (source_type, source_identifier, config, enabled)
VALUES ('rss', 'https://hnrss.org/newest', '{"keywords": "docker"}', true);
EOF
```

## Step 9: Activate and Test (1 minute)

1. Open "RSS Monitor" workflow
2. Click "Inactive" toggle (turns green)
3. Click "Save"
4. Click "Execute Workflow"
5. Check your Telegram for notification!

## What's Next?

### Monitor More Sources

**Add GitHub Repository:**
```bash
docker-compose exec postgres psql -U n8n -d n8n <<EOF
INSERT INTO feed_sources (source_type, source_identifier, config, enabled)
VALUES ('github', 'docker/compose', '{"events": ["release"]}', true);
EOF
```

Then set up webhook (see [CONFIGURATION.md](CONFIGURATION.md))

**Add Reddit Subreddit:**

First configure Reddit OAuth (see [CONFIGURATION.md](CONFIGURATION.md)), then:

```bash
docker-compose exec postgres psql -U n8n -d n8n <<EOF
INSERT INTO feed_sources (source_type, source_identifier, config, enabled)
VALUES ('reddit', 'r/docker', '{"min_score": 100}', true);
EOF
```

### Customize

- **Change polling frequency**: Edit Schedule Trigger in workflows
- **Customize messages**: Edit Format Message in Telegram Dispatcher
- **Add filters**: Modify config JSON when adding sources

### Monitor

```bash
# Check health
./scripts/health-check.sh

# View logs
docker-compose logs -f

# Check executions
# In n8n UI: Click "Executions" tab
```

## Troubleshooting

**Problem: Can't access n8n**
```bash
# Check if running
docker-compose ps n8n

# Check logs
docker-compose logs n8n

# Restart
docker-compose restart n8n
```

**Problem: No notifications received**
1. Check Telegram bot token is correct
2. Verify chat ID (send message to bot, check getUpdates)
3. Check workflow is Active (green toggle)
4. Review execution history for errors

**Problem: Database connection failed**
```bash
# Restart PostgreSQL
docker-compose restart postgres

# Wait 30 seconds
sleep 30

# Restart n8n
docker-compose restart n8n
```

## Learn More

- [Full Installation Guide](INSTALLATION.md)
- [Configuration Options](CONFIGURATION.md)
- [Workflow Customization](N8N_WORKFLOWS.md)
- [Troubleshooting](TROUBLESHOOTING.md)

## Support

- Documentation: `docs/` directory
- Issues: Create GitHub issue
- Health Check: `./scripts/health-check.sh`
