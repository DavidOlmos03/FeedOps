#!/bin/bash
# PostgreSQL Initialization Script for FeedOps
# This script runs automatically on first PostgreSQL container start

set -e

echo "🚀 Initializing FeedOps database..."

# Create additional tables for FeedOps metadata
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create extension for UUID support
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

    -- FeedOps configuration table
    CREATE TABLE IF NOT EXISTS feedops_config (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        key VARCHAR(255) UNIQUE NOT NULL,
        value TEXT,
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Feed sources tracking
    CREATE TABLE IF NOT EXISTS feed_sources (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        source_type VARCHAR(50) NOT NULL, -- github, reddit, rss
        source_identifier VARCHAR(500) NOT NULL, -- repo URL, subreddit, feed URL
        config JSONB DEFAULT '{}',
        enabled BOOLEAN DEFAULT true,
        last_check TIMESTAMP,
        last_item_id VARCHAR(255),
        error_count INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(source_type, source_identifier)
    );

    -- Notifications history for deduplication
    CREATE TABLE IF NOT EXISTS notifications_history (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        source_id UUID REFERENCES feed_sources(id) ON DELETE CASCADE,
        item_id VARCHAR(255) NOT NULL,
        item_hash VARCHAR(64) NOT NULL, -- SHA256 of content
        title TEXT,
        url TEXT,
        sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        telegram_message_id BIGINT,
        metadata JSONB DEFAULT '{}'
    );

    -- Create indexes for performance
    CREATE INDEX IF NOT EXISTS idx_feed_sources_type ON feed_sources(source_type);
    CREATE INDEX IF NOT EXISTS idx_feed_sources_enabled ON feed_sources(enabled);
    CREATE INDEX IF NOT EXISTS idx_notifications_item_hash ON notifications_history(item_hash);
    CREATE INDEX IF NOT EXISTS idx_notifications_sent_at ON notifications_history(sent_at);
    CREATE INDEX IF NOT EXISTS idx_notifications_source_item ON notifications_history(source_id, item_id);

    -- Insert default configuration
    INSERT INTO feedops_config (key, value, description) VALUES
        ('notification_retention_days', '30', 'Days to keep notification history'),
        ('max_retries', '3', 'Maximum retries for failed operations'),
        ('retry_backoff_multiplier', '2', 'Backoff multiplier for retries'),
        ('version', '1.0.0', 'FeedOps version')
    ON CONFLICT (key) DO NOTHING;

    -- Create cleanup function
    CREATE OR REPLACE FUNCTION cleanup_old_notifications()
    RETURNS void AS \$\$
    BEGIN
        DELETE FROM notifications_history
        WHERE sent_at < NOW() - INTERVAL '30 days';
    END;
    \$\$ LANGUAGE plpgsql;

    -- Grant permissions
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $POSTGRES_USER;

EOSQL

echo "✅ Database initialization completed successfully!"
