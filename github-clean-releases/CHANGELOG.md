# Changelog

All notable changes to the GitHub Clean Releases action will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-24

### 🎉 Major Refactoring - Production Grade Release

This is a complete rewrite of the action to production-grade standards.

### Added
- ✨ **Dry-run mode** - Preview changes before applying them
- 📊 **Action outputs** - Expose metrics (prereleases-deleted, old-releases-deleted, tags-deleted, total-deleted, api-calls, errors)
- 🎨 **Color-coded logging** - Enhanced readability with emoji icons and colors
- ⏰ **Timestamped logs** - Every log entry includes timestamp
- 🔄 **Retry logic** - Automatic retries with exponential backoff for failed API calls
- ⚡ **Rate limit handling** - Intelligent detection and handling of GitHub API rate limits
- ✅ **Comprehensive input validation** - Validates all inputs before execution
- 🛡️ **Error handling** - Graceful error handling with detailed error messages
- 📈 **Summary output** - Detailed summary at the end with all statistics
- 🎛️ **Action branding** - Icon and color for GitHub marketplace
- 📚 **Extensive documentation** - Complete README with examples and troubleshooting
- 🧪 **Local testing support** - Script can be tested locally with environment variables
- 📝 **CHANGELOG** - Version history tracking

### Changed
- 🔨 **Extracted bash script** - Moved from inline to separate `scripts/clean-releases.sh` file
- 🏗️ **Improved architecture** - Modular functions with clear separation of concerns
- 📖 **Enhanced input descriptions** - More detailed documentation for each input
- 🔍 **Better version comparison** - More robust semantic version comparison logic
- 🎯 **Improved error messages** - More specific and actionable error messages
- 📦 **Better pagination** - More efficient handling of large repositories

### Fixed
- 🐛 **Tag prefix handling** - Correctly handles both `v1.0.0` and `1.0.0` formats
- 🐛 **Version comparison** - Fixed edge cases in semantic version sorting
- 🐛 **API error handling** - Better handling of various API error codes (403, 404, etc.)
- 🐛 **Script exit codes** - Proper exit codes based on success/failure

### Security
- 🔒 **Token validation** - Validates token is provided before use
- 🔒 **Input sanitization** - All inputs are validated and sanitized

### Performance
- ⚡ **Reduced API calls** - More efficient pagination and caching
- ⚡ **Parallel-safe** - Better handling of concurrent operations

### Developer Experience
- 🧪 **Testable** - Script can be run and tested locally
- 📖 **Well-documented** - Comprehensive inline documentation
- 🎯 **Clear structure** - Logical function organization
- 🔍 **Debug-friendly** - Enhanced logging for troubleshooting

## [1.0.0] - Previous Version

### Initial Release
- Basic release cleanup functionality
- Prerelease and old release deletion
- Simple inline bash script
