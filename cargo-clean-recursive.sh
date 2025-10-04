#!/bin/bash

# cargo-clean-recursive.sh
# A script to recursively run 'cargo clean' in all subdirectories containing Cargo.toml

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to validate Cargo.toml file
validate_cargo_manifest() {
    local project_dir="$1"
    local cargo_toml="$project_dir/Cargo.toml"
    
    if [ ! -f "$cargo_toml" ]; then
        return 1
    fi
    
    # Check if the file has either [package] or [workspace] section
    if ! grep -q "^\[package\]" "$cargo_toml" && ! grep -q "^\[workspace\]" "$cargo_toml"; then
        return 1  # Invalid manifest
    fi
    
    return 0  # Valid manifest
}

# Function to validate workspace dependencies
validate_workspace_dependencies() {
    local project_dir="$1"
    
    if [ ! -f "$project_dir/Cargo.toml" ]; then
        return 1
    fi
    
    # Check if this is a workspace
    if ! grep -q "^\[workspace\]" "$project_dir/Cargo.toml"; then
        return 0  # Not a workspace, no validation needed
    fi
    
    # Extract workspace members
    local members
    members=$(grep -A 20 "^\[workspace\]" "$project_dir/Cargo.toml" | grep -E "^\s*\"[^\"]+\"" | sed 's/.*"\([^"]*\)".*/\1/' | head -20)
    
    if [ -n "$members" ]; then
        for member in $members; do
            local member_path="$project_dir/$member"
            if [ ! -f "$member_path/Cargo.toml" ]; then
                print_warning "Missing workspace member: $member_path/Cargo.toml"
                return 1
            fi
        done
    fi
    
    return 0
}

# Function to detect workspace dependency issues
detect_workspace_issues() {
    local project_dir="$1"
    local error_output="$2"
    
    # Check for common workspace dependency errors
    if echo "$error_output" | grep -q "workspace.dependencies"; then
        return 0  # Workspace issue detected
    fi
    
    if echo "$error_output" | grep -q "dependency.*was not found in.*workspace.dependencies"; then
        return 0  # Missing workspace dependency
    fi
    
    if echo "$error_output" | grep -q "error inheriting.*from workspace root manifest"; then
        return 0  # Workspace inheritance error
    fi
    
    # Check for missing dependency files
    if echo "$error_output" | grep -q "failed to read.*Cargo.toml"; then
        return 0  # Missing dependency file
    fi
    
    if echo "$error_output" | grep -q "No such file or directory.*Cargo.toml"; then
        return 0  # Missing dependency file
    fi
    
    # Check for failed to load manifest errors
    if echo "$error_output" | grep -q "failed to load manifest for dependency"; then
        return 0  # Missing dependency manifest
    fi
    
    # Check for workspace member manifest loading errors
    if echo "$error_output" | grep -q "failed to load manifest for workspace member"; then
        return 0  # Workspace member manifest issue
    fi
    
    # Check for malformed manifest errors
    if echo "$error_output" | grep -q "manifest is missing either a.*package.*or a.*workspace"; then
        return 0  # Malformed manifest
    fi
    
    if echo "$error_output" | grep -q "failed to parse manifest"; then
        return 0  # Manifest parsing error
    fi
    
    return 1  # No workspace issue detected
}

