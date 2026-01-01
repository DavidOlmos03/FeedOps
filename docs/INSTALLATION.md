# FeedOps Installation Guide

This guide will walk you through installing and setting up FeedOps on your local machine or server.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Installation](#detailed-installation)
- [Initial Configuration](#initial-configuration)
- [Importing Workflows](#importing-workflows)
- [Verification](#verification)
- [Next Steps](#next-steps)

## Prerequisites

### Required Software

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **Git**: For cloning the repository
- **Bash**: For running setup scripts (pre-installed on Linux/macOS)

### System Requirements

- **RAM**: Minimum 4GB (8GB recommended)
- **Disk Space**: Minimum 10GB free
- **CPU**: 2 cores minimum (4 cores recommended)
- **OS**: Linux, macOS, or Windows with WSL2

### Check Your System

```bash
# Check Docker version
docker --version
# Should show: Docker version 20.10.x or higher

# Check Docker Compose version
docker-compose --version
# Should show: Docker Compose version 2.x.x or higher

# Verify Docker is running
docker ps
# Should show a list of containers (or empty list if none running)
```

## Quick Start

For experienced users who want to get started quickly:

```bash
# 1. Clone and navigate
git clone <repository-url>
cd feedops

# 2. Setup environment
cp .env.example .env
./scripts/generate-keys.sh

# 3. Edit .env with your API tokens
nano .env  # or use your preferred editor

# 4. Start services
docker-compose up -d

# 5. Access n8n
open http://localhost:5678
```

## Detailed Installation

### Step 1: Clone the Repository

```bash
# Clone the repository
git clone <repository-url>

# Navigate into the directory
cd feedops

# Verify files are present
ls -la
```

You should see:
- `docker-compose.yml`
- `.env.example`
- `scripts/` directory
- `workflows/` directory
- `docs/` directory

### Step 2: Environment Configuration

#### 2.1 Create Environment File

```bash
# Copy the example environment file
cp .env.example .env
```

#### 2.2 Generate Encryption Keys

```bash
# Make script executable (if not already)
chmod +x scripts/generate-keys.sh

# Run the key generation script
./scripts/generate-keys.sh
```

This script will:
- Generate a secure N8N encryption key
- Create random passwords for PostgreSQL, Redis, and n8n
- Replace placeholder values in .env

#### 2.3 Configure API Credentials

Edit the `.env` file with your favorite text editor:

```bash
nano .env
# or
vim .env
# or
code .env  # if using VS Code
```

**Required Configuration:**

1. **Telegram Bot** (Required for notifications)
   ```bash
   TELEGRAM_BOT_TOKEN=your_bot_token_here
   TELEGRAM_DEFAULT_CHAT_ID=your_chat_id_here
   ```

   How to get these:
   - Open Telegram and search for `@BotFather`
   - Send `/newbot` and follow instructions
   - Copy the bot token
   - For chat ID: Send a message to your bot, then visit:
     `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Find your chat ID in the response

2. **GitHub** (Optional - only if monitoring GitHub)
   ```bash
   GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here
   GITHUB_WEBHOOK_SECRET=your_secret_here
   ```

   How to get these:
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Generate new token with `repo` scope
   - For webhook secret, use any random string (or keep generated one)

3. **Reddit** (Optional - only if monitoring Reddit)
   ```bash
   REDDIT_CLIENT_ID=your_client_id
   REDDIT_CLIENT_SECRET=your_client_secret
   REDDIT_USERNAME=your_username
   REDDIT_PASSWORD=your_password
   ```

   How to get these:
   - Go to https://www.reddit.com/prefs/apps
   - Click "Create App" or "Create Another App"
   - Select "script" type
   - Fill in name and redirect URI (can use http://localhost:8080)
   - Copy client ID and secret

**Optional Configuration:**

- Change default ports if needed
- Adjust retention periods
- Configure alert channels
- Set timezone

### Step 3: Start the Services

#### 3.1 First-Time Startup

```bash
# Start all services in detached mode
docker-compose up -d
```

This will:
- Pull Docker images (may take a few minutes)
- Create Docker volumes for persistent data
- Start PostgreSQL, Redis, and n8n
- Initialize the database with FeedOps schema

#### 3.2 Monitor Startup

```bash
# Watch the logs
docker-compose logs -f

# Press Ctrl+C to stop watching (services keep running)
```

Wait for the following messages:
- PostgreSQL: `database system is ready to accept connections`
- n8n: `Editor is now accessible via`

This typically takes 30-60 seconds.

#### 3.3 Verify Services

```bash
# Check service status
docker-compose ps
```

All services should show as "healthy" or "running":
```
NAME                STATUS
feedops-postgres    Up (healthy)
feedops-redis       Up (healthy)
feedops-n8n         Up (healthy)
```

## Initial Configuration

### Step 4: Access n8n

1. Open your browser and navigate to:
   ```
   http://localhost:5678
   ```

2. Login with credentials from `.env`:
   - Username: Value of `N8N_BASIC_AUTH_USER` (default: admin)
   - Password: Value of `N8N_BASIC_AUTH_PASSWORD`

### Step 5: Configure n8n Credentials

Before importing workflows, set up credentials:

#### PostgreSQL Credential

1. Click "Credentials" in left menu
2. Click "+ New Credential"
3. Search for and select "Postgres"
4. Enter:
   - **Name**: `PostgreSQL` (exactly as shown)
   - **Host**: `postgres`
   - **Database**: Value from `POSTGRES_DB` in .env
   - **User**: Value from `POSTGRES_USER` in .env
   - **Password**: Value from `POSTGRES_PASSWORD` in .env
   - **Port**: `5432`
   - **SSL**: Disabled
5. Click "Create"

#### Telegram Credential

1. Click "+ New Credential"
2. Search for and select "Telegram"
3. Enter:
   - **Name**: `Telegram Bot` (exactly as shown)
   - **Access Token**: Value from `TELEGRAM_BOT_TOKEN` in .env
4. Click "Create"

#### Reddit OAuth2 Credential (Optional)

1. Click "+ New Credential"
2. Search for and select "Reddit OAuth2 API"
3. Enter:
   - **Name**: `Reddit OAuth2` (exactly as shown)
   - **Client ID**: Value from `REDDIT_CLIENT_ID` in .env
   - **Client Secret**: Value from `REDDIT_CLIENT_SECRET` in .env
4. Follow OAuth flow to authorize
5. Click "Create"

## Importing Workflows

### Step 6: Import Workflow Templates

#### Method 1: Import via UI (Recommended)

1. In n8n, click "Workflows" in left menu
2. Click "Import from File" (or press Ctrl+O)
3. Navigate to `workflows/` directory
4. Select `04-telegram-dispatcher.json` first
5. Click "Import"
6. Repeat for remaining workflows:
   - `01-github-monitor.json`
   - `02-reddit-monitor.json`
   - `03-rss-monitor.json`

**Important**: Import the Telegram Dispatcher first as other workflows depend on it.

#### Method 2: Automatic Import via Script

```bash
# From the project root directory
for workflow in workflows/0*.json; do
  filename=$(basename "$workflow")
  docker cp "$workflow" feedops-n8n:/tmp/
  docker exec feedops-n8n n8n import:workflow --input="/tmp/$filename"
done
```

### Step 7: Activate Workflows

For each imported workflow:

1. Open the workflow in n8n
2. Review node configurations
3. Click the "Inactive" toggle in top-right to activate
4. Click "Save"

## Verification

### Step 8: Run Health Check

```bash
# Run the health check script
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

### Step 9: Test Workflows

#### Test Telegram Dispatcher

1. In n8n, open the "Telegram Dispatcher" workflow
2. Click "Execute Workflow" button
3. Provide test data in the format:
   ```json
   {
     "source": "test",
     "title": "Test Notification",
     "description": "This is a test",
     "url": "https://example.com",
     "timestamp": "2024-01-01T00:00:00Z",
     "metadata": {}
   }
   ```
4. Check your Telegram chat for the message

#### Test RSS Monitor

1. Add a test RSS feed to the database:
   ```bash
   docker-compose exec postgres psql -U n8n -d n8n -c \
     "INSERT INTO feed_sources (source_type, source_identifier, config, enabled)
      VALUES ('rss', 'https://hnrss.org/newest', '{}', true);"
   ```

2. Open "RSS Monitor" workflow in n8n
3. Click "Execute Workflow"
4. Check execution log for results

## Next Steps

After successful installation:

1. **Configure Data Sources**: See [CONFIGURATION.md](CONFIGURATION.md)
2. **Set Up GitHub Webhooks**: See [N8N_WORKFLOWS.md](N8N_WORKFLOWS.md)
3. **Review Architecture**: See [ARCHITECTURE.md](ARCHITECTURE.md)
4. **Plan for Scaling**: See [SCALABILITY.md](SCALABILITY.md)

## Common Issues

### Port Already in Use

If port 5678 is already in use:

1. Edit `.env` and change `N8N_PORT`:
   ```bash
   N8N_PORT=5679
   ```

2. Restart services:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

### Database Connection Failed

If n8n can't connect to PostgreSQL:

1. Check PostgreSQL is healthy:
   ```bash
   docker-compose ps postgres
   ```

2. Check logs:
   ```bash
   docker-compose logs postgres
   ```

3. Restart services:
   ```bash
   docker-compose restart
   ```

### Workflow Import Fails

If workflow import fails:

1. Ensure credentials are created first
2. Check credential names match exactly
3. Try importing one workflow at a time
4. Check n8n logs for specific errors

For more troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## Uninstallation

To completely remove FeedOps:

```bash
# Stop and remove containers
docker-compose down

# Remove volumes (WARNING: This deletes all data!)
docker volume rm feedops_postgres_data feedops_redis_data feedops_n8n_data

# Remove project directory
cd ..
rm -rf feedops
```

## Support

- Documentation: [docs/](.)
- Issues: Create an issue on GitHub
- Community: [Your community link]
