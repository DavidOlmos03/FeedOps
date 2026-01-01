# FeedOps Scalability & Migration Strategy

This document outlines strategies for scaling FeedOps from a single-host development setup to a production-grade, highly available system.

## Table of Contents

- [Current Architecture Limitations](#current-architecture-limitations)
- [Scaling Dimensions](#scaling-dimensions)
- [Horizontal Scaling Strategy](#horizontal-scaling-strategy)
- [Vertical Scaling Strategy](#vertical-scaling-strategy)
- [Database Scaling](#database-scaling)
- [Caching Strategy](#caching-strategy)
- [Message Queue Integration](#message-queue-integration)
- [Kubernetes Migration](#kubernetes-migration)
- [Multi-Region Deployment](#multi-region-deployment)
- [Migration Roadmap](#migration-roadmap)
- [Performance Benchmarks](#performance-benchmarks)

## Current Architecture Limitations

### Single-Host Setup

**Current Capacity:**
- **Throughput**: ~100 notifications/minute
- **Concurrent Workflows**: Limited by single n8n instance
- **Data Volume**: 10-100K notifications/day
- **Availability**: Single point of failure
- **Scalability**: Vertical only (add more resources to one server)

**Bottlenecks:**

1. **n8n Single Instance**
   - CPU-bound workflow executions
   - Memory limited by container
   - No automatic failover

2. **PostgreSQL Single Instance**
   - Write throughput: ~1000 writes/second
   - Connection pool limited to 100 connections
   - No read replicas

3. **External API Limits**
   - Telegram: 30 messages/second per bot
   - Reddit: 60 requests/minute
   - GitHub: 5000 requests/hour (authenticated)

## Scaling Dimensions

### When to Scale?

| Metric | Threshold | Action |
|--------|-----------|--------|
| CPU Usage | > 80% sustained | Horizontal scaling |
| Memory Usage | > 85% | Vertical scaling |
| Database Connections | > 80 concurrent | Connection pooling / Read replicas |
| Notification Queue | > 1000 pending | Add workers / Message queue |
| API Rate Limits | > 70% usage | Multiple API keys / Stagger requests |
| Response Time | > 5 seconds | Caching / Optimization |

## Horizontal Scaling Strategy

### Phase 1: Multi-Instance n8n

Deploy multiple n8n instances behind a load balancer.

#### Architecture

```
                    ┌──────────────────┐
                    │   Load Balancer  │
                    │    (Traefik)     │
                    └────────┬─────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
     ┌──────▼──────┐  ┌─────▼──────┐  ┌─────▼──────┐
     │  n8n-1      │  │  n8n-2     │  │  n8n-3     │
     │  (Worker)   │  │  (Worker)  │  │  (Worker)  │
     └──────┬──────┘  └─────┬──────┘  └─────┬──────┘
            │                │                │
            └────────────────┼────────────────┘
                             │
                    ┌────────▼─────────┐
                    │   PostgreSQL     │
                    │   (Shared)       │
                    └──────────────────┘
```

#### Implementation

**docker-compose-scaled.yml:**
```yaml
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    deploy:
      replicas: 3  # Run 3 instances
    environment:
      - N8N_METRICS=true
      - N8N_DIAGNOSTICS_ENABLED=false
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
    # ... other config ...

  traefik:
    image: traefik:v2.10
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--metrics.prometheus=true"
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
```

**Start scaled deployment:**
```bash
docker-compose -f docker-compose-scaled.yml up -d --scale n8n=3
```

#### Benefits

- **3x throughput**: Process 3x more workflows concurrently
- **High availability**: Failure of one instance doesn't stop system
- **Rolling updates**: Update instances one at a time

#### Considerations

- **Webhook distribution**: Use consistent hashing in load balancer
- **Execution isolation**: Each instance needs separate Redis queue
- **Shared state**: All instances must use same PostgreSQL

### Phase 2: Dedicated Workflow Workers

Separate webhook receivers from workflow processors.

```
┌──────────────┐         ┌──────────────┐
│  n8n-web     │         │ n8n-worker-1 │
│  (Webhooks)  │────────▶│  (Process)   │
└──────────────┘    │    └──────────────┘
                    │    ┌──────────────┐
                    ├───▶│ n8n-worker-2 │
                    │    └──────────────┘
                    │    ┌──────────────┐
                    └───▶│ n8n-worker-3 │
                         └──────────────┘
```

**Implementation:**
```yaml
services:
  n8n-web:
    image: n8nio/n8n:latest
    environment:
      - N8N_DISABLE_PRODUCTION_MAIN_PROCESS=true
      - EXECUTIONS_MODE=queue

  n8n-worker:
    image: n8nio/n8n:latest
    deploy:
      replicas: 3
    command: worker
    environment:
      - EXECUTIONS_MODE=queue
```

## Vertical Scaling Strategy

### Resource Allocation

Increase resources for critical components.

#### PostgreSQL Optimization

**Current:** 1 CPU, 2GB RAM
**Scaled:** 4 CPU, 16GB RAM

**postgresql.conf:**
```conf
# Connection management
max_connections = 200
shared_buffers = 4GB
effective_cache_size = 12GB

# Query performance
work_mem = 64MB
maintenance_work_mem = 512MB
random_page_cost = 1.1

# Write performance
checkpoint_completion_target = 0.9
wal_buffers = 16MB
max_wal_size = 4GB
```

**Apply configuration:**
```yaml
services:
  postgres:
    image: postgres:16-alpine
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 16G
    volumes:
      - ./postgresql.conf:/etc/postgresql/postgresql.conf
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
```

#### n8n Optimization

**Current:** 1 CPU, 2GB RAM
**Scaled:** 2 CPU, 8GB RAM

```yaml
services:
  n8n:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 8G
    environment:
      - NODE_OPTIONS=--max-old-space-size=7168
      - EXECUTIONS_PROCESS_MAX_OLD_SPACE_SIZE=2048
```

## Database Scaling

### Phase 1: Connection Pooling

Reduce connection overhead with PgBouncer.

```yaml
services:
  pgbouncer:
    image: pgbouncer/pgbouncer:latest
    environment:
      - DATABASES_HOST=postgres
      - DATABASES_PORT=5432
      - DATABASES_USER=n8n
      - DATABASES_PASSWORD=${POSTGRES_PASSWORD}
      - POOL_MODE=transaction
      - MAX_CLIENT_CONN=1000
      - DEFAULT_POOL_SIZE=25

  n8n:
    environment:
      - DB_POSTGRESDB_HOST=pgbouncer
      - DB_POSTGRESDB_PORT=6432
```

**Benefits:**
- 1000 client connections → 25 database connections
- Reduced PostgreSQL overhead
- Better resource utilization

### Phase 2: Read Replicas

Offload read traffic to replica databases.

```
┌──────────────┐
│  PostgreSQL  │
│   (Primary)  │ ◄────── Writes
└──────┬───────┘
       │ Replication
       ├────────────┐
       ▼            ▼
┌──────────┐   ┌──────────┐
│ Replica-1│   │ Replica-2│ ◄── Reads
└──────────┘   └──────────┘
```

**docker-compose.yml:**
```yaml
services:
  postgres-primary:
    image: postgres:16-alpine
    environment:
      - POSTGRES_REPLICATION_MODE=master

  postgres-replica-1:
    image: postgres:16-alpine
    environment:
      - POSTGRES_REPLICATION_MODE=slave
      - POSTGRES_MASTER_HOST=postgres-primary
```

**Application Logic:**
```javascript
// In workflows, route queries appropriately
if (operation === 'SELECT') {
  useHost = 'postgres-replica-1';
} else {
  useHost = 'postgres-primary';
}
```

### Phase 3: Partitioning

Partition `notifications_history` by date.

```sql
-- Create partitioned table
CREATE TABLE notifications_history (
    id UUID,
    source_id UUID,
    item_id VARCHAR(255),
    sent_at TIMESTAMP,
    ...
) PARTITION BY RANGE (sent_at);

-- Create monthly partitions
CREATE TABLE notifications_history_2024_01
    PARTITION OF notifications_history
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE notifications_history_2024_02
    PARTITION OF notifications_history
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Auto-create partitions with pg_partman extension
CREATE EXTENSION pg_partman;
SELECT create_parent(
    'public.notifications_history',
    'sent_at',
    'native',
    'monthly'
);
```

**Benefits:**
- Faster queries (scan only relevant partitions)
- Easier archival (drop old partitions)
- Better maintenance (vacuum per partition)

## Caching Strategy

### Phase 1: Redis Caching

Cache frequently accessed data.

```javascript
// In workflows, add caching logic
const redis = require('redis');
const client = redis.createClient({
  host: process.env.REDIS_HOST,
  password: process.env.REDIS_PASSWORD
});

// Check cache first
const cachedData = await client.get(`source:${sourceId}`);
if (cachedData) {
  return JSON.parse(cachedData);
}

// Query database
const data = await queryDatabase(sourceId);

// Store in cache (5 minute TTL)
await client.setex(`source:${sourceId}`, 300, JSON.stringify(data));

return data;
```

### Phase 2: Application-Level Caching

Cache in n8n workflows.

**Add Cache Node:**
```yaml
- name: Cache Check
  type: n8n-nodes-base.redis
  operation: get
  key: "={{$json.cache_key}}"

- name: Cache Store
  type: n8n-nodes-base.redis
  operation: set
  key: "={{$json.cache_key}}"
  value: "={{JSON.stringify($json.data)}}"
  ttl: 300
```

## Message Queue Integration

### Phase 1: RabbitMQ for High Volume

Decouple producers from consumers.

```
GitHub Webhook ──┐
                 │
Reddit Poll ─────┼──▶ RabbitMQ ──▶ Worker 1 ──┐
                 │     Queue          Worker 2 ─┼──▶ Telegram
RSS Poll ────────┘                    Worker 3 ──┘
```

**docker-compose.yml:**
```yaml
services:
  rabbitmq:
    image: rabbitmq:3-management-alpine
    ports:
      - "5672:5672"   # AMQP
      - "15672:15672" # Management UI
    environment:
      - RABBITMQ_DEFAULT_USER=feedops
      - RABBITMQ_DEFAULT_PASS=${RABBITMQ_PASSWORD}
```

**Workflow Changes:**

Instead of calling Telegram Dispatcher directly:
```javascript
// Publish to queue
const amqp = require('amqplib');
const connection = await amqp.connect('amqp://rabbitmq');
const channel = await connection.createChannel();

await channel.assertQueue('notifications', { durable: true });
channel.sendToQueue(
  'notifications',
  Buffer.from(JSON.stringify(notification)),
  { persistent: true }
);
```

**Consumer Worker:**
```javascript
// Consume from queue
channel.consume('notifications', async (msg) => {
  const notification = JSON.parse(msg.content.toString());

  // Send to Telegram
  await sendToTelegram(notification);

  // Acknowledge message
  channel.ack(msg);
});
```

**Benefits:**
- **Buffering**: Handle traffic spikes
- **Reliability**: Guaranteed delivery with persistence
- **Load balancing**: Distribute work across workers
- **Priority queues**: Process urgent notifications first

### Phase 2: Kafka for Streaming

For very high volume (>10K events/second).

```yaml
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:latest

  kafka:
    image: confluentinc/cp-kafka:latest
    depends_on:
      - zookeeper

  schema-registry:
    image: confluentinc/cp-schema-registry:latest
```

## Kubernetes Migration

### Phase 1: Kompose Conversion

Convert Docker Compose to Kubernetes manifests.

```bash
# Install Kompose
curl -L https://github.com/kubernetes/kompose/releases/download/v1.31.2/kompose-linux-amd64 -o kompose
chmod +x kompose
sudo mv kompose /usr/local/bin/

# Convert docker-compose.yml
kompose convert -f docker-compose.yml -o k8s/
```

### Phase 2: Kubernetes Manifests

**k8s/n8n-deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n
spec:
  replicas: 3
  selector:
    matchLabels:
      app: n8n
  template:
    metadata:
      labels:
        app: n8n
    spec:
      containers:
      - name: n8n
        image: n8nio/n8n:latest
        env:
        - name: DB_POSTGRESDB_HOST
          value: postgres
        - name: DB_POSTGRESDB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 5678
          initialDelaySeconds: 60
          periodSeconds: 30
```

**k8s/postgres-statefulset.yaml:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 100Gi
```

**Deploy to Kubernetes:**
```bash
kubectl apply -f k8s/
kubectl get pods
kubectl logs -f deployment/n8n
```

### Phase 3: Helm Chart

Package as Helm chart for easy deployment.

**helm/feedops/Chart.yaml:**
```yaml
apiVersion: v2
name: feedops
description: Automated feed monitoring system
version: 1.0.0
```

**helm/feedops/values.yaml:**
```yaml
n8n:
  replicas: 3
  image:
    repository: n8nio/n8n
    tag: latest
  resources:
    requests:
      memory: 2Gi
      cpu: 1
    limits:
      memory: 4Gi
      cpu: 2

postgres:
  image:
    repository: postgres
    tag: 16-alpine
  persistence:
    size: 100Gi
```

**Install:**
```bash
helm install feedops ./helm/feedops
```

## Multi-Region Deployment

### Architecture

```
Region: US-East          Region: EU-West         Region: Asia-Pacific
┌──────────────┐         ┌──────────────┐        ┌──────────────┐
│ n8n + Postgres│         │ n8n + Postgres│       │ n8n + Postgres│
└───────┬──────┘         └───────┬──────┘        └───────┬──────┘
        │                        │                        │
        └────────────────────────┼────────────────────────┘
                                 │
                        ┌────────▼─────────┐
                        │  Global Load     │
                        │    Balancer      │
                        │  (CloudFlare)    │
                        └──────────────────┘
```

### Data Synchronization

**Option 1: Active-Active with CockroachDB**

Replace PostgreSQL with CockroachDB for multi-region writes.

**Option 2: Active-Passive with Replication**

Primary region handles writes, others are read replicas.

**Option 3: Event Sourcing**

Each region publishes events to central Kafka cluster.

## Migration Roadmap

### Stage 1: Single Host → Load Balanced (Month 1-2)

**Goals:**
- Deploy load balancer (Traefik)
- Run 3 n8n instances
- Implement health checks

**Steps:**
1. Add Traefik to docker-compose
2. Configure n8n for queue mode
3. Scale to 3 instances
4. Test failover

**Risks:**
- Session persistence issues
- Webhook routing complexity

### Stage 2: Database Optimization (Month 2-3)

**Goals:**
- Add PgBouncer connection pooling
- Create read replicas
- Implement partitioning

**Steps:**
1. Deploy PgBouncer
2. Update app to use pooler
3. Set up streaming replication
4. Partition large tables

**Risks:**
- Replication lag
- Partition maintenance overhead

### Stage 3: Message Queue (Month 3-4)

**Goals:**
- Integrate RabbitMQ
- Decouple workflows
- Implement worker pools

**Steps:**
1. Deploy RabbitMQ cluster
2. Modify workflows to publish
3. Create consumer workers
4. Monitor queue depth

**Risks:**
- Message loss during migration
- Increased complexity

### Stage 4: Kubernetes Migration (Month 4-6)

**Goals:**
- Convert to Kubernetes
- Implement auto-scaling
- Multi-region preparation

**Steps:**
1. Convert with Kompose
2. Create Helm chart
3. Deploy to K8s cluster
4. Configure HPA

**Risks:**
- Learning curve
- Migration downtime

## Performance Benchmarks

### Current (Single Host)

| Metric | Value |
|--------|-------|
| Throughput | 100 notifications/min |
| Latency (webhook) | < 1 second |
| Latency (poll) | 15-30 minutes |
| Max concurrent workflows | 10 |
| Database TPS | ~50 |

### Target (Scaled)

| Metric | Value |
|--------|-------|
| Throughput | 1000 notifications/min |
| Latency (webhook) | < 500ms |
| Latency (poll) | < 5 minutes |
| Max concurrent workflows | 100 |
| Database TPS | 500+ |

### Load Testing

**Tools:**
- Apache JMeter for webhook load testing
- Locust for distributed load testing
- k6 for performance testing

**Test Scenarios:**

```javascript
// k6 load test
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up
    { duration: '5m', target: 100 }, // Steady state
    { duration: '2m', target: 0 },   // Ramp down
  ],
};

export default function () {
  let res = http.post('http://localhost:5678/webhook/github-webhook', {
    // ... test payload ...
  });

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
}
```

**Run test:**
```bash
k6 run load-test.js
```

## Cost Estimates

### Current (Single Host)

- **Server**: $20/month (2 CPU, 4GB RAM)
- **Storage**: $5/month (50GB)
- **Total**: **$25/month**

### Scaled (Load Balanced)

- **Servers**: 3x $20 = $60/month
- **Database**: $50/month (dedicated, optimized)
- **Load Balancer**: $10/month
- **Storage**: $20/month (200GB)
- **Total**: **$140/month**

### Kubernetes (Production)

- **Cluster**: $200/month (managed K8s)
- **Database**: $150/month (managed PostgreSQL)
- **Load Balancer**: $50/month (cloud LB)
- **Storage**: $50/month (1TB)
- **Monitoring**: $30/month (Prometheus + Grafana)
- **Total**: **$480/month**

## Next Steps

1. **Measure current performance**
   - Set up monitoring (Prometheus/Grafana)
   - Baseline current metrics
   - Identify bottlenecks

2. **Plan migration**
   - Choose scaling strategy based on needs
   - Estimate costs and timeline
   - Prepare rollback plan

3. **Execute incrementally**
   - Start with vertical scaling
   - Add horizontal scaling when needed
   - Migrate to K8s when ready

4. **Monitor and optimize**
   - Track key metrics
   - Adjust based on actual usage
   - Iterate on configuration

For implementation details, see:
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [CONFIGURATION.md](CONFIGURATION.md)
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
