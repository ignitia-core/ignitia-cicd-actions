# Example Usage Workflows

This directory contains example workflows demonstrating various use cases for the GitHub Clean Releases action.

## Examples

### 1. Basic Cleanup on Release

```yaml
# .github/workflows/cleanup-on-release.yml
name: Cleanup Old Releases

on:
  release:
    types: [published]

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - name: Extract version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
      
      - name: Clean up old releases
        uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          semantic-version: ${{ steps.version.outputs.VERSION }}
          keep: 10
          clean-prereleases: true
          clean-old-releases: true
```

### 2. Scheduled Cleanup

```yaml
# .github/workflows/scheduled-cleanup.yml
name: Scheduled Release Cleanup

on:
  schedule:
    # Run every Monday at 2 AM UTC
    - cron: '0 2 * * 1'
  workflow_dispatch:

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - name: Get latest release version
        id: latest
        run: |
          VERSION=$(gh api repos/${{ github.repository }}/releases/latest --jq '.tag_name' | sed 's/^v//')
          echo "VERSION=${VERSION}" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Clean up releases
        uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          semantic-version: ${{ steps.latest.outputs.VERSION }}
          keep: 5
          clean-prereleases: true
          clean-old-releases: true
```

### 3. Dry-Run with Approval

```yaml
# .github/workflows/cleanup-with-approval.yml
name: Release Cleanup with Approval

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Target semantic version'
        required: true
      keep:
        description: 'Number of releases to keep'
        required: false
        default: '10'

jobs:
  dry-run:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - name: Preview cleanup (dry-run)
        id: preview
        uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          semantic-version: ${{ github.event.inputs.version }}
          keep: ${{ github.event.inputs.keep }}
          dry-run: true
      
      - name: Create summary
        run: |
          echo "## Cleanup Preview" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Version:** ${{ github.event.inputs.version }}" >> $GITHUB_STEP_SUMMARY
          echo "**Keep:** ${{ github.event.inputs.keep }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Would delete:**" >> $GITHUB_STEP_SUMMARY
          echo "- Prereleases: ${{ steps.preview.outputs.prereleases-deleted }}" >> $GITHUB_STEP_SUMMARY
          echo "- Old releases: ${{ steps.preview.outputs.old-releases-deleted }}" >> $GITHUB_STEP_SUMMARY
          echo "- Total: ${{ steps.preview.outputs.total-deleted }}" >> $GITHUB_STEP_SUMMARY
  
  approval:
    runs-on: ubuntu-latest
    needs: dry-run
    environment: production
    steps:
      - name: Manual approval gate
        run: echo "Approved for cleanup"
  
  cleanup:
    runs-on: ubuntu-latest
    needs: approval
    permissions:
      contents: write
    
    steps:
      - name: Perform actual cleanup
        uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          semantic-version: ${{ github.event.inputs.version }}
          keep: ${{ github.event.inputs.keep }}
          dry-run: false
```

### 4. Multi-Repository Cleanup

```yaml
# .github/workflows/multi-repo-cleanup.yml
name: Multi-Repository Cleanup

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Target semantic version'
        required: true

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    strategy:
      matrix:
        repo:
          - 'my-org/repo-1'
          - 'my-org/repo-2'
          - 'my-org/repo-3'
    
    steps:
      - name: Clean up ${{ matrix.repo }}
        uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v2
        with:
          token: ${{ secrets.PAT_TOKEN }}  # PAT with access to all repos
          semantic-version: ${{ github.event.inputs.version }}
          repo: ${{ matrix.repo }}
          keep: 5
          clean-prereleases: true
          clean-old-releases: true
```

### 5. Cleanup with Notifications

```yaml
# .github/workflows/cleanup-with-notifications.yml
name: Cleanup with Slack Notification

on:
  release:
    types: [published]

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
      
      - name: Clean up releases
        id: cleanup
        uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          semantic-version: ${{ steps.version.outputs.VERSION }}
          keep: 10
          clean-prereleases: true
          clean-old-releases: true
      
      - name: Notify Slack
        if: steps.cleanup.outputs.total-deleted != '0'
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Release cleanup completed for ${{ github.repository }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Release Cleanup Report*\n\n*Repository:* ${{ github.repository }}\n*Version:* ${{ steps.version.outputs.VERSION }}\n*Deleted:* ${{ steps.cleanup.outputs.total-deleted }} releases\n\n• Prereleases: ${{ steps.cleanup.outputs.prereleases-deleted }}\n• Old releases: ${{ steps.cleanup.outputs.old-releases-deleted }}\n• Tags: ${{ steps.cleanup.outputs.tags-deleted }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### 6. Conservative Cleanup (Only Prereleases)

```yaml
# .github/workflows/prerelease-cleanup.yml
name: Cleanup Prereleases Only

on:
  push:
    tags:
      - 'v*'

jobs:
  cleanup-prereleases:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
      
      - name: Clean only prereleases
        uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          semantic-version: ${{ steps.version.outputs.VERSION }}
          clean-prereleases: true
          clean-old-releases: false  # Keep all stable releases
```

### 7. Aggressive Cleanup

```yaml
# .github/workflows/aggressive-cleanup.yml
name: Aggressive Cleanup

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Target version'
        required: true

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - name: Aggressive cleanup
        uses: ignitia-core/ignitia-cicd-actions/github-clean-releases@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          semantic-version: ${{ github.event.inputs.version }}
          keep: 2  # Only keep 2 most recent stable releases
          clean-prereleases: true
          clean-old-releases: true
```

## Tips

1. **Always test with dry-run first** before enabling actual cleanup
2. **Use appropriate permissions** - `contents: write` is required
3. **Consider rate limits** - Schedule cleanup jobs during low-traffic times
4. **Monitor the outputs** - Use action outputs for notifications and metrics
5. **Use concurrency controls** - Prevent multiple cleanup jobs from running simultaneously

## Concurrency Example

```yaml
concurrency:
  group: release-cleanup-${{ github.repository }}
  cancel-in-progress: false
```
