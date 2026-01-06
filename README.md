# FeedOps - Automated Feed Monitoring System

FeedOps is a professional, modular, and scalable monitoring system built with n8n and Docker (Open Source). It automates the collection, processing, and distribution of updates from multiple sources (GitHub, Reddit, RSS feeds) to Telegram.

## Features

- **Multiple Data Sources**
  - GitHub: Monitor repositories for pushes, issues, PRs, and releases
  - Reddit: Track subreddits and user posts with keyword filtering
  - RSS/Atom: Monitor custom feeds with periodic updates

- **Production-Ready**
  - Docker-based deployment
  - Comprehensive logging
  - Health checks and monitoring

## Quick Start

### Prerequisites

- Docker >= 20.10
- Docker Compose >= 2.0
- 4GB RAM minimum
- 10GB disk space (Important)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd feedops
```

2. Copy and configure environment variables:
```bash
cp .env.example .env
# Edit .env with your credentials
```

3. Generate encryption key (Important):
```bash
./scripts/generate-keys.sh
```

4. Start the services:
```bash
docker-compose up -d
```

5. Access n8n:
```
http://localhost:5678
Username: admin (or your configured user)
Password: (from .env)
```

## Documentation
Check the files inside the "docs" folder, in case you have any problem or contact with me 🤙🏻

## Contributing

This project follows industry best practices for Docker and n8n deployments. Contributions should maintain:
- Modular architecture
- Comprehensive error handling
- Clear documentation
- Security best practices

## Support

For issues and questions, please refer to:
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [FAQ](docs/FAQ.md)
