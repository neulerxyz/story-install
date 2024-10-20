#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# ANSI colors for prettier output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GOPATH and GOROOT settings
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
# Global variables
CHAIN_ID="iliad"
STORY_HOME="$HOME/.story"
STORY_BINARY="$HOME/go/bin/story"
STORY_GETH_BINARY="$HOME/go/bin/geth"

# GETH 
GETH_SYNC_METHOD=""
GETH_SNAPSHOT_URL="https://story.iliad.snapshot.neuler.xyz/snapshots/geth_pruned_latest.tar.lz4"
GETH_LOCAL_SNAPSHOT_PATH=""

# Story
STORY_SNAPSHOT_URL="https://story.iliad.snapshot.neuler.xyz/snapshots/story_pruned_latest.tar.lz4"


printHeader() {
    cat << "EOF"
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▓▓▓▒▒▒░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░▒▓██████████████▓▒░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░▓████████████████████▓░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░▒████████████████████████▒░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░▒████████▓▒░░░░░░░▒▓███████▒░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░███████▓░░░░░░░░░░░░▒██████▓░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░███████░░░░░░░▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░███████▒░░░░░░██████▓▒░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░████████▒░░░░░██████████▒░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░██████████▓▓▓████████████▒░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░▓███████████▒▒▓▓█████████▒░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░▒▓█████████░░░░░▒████████░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░▒▓▓█████░░░░░░░███████▒░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░███████▒░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░███████▒░░░░░░░░░░░░▒███████░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░▓███████▓▒░░░░░░░░▒▓███████▓░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░▓████████████████████████▓░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░▒▓█████████████████████▒░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░▒▓███████████████▓░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░▒▒▓▓▓▓▓▓▒▒░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
EOF
}

log() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

install_dependencies() {
    log "Installing dependencies"
    sudo apt update && sudo apt-get update
    sudo apt install -y curl git make jq build-essential gcc unzip wget lz4 aria2 jq
}

install_go() {
    log "Determining required Go version and installing"
    
    GO_VERSION=$(curl -s https://raw.githubusercontent.com/piplabs/story-geth/master/go.mod | grep -oP 'go \K[0-9.]+')
    
    if [ -z "$GO_VERSION" ]; then
        log "Failed to determine Go version from story-geth. Using latest stable version."
        GO_VERSION="1.23.2"  # current latest
    else
        if [[ $GO_VERSION =~ ^[0-9]+\.[0-9]+$ ]]; then
            GO_VERSION="${GO_VERSION}.0"
        fi
    fi
    
    log "Installing Go version $GO_VERSION"
    wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    if [ $? -ne 0 ]; then
        log "Failed to download Go $GO_VERSION. Falling back to latest stable version 1.23.2"
        GO_VERSION="1.23.2"
        wget "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    fi
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
    echo 'export PATH=$PATH:/usr/local/go/bin' >> $HOME/.profile
    echo 'export GOPATH=$HOME/go' >> $HOME/.profile
    echo 'export PATH=$PATH:$GOPATH/bin' >> $HOME/.profile
    source $HOME/.profile
    go version
    rm "go${GO_VERSION}.linux-amd64.tar.gz"
}

select_geth_sync_method() {
    log "Selecting Geth sync method"
    echo "Choose Geth sync method:"
    echo "1) Use a snapshot from URL (faster, but requires download)"
    echo "2) Use a local snapshot (fastest if already downloaded)"
    echo "3) Sync from scratch (slower but more secure)"
    read -p "Choose your preferred method for Geth (1, 2 or 3): " geth_sync_choice

    case $geth_sync_choice in
        1)
            GETH_SYNC_METHOD="snapshot"
            read -p "Enter the URL of the Geth snapshot you want to use (default: $GETH_SNAPSHOT_URL): " user_geth_url
            GETH_SNAPSHOT_URL=${user_geth_url:-$GETH_SNAPSHOT_URL}
            ;;
        2)
            GETH_SYNC_METHOD="local_snapshot"
            read -p "Enter the full path to your local Geth snapshot file: " GETH_LOCAL_SNAPSHOT_PATH
            ;;
        3)
            GETH_SYNC_METHOD="scratch"
            log "You have chosen to sync Geth from scratch."
            ;;
        *)
            log "Invalid choice. Defaulting to sync Geth from scratch."
            GETH_SYNC_METHOD="scratch"
            ;;
    esac
}