# Function to clean workspace projects with special handling
clean_workspace_project() {
    local project_dir="$1"
    print_info "Cleaning workspace project in: $project_dir"
    
    if cd "$project_dir"; then
        # For workspace projects, try to clean from the root first
        if [ -f "Cargo.toml" ] && grep -q "^\[workspace\]" "Cargo.toml"; then
            print_info "Detected workspace root, validating dependencies..."
            
            # Validate workspace dependencies first
            if ! validate_workspace_dependencies "$project_dir"; then
                print_warning "Workspace has missing dependencies, attempting alternative cleaning..."
                # Try to clean individual members that exist
                local members
                members=$(grep -A 20 "^\[workspace\]" "Cargo.toml" | grep -E "^\s*\"[^\"]+\"" | sed 's/.*"\([^"]*\)".*/\1/' | head -20)
                
                if [ -n "$members" ]; then
                    local member_cleaned=0
                    local member_failed=0
                    
                    for member in $members; do
                        local member_path="$project_dir/$member"
                        if [ -d "$member_path" ] && [ -f "$member_path/Cargo.toml" ]; then
                            print_info "Cleaning existing workspace member: $member"
                            
                            # Try to clean the member, but handle dependency issues gracefully
                            if clean_cargo_project "$member_path"; then
                                ((member_cleaned++))
                            else
                                print_warning "Failed to clean workspace member: $member"
                                print_info "This member may have dependency issues due to missing workspace dependencies"
                                
                                # Try direct target removal as fallback
                                if [ -d "$member_path/target" ]; then
                                    print_info "Attempting direct target removal for: $member"
                                    if rm -rf "$member_path/target"; then
                                        print_success "Successfully removed target directory for: $member"
                                        ((member_cleaned++))
                                    else
                                        print_error "Failed to remove target directory for: $member"
                                        ((member_failed++))
                                    fi
                                else
                                    print_info "No target directory found for: $member (may already be clean)"
                                    ((member_cleaned++))
                                fi
                            fi
                        else
                            print_warning "Skipping missing workspace member: $member"
                        fi
                    done
                    
                    if [ $member_cleaned -gt 0 ]; then
                        print_success "Cleaned $member_cleaned workspace members"
                        return 0
                    fi
                fi
                
                # If no members could be cleaned, try direct target removal
                if [ -d "target" ]; then
                    print_info "Removing workspace target directory directly..."
                    if rm -rf target; then
                        print_success "Successfully removed workspace target directory: $project_dir"
                        return 0
                    fi
                fi
                
                print_success "Workspace appears to be clean (no build artifacts): $project_dir"
                return 0
            fi
            
            print_info "Workspace dependencies validated, cleaning workspace members..."
            
            # Try to clean the entire workspace
            if cargo clean --workspace 2>/dev/null; then
                print_success "Successfully cleaned workspace: $project_dir"
                return 0
            fi
            
            # If workspace clean fails, try individual members
            print_warning "Workspace clean failed, trying individual members..."
            
            # Extract workspace members and clean them individually
            local members
            members=$(grep -A 20 "^\[workspace\]" "Cargo.toml" | grep -E "^\s*\"[^\"]+\"" | sed 's/.*"\([^"]*\)".*/\1/' | head -20)
            
            if [ -n "$members" ]; then
                print_info "Found workspace members, cleaning individually..."
                local member_cleaned=0
                local member_failed=0
                
                for member in $members; do
                    local member_path="$project_dir/$member"
                    if [ -d "$member_path" ] && [ -f "$member_path/Cargo.toml" ]; then
                        print_info "Cleaning workspace member: $member"
                        
                        # Try to clean the member, but handle dependency issues gracefully
                        if clean_cargo_project "$member_path"; then
                            ((member_cleaned++))
                        else
                            print_warning "Failed to clean workspace member: $member"
                            print_info "This member may have dependency issues"
                            
                            # Try direct target removal as fallback
                            if [ -d "$member_path/target" ]; then
                                print_info "Attempting direct target removal for: $member"
                                if rm -rf "$member_path/target"; then
                                    print_success "Successfully removed target directory for: $member"
                                    ((member_cleaned++))
                                else
                                    print_error "Failed to remove target directory for: $member"
                                    ((member_failed++))
                                fi
                            else
                                print_info "No target directory found for: $member (may already be clean)"
                                ((member_cleaned++))
                            fi
                        fi
                    fi
                done
                
                if [ $member_cleaned -gt 0 ]; then
                    print_success "Cleaned $member_cleaned workspace members"
                fi
                
                if [ $member_failed -gt 0 ]; then
                    print_warning "Failed to clean $member_failed workspace members"
                fi
                
                # If we cleaned any members or if all members were already clean, consider it a success
                if [ $member_cleaned -gt 0 ] || [ $member_failed -eq 0 ]; then
                    return 0
                fi
            fi
        fi
        
        # Fall back to regular cleaning
        clean_cargo_project "$project_dir"
    else
        print_error "Failed to change directory to: $project_dir"
        return 1
    fi
}

