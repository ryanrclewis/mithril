# Contributing to Mithril

Thank you for your interest in contributing to Mithril!

## How to Contribute

### Reporting Issues

- Check existing issues before creating a new one
- Provide detailed information about your setup (OS, Docker version, etc.)
- Include relevant logs and error messages

### Suggesting Blocklists

If you know of a good adult content blocklist that should be included:

1. Open an issue with the blocklist URL
2. Explain what content it blocks
3. Confirm it's actively maintained

### Code Contributions

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test your changes locally
5. Submit a pull request

### Testing Changes

Before submitting a PR:

```bash
# Build the image
./build.sh

# Test the container
docker compose up -d

# Verify DNS blocking works
nslookup blocked-site.com localhost
```

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help maintain a welcoming community

## Questions?

Open an issue or start a discussion if you have questions!
