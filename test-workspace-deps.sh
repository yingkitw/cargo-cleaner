#!/bin/bash

# Test script for workspace with missing dependencies
# This creates a test workspace with missing dependencies to verify improved error handling

set -e

TEST_DIR="test-workspace-deps"
SCRIPT_PATH="./cargo-clean-recursive.sh"

echo "Creating test workspace with missing dependencies..."

# Create test directory structure
mkdir -p "$TEST_DIR/crates/core/src"
mkdir -p "$TEST_DIR/crates/cli/src"

# Create workspace root Cargo.toml with missing dependency
cat > "$TEST_DIR/Cargo.toml" << 'EOF'
[workspace]
members = [
    "crates/core",
    "crates/cli",
    "crates/utils",  # This will be missing
]

[workspace.dependencies]
wx-agentic-utils = { path = "crates/utils" }
EOF

# Create core crate that depends on the missing utils
cat > "$TEST_DIR/crates/core/Cargo.toml" << 'EOF'
[package]
name = "core"
version = "0.1.0"
edition = "2021"

[dependencies]
wx-agentic-utils = { workspace = true }
EOF

cat > "$TEST_DIR/crates/core/src/lib.rs" << 'EOF'
pub fn hello() {
    println!("Hello from core!");
}
EOF

# Create cli crate
cat > "$TEST_DIR/crates/cli/Cargo.toml" << 'EOF'
[package]
name = "cli"
version = "0.1.0"
edition = "2021"

[dependencies]
core = { path = "../core" }
EOF

cat > "$TEST_DIR/crates/cli/src/main.rs" << 'EOF'
fn main() {
    println!("Hello from CLI!");
}
EOF

# Create some build artifacts to test cleaning
mkdir -p "$TEST_DIR/crates/core/target/debug"
mkdir -p "$TEST_DIR/crates/cli/target/debug"
echo "fake build artifact" > "$TEST_DIR/crates/core/target/debug/test"
echo "fake build artifact" > "$TEST_DIR/crates/cli/target/debug/test"

# Note: crates/utils is intentionally missing to test error handling

echo "Test workspace created. Running cargo clean script..."

# Run the script on the test directory
if [ -f "$SCRIPT_PATH" ]; then
    bash "$SCRIPT_PATH" "$TEST_DIR"
    echo "Test completed. Check output above for error handling."
else
    echo "Error: cargo-clean-recursive.sh not found!"
    exit 1
fi

# Cleanup
echo "Cleaning up test directory..."
rm -rf "$TEST_DIR"

echo "Test completed successfully!"
