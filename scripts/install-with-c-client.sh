#!/bin/bash
################################################################################
# Smart installer that only builds C client when building from source
################################################################################

# First, try to install pre-built binaries
node-pre-gyp install --addon_version=$(node -p "require('./package.json').version") 2>/dev/null

# Check if installation succeeded
if [ $? -eq 0 ]; then
    echo "Successfully installed pre-built binaries"
    exit 0
fi

# Pre-built binaries not available, need to build from source
echo "Pre-built binaries not available, building from source..."

# Ensure submodules are initialized (critical for GitHub installs)
if [ ! -f "aerospike-client-c/Makefile" ]; then
    echo "Initializing git submodules..."
    git submodule update --init --recursive 2>/dev/null || {
        echo "Warning: Could not initialize submodules (not a git repo or already initialized)"
    }
fi

# Build C client first
echo "Building Aerospike C client..."
./scripts/build-c-client.sh || {
    echo "Warning: C client build failed, attempting to use existing build"
}

# Now build the Node.js addon
echo "Building Node.js addon..."
node-pre-gyp build --addon_version=$(node -p "require('./package.json').version")

