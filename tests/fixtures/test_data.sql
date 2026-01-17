-- Test data fixtures for FeedOps database tests

-- Insert test configuration
INSERT INTO feedops_config (key, value, description) VALUES
    ('test_config_1', 'test_value_1', 'Test configuration entry 1'),
    ('test_config_2', 'test_value_2', 'Test configuration entry 2')
ON CONFLICT (key) DO NOTHING;

-- Insert test feed sources
INSERT INTO feed_sources (id, source_type, source_identifier, config, enabled, last_check)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'github', 'https://github.com/test/repo1', '{"branch": "main"}', true, NOW()),
    ('00000000-0000-0000-0000-000000000002', 'reddit', 'r/test', '{"limit": 10}', true, NOW()),
    ('00000000-0000-0000-0000-000000000003', 'rss', 'https://example.com/feed.xml', '{"refresh_interval": 30}', true, NOW()),
    ('00000000-0000-0000-0000-000000000004', 'github', 'https://github.com/test/repo2', '{"branch": "develop"}', false, NOW())
ON CONFLICT (source_type, source_identifier) DO NOTHING;

-- Insert test notifications history
INSERT INTO notifications_history (source_id, item_id, item_hash, title, url, sent_at, metadata)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'test-item-1', 'abc123def456', 'Test Notification 1', 'https://example.com/1', NOW() - INTERVAL '1 day', '{"priority": "high"}'),
    ('00000000-0000-0000-0000-000000000001', 'test-item-2', 'def456ghi789', 'Test Notification 2', 'https://example.com/2', NOW() - INTERVAL '2 days', '{"priority": "medium"}'),
    ('00000000-0000-0000-0000-000000000002', 'test-item-3', 'ghi789jkl012', 'Test Notification 3', 'https://example.com/3', NOW() - INTERVAL '3 days', '{"priority": "low"}'),
    ('00000000-0000-0000-0000-000000000003', 'test-item-4', 'jkl012mno345', 'Test Notification 4', 'https://example.com/4', NOW() - INTERVAL '40 days', '{"priority": "medium"}');
