# FeedOps Troubleshooting Guide

This guide helps you diagnose and fix common issues with FeedOps.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Installation Issues](#installation-issues)
- [Service Issues](#service-issues)
- [Workflow Issues](#workflow-issues)
- [Database Issues](#database-issues)
- [Integration Issues](#integration-issues)
- [Performance Issues](#performance-issues)
- [Data Issues](#data-issues)
- [FAQ](#faq)

## Quick Diagnostics

### Health Check Script

Run the automated health check:

```bash
./scripts/health-check.sh
```

Expected output:
```
🏥 FeedOps Health Check
=======================

Services:
--------
✓ postgres: Healthy
✓ redis: Healthy
✓ n8n: Healthy

Connectivity:
------------
✓ n8n web interface: Accessible
✓ PostgreSQL: Accepting connections
✓ Redis: Responding

✅ All checks passed!
```

### Manual Checks

```bash
# Check service status
docker-compose ps

# Check logs
docker-compose logs --tail=50

# Check disk space
df -h

# Check memory usage
free -h
```

## Installation Issues

### Issue: Docker Compose Not Found

**Error:**
```
bash: docker-compose: command not found
```

**Solution:**

Check Docker Compose installation:
```bash
docker compose version
```

If using Docker Compose V2:
```bash
# Use 'docker compose' instead of 'docker-compose'
docker compose up -d
```

Or install Docker Compose V1:
```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Issue: Port Already in Use

**Error:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:5678: bind: address already in use
```

**Solution 1: Change Port**

Edit `.env`:
```bash
N8N_PORT=5679  # Use different port
```

Restart:
```bash
docker-compose down
docker-compose up -d
```

**Solution 2: Find and Stop Conflicting Process**

```bash
# Find process using port 5678
sudo lsof -i :5678

# Kill the process
sudo kill -9 <PID>
```

### Issue: Permission Denied

**Error:**
```
ERROR: for postgres  Cannot start service postgres: driver failed programming external connectivity
```

**Solution:**

Run Docker commands with sudo or add user to docker group:

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in for changes to take effect
# Or run:
newgrp docker

# Verify
docker ps
```

### Issue: generate-keys.sh Not Executable

**Error:**
```
bash: ./scripts/generate-keys.sh: Permission denied
```

**Solution:**

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run script
./scripts/generate-keys.sh
```

## Service Issues

### Issue: PostgreSQL Won't Start

**Symptoms:**
- Container exits immediately
- Health check shows unhealthy
- Logs show initialization errors

**Diagnosis:**

```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Check if data directory is corrupted
docker-compose exec postgres ls -la /var/lib/postgresql/data
```

**Common Causes:**

#### 1. Corrupted Data Directory

**Solution:**
```bash
# Stop services
docker-compose down

# Remove data volume (WARNING: Deletes all data!)
docker volume rm feedops_postgres_data

# Restart
docker-compose up -d
```

#### 2. Wrong Permissions

**Solution:**
```bash
# Fix permissions
docker-compose exec postgres chown -R postgres:postgres /var/lib/postgresql/data
```

#### 3. Insufficient Disk Space

**Solution:**
```bash
# Check disk space
df -h

# Clean up Docker
docker system prune -a
```

### Issue: n8n Won't Start

**Symptoms:**
- Container restarts continuously
- Can't access web interface
- Error in logs

**Diagnosis:**

```bash
# Check n8n logs
docker-compose logs n8n

# Check if database is accessible
docker-compose exec n8n ping postgres
```

**Common Causes:**

#### 1. Database Connection Failed

**Error:**
```
Error: connect ECONNREFUSED postgres:5432
```

**Solution:**
```bash
# Verify PostgreSQL is running
docker-compose ps postgres

# Check credentials in .env
cat .env | grep POSTGRES

# Restart in correct order
docker-compose down
docker-compose up -d postgres
# Wait 30 seconds
docker-compose up -d n8n
```

#### 2. Missing Encryption Key

**Error:**
```
Error: N8N_ENCRYPTION_KEY is required
```

**Solution:**
```bash
# Generate encryption key
./scripts/generate-keys.sh

# Or manually add to .env
echo "N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)" >> .env

# Restart
docker-compose restart n8n
```

#### 3. Port Conflict

**Solution:**
```bash
# Change port in .env
N8N_PORT=5679

# Restart
docker-compose down
docker-compose up -d
```

### Issue: Redis Connection Failed

**Error:**
```
Error: Redis connection to redis:6379 failed - NOAUTH Authentication required
```

**Solution:**

```bash
# Check Redis password in .env
cat .env | grep REDIS_PASSWORD

# Test connection
docker-compose exec redis redis-cli -a "your_password" ping
# Should return: PONG

# If password is wrong, update .env and restart
docker-compose restart redis n8n
```

## Workflow Issues

### Issue: Workflow Not Triggering

**Symptoms:**
- Webhook returns 404
- Scheduled workflow doesn't run
- No executions in history

**Diagnosis:**

```bash
# Check if workflow is active
# In n8n UI: Look for green "Active" toggle

# Check workflow executions
# In n8n UI: Click "Executions" tab

# Check n8n logs
docker-compose logs n8n | grep -i error
```

**Solutions:**

#### 1. Workflow Not Activated

**Solution:**
1. Open workflow in n8n
2. Click "Inactive" toggle in top-right
3. Should change to green "Active"
4. Click "Save"

#### 2. Webhook URL Wrong

**Error:**
```
404 Not Found
```

**Solution:**

Verify webhook URL format:
```
Correct: http://localhost:5678/webhook/github-webhook
Wrong:   http://localhost:5678/github-webhook
Wrong:   http://localhost:5678/webhook-test/github-webhook
```

Check webhook path in workflow:
1. Open workflow
2. Click webhook node
3. Verify "Path" parameter
4. Should match URL path

#### 3. Schedule Not Running

**Solution:**

Check cron expression:
1. Open workflow
2. Click "Schedule Trigger" node
3. Verify cron expression is valid
4. Test with short interval: `*/5 * * * *` (every 5 min)
5. Check execution history after 5 minutes

### Issue: Credential Errors

**Error:**
```
Missing credentials for node "PostgreSQL"
```

**Solution:**

1. **Check credential exists:**
   - Go to Credentials tab
   - Verify credential name matches exactly
   - Name is case-sensitive!

2. **Recreate credential:**
   - Delete old credential
   - Create new with exact name: `PostgreSQL`
   - Re-enter all values
   - Save

3. **Update workflow:**
   - Open workflow
   - Click node with credential error
   - Select credential from dropdown
   - Save workflow

### Issue: Workflow Execution Fails

**Symptoms:**
- Workflow executes but shows error
- Some nodes succeed, others fail
- Data not passing between nodes

**Diagnosis:**

```bash
# View execution details in n8n UI
# Click Executions → Select failed execution
# Click each node to see input/output

# Check logs
docker-compose logs n8n | grep -A 10 -B 10 "ERROR"
```

**Common Issues:**

#### 1. Data Format Mismatch

**Error:**
```
Cannot read property 'title' of undefined
```

**Solution:**

Add debugging to Function nodes:
```javascript
// At start of function
console.log('Input data:', JSON.stringify($input.all(), null, 2));

// Check if data exists before accessing
if (!$json.title) {
  console.log('Warning: title is missing!');
  return null;
}

return $json;
```

View logs:
```bash
docker-compose logs n8n | grep "Input data"
```

#### 2. Database Query Failed

**Error:**
```
column "item_hash" does not exist
```

**Solution:**

Check database schema:
```bash
docker-compose exec postgres psql -U n8n -d n8n -c "\d notifications_history"
```

If table doesn't exist:
```bash
# Re-run initialization
docker-compose down
docker volume rm feedops_postgres_data
docker-compose up -d
```

#### 3. API Rate Limit

**Error:**
```
429 Too Many Requests
```

**Solution:**

Add delay between requests:
```javascript
// In Function node
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

// Before API call
await delay(2000); // Wait 2 seconds
```

Or adjust polling frequency:
- Change cron expression to less frequent
- Example: `0 * * * *` (hourly instead of every 15 min)

## Database Issues

### Issue: Database Connection Pool Exhausted

**Error:**
```
Error: Connection pool exhausted
```

**Solution:**

Increase max connections in PostgreSQL:

Create `postgresql.conf`:
```conf
max_connections = 200
```

Update docker-compose.yml:
```yaml
postgres:
  volumes:
    - ./postgresql.conf:/etc/postgresql/postgresql.conf
  command: postgres -c config_file=/etc/postgresql/postgresql.conf
```

Restart:
```bash
docker-compose down
docker-compose up -d
```

### Issue: Slow Queries

**Symptoms:**
- Workflows take a long time to execute
- Database CPU high
- Queries timeout

**Diagnosis:**

```bash
# Check slow queries
docker-compose exec postgres psql -U n8n -d n8n <<EOF
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '5 seconds';
EOF
```

**Solution:**

#### 1. Missing Indexes

```sql
-- Add indexes for common queries
CREATE INDEX IF NOT EXISTS idx_notifications_item_hash ON notifications_history(item_hash);
CREATE INDEX IF NOT EXISTS idx_notifications_sent_at ON notifications_history(sent_at);
CREATE INDEX IF NOT EXISTS idx_feed_sources_enabled ON feed_sources(enabled);
```

#### 2. Large Table

Run vacuum:
```bash
docker-compose exec postgres psql -U n8n -d n8n -c "VACUUM ANALYZE;"
```

#### 3. Too Much Data

Clean up old data:
```bash
./scripts/cleanup.sh
```

### Issue: Duplicate Notifications

**Symptoms:**
- Same notification sent multiple times
- Database shows duplicate entries

**Diagnosis:**

```bash
# Check for duplicates
docker-compose exec postgres psql -U n8n -d n8n <<EOF
SELECT item_hash, COUNT(*)
FROM notifications_history
GROUP BY item_hash
HAVING COUNT(*) > 1;
EOF
```

**Solution:**

#### 1. Race Condition

Add unique constraint:
```sql
CREATE UNIQUE INDEX idx_unique_item_hash ON notifications_history(item_hash);
```

#### 2. Multiple Workflow Instances

Ensure only one instance is active:
```bash
# Check for duplicate workflows
# In n8n UI: Look for workflows with same name
# Deactivate or delete duplicates
```

## Integration Issues

### Issue: GitHub Webhook Not Received

**Symptoms:**
- Push to GitHub, no notification
- Webhook shows error in GitHub
- n8n doesn't receive webhook

**Diagnosis:**

1. **Check GitHub webhook deliveries:**
   - Go to repository Settings → Webhooks
   - Click webhook
   - Check "Recent Deliveries"
   - Look for errors

2. **Check n8n logs:**
   ```bash
   docker-compose logs n8n | grep webhook
   ```

**Common Issues:**

#### 1. Webhook URL Not Accessible

**Solution for local development:**

Use ngrok to expose local server:
```bash
# Install ngrok
npm install -g ngrok

# Start tunnel
ngrok http 5678

# Copy HTTPS URL (e.g., https://abc123.ngrok.io)
# Update GitHub webhook URL to:
https://abc123.ngrok.io/webhook/github-webhook
```

#### 2. Invalid Signature

**Error in GitHub:**
```
Delivery failed: Invalid signature
```

**Solution:**

Verify webhook secret matches:
```bash
# Check secret in .env
cat .env | grep GITHUB_WEBHOOK_SECRET

# Update GitHub webhook secret to match
# Go to GitHub → Settings → Webhooks → Edit
```

#### 3. Workflow Not Active

**Solution:**
1. Open "GitHub Monitor" workflow
2. Click "Inactive" toggle
3. Save workflow

### Issue: Reddit API Authentication Failed

**Error:**
```
401 Unauthorized
```

**Solution:**

#### 1. Check Credentials

```bash
# Verify Reddit credentials in .env
cat .env | grep REDDIT

# Test credentials
curl -X POST -d 'grant_type=password&username=YOUR_USERNAME&password=YOUR_PASSWORD' \
  --user 'YOUR_CLIENT_ID:YOUR_CLIENT_SECRET' \
  https://www.reddit.com/api/v1/access_token
```

#### 2. Re-authorize OAuth

1. Go to n8n → Credentials
2. Find "Reddit OAuth2" credential
3. Click "Reconnect"
4. Complete OAuth flow

### Issue: Telegram Bot Not Sending

**Symptoms:**
- No error in workflow
- Workflow completes successfully
- No message in Telegram

**Diagnosis:**

```bash
# Test Telegram bot directly
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/sendMessage" \
  -d "chat_id=<YOUR_CHAT_ID>" \
  -d "text=Test message"
```

**Common Issues:**

#### 1. Wrong Chat ID

**Solution:**

Verify chat ID:
```bash
# Send message to bot
# Then check:
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"

# Find "chat":{"id":123456}
# Update .env with correct chat ID
```

#### 2. Bot Blocked

**Solution:**

- Unblock bot in Telegram
- For groups: Re-add bot to group
- Check bot has permission to send messages

#### 3. Invalid Token

**Solution:**

Verify token with BotFather:
1. Message @BotFather on Telegram
2. Send `/mybots`
3. Select your bot
4. Click "API Token"
5. Verify matches .env

### Issue: RSS Feed Not Parsing

**Error:**
```
Error parsing RSS feed
```

**Solution:**

#### 1. Test Feed URL

```bash
# Test feed manually
curl -I "https://example.com/feed.xml"

# Should return 200 OK
# Content-Type should be application/rss+xml or application/atom+xml
```

#### 2. Invalid XML

Some feeds have invalid XML:
```bash
# Download and validate
curl "https://example.com/feed.xml" > test.xml
xmllint --noout test.xml

# If errors, feed is malformed
```

**Workaround:**

Use alternative feed URL or contact feed provider.

## Performance Issues

### Issue: High CPU Usage

**Diagnosis:**

```bash
# Check container stats
docker stats

# Check which process is using CPU
docker-compose exec n8n top
```

**Solution:**

#### 1. Too Many Workflows

Reduce concurrent executions:

In n8n, edit `.env`:
```bash
N8N_CONCURRENCY_PRODUCTION_LIMIT=5
```

#### 2. Heavy Workflow

Optimize workflow:
- Remove unnecessary nodes
- Use batch processing
- Add limits to queries
- Cache results

### Issue: High Memory Usage

**Diagnosis:**

```bash
# Check memory usage
docker stats feedops-n8n

# Check for memory leaks
docker-compose logs n8n | grep "out of memory"
```

**Solution:**

Increase memory limit:
```yaml
# In docker-compose.yml
services:
  n8n:
    deploy:
      resources:
        limits:
          memory: 4G
```

Or reduce workflow concurrency.

### Issue: Slow Response Times

**Symptoms:**
- Webhooks take >5 seconds to respond
- UI is slow
- Workflows queue up

**Solution:**

1. **Check database performance:**
   ```bash
   docker stats feedops-postgres
   ```

2. **Add indexes:**
   ```sql
   CREATE INDEX idx_notifications_sent_at ON notifications_history(sent_at);
   ```

3. **Enable caching:**
   - Use Redis for frequently accessed data
   - Cache feed source configuration

4. **Scale horizontally:**
   - See [SCALABILITY.md](SCALABILITY.md)

## Data Issues

### Issue: Missing Notifications

**Symptoms:**
- Workflow executes successfully
- No errors in logs
- Notification not in Telegram

**Diagnosis:**

```bash
# Check if notification was logged
docker-compose exec postgres psql -U n8n -d n8n -c \
  "SELECT * FROM notifications_history ORDER BY sent_at DESC LIMIT 10;"

# Check if marked as duplicate
docker-compose exec postgres psql -U n8n -d n8n -c \
  "SELECT item_hash, COUNT(*) FROM notifications_history GROUP BY item_hash HAVING COUNT(*) > 1;"
```

**Solution:**

If marked as duplicate incorrectly:
```sql
-- Clear specific duplicate
DELETE FROM notifications_history WHERE item_hash = 'hash_value';

-- Or clear all old data
DELETE FROM notifications_history WHERE sent_at < NOW() - INTERVAL '1 day';
```

### Issue: Incorrect Data in Notifications

**Symptoms:**
- Wrong title or description
- Missing fields
- Corrupted formatting

**Solution:**

Debug normalization function:

1. Open workflow
2. Click "Normalize" function node
3. Add logging:
   ```javascript
   console.log('Raw data:', JSON.stringify($input.item.json, null, 2));

   // ... normalization logic ...

   console.log('Normalized:', JSON.stringify(normalized, null, 2));
   return normalized;
   ```
4. Execute workflow
5. Check logs:
   ```bash
   docker-compose logs n8n | grep "Raw data"
   ```

## FAQ

### Q: How do I reset everything?

**A:** Complete reset (deletes all data):

```bash
docker-compose down -v
docker volume rm feedops_postgres_data feedops_redis_data feedops_n8n_data
docker-compose up -d
```

### Q: How do I backup my data?

**A:** Use backup script:

```bash
./scripts/backup.sh
```

Backup saved to `backups/` directory.

### Q: How do I restore from backup?

**A:** Use restore script:

```bash
./scripts/restore.sh backups/feedops_backup_YYYYMMDD_HHMMSS.tar.gz
```

### Q: Where are logs stored?

**A:** View logs:

```bash
# All services
docker-compose logs

# Specific service
docker-compose logs n8n
docker-compose logs postgres

# Follow logs (real-time)
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100
```

### Q: How do I update n8n?

**A:** Pull latest image and restart:

```bash
docker-compose pull n8n
docker-compose down
docker-compose up -d
```

### Q: Can I run FeedOps on Windows?

**A:** Yes, using Docker Desktop:

1. Install Docker Desktop for Windows
2. Enable WSL2 integration
3. Follow normal installation steps

Note: Scripts may need modification for Windows paths.

### Q: How do I change the database password?

**A:**

1. Stop services:
   ```bash
   docker-compose down
   ```

2. Update `.env`:
   ```bash
   POSTGRES_PASSWORD=new_password
   ```

3. Update database:
   ```bash
   docker-compose up -d postgres
   docker-compose exec postgres psql -U postgres -c "ALTER USER n8n WITH PASSWORD 'new_password';"
   ```

4. Restart all:
   ```bash
   docker-compose restart
   ```

### Q: How do I access the database directly?

**A:**

```bash
# PostgreSQL CLI
docker-compose exec postgres psql -U n8n -d n8n

# Run single query
docker-compose exec postgres psql -U n8n -d n8n -c "SELECT COUNT(*) FROM notifications_history;"
```

### Q: Workflow works manually but not automatically

**A:** Check:

1. Workflow is **Active** (green toggle)
2. Schedule is correct (for scheduled workflows)
3. Webhook URL is accessible (for webhook workflows)
4. Check execution history for errors

### Q: How do I monitor FeedOps in production?

**A:** Set up monitoring:

1. **Logs:** Use centralized logging (ELK stack, Loki)
2. **Metrics:** Use Prometheus + Grafana
3. **Alerts:** Configure alerting rules
4. **Uptime:** Use external monitoring (UptimeRobot, Pingdom)

See [SCALABILITY.md](SCALABILITY.md) for details.

## Getting Help

If you can't resolve your issue:

1. **Check existing issues:** [GitHub Issues]
2. **Create new issue:** Include:
   - Error message (full text)
   - Steps to reproduce
   - Environment details (OS, Docker version)
   - Relevant logs
3. **Community:** [Discord/Forum link]

## Additional Resources

- [Installation Guide](INSTALLATION.md)
- [Configuration Guide](CONFIGURATION.md)
- [Architecture Documentation](ARCHITECTURE.md)
- [Workflow Guide](N8N_WORKFLOWS.md)
- [Scalability Guide](SCALABILITY.md)
