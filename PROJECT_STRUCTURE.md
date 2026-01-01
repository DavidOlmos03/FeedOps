# FeedOps Project Structure

Complete overview of the FeedOps project organization.

## Directory Tree

```
feedops/
├── docs/                          # Documentation
│   ├── ARCHITECTURE.md           # Technical architecture and design
│   ├── CONFIGURATION.md          # Configuration guide
│   ├── INSTALLATION.md           # Installation instructions
│   ├── N8N_WORKFLOWS.md          # Workflow guide (UI & code)
│   ├── QUICKSTART.md             # Quick start guide
│   ├── SCALABILITY.md            # Scaling and migration strategies
│   ├── TROUBLESHOOTING.md        # Common issues and solutions
│   └── prompt.md                 # Original project specification
│
├── scripts/                       # Automation scripts
│   ├── backup.sh                 # Backup database and workflows
│   ├── cleanup.sh                # Database maintenance
│   ├── generate-keys.sh          # Generate encryption keys
│   ├── health-check.sh           # System health verification
│   ├── init-db.sh                # Database initialization
│   └── restore.sh                # Restore from backup
│
├── workflows/                     # n8n workflow templates
│   ├── 01-github-monitor.json    # GitHub webhook workflow
│   ├── 02-reddit-monitor.json    # Reddit polling workflow
│   ├── 03-rss-monitor.json       # RSS polling workflow
│   ├── 04-telegram-dispatcher.json # Notification dispatcher
│   └── README.md                 # Workflow documentation
│
├── configs/                       # Configuration files (optional)
│   └── (custom configs)
│
├── custom-nodes/                  # Custom n8n nodes (optional)
│   └── (custom node implementations)
│
├── .env.example                   # Environment template
├── .gitignore                     # Git ignore rules
├── .dockerignore                  # Docker ignore rules
├── CHANGELOG.md                   # Version history
├── CONTRIBUTING.md                # Contribution guidelines
├── docker-compose.yml             # Main orchestration file
├── PROJECT_STRUCTURE.md           # This file
└── README.md                      # Project overview

```

## File Purposes

### Root Level

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Orchestrates all services (n8n, PostgreSQL, Redis) |
| `.env.example` | Template for environment configuration |
| `.gitignore` | Files to exclude from version control |
| `.dockerignore` | Files to exclude from Docker builds |
| `README.md` | Project overview and quick links |
| `CHANGELOG.md` | Version history and release notes |
| `CONTRIBUTING.md` | Guidelines for contributors |
| `PROJECT_STRUCTURE.md` | This documentation |

### Documentation (`docs/`)

| File | Description | Audience |
|------|-------------|----------|
| `INSTALLATION.md` | Step-by-step installation | New users |
| `QUICKSTART.md` | 10-minute setup guide | Beginners |
| `CONFIGURATION.md` | Configuration options | All users |
| `N8N_WORKFLOWS.md` | Workflow customization | Power users |
| `ARCHITECTURE.md` | Technical design | Developers |
| `SCALABILITY.md` | Scaling strategies | DevOps/SRE |
| `TROUBLESHOOTING.md` | Problem solving | All users |
| `prompt.md` | Original specification | Reference |

### Scripts (`scripts/`)

| Script | Purpose | Usage |
|--------|---------|-------|
| `generate-keys.sh` | Generate encryption keys and passwords | Once during setup |
| `init-db.sh` | Initialize PostgreSQL schema | Automatic on first run |
| `backup.sh` | Create full system backup | Regularly (cron job) |
| `restore.sh` | Restore from backup | When needed |
| `cleanup.sh` | Clean old data and optimize | Weekly/monthly |
| `health-check.sh` | Verify system health | Monitoring/debugging |

### Workflows (`workflows/`)

| Workflow | Type | Trigger | Purpose |
|----------|------|---------|---------|
| `01-github-monitor.json` | Webhook | Real-time | Monitor GitHub events |
| `02-reddit-monitor.json` | Schedule | Every 15min | Poll Reddit for posts |
| `03-rss-monitor.json` | Schedule | Every 30min | Fetch RSS feeds |
| `04-telegram-dispatcher.json` | Sub-workflow | On-demand | Send notifications |

## Data Flow