clone_and_build_story_geth() {
    log "Cloning and building story-geth"
    
    if [ -d "story-geth" ]; then
        log "story-geth directory already exists. Updating instead of cloning."
        cd story-geth
        git fetch --all
        
        DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
        git reset --hard "origin/$DEFAULT_BRANCH"
    else
        git clone https://github.com/piplabs/story-geth.git
        cd story-geth
    fi
    
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/piplabs/story-geth/releases/latest | jq -r .tag_name)
    
    if [ -n "$LATEST_RELEASE" ]; then
        git checkout $LATEST_RELEASE
    else
        log "Failed to get latest release tag. Using the current HEAD."
    fi
    
    make geth

    # 新しいバイナリをコピー
    log "Copying new geth binary"
    mkdir -p "$HOME/go/bin"
    sudo cp build/bin/geth $HOME/go/bin/geth
    
    if [ $? -ne 0 ]; then
        log "Failed to copy geth binary. Retrying after a short delay..."
        sleep 5
        sudo cp build/bin/geth $HOME/go/bin/geth
    fi
    
    cd ..
    geth version
}

build_and_install_story() {
    log "Building and installing Story"
    
    if [ -d "story" ]; then
        log "story directory already exists. Updating instead of cloning."
        cd story
        git fetch --all
        
        DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
    
        git reset --hard "origin/$DEFAULT_BRANCH"
    else
        git clone https://github.com/piplabs/story.git
        cd story
    fi
    
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/piplabs/story/releases/latest | jq -r .tag_name)
    
    if [ -n "$LATEST_RELEASE" ]; then
        git checkout $LATEST_RELEASE
    else
        log "Failed to get latest release tag. Using the current HEAD."
    fi
    
    if [ -f "go.mod" ]; then
        go mod tidy

        if [ -d "cmd/story" ]; then
            go build -o story ./cmd/story
        else
"DREF"
            MAIN_PACKAGE=$(find . -name "main.go" | head -n 1 | xargs dirname)
            if [ -n "$MAIN_PACKAGE" ]; then
                go build -o story ./$MAIN_PACKAGE
            else
                log "Unable to find main package. Please check the repository structure."
                exit 1
            fi
        fi
    else
        log "go.mod file not found. Unable to build."
        exit 1
    fi
    
    if [ -f "story" ]; then
        sudo mv story $GOPATH/bin/
        log "Story binary installed successfully."
    else
        log "Story binary not found after build. Please check the build process."
        exit 1
    fi
    
    cd ..
    story version
}

create_service_file() {
    local service_name=$1
    local exec_start=$2

    log "Creating $service_name service file"
    sudo tee "/etc/systemd/system/${service_name}.service" > /dev/null <<EOF
[Unit]
Description=$service_name
After=network.target

[Service]
User=$USER
ExecStart=$exec_start
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF
}

configure_story() {
    log "Configuring Story node"

    # Story初期化
    story init --network "$chain_id" --moniker "$moniker_name" || {
        log "Error initializing node. Attempting to resolve..."
        
        if [ ! -f "$HOME/.story/story/data/priv_validator_state.json" ]; then
            log "Creating empty priv_validator_state.json"
            mkdir -p "$HOME/.story/story/data"
            echo "{}" > "$HOME/.story/story/data/priv_validator_state.json"
        fi

        story init --network "$chain_id" --moniker "$moniker_name" || {
            log "Failed to initialize node. Please check your installation and try again."
            exit 1
        }
    }

    # 設定ファイルの更新
    config_dir="$HOME/.story/story/config"
    
    # app.tomlの更新または作成
    app_toml="$config_dir/app.toml"
    if [ ! -f "$app_toml" ]; then
        log "app.toml not found. Creating a new one with default settings."
        echo "# This is a TOML config file for Story application.

minimum-gas-prices = \"$min_gas_price\"
pruning = \"$pruning_mode\"
" > "$app_toml"
    else
        sed -i "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"$min_gas_price\"/" "$app_toml"
        sed -i "s/^pruning *=.*/pruning = \"$pruning_mode\"/" "$app_toml"
    fi

    # RPC ノードの場合、追加の設定
    if [ "$NODE_TYPE" == "rpc" ]; then
        if grep -q "^enable *=" "$app_toml"; then
            sed -i 's/^enable *= *false/enable = true/' "$app_toml"
        else
            echo "enable = true" >> "$app_toml"
        fi
        if grep -q "^swagger *=" "$app_toml"; then
            sed -i 's/^swagger *= *false/swagger = true/' "$app_toml"
        else
            echo "swagger = true" >> "$app_toml"
        fi
    fi
    
    # config.tomlの更新
    config_toml="$config_dir/config.toml"
    sed -i 's/^prometheus *= *false/prometheus = true/' "$config_toml"

    # バリデータノードの場合、追加の設定
    if [ "$NODE_TYPE" == "validator" ]; then
        # config.tomlの更新
        sed -i 's/^mode *= *"full"/mode = "validator"/' "$config_toml"
        sed -i 's/^max_num_outbound_peers *= *[0-9]*/max_num_outbound_peers = 40/' "$config_toml"
        sed -i 's/^indexer *= *"kv"/indexer = "null"/' "$config_toml"
        
        # story.tomlの更新または作成
        story_toml="$config_dir/story.toml"
        if [ ! -f "$story_toml" ]; then
            log "story.toml not found. Creating a new one with default settings."
            echo "# This is a TOML config file for Story validator.

snapshot-interval = 0
" > "$story_toml"
        else
            if grep -q "^snapshot-interval *=" "$story_toml"; then
                sed -i 's/^snapshot-interval *= *[0-9]*/snapshot-interval = 0/' "$story_toml"
            else
                echo "snapshot-interval = 0" >> "$story_toml"
            fi
        fi
    fi

    # client.tomlの更新または作成
    client_toml="$config_dir/client.toml"
    if [ ! -f "$client_toml" ]; then
        log "client.toml not found. Creating a new one with default settings."
        echo "# This is a TOML config file for Story client.

chain-id = \"$chain_id\"
" > "$client_toml"
    else
        sed -i "s/^chain-id *= *.*/chain-id = \"$chain_id\"/" "$client_toml"
    fi

    log "Story node configuration completed"
}

