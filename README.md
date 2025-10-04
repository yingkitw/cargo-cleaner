# Cargo Clean Recursive

A robust bash script to recursively clean Cargo projects, with special handling for workspace dependencies and missing files.

## Features

- **Recursive Cleaning**: Automatically finds and cleans all Cargo projects in subdirectories
- **Workspace Support**: Special handling for Cargo workspaces with dependency validation
- **Missing File Handling**: Gracefully handles missing dependency files in workspaces
- **Multiple Fallback Methods**: Uses various cleaning strategies when standard `cargo clean` fails
- **Detailed Logging**: Color-coded output with informative messages
- **Error Recovery**: Continues cleaning other projects even if some fail

## Usage

```bash
# Clean all Cargo projects in current directory
./cargo-clean-recursive.sh

# Clean all Cargo projects in a specific directory
./cargo-clean-recursive.sh /path/to/projects

# Show help
./cargo-clean-recursive.sh --help
```

## Error Handling

The script handles various error conditions:

- **Missing Workspace Dependencies**: Detects and handles missing `Cargo.toml` files in workspace members
- **Malformed Manifests**: Validates and skips `Cargo.toml` files missing required `[package]` or `[workspace]` sections
- **Dependency Validation**: Validates workspace dependencies before attempting to clean
- **Alternative Cleaning Methods**: Falls back to direct target directory removal when `cargo clean` fails
- **Graceful Degradation**: Continues processing other projects when individual projects fail

## Recent Improvements

- Enhanced workspace dependency error detection
- Added validation for missing dependency files
- Added validation for malformed Cargo.toml files
- Improved error messages with specific file information
- Better handling of workspace member manifest loading errors
- More robust fallback cleaning strategies

## Examples

### Successful Clean
```
[INFO] Starting recursive cargo clean from: /path/to/projects
[INFO] Cleaning Cargo project in: /path/to/projects/my-crate
[SUCCESS] Successfully cleaned: /path/to/projects/my-crate
[SUCCESS] All Cargo projects cleaned successfully!
```

### Workspace with Missing Dependencies
```
[INFO] Cleaning workspace project in: /path/to/workspace
[WARNING] Missing workspace member: /path/to/workspace/crates/utils/Cargo.toml
[WARNING] Workspace has missing dependencies, attempting alternative cleaning...
[INFO] Cleaning existing workspace member: crates/core
[SUCCESS] Cleaned 1 workspace members
```

### Malformed Cargo.toml
```
[INFO] Cleaning Cargo project in: /path/to/malformed-project
[WARNING] Invalid Cargo.toml file detected in: /path/to/malformed-project
[INFO] Manifest is missing either [package] or [workspace] section
[INFO] Skipping this project as it cannot be cleaned with cargo
```

## Requirements

- Bash shell
- Cargo (Rust package manager)
- Standard Unix utilities (find, grep, sed, etc.)