```
External Sources          FeedOps Services           Outputs
─────────────────        ──────────────────         ────────

GitHub (webhook) ──┐
                   │
Reddit (API) ──────┼──▶ n8n Workflows ──▶ PostgreSQL
                   │         ▼                 │
RSS (HTTP) ────────┘         │                 │
                             │                 ▼
                             │            Deduplication
                             │                 │
                             │                 ▼
                             └──▶ Telegram Dispatcher
                                       │
                                       ▼
                                  Telegram Bot
                                       │
                                       ▼
                                  Your Phone 📱
```

## Configuration Files

### Environment Configuration (`.env`)

Contains sensitive configuration:
- Database credentials
- API tokens (GitHub, Reddit, Telegram)
- Encryption keys
- Application settings

**Never commit to git!**

### Docker Compose (`docker-compose.yml`)

Defines services:
- **postgres**: PostgreSQL 16 database
- **redis**: Redis 7 cache
- **n8n**: n8n workflow engine
- **traefik**: Reverse proxy (production only)

Networks:
- **feedops-internal**: Database/cache (isolated)
- **feedops-external**: n8n/Traefik (internet-facing)

Volumes:
- **postgres_data**: Database files
- **redis_data**: Redis persistence
- **n8n_data**: n8n workflows and credentials
- **traefik_certs**: SSL certificates

## Database Schema

### Tables

```sql
feedops_config          -- System configuration
  ├── key (unique)
  ├── value
  └── description

feed_sources           -- Data source configuration
  ├── id (UUID)
  ├── source_type (github/reddit/rss)
  ├── source_identifier (URL/name)
  ├── config (JSONB)
  ├── enabled (boolean)
  ├── last_check (timestamp)
  └── error_count

notifications_history  -- Sent notifications (dedup)
  ├── id (UUID)
  ├── source_id (FK)
  ├── item_id (unique)
  ├── item_hash (SHA256)
  ├── title
  ├── url
  ├── sent_at (timestamp)
  ├── telegram_message_id
  └── metadata (JSONB)
```

### Indexes

- `idx_notifications_item_hash` - Fast duplicate checks
- `idx_notifications_sent_at` - Cleanup queries
- `idx_feed_sources_enabled` - Active source queries

## Technology Stack

### Core Services

| Service | Version | Purpose |
|---------|---------|---------|
| n8n | Latest | Workflow automation |
| PostgreSQL | 16-alpine | Primary database |
| Redis | 7-alpine | Caching & queues |
| Traefik | 2.10 | Reverse proxy (prod) |

### Languages & Formats

- **JavaScript/Node.js**: n8n workflows, functions
- **SQL**: Database queries and schema
- **Bash**: Automation scripts
- **YAML**: Docker Compose configuration
- **JSON**: Workflow definitions
- **Markdown**: Documentation

### External APIs

- **GitHub API**: Webhook events
- **Reddit API**: OAuth2, JSON API
- **Telegram Bot API**: Message sending
- **RSS/Atom**: Standard XML feeds

## Extension Points

### Adding New Data Sources

1. Create workflow in `workflows/`
2. Add normalization logic (standard format)
3. Configure deduplication
4. Call Telegram Dispatcher
5. Document in `docs/`

### Adding New Destinations

1. Create new dispatcher workflow
2. Add credential type in n8n
3. Update source workflows to call new dispatcher
4. Document configuration

### Custom Nodes

Place custom n8n nodes in `custom-nodes/`:

```
custom-nodes/
└── n8n-nodes-custom-source/
    ├── package.json
    ├── CustomSource.node.ts
    └── CustomSource.node.json
```

Mount in docker-compose.yml:
```yaml
volumes:
  - ./custom-nodes:/home/node/.n8n/custom
```

## Deployment Variations

### Development (Local)

```bash
docker-compose up -d
```

Services:
- n8n (1 instance)
- PostgreSQL (1 instance)
- Redis (1 instance)

### Staging

```bash
docker-compose -f docker-compose.yml up -d
```

Additional:
- Basic monitoring
- Backup automation
- Log aggregation

### Production

```bash
docker-compose --profile production up -d
```

Additional services:
- Traefik (SSL, load balancing)
- Health checks enabled
- Resource limits configured
- Automatic restarts

