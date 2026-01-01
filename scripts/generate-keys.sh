#!/bin/bash
# Generate encryption keys for FeedOps

set -e

echo "🔐 Generating encryption keys for FeedOps..."

# Check if .env exists
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo "📋 Creating .env from .env.example..."
        cp .env.example .env
    else
        echo "❌ Error: .env.example not found!"
        exit 1
    fi
fi

# Generate N8N encryption key
if grep -q "^N8N_ENCRYPTION_KEY=$" .env || ! grep -q "^N8N_ENCRYPTION_KEY=" .env; then
    echo "🔑 Generating N8N encryption key..."
    N8N_KEY=$(openssl rand -hex 32)

    if grep -q "^N8N_ENCRYPTION_KEY=" .env; then
        # Update existing empty key
        sed -i "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=$N8N_KEY|" .env
    else
        # Add new key
        echo "N8N_ENCRYPTION_KEY=$N8N_KEY" >> .env
    fi

    echo "✅ N8N encryption key generated"
else
    echo "ℹ️  N8N encryption key already exists"
fi

# Generate random passwords if they contain 'changeme'
if grep -q "changeme" .env; then
    echo "🔒 Generating random passwords..."

    # Generate strong random password
    generate_password() {
        openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
    }

    # Replace changeme passwords
    sed -i "s/changeme_postgres_password/$(generate_password)/g" .env
    sed -i "s/changeme_n8n_password/$(generate_password)/g" .env
    sed -i "s/changeme_redis_password/$(generate_password)/g" .env
    sed -i "s/changeme_github_webhook_secret/$(generate_password)/g" .env

    echo "✅ Random passwords generated"
fi

echo ""
echo "✅ All keys generated successfully!"
echo ""
echo "⚠️  IMPORTANT: Keep your .env file secure and never commit it to version control!"
echo ""
echo "Next steps:"
echo "1. Edit .env and add your API tokens (GitHub, Reddit, Telegram)"
echo "2. Review other configuration values"
echo "3. Run: docker-compose up -d"
