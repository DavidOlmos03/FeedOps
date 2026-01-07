# n8n Workflows Guide

This guide explains how to configure, customize, and manage n8n workflows for FeedOps. It includes both graphical (UI-based) and code-based instructions.

## Table of Contents

- [Workflow Overview](#workflow-overview)
- [Importing Workflows](#importing-workflows)
- [Configuring Credentials](#configuring-credentials)
- [Understanding Each Workflow](#understanding-each-workflow)
- [Customizing Workflows](#customizing-workflows)
- [Testing Workflows](#testing-workflows)
- [Monitoring & Debugging](#monitoring--debugging)
- [Best Practices](#best-practices)

## Workflow Overview

FeedOps uses 4 main workflows:

| Workflow | Type | Trigger | Purpose |
|----------|------|---------|---------|
| GitHub Monitor | Webhook | Real-time | Receive and process GitHub events |
| Reddit Monitor | Schedule | Every 15 min | Poll Reddit for new posts |
| RSS Monitor | Schedule | Every 30 min | Fetch and parse RSS feeds |
| Telegram Dispatcher | Sub-workflow | On-demand | Format and send notifications |

## Importing Workflows

### Method 1: Via n8n UI (Recommended for Beginners)

**Step-by-Step with Screenshots:**

1. **Access n8n**
   - Open browser to `http://localhost:5678`
   - Login with credentials from `.env`

2. **Navigate to Workflows**
   - Click "Workflows" in the left sidebar
   - You'll see a list of existing workflows (empty at first)

3. **Import First Workflow** (Telegram Dispatcher)
   - Click the "⋮" menu in top-right
   - Select "Import from File" (or press Ctrl+O)
   - Browse to `workflows/04-telegram-dispatcher.json`
   - Click "Open"
   - Workflow will appear in editor

4. **Save the Workflow**
   - Click "Save" button in top-right
   - Workflow is now saved but not active

5. **Repeat for Other Workflows**
   - Import in this order:
     1. `04-telegram-dispatcher.json` (first!)
     2. `01-github-monitor.json`
     3. `02-reddit-monitor.json`
     4. `03-rss-monitor.json`

### Method 2: Bulk Import via CLI

```bash
# From project root directory
cd /home/david/Documents/projects/feedops

# Import all workflows
for workflow in workflows/0*.json; do
  filename=$(basename "$workflow")
  docker cp "$workflow" feedops-n8n:/tmp/
  docker exec feedops-n8n n8n import:workflow --input="/tmp/$filename"
  echo "Imported $filename"
done
```

## Configuring Credentials

Before activating workflows, you must configure credentials in the n8n UI.

### 1. PostgreSQL Credential

**Via UI:**

1. Click "Credentials" in left sidebar
2. Click "+ Add Credential" button
3. Search for "Postgres"
4. Click "Postgres" in results
5. Fill in the form:
   ```
   Name: PostgreSQL
   Host: postgres
   Database: n8n (or value from .env POSTGRES_DB)
   User: n8n (or value from .env POSTGRES_USER)
   Password: [value from .env POSTGRES_PASSWORD]
   Port: 5432
   SSL: Disabled
   ```
6. Click "Create" button
7. Test connection by clicking "Test"
   - Should show "Connection tested successfully"

**Troubleshooting:**
- If connection fails, ensure PostgreSQL container is running: `docker-compose ps postgres`
- Check password matches exactly (no extra spaces)

### 2. Telegram Credential

**Via UI:**

1. Credentials → "+ Add Credential"
2. Search for "Telegram"
3. Select "Telegram"
4. Fill in:
   ```
   Name: Telegram Bot
   Access Token: [value from .env TELEGRAM_BOT_TOKEN]
   ```
5. Click "Create"

**To verify:**
- The token should start with a number followed by colon
- Example: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

### 3. Reddit OAuth2 Credential (Optional)

**Via UI:**

1. Credentials → "+ Add Credential"
2. Search for "Reddit OAuth2"
3. Select "Reddit OAuth2 API"
4. Fill in:
   ```
   Name: Reddit OAuth2
   Client ID: [from .env REDDIT_CLIENT_ID]
   Client Secret: [from .env REDDIT_CLIENT_SECRET]
   ```
5. Click "Connect my account"
6. Authorize in popup window
7. Click "Create"

**Note**: This requires the Reddit app to be created first (see CONFIGURATION.md)

## Understanding Each Workflow

### GitHub Monitor Workflow

**Purpose**: Receive real-time events from GitHub via webhooks
Note: Also you can build or use a workflow for a **github page**

**Flow Diagram:**
```
Webhook Trigger
    ↓
Validate Signature (Security)
    ↓
Verify Signature (HMAC-SHA256)
    ↓
Normalize Event Data
    ↓
Check Duplicate (PostgreSQL)
    ↓
Is New? (Conditional)
    ↓
Send to Telegram + Log Notification
    ↓
Respond OK
```

**Nodes Explained:**

1. **GitHub Webhook Node**
   - **Type**: Trigger
   - **Path**: `/webhook/github-webhook`
   - **Method**: POST
   - **Purpose**: Receives webhook events from GitHub

   **How to configure:**
   - No configuration needed (already set in template)
   - Just activate the workflow

2. **Validate Signature Node**
   - **Type**: IF (Conditional)
   - **Purpose**: Check if signature header exists
   - **Logic**: Ensures `x-hub-signature-256` header is present

3. **Verify Signature Node**
   - **Type**: Function
   - **Purpose**: Cryptographic validation of webhook
   - **Logic**:
     ```javascript
     const crypto = require('crypto');
     const secret = process.env.GITHUB_WEBHOOK_SECRET;
     const payload = JSON.stringify($input.item.json.body);
     const signature = $input.item.json.headers['x-hub-signature-256'];

     // Create HMAC
     const hmac = crypto.createHmac('sha256', secret);
     hmac.update(payload);
     const digest = 'sha256=' + hmac.digest('hex');

     // Compare signatures
     const valid = crypto.timingSafeEqual(
       Buffer.from(signature),
       Buffer.from(digest)
     );
     ```

4. **Normalize Event Node**
   - **Type**: Function
   - **Purpose**: Convert GitHub event to standard format
   - **Output**: Normalized data structure used by all sources

5. **Check Duplicate Node**
   - **Type**: PostgreSQL Query
   - **Purpose**: Check if notification already sent
   - **Query**: `SELECT item_hash FROM notifications_history WHERE item_hash = $1`

6. **Send to Telegram Node**
   - **Type**: Execute Workflow
   - **Purpose**: Calls Telegram Dispatcher workflow
   - **Note**: Requires Telegram Dispatcher to be imported and active

**Customization Points:**

- **Change webhook path**: Edit Webhook node → Path parameter
- **Add/remove event types**: Edit Normalize Event function
- **Adjust filtering**: Add IF nodes after normalization

### Reddit Monitor Workflow

**Purpose**: Poll Reddit API for new posts at regular intervals

**Flow Diagram:**
```
Schedule Trigger (Every 15 min)
    ↓
Get Reddit Sources (PostgreSQL)
    ↓
Fetch Reddit Posts (Reddit API)
    ↓
Normalize Posts (Filter & Transform)
    ↓
Check Duplicate (PostgreSQL)
    ↓
Is New? (Conditional)
    ↓
Send to Telegram + Log Notification
    ↓
Update Source Status
```

**Nodes Explained:**

1. **Schedule Trigger Node**
   - **Type**: Cron Trigger
   - **Schedule**: `*/15 * * * *` (every 15 minutes)
   - **Purpose**: Automatically runs workflow

   **How to change frequency:**
   - Click the node
   - Under "Trigger Rules" → "Cron Expression"
   - Enter new cron expression:
     - Every 5 minutes: `*/5 * * * *`
     - Every hour: `0 * * * *`
     - Every 6 hours: `0 */6 * * *`

2. **Get Reddit Sources Node**
   - **Type**: PostgreSQL Query
   - **Query**: `SELECT * FROM feed_sources WHERE source_type = 'reddit' AND enabled = true`
   - **Purpose**: Fetch all active Reddit sources

3. **Fetch Reddit Posts Node**
   - **Type**: Reddit Node
   - **Resource**: Subreddit
   - **Operation**: Get Posts
   - **Parameters**:
     - Subreddit: `={{$json.config.subreddit}}`
     - Category: new
     - Limit: 25

4. **Normalize Posts Node**
   - **Type**: Function
   - **Purpose**: Filter and transform Reddit posts
   - **Filtering Logic**:
     ```javascript
     // Filter by minimum score
     if (sourceConfig.min_score && post.score < sourceConfig.min_score) {
       return null;
     }

     // Filter by keywords
     if (sourceConfig.keywords) {
       const keywords = sourceConfig.keywords.toLowerCase().split(',');
       const title = post.title.toLowerCase();
       const hasKeyword = keywords.some(kw => title.includes(kw.trim()));
       if (!hasKeyword) return null;
     }
     ```

**Customization Points:**

- **Change polling frequency**: Edit Schedule Trigger node
- **Adjust post limit**: Edit Fetch Reddit Posts → Limit
- **Custom filtering**: Modify Normalize Posts function
- **Different sort**: Change Category (hot, new, rising, top)

### RSS Monitor Workflow

**Purpose**: Fetch and parse RSS/Atom feeds

**Flow Diagram:**
```
Schedule Trigger (Every 30 min)
    ↓
Get RSS Sources (PostgreSQL)
    ↓
Fetch RSS Feed (HTTP)
    ↓
Normalize Items (Filter & Transform)
    ↓
Check Duplicate (PostgreSQL)
    ↓
Is New? (Conditional)
    ↓
Send to Telegram + Log Notification
    ↓
Update Source Status
```

**Nodes Explained:**

1. **Schedule Trigger Node**
   - **Schedule**: `*/30 * * * *` (every 30 minutes)
   - **Purpose**: Periodic fetching

2. **Fetch RSS Feed Node**
   - **Type**: RSS Feed Read
   - **URL**: `={{$json.source_identifier}}`
   - **Purpose**: Download and parse RSS/Atom feed

3. **Normalize Items Node**
   - **Type**: Function
   - **Purpose**: Convert RSS items to standard format
   - **Filtering**:
     ```javascript
     // Only process items newer than last check
     const lastCheck = source.last_check ? new Date(source.last_check) : null;
     const itemDate = new Date(item.pubDate || item.isoDate);

     if (lastCheck && itemDate <= lastCheck) {
       return null;
     }
     ```

**Customization Points:**

- **Change polling frequency**: Edit Schedule Trigger
- **Custom date filtering**: Modify Normalize Items function
- **Add category filtering**: Check `item.categories` array

### Telegram Dispatcher Workflow

**Purpose**: Central notification formatting and delivery

**Flow Diagram:**
```
Execute Workflow Trigger (Called by others)
    ↓
Format Message (Transform to Telegram format)
    ↓
Send to Telegram (Bot API)
    ↓
Update Notification (Store message ID)
    ↓
[On Error] → Retry with Backoff
```

**Nodes Explained:**

1. **Format Message Node**
   - **Type**: Function
   - **Purpose**: Transform data into Telegram Markdown
   - **Output**:
     ```javascript
     {
       message: "🚀 **Title**\n\nDescription...",
       parse_mode: "Markdown",
       source_data: { original data }
     }
     ```

   **Message Template**:
   ```
   [Emoji] **Title**

   Description

   📦 Repository: `owner/repo`
   🌿 Branch: `main`
   ⏰ Jan 15, 10:30 AM

   🔗 [View on GitHub](url)
   ```

2. **Send to Telegram Node**
   - **Type**: Telegram Send Message
   - **Chat ID**: `={{$env.TELEGRAM_DEFAULT_CHAT_ID}}`
   - **Text**: `={{$json.message}}`
   - **Parse Mode**: Markdown
   - **Retry**: Enabled (3 attempts, 2s between)

3. **Error Handler Node**
   - **Type**: Function
   - **Purpose**: Implement exponential backoff
   - **Logic**:
     ```javascript
     const attempt = $json.attempt || 1;
     const maxRetries = 3;
     const backoffTime = Math.pow(2, attempt) * 1000;
     // Returns: { retry_after: backoffTime, attempt: attempt + 1 }
     ```

**Customization Points:**

- **Change message format**: Edit Format Message function
- **Add inline buttons**: Modify reply_markup in Send Telegram node
- **Route to different channels**: Add routing logic in Format Message
- **Adjust retry logic**: Modify Error Handler function

## Customizing Workflows

### Adding Custom Filters

**Scenario**: Only notify for GitHub releases marked as "production"

**Solution**: Add IF node after Normalize Event

1. Open "GitHub Monitor" workflow
2. Click between "Normalize Event" and "Check Duplicate"
3. Click "+" to add node
4. Select "IF" node
5. Configure:
   ```
   Condition: String
   Value 1: ={{$json.metadata.tag}}
   Operation: Contains
   Value 2: prod
   ```
6. Connect "true" branch to "Check Duplicate"
7. Delete "false" branch (or connect to different handler)

### Custom Notification Format

**Scenario**: Add company-specific branding to messages

**Solution**: Edit Format Message in Telegram Dispatcher

1. Open "Telegram Dispatcher" workflow
2. Click "Format Message" function node
3. Edit the code:
   ```javascript
   // Add custom header
   let message = `🏢 **ACME Corp Notification**\n`;
   message += `━━━━━━━━━━━━━━━━━━\n\n`;

   // Existing message content
   message += `${emoji} **${data.title}**\n\n`;
   // ... rest of template ...

   // Add custom footer
   message += `\n━━━━━━━━━━━━━━━━━━\n`;
   message += `📊 [Dashboard](https://dashboard.acme.com)`;
   ```
4. Click "Execute node" to test
5. Save workflow

### Adding Priority Levels

**Scenario**: Mark critical notifications with high priority

**Solution**: Add priority logic and visual indicators

1. **Define priority function** (add new Function node):
   ```javascript
   const data = $input.item.json;

   // Determine priority
   let priority = 'normal';

   if (data.source === 'github' && data.event_type === 'release') {
     priority = 'high';
   }

   if (data.metadata?.labels?.includes('critical')) {
     priority = 'urgent';
   }

   return { ...data, priority };
   ```

2. **Update message format** (in Telegram Dispatcher):
   ```javascript
   // Priority emojis
   const priorityEmoji = {
     'urgent': '🔴',
     'high': '🟠',
     'normal': '🟢'
   };

   let prefix = priorityEmoji[data.priority] || '🟢';
   let message = `${prefix} ${emoji} **${data.title}**\n\n`;
   ```

### Routing to Multiple Channels

**Scenario**: Send GitHub notifications to #dev, Reddit to #community

**Solution**: Route based on source

1. Open "Telegram Dispatcher"
2. Edit "Send to Telegram" node
3. Change Chat ID to expression:
   ```javascript
   {{
     $json.source === 'github' ? '-1001111111111' :
     $json.source === 'reddit' ? '-1002222222222' :
     $env.TELEGRAM_DEFAULT_CHAT_ID
   }}
   ```

Or use IF nodes for complex routing.

## Testing Workflows

### Test Individual Workflows

#### 1. Manual Execution

1. Open workflow in n8n
2. Click "Execute Workflow" button (play icon)
3. Observe execution in real-time
4. Check each node's output

#### 2. Test with Sample Data

For workflows triggered by Execute Workflow:

1. Click "Execute Workflow"
2. Enter test data in JSON format:
   ```json
   {
     "source": "github",
     "title": "Test Notification",
     "description": "This is a test",
     "url": "https://github.com/test",
     "timestamp": "2024-01-01T00:00:00Z",
     "author": "testuser",
     "metadata": {}
   }
   ```
3. Click "Execute"

### Test Webhooks

#### GitHub Webhook Test

```bash
# Send test webhook
curl -X POST http://localhost:5678/webhook/github-webhook \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -H "X-Hub-Signature-256: sha256=test" \
  -d '{
    "ref": "refs/heads/main",
    "repository": {
      "full_name": "test/repo",
      "html_url": "https://github.com/test/repo"
    },
    "head_commit": {
      "message": "Test commit",
      "url": "https://github.com/test/repo/commit/abc123"
    },
    "pusher": {"name": "testuser"}
  }'
```

### Test Database Queries

```bash
# Add test source
docker-compose exec postgres psql -U n8n -d n8n <<EOF
INSERT INTO feed_sources (source_type, source_identifier, config, enabled)
VALUES ('rss', 'https://hnrss.org/newest', '{}', true);
EOF

# Execute RSS Monitor workflow manually in n8n UI
# Check execution log for results
```

## Monitoring & Debugging

### View Execution History

**Via UI:**

1. Click "Executions" in left sidebar
2. See list of all workflow executions
3. Click any execution to see details
4. Inspect each node's input/output

**Filters:**
- Status: All / Error / Success
- Workflow: Filter by specific workflow
- Date range: Last hour / day / week

### Check Execution Logs

```bash
# View n8n logs
docker-compose logs -f n8n

# Filter for errors
docker-compose logs n8n | grep -i error

# View last 100 lines
docker-compose logs --tail=100 n8n
```

### Debug Workflow Issues

**Common Issues:**

1. **Credential Error**
   - Symptom: "Missing credentials" or "Authentication failed"
   - Solution: Check credential name matches exactly
   - Verify credentials are saved and active

2. **Database Connection Error**
   - Symptom: "Connection refused" or "ECONNREFUSED"
   - Solution: Check PostgreSQL is running
   - Verify credentials and host name

3. **Workflow Not Triggering**
   - Symptom: Workflow exists but never executes
   - Solution: Check workflow is **Active** (toggle in top-right)
   - For webhooks: Verify webhook URL is accessible

4. **Data Not Flowing**
   - Symptom: Nodes execute but no data passes through
   - Solution: Check IF node conditions
   - Verify node connections (arrows between nodes)

**Debug Mode:**

Add console.log in Function nodes:
```javascript
// In any Function node
console.log('DEBUG: Current data:', JSON.stringify($json, null, 2));
console.log('DEBUG: Environment:', process.env.NODE_ENV);

return $json;
```

View output in logs:
```bash
docker-compose logs n8n | grep DEBUG
```

## Best Practices

### 1. Workflow Organization

- **Name workflows clearly**: "GitHub Monitor", not "Workflow 1"
- **Add descriptions**: Use workflow description field
- **Tag workflows**: Use tags for categorization
- **Version control**: Export workflows regularly

### 2. Error Handling

- **Always add error outputs**: Connect error branches
- **Log errors**: Use Function nodes to log to console
- **Retry with backoff**: Don't retry immediately
- **Alert on failures**: Send notifications for persistent errors

### 3. Performance

- **Limit batch sizes**: Don't process 1000s of items at once
- **Use pagination**: Break large queries into pages
- **Add delays**: Respect API rate limits
- **Clean up old data**: Use retention policies

### 4. Security

- **Never hardcode secrets**: Use environment variables
- **Validate webhooks**: Always verify signatures
- **Sanitize inputs**: Prevent injection attacks
- **Limit permissions**: Use least-privilege principle

### 5. Testing

- **Test before activating**: Execute manually first
- **Use test data**: Don't test in production
- **Monitor executions**: Check execution log regularly
- **Set up alerts**: Get notified of failures

## Next Steps

- Configure data sources: [CONFIGURATION.md](CONFIGURATION.md)
- Review architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Plan for scaling: [SCALABILITY.md](SCALABILITY.md)
- Troubleshoot issues: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
