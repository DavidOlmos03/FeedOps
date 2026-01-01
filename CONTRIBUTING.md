# Contributing to FeedOps

Thank you for your interest in contributing to FeedOps! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors.

### Expected Behavior

- Be respectful and constructive
- Focus on what's best for the community
- Show empathy towards others
- Accept constructive criticism gracefully

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or inflammatory comments
- Personal attacks
- Publishing others' private information

## Getting Started

### Prerequisites

- Git
- Docker & Docker Compose
- Basic understanding of n8n
- Familiarity with JavaScript/Node.js

### Finding Issues to Work On

1. Check the [Issues](https://github.com/your-org/feedops/issues) page
2. Look for issues labeled:
   - `good first issue` - Great for newcomers
   - `help wanted` - We need assistance
   - `bug` - Something isn't working
   - `enhancement` - New feature or improvement

3. Comment on the issue to express interest

## Development Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/feedops.git
cd feedops

# Add upstream remote
git remote add upstream https://github.com/original/feedops.git
```

### 2. Create Development Environment

```bash
# Copy environment template
cp .env.example .env

# Generate keys
./scripts/generate-keys.sh

# Add your credentials for testing
nano .env
```

### 3. Start Development Environment

```bash
# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

### 4. Create Feature Branch

```bash
# Update main branch
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/your-feature-name
```

## How to Contribute

### Reporting Bugs

**Before submitting:**
1. Check if bug already reported
2. Test with latest version
3. Gather relevant information

**Bug Report Should Include:**
- Clear, descriptive title
- Steps to reproduce
- Expected behavior
- Actual behavior
- Environment details (OS, Docker version)
- Logs and error messages
- Screenshots if applicable

**Template:**
```markdown
**Description**
A clear description of the bug.

**Steps to Reproduce**
1. Step one
2. Step two
3. ...

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- OS: [e.g., Ubuntu 22.04]
- Docker version: [e.g., 20.10.21]
- FeedOps version: [e.g., 1.0.0]

**Logs**
```
Paste relevant logs here
```

**Screenshots**
If applicable
```

### Suggesting Enhancements

**Enhancement Proposal Should Include:**
- Clear, descriptive title
- Use case / motivation
- Detailed description of proposed feature
- Benefits and potential drawbacks
- Alternative solutions considered
- Mockups or examples (if applicable)

### Contributing Code

#### Types of Contributions

1. **Bug Fixes**
   - Fix identified bugs
   - Add tests to prevent regression
   - Update documentation if needed

2. **New Features**
   - Discuss in issue first
   - Follow existing architecture
   - Include tests and documentation
   - Update relevant guides

3. **Documentation**
   - Fix typos and errors
   - Improve clarity
   - Add examples
   - Translate to other languages

4. **Workflow Improvements**
   - Optimize existing workflows
   - Add new data source integrations
   - Improve error handling

## Pull Request Process

### 1. Prepare Your Changes

```bash
# Make your changes
# Edit files...

# Test your changes
docker-compose down
docker-compose up -d

# Run health check
./scripts/health-check.sh

# Test workflows manually
```

### 2. Commit Your Changes

```bash
# Stage changes
git add .

# Commit with clear message
git commit -m "feat: add support for Twitter monitoring

- Add Twitter API integration
- Create Twitter monitor workflow
- Update documentation
- Add tests for Twitter normalization

Closes #123"
```

**Commit Message Format:**

```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```
feat: add Discord integration

fix: resolve duplicate notification issue

docs: update installation guide for Windows

refactor: optimize database queries in RSS monitor
```

### 3. Push to Your Fork

```bash
# Push to your fork
git push origin feature/your-feature-name
```

### 4. Create Pull Request

1. Go to your fork on GitHub
2. Click "Pull Request"
3. Select your feature branch
4. Fill in PR template:

```markdown
## Description
Brief description of changes

## Motivation and Context
Why is this change needed?

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change (fix or feature)
- [ ] Documentation update

## How Has This Been Tested?
Describe testing performed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-reviewed my own code
- [ ] Commented complex code sections
- [ ] Updated documentation
- [ ] Changes generate no new warnings
- [ ] Added tests for changes
- [ ] All tests pass locally
- [ ] Dependent changes merged

## Screenshots
If applicable
```

### 5. Code Review Process

- Maintainers review within 3-5 days
- Address feedback by pushing new commits
- Discussion happens in PR comments
- Once approved, maintainer will merge

## Coding Standards

### JavaScript/Node.js

```javascript
// Use const/let, not var
const apiKey = process.env.API_KEY;
let counter = 0;

// Use template literals
const message = `Hello, ${name}!`;

// Use arrow functions for callbacks
items.map(item => item.id);

// Handle errors properly
try {
  const result = await fetchData();
} catch (error) {
  console.error('Failed to fetch:', error.message);
  // Handle error
}

// Add comments for complex logic
// Calculate exponential backoff time
const backoffTime = Math.pow(2, attempt) * 1000;
```

### n8n Workflows

- **Naming**: Use clear, descriptive node names
- **Error Handling**: Connect error outputs
- **Logging**: Add console.log in Function nodes for debugging
- **Documentation**: Add node notes for complex logic

### SQL

```sql
-- Use uppercase for keywords
SELECT id, name
FROM users
WHERE active = true
ORDER BY created_at DESC;

-- Use meaningful aliases
SELECT
    u.name AS user_name,
    COUNT(n.id) AS notification_count
FROM users u
LEFT JOIN notifications n ON u.id = n.user_id
GROUP BY u.id;

-- Add indexes for performance
CREATE INDEX idx_notifications_sent_at
ON notifications_history(sent_at);
```

### Shell Scripts

```bash
#!/bin/bash
# Script description
# Usage: script.sh [args]

set -e  # Exit on error

# Use variables for readability
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/feedops.log"

# Add help text
show_help() {
    cat << EOF
Usage: ${0##*/} [OPTIONS]

Options:
    -h, --help      Display this help
    -v, --verbose   Verbose output
EOF
}

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo "Error: Docker not found"
    exit 1
fi
```

### Documentation

- Use Markdown for all documentation
- Include code examples
- Add screenshots for UI steps
- Keep line length < 100 characters
- Use proper heading hierarchy

## Testing

### Manual Testing

```bash
# Test installation
./scripts/generate-keys.sh
docker-compose up -d
./scripts/health-check.sh

# Test workflows
# 1. Import workflows via n8n UI
# 2. Configure credentials
# 3. Execute manually
# 4. Verify output

# Test integrations
# 1. Add test data source
# 2. Trigger workflow
# 3. Verify notification received
```

### Test Checklist

Before submitting PR, verify:

- [ ] Fresh installation works
- [ ] All workflows import successfully
- [ ] Credentials can be configured
- [ ] Workflows execute without errors
- [ ] Notifications sent correctly
- [ ] Database queries work
- [ ] Scripts run without errors
- [ ] Documentation is accurate
- [ ] No breaking changes (or documented)

## Documentation

### When to Update Documentation

Update documentation when:
- Adding new feature
- Changing existing behavior
- Fixing documentation errors
- Adding examples or clarifications

### Documentation Files

- `README.md` - Project overview
- `docs/INSTALLATION.md` - Installation guide
- `docs/CONFIGURATION.md` - Configuration options
- `docs/ARCHITECTURE.md` - Technical architecture
- `docs/N8N_WORKFLOWS.md` - Workflow guide
- `docs/SCALABILITY.md` - Scaling strategies
- `docs/TROUBLESHOOTING.md` - Common issues
- `workflows/README.md` - Workflow templates

### Documentation Standards

- Start with overview/summary
- Use clear headings
- Include examples
- Add diagrams for complex concepts
- Link to related documentation
- Keep up to date

## Release Process

Maintainers handle releases:

1. Update version in relevant files
2. Update CHANGELOG.md
3. Create release branch
4. Tag release
5. Build and push Docker images
6. Create GitHub release
7. Announce release

## Questions?

- Open a [Discussion](https://github.com/your-org/feedops/discussions)
- Ask in issue comments
- Contact maintainers

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Recognition

Contributors are recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation

Thank you for contributing to FeedOps! 🎉