### Kubernetes (Scaled)

Use Kompose to convert:
```bash
kompose convert -f docker-compose.yml -o k8s/
```

Or use provided Helm chart (future).

## Monitoring Files

### Logs

```bash
# All services
docker-compose logs

# Specific service
docker-compose logs n8n
docker-compose logs postgres
docker-compose logs redis

# Follow logs
docker-compose logs -f

# With timestamps
docker-compose logs -f --timestamps
```

### Execution History

In n8n UI:
- Click "Executions" tab
- Filter by workflow, status, date
- Inspect node inputs/outputs

### Database Queries

```bash
# Active sources
docker-compose exec postgres psql -U n8n -d n8n -c \
  "SELECT * FROM feed_sources WHERE enabled = true;"

# Recent notifications
docker-compose exec postgres psql -U n8n -d n8n -c \
  "SELECT * FROM notifications_history ORDER BY sent_at DESC LIMIT 10;"

# System stats
docker-compose exec postgres psql -U n8n -d n8n -c \
  "SELECT
    (SELECT COUNT(*) FROM feed_sources) as total_sources,
    (SELECT COUNT(*) FROM feed_sources WHERE enabled = true) as active_sources,
    (SELECT COUNT(*) FROM notifications_history) as total_notifications,
    (SELECT COUNT(*) FROM notifications_history WHERE sent_at > NOW() - INTERVAL '24 hours') as last_24h;"
```

## Backup Structure

Created by `./scripts/backup.sh`:

```
backups/
└── feedops_backup_20240101_120000.tar.gz
    ├── database.sql           # PostgreSQL dump
    ├── workflows.json         # Exported workflows
    ├── n8n_data.tar.gz       # n8n volume backup
    ├── env.template          # Sanitized env vars
    └── workflows/            # Workflow templates
```

## Development Workflow

```
1. Fork & Clone
   ↓
2. Create Branch
   ↓
3. Make Changes
   ↓
4. Test Locally
   ↓
5. Commit & Push
   ↓
6. Create Pull Request
   ↓
7. Code Review
   ↓
8. Merge to Main
   ↓
9. Deploy
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Resource Usage

### Typical Usage (Single Host)

| Service | CPU | Memory | Disk |
|---------|-----|--------|------|
| n8n | 0.5-1 core | 500MB-1GB | - |
| PostgreSQL | 0.2-0.5 core | 200MB-500MB | 1-10GB |
| Redis | 0.1 core | 50-100MB | 100MB |
| **Total** | **1-2 cores** | **1-2GB** | **2-11GB** |

### Recommended (Production)

| Service | CPU | Memory | Disk |
|---------|-----|--------|------|
| n8n (×3) | 3 cores | 6GB | - |
| PostgreSQL | 2 cores | 4GB | 50GB |
| Redis | 1 core | 1GB | 5GB |
| **Total** | **6 cores** | **11GB** | **55GB** |

## Quick Reference

### Common Commands

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# View logs
docker-compose logs -f

# Health check
./scripts/health-check.sh

# Backup
./scripts/backup.sh

# Clean up
./scripts/cleanup.sh

# Access database
docker-compose exec postgres psql -U n8n -d n8n

# Access n8n
http://localhost:5678
```

### Common Locations

| Item | Location |
|------|----------|
| Configuration | `.env` |
| Logs | `docker-compose logs` |
| Database | `docker volume feedops_postgres_data` |
| Workflows | n8n UI or `workflows/` templates |
| Backups | `backups/` directory |
| Scripts | `scripts/` directory |
| Documentation | `docs/` directory |

## Next Steps

1. **Read Documentation**
   - Start with [QUICKSTART.md](docs/QUICKSTART.md)
   - Or [INSTALLATION.md](docs/INSTALLATION.md) for details

2. **Set Up Environment**
   - Copy `.env.example` to `.env`
   - Configure credentials
   - Generate keys

3. **Deploy**
   - Run `docker-compose up -d`
   - Import workflows
   - Configure sources

4. **Monitor**
   - Check execution history
   - Review logs
   - Run health checks

5. **Customize**
   - Modify workflows
   - Add data sources
   - Adjust notifications

For questions, see [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).