# Function to clean a single cargo project
clean_cargo_project() {
    local project_dir="$1"
    print_info "Cleaning Cargo project in: $project_dir"
    
    # Validate the Cargo.toml file first
    if ! validate_cargo_manifest "$project_dir"; then
        print_warning "Invalid Cargo.toml file detected in: $project_dir"
        print_info "Manifest is missing either [package] or [workspace] section"
        print_info "Skipping this project as it cannot be cleaned with cargo"
        return 0  # Treat as success since there's nothing to clean
    fi
    
    if cd "$project_dir"; then
        # Try cargo clean first
        if cargo clean 2>/dev/null; then
            print_success "Successfully cleaned: $project_dir"
            return 0
        else
            # If cargo clean fails, try alternative cleaning methods
            print_warning "Standard cargo clean failed for: $project_dir"
            print_info "Attempting alternative cleaning methods..."
            
            # Method 1: Remove target directory directly
            if [ -d "target" ]; then
                print_info "Removing target directory directly..."
                if rm -rf target; then
                    print_success "Successfully removed target directory: $project_dir"
                    return 0
                else
                    print_error "Failed to remove target directory: $project_dir"
                fi
            fi
            
            # Method 2: Try cargo clean with --offline flag
            print_info "Trying cargo clean with --offline flag..."
            if cargo clean --offline 2>/dev/null; then
                print_success "Successfully cleaned with --offline: $project_dir"
                return 0
            fi
            
            # Method 3: Try cargo clean with --release flag
            print_info "Trying cargo clean with --release flag..."
            if cargo clean --release 2>/dev/null; then
                print_success "Successfully cleaned with --release: $project_dir"
                return 0
            fi
            
            # If all methods fail, check if it's a workspace dependency issue
            local error_output
            error_output=$(cargo clean 2>&1 || true)
            
            if detect_workspace_issues "$project_dir" "$error_output"; then
                print_warning "Workspace dependency issue detected in: $project_dir"
                
                # Check if it's a missing dependency file issue
                if echo "$error_output" | grep -q "failed to read.*Cargo.toml\|No such file or directory.*Cargo.toml"; then
                    local missing_file
                    missing_file=$(echo "$error_output" | grep -o "failed to read '[^']*'" | sed "s/failed to read '//;s/'//" | head -1)
                    if [ -n "$missing_file" ]; then
                        print_info "Missing dependency file: $missing_file"
                    fi
                    print_info "This is likely due to missing dependency files in the workspace"
                elif echo "$error_output" | grep -q "manifest is missing either a.*package.*or a.*workspace\|failed to parse manifest"; then
                    print_info "This is due to a malformed Cargo.toml file"
                    print_info "The manifest is missing required [package] or [workspace] sections"
                elif echo "$error_output" | grep -q "failed to load manifest for dependency"; then
                    print_info "This is due to a missing workspace dependency"
                    print_info "The project depends on a workspace member that is missing or has issues"
                else
                    print_info "This is likely due to missing dependencies in workspace root"
                fi
                
                if [ -d "target" ]; then
                    print_info "Found target directory, attempting to remove it..."
                    if rm -rf target; then
                        print_success "Successfully cleaned despite workspace issues: $project_dir"
                        return 0
                    else
                        print_error "Failed to remove target directory: $project_dir"
                    fi
                else
                    print_info "No target directory found - project may already be clean"
                    print_success "Project appears to be clean (no build artifacts): $project_dir"
                    return 0
                fi
            fi
            
            print_error "Failed to clean: $project_dir"
            print_info "Error details: $error_output"
            return 1
        fi
    else
        print_error "Failed to change directory to: $project_dir"
        return 1
    fi
}

# Main function
main() {
    local start_dir="${1:-.}"  # Use current directory if no argument provided
    local start_dir_abs
    start_dir_abs=$(realpath "$start_dir")  # Store absolute path
    local cleaned_count=0
    local failed_count=0
    
    print_info "Starting recursive cargo clean from: $start_dir_abs"
    print_info "Searching for Cargo.toml files..."
    
    # Find all directories containing Cargo.toml files
    while IFS= read -r -d '' cargo_toml; do
        project_dir=$(dirname "$cargo_toml")
        
        # Check if this is a workspace root
        if [ -f "$project_dir/Cargo.toml" ] && grep -q "^\[workspace\]" "$project_dir/Cargo.toml"; then
            if clean_workspace_project "$project_dir"; then
                ((cleaned_count++))
            else
                ((failed_count++))
            fi
        else
            # Check if this project is already part of a workspace that was processed
            local is_workspace_member=false
            local parent_dir="$project_dir"
            while [ "$parent_dir" != "/" ] && [ "$parent_dir" != "." ]; do
                parent_dir=$(dirname "$parent_dir")
                if [ -f "$parent_dir/Cargo.toml" ] && grep -q "^\[workspace\]" "$parent_dir/Cargo.toml"; then
                    is_workspace_member=true
                    break
                fi
            done
            
            if [ "$is_workspace_member" = false ]; then
                if clean_cargo_project "$project_dir"; then
                    ((cleaned_count++))
                else
                    ((failed_count++))
                fi
            else
                print_info "Skipping workspace member (already processed): $project_dir"
            fi
        fi
        
        # Return to the original directory
        if ! cd "$start_dir_abs"; then
            print_error "Failed to return to start directory: $start_dir_abs"
            exit 1
        fi
        
    done < <(find "$start_dir" -name "Cargo.toml" -type f -print0)
    
    # Print summary
    echo
    print_info "=== SUMMARY ==="
    print_success "Successfully cleaned: $cleaned_count projects"
    
    if [ $failed_count -gt 0 ]; then
        print_error "Failed to clean: $failed_count projects"
        exit 1
    else
        print_success "All Cargo projects cleaned successfully!"
    fi
}

# Show help if requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [directory]"
    echo
    echo "Recursively runs 'cargo clean' in all subdirectories containing Cargo.toml files."
    echo
    echo "Arguments:"
    echo "  directory    Starting directory (default: current directory)"
    echo
    echo "Options:"
    echo "  -h, --help   Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    # Clean all Cargo projects in current directory"
    echo "  $0 /path/to/projects  # Clean all Cargo projects in specified directory"
    exit 0
fi

# Run the main function
main "$@"