#!/usr/bin/env bash

##############################################################################
# GitHub Releases Cleanup Script
# 
# Production-grade script for cleaning up GitHub releases and tags based on
# semantic versioning rules. Supports dry-run mode, comprehensive validation,
# and detailed logging.
##############################################################################

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Script configuration
readonly SCRIPT_VERSION="2.0.0"
readonly API_BASE_URL="https://api.github.com"
readonly PER_PAGE=100
readonly MAX_RETRIES=3
readonly RETRY_DELAY=2

# Global counters
PRERELEASES_DELETED=0
OLD_RELEASES_DELETED=0
TAGS_DELETED=0
API_CALLS=0
ERRORS=0

##############################################################################
# Logging functions
##############################################################################

log_info() {
    echo -e "${BLUE}ℹ${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo -e "${RED}✗${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    ((ERRORS++))
}

log_section() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$*${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

##############################################################################
# Validation functions
##############################################################################

validate_inputs() {
    log_section "Validating Inputs"
    
    local validation_failed=0

    # Validate token
    if [[ -z "${TOKEN:-}" ]]; then
        log_error "GitHub token is required but not provided"
        validation_failed=1
    fi

    # Validate semantic version
    if [[ -z "${SEMVER:-}" ]]; then
        log_error "Semantic version is required but not provided"
        validation_failed=1
    elif ! [[ "${SEMVER}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9\.\-]+)?(\+[a-zA-Z0-9\.\-]+)?$ ]]; then
        log_error "Invalid semantic version format: ${SEMVER}"
        log_info "Expected format: MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]"
        validation_failed=1
    fi

    # Validate keep count
    if ! [[ "${KEEP}" =~ ^[0-9]+$ ]] || [[ "${KEEP}" -lt 0 ]]; then
        log_error "Keep count must be a non-negative integer, got: ${KEEP}"
        validation_failed=1
    fi

    # Validate boolean inputs
    for var in CLEAN_PRERELEASES CLEAN_OLD_RELEASES DRY_RUN; do
        local value="${!var}"
        if [[ "${value}" != "true" && "${value}" != "false" ]]; then
            log_error "${var} must be 'true' or 'false', got: ${value}"
            validation_failed=1
        fi
    done

    # Validate repository format
    if ! [[ "${REPO}" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
        log_error "Invalid repository format: ${REPO}"
        log_info "Expected format: owner/repo"
        validation_failed=1
    fi

    # Check required commands
    for cmd in curl jq sort; do
        if ! command -v "${cmd}" &> /dev/null; then
            log_error "Required command '${cmd}' not found in PATH"
            validation_failed=1
        fi
    done

    if [[ ${validation_failed} -eq 1 ]]; then
        log_error "Validation failed. Exiting."
        exit 1
    fi

    log_success "All inputs validated successfully"
}

##############################################################################
# API interaction functions
##############################################################################

# Make an API call with retry logic
api_call() {
    local method="$1"
    local url="$2"
    local retry_count=0
    
    ((API_CALLS++))
    
    while [[ ${retry_count} -lt ${MAX_RETRIES} ]]; do
        local response
        local http_code
        
        response=$(curl -s -w "\n%{http_code}" -X "${method}" \
            -H "Authorization: token ${TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            "${url}" 2>&1)
        
        http_code=$(echo "${response}" | tail -n1)
        local body=$(echo "${response}" | sed '$d')
        
        case "${http_code}" in
            200|204)
                echo "${body}"
                return 0
                ;;
            403)
                # Check if it's a rate limit issue
                if echo "${body}" | jq -e '.message | contains("rate limit")' &> /dev/null; then
                    log_warning "Rate limit exceeded. Waiting before retry..."
                    sleep $((RETRY_DELAY * (retry_count + 1)))
                    ((retry_count++))
                    continue
                fi
                log_error "API call forbidden (403): ${url}"
                return 1
                ;;
            404)
                log_warning "Resource not found (404): ${url}"
                return 1
                ;;
            *)
                log_warning "API call failed with HTTP ${http_code}: ${url}"
                if [[ ${retry_count} -lt $((MAX_RETRIES - 1)) ]]; then
                    log_info "Retrying in ${RETRY_DELAY}s... (attempt $((retry_count + 2))/${MAX_RETRIES})"
                    sleep ${RETRY_DELAY}
                    ((retry_count++))
                    continue
                fi
                log_error "Max retries exceeded for: ${url}"
                return 1
                ;;
        esac
    done
    
    return 1
}

# Fetch all releases with pagination
fetch_all_releases() {
    log_section "Fetching Releases"
    log_info "Fetching releases from ${REPO}..."
    
    local temp_file
    temp_file=$(mktemp)
    echo "tag_name,id,prerelease" > "${temp_file}"
    
    local page=1
    local total_releases=0
    
    while true; do
        local url="${API_BASE_URL}/repos/${REPO}/releases?per_page=${PER_PAGE}&page=${page}"
        local response
        
        if ! response=$(api_call "GET" "${url}"); then
            log_error "Failed to fetch releases page ${page}"
            rm -f "${temp_file}"
            return 1
        fi
        
        local count
        count=$(echo "${response}" | jq '. | length')
        
        if [[ "${count}" -eq 0 ]]; then
            break
        fi
        
        echo "${response}" | jq -r '.[] | "\(.tag_name),\(.id),\(.prerelease)"' >> "${temp_file}"
        total_releases=$((total_releases + count))
        
        log_info "Fetched page ${page}: ${count} releases (total: ${total_releases})"
        
        if [[ "${count}" -lt ${PER_PAGE} ]]; then
            break
        fi
        
        ((page++))
    done
    
    log_success "Fetched ${total_releases} releases across ${page} page(s)"
    echo "${temp_file}"
}

##############################################################################
# Release processing functions
##############################################################################

# Compare two semantic versions
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Use sort -V for version sorting
    local sorted
    sorted=$(printf '%s\n%s\n' "${version1}" "${version2}" | sort -V | tail -n1)
    
    [[ "${sorted}" == "${version2}" ]]
}

# Categorize releases into prereleases and stable releases
categorize_releases() {
    local releases_file="$1"
    
    log_section "Categorizing Releases"
    
    declare -gA PRERELEASE_MAP
    declare -gA NON_PRERELEASE_MAP
    
    local line_num=0
    while IFS=',' read -r tag_name id is_prerelease; do
        ((line_num++))
        
        # Skip header
        if [[ "${tag_name}" == "tag_name" ]]; then
            continue
        fi
        
        # Strip 'v' prefix if present
        local stripped_tag="${tag_name#v}"
        
        # Check if this version is <= current semantic version
        if ! version_compare "${stripped_tag}" "${SEMVER}"; then
            continue
        fi
        
        # Categorize based on presence of prerelease identifier (dash in version)
        if [[ "${stripped_tag}" == *"-"* ]]; then
            PRERELEASE_MAP["${tag_name}"]="${id}"
            log_info "Prerelease: ${tag_name}"
        else
            NON_PRERELEASE_MAP["${tag_name}"]="${id}"
            log_info "Stable release: ${tag_name}"
        fi
    done < "${releases_file}"
    
    log_info "Found ${#PRERELEASE_MAP[@]} prerelease(s)"
    log_info "Found ${#NON_PRERELEASE_MAP[@]} stable release(s)"
}

# Delete a release and its tag
delete_release() {
    local tag_name="$1"
    local release_id="$2"
    local release_type="$3"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warning "[DRY-RUN] Would delete ${release_type}: ${tag_name} (ID: ${release_id})"
        return 0
    fi
    
    log_info "Deleting ${release_type}: ${tag_name} (ID: ${release_id})"
    
    # Delete the release
    if api_call "DELETE" "${API_BASE_URL}/repos/${REPO}/releases/${release_id}" > /dev/null; then
        log_success "Deleted release: ${tag_name}"
    else
        log_error "Failed to delete release: ${tag_name}"
        return 1
    fi
    
    # Delete the tag
    if api_call "DELETE" "${API_BASE_URL}/repos/${REPO}/git/refs/tags/${tag_name}" > /dev/null; then
        log_success "Deleted tag: ${tag_name}"
        ((TAGS_DELETED++))
    else
        log_warning "Failed to delete tag: ${tag_name} (may not exist)"
    fi
    
    return 0
}

# Clean prerelease versions
clean_prereleases() {
    if [[ "${CLEAN_PRERELEASES}" != "true" ]]; then
        log_info "Prerelease cleanup is disabled"
        return 0
    fi
    
    log_section "Cleaning Prereleases"
    
    if [[ ${#PRERELEASE_MAP[@]} -eq 0 ]]; then
        log_info "No prereleases to clean"
        return 0
    fi
    
    log_info "Processing ${#PRERELEASE_MAP[@]} prerelease(s)..."
    
    for tag_name in "${!PRERELEASE_MAP[@]}"; do
        local release_id="${PRERELEASE_MAP[${tag_name}]}"
        if delete_release "${tag_name}" "${release_id}" "prerelease"; then
            ((PRERELEASES_DELETED++))
        fi
    done
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warning "[DRY-RUN] Would have deleted ${#PRERELEASE_MAP[@]} prerelease(s)"
    else
        log_success "Deleted ${PRERELEASES_DELETED} prerelease(s)"
    fi
}

# Clean old stable releases beyond retention count
clean_old_releases() {
    if [[ "${CLEAN_OLD_RELEASES}" != "true" ]]; then
        log_info "Old release cleanup is disabled"
        return 0
    fi
    
    log_section "Cleaning Old Releases"
    
    if [[ ${#NON_PRERELEASE_MAP[@]} -eq 0 ]]; then
        log_info "No stable releases to process"
        return 0
    fi
    
    log_info "Found ${#NON_PRERELEASE_MAP[@]} stable release(s), keeping ${KEEP}"
    
    # Sort releases by version (newest first)
    local sorted_releases
    mapfile -t sorted_releases < <(printf '%s\n' "${!NON_PRERELEASE_MAP[@]}" | sed 's/^v//' | sort -rV | sed 's/^/v/')
    
    if [[ ${#sorted_releases[@]} -le ${KEEP} ]]; then
        log_info "No old releases to clean (${#sorted_releases[@]} <= ${KEEP})"
        return 0
    fi
    
    log_info "Processing $((${#sorted_releases[@]} - KEEP)) old release(s)..."
    
    for ((i=KEEP; i<${#sorted_releases[@]}; i++)); do
        local tag_name="${sorted_releases[$i]}"
        # Handle both with and without 'v' prefix
        local release_id="${NON_PRERELEASE_MAP[${tag_name}]:-${NON_PRERELEASE_MAP[${tag_name#v}]}}"
        
        if [[ -z "${release_id}" ]]; then
            log_warning "Could not find release ID for tag: ${tag_name}"
            continue
        fi
        
        if delete_release "${tag_name}" "${release_id}" "old release"; then
            ((OLD_RELEASES_DELETED++))
        fi
    done
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warning "[DRY-RUN] Would have deleted $((${#sorted_releases[@]} - KEEP)) old release(s)"
    else
        log_success "Deleted ${OLD_RELEASES_DELETED} old release(s)"
    fi
}

##############################################################################
# Summary and output functions
##############################################################################

print_summary() {
    log_section "Cleanup Summary"
    
    echo -e "${BOLD}Configuration:${NC}"
    echo "  Repository:              ${REPO}"
    echo "  Semantic Version:        ${SEMVER}"
    echo "  Retention Count:         ${KEEP}"
    echo "  Clean Prereleases:       ${CLEAN_PRERELEASES}"
    echo "  Clean Old Releases:      ${CLEAN_OLD_RELEASES}"
    echo "  Dry Run:                 ${DRY_RUN}"
    echo ""
    
    echo -e "${BOLD}Results:${NC}"
    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "  Mode:                    DRY RUN (no changes made)"
    fi
    echo "  Prereleases Deleted:     ${PRERELEASES_DELETED}"
    echo "  Old Releases Deleted:    ${OLD_RELEASES_DELETED}"
    echo "  Tags Deleted:            ${TAGS_DELETED}"
    echo "  Total Releases Deleted:  $((PRERELEASES_DELETED + OLD_RELEASES_DELETED))"
    echo ""
    
    echo -e "${BOLD}Statistics:${NC}"
    echo "  API Calls Made:          ${API_CALLS}"
    echo "  Errors Encountered:      ${ERRORS}"
    echo ""
    
    # Set GitHub Actions outputs
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        {
            echo "prereleases-deleted=${PRERELEASES_DELETED}"
            echo "old-releases-deleted=${OLD_RELEASES_DELETED}"
            echo "tags-deleted=${TAGS_DELETED}"
            echo "total-deleted=$((PRERELEASES_DELETED + OLD_RELEASES_DELETED))"
            echo "api-calls=${API_CALLS}"
            echo "errors=${ERRORS}"
        } >> "${GITHUB_OUTPUT}"
    fi
    
    if [[ ${ERRORS} -gt 0 ]]; then
        log_warning "Completed with ${ERRORS} error(s)"
        return 1
    else
        log_success "Cleanup completed successfully!"
        return 0
    fi
}

##############################################################################
# Main execution
##############################################################################

main() {
    log_section "GitHub Releases Cleanup v${SCRIPT_VERSION}"
    
    # Validate all inputs
    validate_inputs
    
    # Fetch all releases
    local releases_file
    if ! releases_file=$(fetch_all_releases); then
        log_error "Failed to fetch releases"
        exit 1
    fi
    
    # Categorize releases
    categorize_releases "${releases_file}"
    
    # Clean up the temporary file
    rm -f "${releases_file}"
    
    # Perform cleanup operations
    clean_prereleases
    clean_old_releases
    
    # Print summary and set exit code
    if print_summary; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main
