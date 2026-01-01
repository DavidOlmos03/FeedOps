# FeedOps Workflows

This directory contains n8n workflow templates for FeedOps. These workflows need to be imported into your n8n instance.

## Workflows Overview

### 01-github-monitor.json
Monitors GitHub repositories via webhooks. Receives push, issue, pull request, and release events.

**Trigger**: Webhook
**Frequency**: Real-time (event-driven)
**Prerequisites**:
- GitHub webhook configured on target repositories
- GITHUB_WEBHOOK_SECRET set in .env

### 02-reddit-monitor.json
Polls Reddit for new posts in specified subreddits.

**Trigger**: Schedule (every 15 minutes)
**Frequency**: Configurable via cron expression
**Prerequisites**:
- Reddit OAuth2 credentials configured
- Feed sources added to database

### 03-rss-monitor.json
Fetches and monitors RSS/Atom feeds.

**Trigger**: Schedule (every 30 minutes)
**Frequency**: Configurable via cron expression
**Prerequisites**:
- Feed sources added to database with RSS URLs

### 04-telegram-dispatcher.json
Formats and sends notifications to Telegram with retry logic.

**Trigger**: Called by other workflows
**Frequency**: On-demand
**Prerequisites**:
- Telegram bot token configured
- TELEGRAM_DEFAULT_CHAT_ID set

## Import Instructions

### Method 1: Via n8n UI (Recommended for beginners)

1. Access your n8n instance: `http://localhost:5678`
2. Login with your credentials
3. Click "Workflows" in the left menu
4. Click "Import from File" or use Ctrl+O
5. Select a workflow JSON file
6. Click "Import"
7. Repeat for all workflow files

### Method 2: Via CLI (Advanced)

```bash
# Copy workflows to n8n container
docker cp workflows/01-github-monitor.json feedops-n8n:/tmp/

# Import using n8n CLI
docker exec feedops-n8n n8n import:workflow --input=/tmp/01-github-monitor.json

# Repeat for each workflow
```

### Method 3: Automatic Import (All at once)

```bash
# Import all workflows at once
for workflow in workflows/*.json; do
  filename=$(basename "$workflow")
  docker cp "$workflow" feedops-n8n:/tmp/
  docker exec feedops-n8n n8n import:workflow --input="/tmp/$filename"
done
```

## Post-Import Configuration

After importing workflows, you need to configure credentials and connections:

### 1. Configure PostgreSQL Connection

1. Go to "Credentials" → "New"
2. Select "Postgres"
3. Enter connection details:
   - Host: `postgres`
   - Database: Value from `POSTGRES_DB` in .env
   - User: Value from `POSTGRES_USER` in .env
   - Password: Value from `POSTGRES_PASSWORD` in .env
   - Port: `5432`
4. Save as "PostgreSQL"

### 2. Configure Reddit OAuth2 (if using Reddit)

1. Go to "Credentials" → "New"
2. Select "Reddit OAuth2 API"
3. Enter your Reddit app credentials:
   - Client ID: From Reddit app
   - Client Secret: From Reddit app
4. Complete OAuth flow
5. Save as "Reddit OAuth2"

### 3. Configure Telegram Bot

1. Go to "Credentials" → "New"
2. Select "Telegram"
3. Enter your bot token from BotFather
4. Save as "Telegram Bot"

### 4. Activate Workflows

1. Open each imported workflow
2. Check all node configurations
3. Click "Active" toggle in top right
4. Save the workflow

## Workflow Dependencies

The workflows have the following dependency structure:

```
GitHub Monitor ────┐
                   │
Reddit Monitor ────┼──→ Telegram Dispatcher
                   │
RSS Monitor ────────┘
```

**Important**: Make sure to import and activate the Telegram Dispatcher workflow first, as the other workflows depend on it.

## Testing Workflows

### Test GitHub Webhook
```bash
curl -X POST http://localhost:5678/webhook/github-webhook \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d '{"test": true}'
```

### Test Reddit Monitor
1. Add a test source to the database
2. Manually execute the workflow from n8n UI
3. Check execution log

### Test RSS Monitor
1. Add a test RSS feed to the database
2. Manually execute the workflow
3. Verify items are fetched

## Workflow Customization

### Adjust Polling Frequency

Edit the Schedule Trigger node in Reddit/RSS monitors:

```javascript
// Change from every 15 minutes to every 5 minutes
"expression": "*/5 * * * *"

// Change to hourly
"expression": "0 * * * *"

// Change to every 6 hours
"expression": "0 */6 * * *"
```

### Modify Message Format

Edit the "Format Message" function in the Telegram Dispatcher workflow to customize how notifications appear.

### Add Custom Filters

Add filter logic in the "Normalize" function nodes to implement custom filtering rules based on keywords, scores, or other criteria.

## Troubleshooting

### Workflows not receiving data
- Check that credentials are properly configured
- Verify database connection
- Check workflow execution logs

### Duplicate notifications
- Verify deduplication logic in Check Duplicate nodes
- Check database indexes are created

### Telegram send failures
- Verify bot token is correct
- Check that chat ID is valid
- Review retry logic in error handler

For more detailed troubleshooting, see [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)