install_dependencies() {
    log "Checking and installing dependencies"
    local dependencies=(curl git make jq build-essential gcc unzip wget lz4 aria2 pv)
    local to_install=()

    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &> /dev/null; then
            to_install+=($dep)
        fi
    done

    if [ ${#to_install[@]} -ne 0 ]; then
        log "The following dependencies need to be installed: ${to_install[*]}"
        read -p "Do you want to install these dependencies? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Installing dependencies. This may require sudo privileges."
            sudo apt update && sudo apt install -y "${to_install[@]}"
            log "Dependencies installed successfully."
        else
            log "Dependency installation skipped. Script may not function correctly."
        fi
    else
        log "All required dependencies are already installed."
    fi
}

NODE_TYPE=""

select_node_type() {
    log "Selecting node type"
    echo "Please select the type of node you want to set up:"
    echo "1) RPC Node"
    echo "2) Validator Node"
    read -p "Enter your choice (1-2): " node_choice

    case $node_choice in
        1)
            NODE_TYPE="rpc"
            log "RPC Node selected"
            ;;
        2)
            NODE_TYPE="validator"
            log "Validator Node selected"
            ;;
        *)
            log "Invalid choice. Defaulting to RPC Node."
            NODE_TYPE="rpc"
            ;;
    esac
}

collect_user_inputs() {
    log "Collecting user inputs for configuration"

    select_node_type
    select_geth_sync_method

    read -p "Enter your moniker name: " moniker_name
    read -p "Enter the network/chain ID (default: iliad): " chain_id
    chain_id=${chain_id:-iliad}
    read -p "Enter minimum gas price (default: 0agstory): " min_gas_price
    min_gas_price=${min_gas_price:-0agstory}
    read -p "Enter pruning mode (default: nothing): " pruning_mode
    pruning_mode=${pruning_mode:-nothing}
    read -p "Enable Prometheus metrics? (y/n, default: y): " enable_prometheus
    enable_prometheus=${enable_prometheus:-y}

    echo "Choose Story sync method:"
    echo "1) Use a snapshot from URL (faster, but requires download)"
    echo "2) Use a local snapshot (fastest if already downloaded)"
    echo "3) Sync from scratch (slower but more secure)"
    read -p "Choose your preferred method (1, 2 or 3): " sync_choice

    case $sync_choice in
        1)
            read -p "Enter the URL of the Story snapshot you want to use (default: $STORY_SNAPSHOT_URL): " user_story_url
            snapshot_url=${user_story_url:-$STORY_SNAPSHOT_URL}
            ;;
        2)
            read -p "Enter the full path to your local snapshot file: " local_snapshot_path
            ;;
        3)
            log "You have chosen to sync from scratch."
            ;;
        *)
            log "Invalid choice. Defaulting to sync from scratch."
            sync_choice=3
            ;;
    esac

    # 確認
    echo -e "\nPlease confirm your settings:"
    echo "Node Type: $NODE_TYPE"
    echo "Moniker name: $moniker_name"
    echo "Chain ID: $chain_id"
    echo "Minimum gas price: $min_gas_price"
    echo "Pruning mode: $pruning_mode"
    echo "Enable Prometheus: $enable_prometheus"
    echo "Story Sync method: $sync_choice"
    if [ "$sync_choice" == "1" ]; then
        echo "Story Snapshot URL: $snapshot_url"
    elif [ "$sync_choice" == "2" ]; then
        echo "Local Story snapshot path: $local_snapshot_path"
    fi

    echo "Geth sync method: $GETH_SYNC_METHOD"
    if [ "$GETH_SYNC_METHOD" == "snapshot" ]; then
        echo "Geth Snapshot URL: $GETH_SNAPSHOT_URL"
    elif [ "$GETH_SYNC_METHOD" == "local_snapshot" ]; then
        echo "Geth Local snapshot path: $GETH_LOCAL_SNAPSHOT_PATH"
    fi

    while true; do
        read -p "Are these settings correct? (y/n): " confirm
        case $confirm in
            [Yy]* ) break;;
            [Nn]* ) 
                log "Configuration cancelled. Please run the script again."
                exit 1
                ;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

