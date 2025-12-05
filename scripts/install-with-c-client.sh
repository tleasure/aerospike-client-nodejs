#!/bin/bash
################################################################################
# Smart installer that only builds C client when building from source
################################################################################

# Get the absolute path to the package root (where this script's parent dir is)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Ensure we're in the package root
cd "${PACKAGE_ROOT}"

# First, try to install pre-built binaries
node-pre-gyp install --addon_version=$(node -p "require('./package.json').version") 2>/dev/null

# Check if installation succeeded
if [ $? -eq 0 ]; then
    echo "Successfully installed pre-built binaries"
    exit 0
fi

# Pre-built binaries not available, need to build from source
echo "Pre-built binaries not available, building from source..."

# Ensure C client source exists (critical for GitHub installs where submodules aren't included)
if [ ! -f "aerospike-client-c/Makefile" ]; then
    echo "C client source not found, attempting to initialize..."
    
    # Try git submodule first (for git clones)
    if git submodule update --init --recursive 2>/dev/null; then
        echo "Initialized git submodules"
    else
        # Not a git repo or submodules not available - download from GitHub
        echo "Downloading Aerospike C client from GitHub..."
        C_CLIENT_VERSION="9ce78e53aace39d4767633b2c204aa056baf2937"  # Match the submodule commit
        
        # Remove existing aerospike-client-c directory if it exists
        rm -rf aerospike-client-c
        
        curl -L "https://github.com/aerospike/aerospike-client-c/archive/${C_CLIENT_VERSION}.tar.gz" -o /tmp/aerospike-client-c.tar.gz || {
            echo "ERROR: Failed to download C client"
            exit 1
        }
        echo "Extracting C client..."
        tar -xzf /tmp/aerospike-client-c.tar.gz || {
            echo "ERROR: Failed to extract C client"
            exit 1
        }
        mv "aerospike-client-c-${C_CLIENT_VERSION}" aerospike-client-c
        rm /tmp/aerospike-client-c.tar.gz
        
        # Download submodules too
        echo "Downloading C client submodules..."
        cd aerospike-client-c
        
        # Download common module
        curl -L "https://github.com/aerospike/aerospike-common/archive/814081ba9145d7d95266721ea5ba3d15a228b578.tar.gz" -o /tmp/common.tar.gz
        mkdir -p modules/common
        tar -xzf /tmp/common.tar.gz -C modules/common --strip-components=1
        rm /tmp/common.tar.gz
        
        # Download lua module
        curl -L "https://github.com/aerospike/lua/archive/6443185167c77adcc8552a3fee7edab7895db1a9.tar.gz" -o /tmp/lua.tar.gz
        mkdir -p modules/lua
        tar -xzf /tmp/lua.tar.gz -C modules/lua --strip-components=1
        rm /tmp/lua.tar.gz
        
        # Download mod-lua module
        curl -L "https://github.com/aerospike/aerospike-mod-lua/archive/0bd5641cb57e3d2f98a74f2e8e82deb50ba3f2d8.tar.gz" -o /tmp/mod-lua.tar.gz
        mkdir -p modules/mod-lua
        tar -xzf /tmp/mod-lua.tar.gz -C modules/mod-lua --strip-components=1
        rm /tmp/mod-lua.tar.gz
        
        cd ..
        echo "C client downloaded successfully"
    fi
fi

# Build C client first
echo "Building Aerospike C client..."
./scripts/build-c-client.sh || {
    echo "Warning: C client build failed, attempting to use existing build"
}

# Now build the Node.js addon (rebuild = configure + build)
echo "Building Node.js addon..."
node-pre-gyp rebuild --addon_version=$(node -p "require('./package.json').version")

