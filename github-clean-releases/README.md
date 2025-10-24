# GitHub Clean Releases Action

[![GitHub Release](https://img.shields.io/github/v/release/ignitia-core/ignitia-cicd-actions)](https://github.com/ignitia-core/ignitia-cicd-actions/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Production-grade GitHub Action for cleaning up releases and tags based on semantic versioning rules. Automatically removes prerelease versions and maintains configurable retention of stable releases.

## ✨ Features

- 🎯 **Semantic Version Aware** - Only processes releases at or below your current version
- 🧪 **Prerelease Cleanup** - Automatically removes alpha, beta, and other prerelease versions
- 📦 **Retention Management** - Keep configurable number of stable releases
- 🔍 **Dry-Run Mode** - Preview changes before applying them
- 🔄 **Retry Logic** - Automatic retries with exponential backoff
- ⚡ **Rate Limit Handling** - Intelligently handles GitHub API rate limits
- 📊 **Detailed Logging** - Comprehensive, color-coded output with timestamps
- 🎛️ **Action Outputs** - Provides metrics for downstream workflow steps
- ✅ **Input Validation** - Validates all inputs before execution
- 🛡️ **Error Handling** - Graceful error handling with detailed messages

## 📋 Prerequisites

- GitHub token with `repo` scope (for deleting releases and tags)
- `curl`, `jq`, and `sort` (pre-installed on GitHub Actions runners)

## 🚀 Usage

### Basic Example

```yaml
name: Cleanup Releases

on:
  push:
    tags:
      - 'v*'

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Clean up old releases
        uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          semantic-version: '1.2.3'
```

### Advanced Example

```yaml
name: Advanced Release Cleanup

on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      dry-run:
        description: 'Run in dry-run mode'
        required: false
        default: 'true'

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      contents: write  # Required for deleting releases and tags
    
    steps:
      - name: Extract version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
      
      - name: Clean up releases
        id: cleanup
        uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          semantic-version: ${{ steps.version.outputs.VERSION }}
          keep: 5
          clean-prereleases: true
          clean-old-releases: true
          dry-run: ${{ github.event.inputs.dry-run || 'false' }}
      
      - name: Report cleanup results
        run: |
          echo "## Cleanup Results" >> $GITHUB_STEP_SUMMARY
          echo "- Prereleases deleted: ${{ steps.cleanup.outputs.prereleases-deleted }}" >> $GITHUB_STEP_SUMMARY
          echo "- Old releases deleted: ${{ steps.cleanup.outputs.old-releases-deleted }}" >> $GITHUB_STEP_SUMMARY
          echo "- Total deleted: ${{ steps.cleanup.outputs.total-deleted }}" >> $GITHUB_STEP_SUMMARY
          echo "- API calls: ${{ steps.cleanup.outputs.api-calls }}" >> $GITHUB_STEP_SUMMARY
```

### Dry-Run Before Cleanup

```yaml
- name: Test cleanup (dry-run)
  uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    semantic-version: '2.0.0'
    dry-run: true

- name: Perform actual cleanup
  if: success()
  uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    semantic-version: '2.0.0'
    dry-run: false
```

### Custom Repository

```yaml
- name: Clean another repository
  uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v1
  with:
    token: ${{ secrets.PAT_TOKEN }}  # Personal Access Token with repo scope
    semantic-version: '1.5.0'
    repo: 'my-org/other-repo'
```

## 📥 Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `token` | GitHub Personal Access Token with `repo` scope | ✅ Yes | - |
| `semantic-version` | Current semantic version (e.g., `1.2.3` or `1.2.3-alpha`) | ✅ Yes | - |
| `keep` | Number of stable releases to retain | ❌ No | `10` |
| `clean-prereleases` | Delete prerelease versions (e.g., `1.2.3-alpha`) | ❌ No | `true` |
| `clean-old-releases` | Delete stable releases beyond the `keep` count | ❌ No | `true` |
| `dry-run` | Preview changes without deleting | ❌ No | `false` |
| `repo` | Repository in format `owner/repo` (defaults to current) | ❌ No | Current repo |

### Input Details

#### `semantic-version`
- Must follow semver format: `MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]`
- Examples: `1.0.0`, `2.3.4-alpha`, `1.0.0-beta.1`, `1.2.3+build.123`
- Only releases at or below this version are considered for cleanup
- Can include or omit the `v` prefix

#### `keep`
- Must be a non-negative integer
- Applies only to stable (non-prerelease) releases
- Most recent releases are always retained
- Example: `keep: 5` retains the 5 newest stable releases

#### `clean-prereleases`
- Identifies prereleases by the presence of a dash in the version
- Examples: `1.2.3-alpha`, `1.0.0-beta.1`, `2.0.0-rc.2`
- If `false`, all prereleases are preserved

#### `clean-old-releases`
- Only affects stable releases beyond the `keep` count
- If `false`, no stable releases are deleted (only prereleases if enabled)
- Works in conjunction with the `keep` parameter

#### `dry-run`
- When `true`, shows what would be deleted without making changes
- Useful for testing configuration before actual cleanup
- All outputs still reflect what would have happened

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `prereleases-deleted` | Number of prerelease versions deleted |
| `old-releases-deleted` | Number of old stable releases deleted |
| `tags-deleted` | Number of Git tags deleted |
| `total-deleted` | Total releases deleted (prereleases + old releases) |
| `api-calls` | Number of GitHub API calls made |
| `errors` | Number of errors encountered (0 = success) |

### Using Outputs

```yaml
- name: Clean releases
  id: cleanup
  uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    semantic-version: '1.0.0'

- name: Check for errors
  if: steps.cleanup.outputs.errors != '0'
  run: |
    echo "Cleanup encountered ${{ steps.cleanup.outputs.errors }} error(s)"
    exit 1

- name: Post to Slack
  if: steps.cleanup.outputs.total-deleted != '0'
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -d "Cleaned up ${{ steps.cleanup.outputs.total-deleted }} releases"
```

## 🔧 How It Works

1. **Validation** - Validates all inputs (token, version format, boolean values, etc.)
2. **Fetch Releases** - Retrieves all releases from GitHub with pagination support
3. **Categorization** - Separates releases into prereleases and stable releases
4. **Version Filtering** - Only considers releases at or below the specified semantic version
5. **Cleanup** - Deletes releases and tags based on configuration:
   - Prereleases (if `clean-prereleases: true`)
   - Old stable releases beyond retention count (if `clean-old-releases: true`)
6. **Summary** - Generates detailed summary with statistics and outputs

### Version Comparison

The action uses semantic version comparison to ensure only older or equal releases are considered:

```
Current Version: 2.0.0

Considered for cleanup:
✅ 2.0.0-alpha
✅ 2.0.0-beta
✅ 1.9.9
✅ 1.0.0

Ignored (newer):
❌ 2.0.1
❌ 2.1.0
❌ 3.0.0
```

## 📊 Example Scenarios

### Scenario 1: Release v2.0.0, Clean Prereleases

**Configuration:**
```yaml
semantic-version: '2.0.0'
keep: 3
clean-prereleases: true
clean-old-releases: true
```

**Before:**
- v2.0.0 (stable) ← Current release
- v2.0.0-rc.2 (prerelease)
- v2.0.0-rc.1 (prerelease)
- v1.9.0 (stable)
- v1.8.0 (stable)
- v1.7.0 (stable)
- v1.6.0 (stable)

**After:**
- v2.0.0 (stable) ✅ Kept
- v1.9.0 (stable) ✅ Kept
- v1.8.0 (stable) ✅ Kept
- ❌ Deleted: v2.0.0-rc.2, v2.0.0-rc.1 (prereleases)
- ❌ Deleted: v1.7.0, v1.6.0 (old stable releases)

### Scenario 2: Keep Prereleases, Clean Old Releases

**Configuration:**
```yaml
semantic-version: '1.5.0'
keep: 2
clean-prereleases: false
clean-old-releases: true
```

**Before:**
- v1.5.0-beta (prerelease)
- v1.4.0 (stable)
- v1.3.0 (stable)
- v1.2.0 (stable)
- v1.1.0 (stable)

**After:**
- v1.5.0-beta (prerelease) ✅ Kept
- v1.4.0 (stable) ✅ Kept
- v1.3.0 (stable) ✅ Kept
- ❌ Deleted: v1.2.0, v1.1.0 (old stable releases)

## 🔒 Permissions

The action requires the following permissions:

```yaml
permissions:
  contents: write  # Required for deleting releases and tags
```

When using `GITHUB_TOKEN`, ensure it has sufficient permissions:
- For public repositories: Default `GITHUB_TOKEN` works
- For private repositories: May need a Personal Access Token (PAT) with `repo` scope

## ⚠️ Important Notes

### Rate Limits
- GitHub API has rate limits (5000 requests/hour for authenticated requests)
- The action includes automatic retry logic with exponential backoff
- Rate limit handling is built-in and transparent

### Tag Deletion
- Deleting a release also attempts to delete its associated Git tag
- If tag deletion fails (e.g., tag already deleted), the action logs a warning but continues
- Tags without releases are not affected by this action

### Version Prefix
- The action handles both `v1.0.0` and `1.0.0` formats automatically
- You can specify versions with or without the `v` prefix
- Tags are matched regardless of prefix

### Dry-Run Mode
- Always test with `dry-run: true` first
- Dry-run mode shows exactly what would be deleted
- No API rate limit consumption for destructive operations in dry-run mode

### Concurrent Runs
- Avoid running multiple instances simultaneously on the same repository
- Can cause race conditions and unexpected behavior
- Use workflow concurrency controls if needed

## 🧪 Testing

### Local Testing

The bash script can be tested locally:

```bash
# Set required environment variables
export TOKEN="your-github-token"
export SEMVER="1.0.0"
export KEEP="5"
export CLEAN_PRERELEASES="true"
export CLEAN_OLD_RELEASES="true"
export DRY_RUN="true"
export REPO="owner/repo"

# Run the script
./scripts/clean-releases.sh
```

### GitHub Actions Testing

Create a test workflow:

```yaml
name: Test Cleanup

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to test'
        required: true
        default: '1.0.0'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test cleanup (dry-run)
        uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          semantic-version: ${{ github.event.inputs.version }}
          dry-run: true
```

## 🐛 Troubleshooting

### Common Issues

**Issue: "Failed to fetch releases"**
- Check that the token has `repo` scope
- Verify the repository name format (`owner/repo`)
- Check GitHub API rate limits

**Issue: "Invalid semantic version format"**
- Ensure version follows semver: `MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]`
- Examples: `1.0.0`, `2.3.4-alpha`, `1.0.0-beta.1`

**Issue: "Failed to delete release"**
- Verify token has `contents: write` permission
- Check if release exists and wasn't already deleted
- Review GitHub API logs for specific error

**Issue: Rate limit exceeded**
- The action includes automatic retry logic
- Wait for rate limit to reset (up to 1 hour)
- Consider reducing frequency of cleanup runs

### Debug Mode

Enable debug logging in GitHub Actions:

```yaml
- name: Clean releases with debug
  uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    semantic-version: '1.0.0'
  env:
    ACTIONS_STEP_DEBUG: true
```

## 📝 Best Practices

1. **Always test with dry-run first** before enabling actual cleanup
2. **Set appropriate retention counts** - too low may delete important releases
3. **Run after successful releases** - integrate into your release workflow
4. **Monitor the outputs** - track cleanup metrics over time
5. **Use descriptive version tags** - follow semantic versioning consistently
6. **Review logs regularly** - watch for patterns of errors or issues
7. **Document your strategy** - make cleanup policies clear to your team

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with ❤️ by the Ignitia Core team
- Inspired by the need for automated release management
- Uses GitHub REST API v3

## 📞 Support

- 📚 [Documentation](https://github.com/ignitia-core/ignitia-cicd-actions)
- 🐛 [Issue Tracker](https://github.com/ignitia-core/ignitia-cicd-actions/issues)
- 💬 [Discussions](https://github.com/ignitia-core/ignitia-cicd-actions/discussions)

---

Made with ❤️ by [Ignitia Core](https://github.com/ignitia-core)
