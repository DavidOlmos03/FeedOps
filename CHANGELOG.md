# Changelog

All notable changes to FeedOps will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Web dashboard for management
- API endpoints for programmatic access
- Multi-tenant support
- Additional data sources (Twitter, Discord)
- Advanced analytics and reporting

## [1.0.0] - 2024-01-01

### Added
- Initial release of FeedOps
- Docker Compose setup for easy deployment
- PostgreSQL database with custom schema
- Redis caching support
- n8n workflow automation engine integration

#### Data Sources
- GitHub webhook monitoring (push, issues, PRs, releases)
- Reddit API polling with filtering
- RSS/Atom feed monitoring
- Extensible architecture for new sources

#### Features
- Telegram notification delivery with Markdown support
- Duplicate notification prevention
- Configurable message templates
- Retry logic with exponential backoff
- Error handling and alerting
- Source-specific filtering (keywords, scores, etc.)

#### Workflows
- GitHub Monitor workflow (webhook-based)
- Reddit Monitor workflow (polling)
- RSS Monitor workflow (polling)
- Telegram Dispatcher workflow (centralized delivery)

#### Scripts
- `generate-keys.sh` - Generate encryption keys and passwords
- `backup.sh` - Backup database and workflows
- `restore.sh` - Restore from backup
- `health-check.sh` - System health verification
- `cleanup.sh` - Database maintenance and cleanup
- `init-db.sh` - Database initialization

#### Documentation
- Comprehensive installation guide
- Configuration guide with examples
- Architecture documentation
- Workflow customization guide
- Scalability and migration strategies
- Troubleshooting guide with common solutions
- Quick start guide
- Contributing guidelines

#### Infrastructure
- Multi-service Docker Compose configuration
- Internal and external network separation
- Volume management for persistence
- Health checks for all services
- Production-ready with Traefik support
- Environment-based configuration

### Security
- HMAC-SHA256 webhook signature validation
- Encrypted credential storage
- Secure environment variable management
- Network isolation for databases
- Basic authentication for n8n UI

### Performance
- Connection pooling ready
- Redis caching support
- Indexed database queries
- Configurable retention policies
- Batch processing support

## [0.1.0] - 2023-12-01 (Beta)

### Added
- Initial beta release
- Basic GitHub monitoring
- Simple Telegram notifications
- PostgreSQL storage
- n8n integration

---

## Release Notes

### Version 1.0.0 - Production Ready

FeedOps 1.0.0 is the first production-ready release, featuring:

**Highlights:**
- 🚀 Complete automation of feed monitoring
- 📱 Real-time notifications via Telegram
- 🔄 Support for GitHub, Reddit, and RSS feeds
- 🐳 Easy Docker-based deployment
- 📚 Comprehensive documentation
- 🛡️ Production-ready security
- 📈 Scalability architecture

**What's Included:**
- 4 pre-built n8n workflows
- 6 management scripts
- 8 comprehensive documentation guides
- Full Docker Compose setup
- Database schema with indexes
- Backup and restore tools

**System Requirements:**
- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM minimum
- 10GB disk space

**Migration from Beta:**

If upgrading from beta version:

1. Backup existing data:
   ```bash
   ./scripts/backup.sh
   ```

2. Stop old version:
   ```bash
   docker-compose down
   ```

3. Pull latest version:
   ```bash
   git pull origin main
   ```

4. Update configuration:
   ```bash
   # Review changes in .env.example
   # Update your .env accordingly
   ```

5. Start new version:
   ```bash
   docker-compose up -d
   ```

6. Re-import workflows (they've been updated)

**Breaking Changes:**
- Database schema updated (auto-migrated)
- Workflow structure changed (re-import required)
- Environment variable names standardized

**Known Issues:**
- Large RSS feeds (>1000 items) may timeout - workaround: increase timeout in .env
- Reddit OAuth may need re-authorization after long idle periods
- Webhook URLs must be HTTPS in production (use Traefik or ngrok)

**Contributors:**
Thank you to all contributors who made this release possible!

**Next Steps:**
See [ROADMAP.md] for planned features in version 2.0.

---

For detailed changes, see commit history:
https://github.com/your-org/feedops/commits/main