print_completion_message() {
    echo -e "\n${GREEN}===== Story Node Setup Completed Successfully! =====${NC}"
    
    echo -e "\n${YELLOW}1. Installation Complete${NC}"
    if [ "$NODE_TYPE" == "validator" ]; then
        echo -e "To create a validator, use the following command:"
        echo -e "${GREEN}story tx staking create-validator --amount=1000000agstory --pubkey=\$(story tendermint show-validator) --moniker=\"$moniker_name\" --chain-id=$chain_id --commission-rate=0.10 --commission-max-rate=0.20 --commission-max-change-rate=0.01 --min-self-delegation=1 --gas=auto --gas-adjustment=1.5 --gas-prices=$min_gas_price --from=operator --keyring-backend=test${NC}"
    fi

    echo -e "\n${YELLOW}2. Download and Apply Snapshots${NC}"
    echo -e "Run the following commands to synchronize your node:"

    # Geth sync command
    echo -e "\n${BLUE}Geth Sync Command:${NC}"
    case $GETH_SYNC_METHOD in
        snapshot)
            echo -e "${GREEN}mkdir -p \"$HOME/.story/geth/$chain_id/geth\" && wget -qO - \"$GETH_SNAPSHOT_URL\" | lz4 -dc | tar xf - -C \"$HOME/.story/geth/$chain_id/geth/chaindata\”${NC}"
            ;;
        local_snapshot)
            echo -e "${GREEN}mkdir -p \"$HOME/.story/geth/$chain_id/geth\" && lz4 -dc \"$GETH_LOCAL_SNAPSHOT_PATH\" | tar xf - -C \"$HOME/.story/geth/$chain_id/geth\"${NC}"
            ;;
        scratch)
            echo -e "${GREEN}No snapshot needed. Geth will sync from scratch.${NC}"
            ;;
    esac

    # Story sync command
    echo -e "\n${BLUE}Story Sync Command:${NC}"
    case $sync_choice in
        1)
            echo -e "${GREEN}wget -qO - \"$snapshot_url\" | lz4 -dc  | tar xf - -C \"$HOME/.story/story/data\"${NC}"
            ;;
        2)
            echo -e "${GREEN}lz4 -dc \"$local_snapshot_path\" | tar xf - -C \"$HOME/.story/story/data\"${NC}"
            ;;
        3)
            echo -e "${GREEN}No snapshot needed. Story will sync from scratch.${NC}"
            ;;
    esac

    echo -e "\n${YELLOW}3. Start Services${NC}"
    echo -e "After applying the snapshots, start the services with these commands:"
    echo -e "${GREEN}sudo systemctl start story-geth${NC}"
    echo -e "${GREEN}sudo systemctl start story${NC}"
}

main() {
    printHeader

    collect_user_inputs

    install_dependencies
    install_go

    clone_and_build_story_geth
    build_and_install_story

    # PATHを更新
    export PATH=$PATH:$HOME/go/bin

    configure_story

    # Gethサービスファイルの作成
    geth_exec_start="$STORY_GETH_BINARY --datadir $HOME/.story/geth/$chain_id --$chain_id"
    if [ "$GETH_SYNC_METHOD" != "scratch" ]; then
        geth_exec_start="$geth_exec_start --syncmode full"
    fi
    create_service_file "story-geth" "$geth_exec_start"
    
    create_service_file "story" "$STORY_BINARY start"

    print_completion_message
}

main
