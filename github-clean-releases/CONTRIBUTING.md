# Contributing to GitHub Clean Releases Action

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## 🚀 Quick Start

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test locally (see Testing section)
5. Commit your changes: `git commit -m "Add my feature"`
6. Push to your fork: `git push origin feature/my-feature`
7. Open a Pull Request

## 📋 Development Setup

### Prerequisites

- Bash 4.0 or higher
- `curl`, `jq`, `sort` (standard on most systems)
- GitHub account with a Personal Access Token

### Local Testing

Test the script locally before submitting:

```bash
# Set environment variables
export TOKEN="your-github-token"
export SEMVER="1.0.0"
export KEEP="5"
export CLEAN_PRERELEASES="true"
export CLEAN_OLD_RELEASES="true"
export DRY_RUN="true"
export REPO="owner/repo"

# Run the script
cd scripts
chmod +x clean-releases.sh
./clean-releases.sh
```

### Syntax Validation

```bash
# Validate bash syntax
bash -n scripts/clean-releases.sh

# Run shellcheck if available
shellcheck scripts/clean-releases.sh
```

## 🧪 Testing

### Unit Testing

The action includes comprehensive test workflows:

1. **Syntax validation** - Ensures bash script is valid
2. **Integration tests** - Tests the action end-to-end
3. **Edge case tests** - Tests various version formats and configurations
4. **Validation tests** - Ensures input validation works correctly

Run tests in GitHub Actions by pushing to a branch or manually triggering the test workflow.

### Test Checklist

Before submitting a PR, ensure:

- [ ] Script passes syntax validation (`bash -n`)
- [ ] All test workflows pass
- [ ] Dry-run mode works correctly
- [ ] Error handling works as expected
- [ ] New features have documentation
- [ ] CHANGELOG.md is updated

## 📝 Coding Standards

### Bash Style Guide

- Use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use meaningful variable names in UPPER_CASE for global variables
- Use lowercase for local variables
- Quote all variables: `"${VARIABLE}"`
- Use functions for logical grouping
- Include comments for complex logic
- Use readonly for constants

### Example

```bash
# Good
readonly MAX_RETRIES=3
local retry_count=0

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Running in dry-run mode"
fi

# Bad
MAX_RETRIES=3
retry_count=0

if [ $DRY_RUN == "true" ]; then
    echo "Running in dry-run mode"
fi
```

### Logging

Use the provided logging functions:

```bash
log_info "Informational message"
log_success "Success message"
log_warning "Warning message"
log_error "Error message"
log_section "Section Header"
```

### Error Handling

- Always check command return values
- Use `|| return 1` for functions that can fail
- Increment `ERRORS` counter for non-fatal errors
- Exit with appropriate exit codes (0 = success, 1 = error)
- Provide meaningful error messages

## 🎯 Pull Request Guidelines

### Before Submitting

1. **Test thoroughly** - Ensure all tests pass
2. **Update documentation** - Add/update README, examples, changelog
3. **Follow conventions** - Match existing code style
4. **Keep focused** - One feature/fix per PR
5. **Write good commits** - Clear, descriptive commit messages

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested locally
- [ ] All CI tests pass
- [ ] Added new tests if applicable

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] No breaking changes (or documented)
```

### Commit Message Format

Use conventional commits:

```
type(scope): subject

body (optional)

footer (optional)
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(cleanup): add dry-run mode
fix(api): handle rate limit errors correctly
docs(readme): add troubleshooting section
```

## 🐛 Bug Reports

### Before Reporting

1. Check existing issues
2. Test with the latest version
3. Verify it's not a configuration issue

### Bug Report Template

```markdown
**Describe the bug**
Clear description of the bug

**To Reproduce**
Steps to reproduce:
1. Configure action with...
2. Run workflow...
3. Observe error...

**Expected behavior**
What you expected to happen

**Actual behavior**
What actually happened

**Workflow Configuration**
```yaml
# Your action configuration
```

**Logs**
```
# Relevant log output
```

**Environment**
- Runner OS: [e.g., ubuntu-latest]
- Action version: [e.g., v2.0.0]
- Repository size: [e.g., 100 releases]
```

## 💡 Feature Requests

### Feature Request Template

```markdown
**Feature Description**
Clear description of the feature

**Use Case**
Why is this feature needed?

**Proposed Solution**
How should it work?

**Alternatives Considered**
Other approaches you've considered

**Additional Context**
Any other relevant information
```

## 🔄 Release Process

Maintainers follow this process for releases:

1. Update version in script
2. Update CHANGELOG.md
3. Create GitHub release with tag
4. Update marketplace listing

## 📜 Code of Conduct

### Our Standards

- Be respectful and inclusive
- Accept constructive criticism
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Public or private harassment
- Publishing others' private information

## 📞 Getting Help

- 📚 Read the [README](README.md)
- 🔍 Search [existing issues](https://github.com/ignitia-core/ignitia-cicd-actions/issues)
- 💬 Start a [discussion](https://github.com/ignitia-core/ignitia-cicd-actions/discussions)
- 📧 Contact maintainers (for security issues only)

## 🏆 Recognition

Contributors will be:
- Listed in release notes
- Mentioned in CHANGELOG.md
- Credited in documentation (for significant contributions)

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

Thank you for contributing to make this action better! 🎉
