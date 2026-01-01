# FeedOps Architecture Documentation

This document describes the technical architecture, design decisions, and implementation details of FeedOps.

## Table of Contents

- [System Overview](#system-overview)
- [Architecture Diagram](#architecture-diagram)
- [Components](#components)
- [Data Flow](#data-flow)
- [Database Schema](#database-schema)
- [Workflow Architecture](#workflow-architecture)
- [Security Considerations](#security-considerations)
- [Performance & Scalability](#performance--scalability)
- [Design Decisions](#design-decisions)

## System Overview

FeedOps is a modular, event-driven notification system that monitors multiple data sources and delivers formatted notifications via Telegram. The system is built on n8n workflow automation platform with PostgreSQL for persistence and Redis for caching.

### Key Characteristics

- **Event-Driven**: Responds to webhooks and scheduled polls
- **Modular**: Each data source has its own workflow
- **Scalable**: Designed for horizontal scaling
- **Resilient**: Automatic retries with exponential backoff
- **Extensible**: Easy to add new sources or destinations

### Technology Stack

- **Orchestration**: n8n (Node.js based workflow automation)
- **Database**: PostgreSQL 16 (Primary data store)
- **Cache**: Redis 7 (Session and temporary data)
- **Containerization**: Docker & Docker Compose
- **Reverse Proxy**: Traefik (Production only)

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Data Sources                            │
├─────────────┬─────────────┬─────────────┬──────────────────────┤
│   GitHub    │   Reddit    │   RSS/Atom  │   Future Sources     │
│  (Webhook)  │   (Polling) │  (Polling)  │   (Extensible)       │
└──────┬──────┴──────┬──────┴──────┬──────┴──────────────────────┘
       │             │             │
       │             │             │
       ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────────┐
│                         n8n Workflows                            │
├─────────────┬─────────────┬─────────────┬──────────────────────┤
│   GitHub    │   Reddit    │     RSS     │     Telegram         │
│   Monitor   │   Monitor   │   Monitor   │   Dispatcher         │
│             │             │             │                      │
│  • Validate │  • Poll API │  • Fetch    │  • Format msg        │
│  • Parse    │  • Filter   │  • Parse    │  • Send              │
│  • Dedup    │  • Dedup    │  • Dedup    │  • Retry             │
└──────┬──────┴──────┬──────┴──────┬──────┴──────────┬───────────┘
       │             │             │                  │
       └─────────────┴─────────────┴──────────────────┘
                             │
                             ▼
       ┌─────────────────────────────────────────────┐
       │           PostgreSQL Database               │
       ├─────────────────────────────────────────────┤
       │  • Feed sources configuration               │
       │  • Notification history (deduplication)     │
       │  • Execution logs                           │
       │  • n8n workflow data                        │
       └─────────────────┬───────────────────────────┘
                         │
                         ▼
       ┌─────────────────────────────────────────────┐
       │              Redis Cache                     │
       ├─────────────────────────────────────────────┤
       │  • Rate limiting data                        │
       │  • Temporary workflow state                  │
       │  • Session management                        │
       └─────────────────────────────────────────────┘
                         │
                         ▼
       ┌─────────────────────────────────────────────┐
       │           Telegram API                       │
       ├─────────────────────────────────────────────┤
       │  • Send formatted notifications              │
       │  • Support markdown & inline buttons         │
       │  • Multiple channels/groups                  │
       └─────────────────────────────────────────────┘
```

## Components

### 1. n8n Workflow Engine

**Role**: Core orchestration layer that executes workflows

**Responsibilities**:
- Execute scheduled and webhook-triggered workflows
- Manage workflow state and execution history
- Handle authentication and credentials
- Provide web UI for configuration

**Configuration**:
- Runs on port 5678 (configurable)
- Uses PostgreSQL for persistence
- Basic auth for security
- Environment variables for sensitive data

### 2. PostgreSQL Database

**Role**: Primary persistent data store

**Responsibilities**:
- Store n8n workflow definitions and executions
- Track feed sources and their configuration
- Maintain notification history for deduplication
- Store system configuration

**Key Tables**:
- `feed_sources`: Configuration for each monitored source
- `notifications_history`: All sent notifications (for dedup)
- `feedops_config`: System-wide settings
- n8n internal tables: workflow definitions, executions, credentials

### 3. Redis Cache

**Role**: High-performance cache and session store

**Responsibilities**:
- Cache frequently accessed data
- Store temporary workflow state
- Rate limiting counters
- Session management

**Use Cases**:
- Reduce database load for repeated queries
- Fast lookup for recent items
- Distributed locks for parallel execution

### 4. Data Source Monitors

#### GitHub Monitor (Webhook-based)

**Trigger**: Real-time via webhooks
**Events**: push, issues, pull_request, release

**Flow**:
1. Receive webhook POST
2. Validate signature using HMAC-SHA256
3. Extract and normalize event data
4. Check for duplicates in database
5. Send to Telegram Dispatcher
6. Log notification

**Advantages**:
- Real-time notifications (< 1 second latency)
- No polling overhead
- Scales well with many repositories

**Limitations**:
- Requires public endpoint or tunnel
- Webhook must be configured per repository

#### Reddit Monitor (Poll-based)

**Trigger**: Scheduled (every 15 minutes)
**API**: Reddit JSON API via OAuth2

**Flow**:
1. Fetch enabled Reddit sources from database
2. For each source, fetch latest posts
3. Apply filters (keywords, score, flair)
4. Normalize post data
5. Check for duplicates
6. Send to Telegram Dispatcher
7. Update source last_check timestamp

**Advantages**:
- No webhook configuration needed
- Flexible filtering
- Works with private subreddits

**Limitations**:
- Polling delay (up to 15 minutes)
- API rate limits (60 requests/minute)
- Requires OAuth credentials

#### RSS Monitor (Poll-based)

**Trigger**: Scheduled (every 30 minutes)
**Protocol**: RSS/Atom feeds via HTTP

**Flow**:
1. Fetch enabled RSS sources from database
2. For each source, fetch and parse feed
3. Filter items newer than last_check
4. Apply keyword filters if configured
5. Normalize item data
6. Check for duplicates
7. Send to Telegram Dispatcher
8. Update source last_check

**Advantages**:
- Universal (works with any RSS feed)
- No authentication required
- Standardized format

**Limitations**:
- Polling delay (up to 30 minutes)
- No real-time updates
- Feed quality varies

### 5. Telegram Dispatcher

**Trigger**: Called by other workflows
**Purpose**: Centralized notification formatting and delivery

**Flow**:
1. Receive normalized notification data
2. Format message based on source type
3. Add emoji, metadata, and inline buttons
4. Send to Telegram via Bot API
5. Handle errors with exponential backoff
6. Update notification with Telegram message ID
7. Send alerts if max retries reached

**Features**:
- **Smart Formatting**: Different layouts for GitHub/Reddit/RSS
- **Retry Logic**: Exponential backoff (2s, 4s, 8s)
- **Error Alerts**: Notify admins of persistent failures
- **Inline Buttons**: Quick actions (Open link, etc.)

## Data Flow

### End-to-End Flow Example (GitHub Push Event)

```
1. Developer pushes code to GitHub
   │
   ├─> GitHub sends webhook POST to n8n
   │
2. n8n: GitHub Monitor workflow triggered
   │
   ├─> Validate webhook signature (HMAC-SHA256)
   │   ├─ Valid? Continue
   │   └─ Invalid? Return 403 error
   │
   ├─> Extract event data (commit message, author, branch, etc.)
   │
   ├─> Normalize to standard format:
   │   {
   │     source: "github",
   │     event_type: "push",
   │     title: "Push to main",
   │     description: "Add new feature",
   │     url: "https://github.com/...",
   │     author: "developer",
   │     metadata: { commits: 3, branch: "main" }
   │   }
   │
   ├─> Generate content hash (SHA256) for deduplication
   │
   ├─> Query PostgreSQL: "SELECT * FROM notifications_history WHERE item_hash = ?"
   │   ├─ Found? Skip (duplicate)
   │   └─ Not found? Continue
   │
   ├─> Call Telegram Dispatcher workflow
   │
3. Telegram Dispatcher workflow
   │
   ├─> Format message with emoji and metadata
   │
   ├─> Send to Telegram API
   │   ├─ Success? Continue
   │   └─ Fail? Retry with exponential backoff (max 3 attempts)
   │
   ├─> Update notifications_history with Telegram message ID
   │
   └─> Return success

4. GitHub Monitor returns 200 OK to GitHub
```

## Database Schema

### feed_sources

Stores configuration for each monitored source.

```sql
CREATE TABLE feed_sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_type VARCHAR(50) NOT NULL,           -- 'github', 'reddit', 'rss'
    source_identifier VARCHAR(500) NOT NULL,    -- URL or identifier
    config JSONB DEFAULT '{}',                  -- Source-specific config
    enabled BOOLEAN DEFAULT true,
    last_check TIMESTAMP,                       -- Last successful check
    last_item_id VARCHAR(255),                  -- ID of last processed item
    error_count INTEGER DEFAULT 0,              -- Consecutive errors
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(source_type, source_identifier)
);
```

**Example Rows**:
```sql
-- GitHub repository
INSERT INTO feed_sources VALUES (
    uuid_generate_v4(),
    'github',
    'owner/repo',
    '{"events": ["push", "release"]}',
    true,
    NOW(),
    NULL,
    0,
    NOW(),
    NOW()
);

-- Reddit subreddit
INSERT INTO feed_sources VALUES (
    uuid_generate_v4(),
    'reddit',
    'r/programming',
    '{"keywords": "golang,rust", "min_score": 100}',
    true,
    NOW(),
    NULL,
    0,
    NOW(),
    NOW()
);

-- RSS feed
INSERT INTO feed_sources VALUES (
    uuid_generate_v4(),
    'rss',
    'https://hnrss.org/newest',
    '{"keywords": "docker"}',
    true,
    NOW(),
    NULL,
    0,
    NOW(),
    NOW()
);
```

### notifications_history

Stores all sent notifications for deduplication and audit.

```sql
CREATE TABLE notifications_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id UUID REFERENCES feed_sources(id) ON DELETE CASCADE,
    item_id VARCHAR(255) NOT NULL,              -- Unique item identifier
    item_hash VARCHAR(64) NOT NULL,             -- SHA256 content hash
    title TEXT,
    url TEXT,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    telegram_message_id BIGINT,                 -- Telegram message ID
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_notifications_item_hash ON notifications_history(item_hash);
CREATE INDEX idx_notifications_sent_at ON notifications_history(sent_at);
CREATE INDEX idx_notifications_source_item ON notifications_history(source_id, item_id);
```

### feedops_config

System-wide configuration key-value store.

```sql
CREATE TABLE feedops_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(255) UNIQUE NOT NULL,
    value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Workflow Architecture

### Workflow Design Patterns

#### 1. Trigger Pattern

Each monitoring workflow uses appropriate trigger:
- **Webhooks**: For real-time events (GitHub)
- **Schedule**: For polling (Reddit, RSS)

#### 2. ETL Pattern

Extract → Transform → Load pattern:
1. **Extract**: Fetch data from source
2. **Transform**: Normalize to standard format
3. **Load**: Store in database and send notification

#### 3. Error Handling Pattern

Comprehensive error handling at each step:
```javascript
try {
  // Primary operation
} catch (error) {
  // Log error
  // Increment error counter
  // Send alert if threshold reached
  // Apply exponential backoff for retries
}
```

#### 4. Deduplication Pattern

Two-layer deduplication:
1. **Item ID**: Unique identifier per item
2. **Content Hash**: SHA256 of content to catch duplicates with different IDs

### Workflow Communication

Workflows communicate via:
1. **Execute Workflow Node**: Synchronous call to another workflow
2. **Database**: Shared state via PostgreSQL
3. **Environment Variables**: Configuration passed via env vars

## Security Considerations

### Authentication & Authorization

1. **n8n Web UI**: Basic authentication (username/password)
2. **GitHub Webhooks**: HMAC-SHA256 signature validation
3. **Reddit API**: OAuth2 with client credentials
4. **Telegram Bot**: Token-based authentication
5. **PostgreSQL**: Password authentication, internal network only

### Data Security

1. **Credentials**: Stored encrypted in n8n (AES-256-GCM)
2. **Environment Variables**: Never committed to git
3. **Network Isolation**: Internal network for database/redis
4. **Secrets Management**: Stored in .env, mounted as environment variables

### Network Security

```
External Network (feedops-external)
├─ n8n (port 5678 exposed)
└─ Traefik (ports 80, 443 exposed in production)

Internal Network (feedops-internal)
├─ PostgreSQL (port 5432, internal only)
├─ Redis (port 6379, internal only)
└─ n8n (can access both networks)
```

### Input Validation

1. **Webhook Signatures**: Cryptographic validation
2. **SQL Injection**: Parameterized queries only
3. **XSS Prevention**: No HTML rendering in Telegram (Markdown only)
4. **Rate Limiting**: Via Redis counters

## Performance & Scalability

### Current Performance Characteristics

- **GitHub Webhooks**: < 1s latency from event to notification
- **Reddit Polling**: 15-minute maximum delay
- **RSS Polling**: 30-minute maximum delay
- **Throughput**: 100+ notifications/minute
- **Database**: Handles 10K+ notifications/day comfortably

### Bottlenecks

1. **Telegram API**: 30 messages/second limit per bot
2. **Reddit API**: 60 requests/minute limit
3. **Database Writes**: ~1000 writes/second max on single instance

### Scalability Strategies

See [SCALABILITY.md](SCALABILITY.md) for detailed scaling strategies.

Quick overview:
- **Horizontal**: Multiple n8n instances with load balancer
- **Vertical**: Increase resources for database
- **Caching**: Redis for frequently accessed data
- **Sharding**: Partition database by source type
- **Queue**: RabbitMQ/Kafka for high-volume async processing

## Design Decisions

### Why n8n?

**Pros**:
- Visual workflow editor (low barrier to entry)
- Self-hosted (full control over data)
- Extensive integrations (200+ nodes)
- Active community
- Docker-friendly

**Cons**:
- Node.js performance limitations
- UI-heavy (not ideal for pure code)
- Limited horizontal scaling without enterprise version

**Alternatives Considered**: Airflow (too heavy), Prefect (requires Python), custom solution (too much development)

### Why PostgreSQL?

**Pros**:
- ACID compliance for critical data
- JSON support (JSONB) for flexible schemas
- Excellent n8n integration
- Proven reliability

**Cons**:
- Vertical scaling limitations
- Requires maintenance (vacuuming, etc.)

**Alternatives Considered**: MySQL (less JSON support), MongoDB (lack of ACID for critical data)

### Why Docker Compose?

**Pros**:
- Simple deployment
- Declarative configuration
- Easy local development
- Path to Kubernetes (via Kompose)

**Cons**:
- Single-host limitation
- No built-in HA
- Manual orchestration needed for updates

**Alternatives Considered**: Kubernetes (too complex for v1), systemd (less portable)

### Monorepo vs Multi-repo

**Decision**: Monorepo (all workflows in one repository)

**Reasoning**:
- Easier to maintain consistency
- Shared database schema
- Atomic updates across workflows
- Simpler deployment

## Future Improvements

1. **Monitoring**: Add Prometheus metrics and Grafana dashboards
2. **Alerting**: Integrate with PagerDuty/Opsgenie
3. **Testing**: Add workflow integration tests
4. **CI/CD**: Automated testing and deployment pipeline
5. **Multi-tenancy**: Support multiple users with isolated data
6. **API**: REST API for programmatic access
7. **Web Dashboard**: Custom UI for management

## References

- [n8n Documentation](https://docs.n8n.io/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/documentation)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [GitHub Webhooks](https://docs.github.com/en/webhooks)
