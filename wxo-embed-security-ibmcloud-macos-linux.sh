#!/bin/bash
# IBM watsonx Orchestrate - IBM Cloud Security Configuration Tool (macOS/Linux)

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
OUTPUT_DIR="wxo_security_config"

echo -e "${BOLD}IBM watsonx Orchestrate - IBM Cloud Security Configuration Tool${NC}\n"
echo -e "This tool will configure security for your IBM Cloud embedded chat integration.\n"

mkdir -p "$OUTPUT_DIR" 2>/dev/null
[ ! -d "$OUTPUT_DIR" ] || [ ! -w "$OUTPUT_DIR" ] && { echo -e "${RED}ERROR: Cannot create/write to '$OUTPUT_DIR'.${NC}"; exit 1; }
echo -e "${GREEN}Output directory ready: $OUTPUT_DIR${NC}\n"

get_input() { local p="$1" v="$2" s="$3" val=""; while [ -z "$val" ]; do [ "$s" = true ] && read -sp "$p: " val || read -p "$p: " val; echo; [ -z "$val" ] && echo -e "${YELLOW}Cannot be empty.${NC}"; done; eval $v=\$val; }

echo -e "${BOLD}Enter your Service instance URL:${NC}"
echo -e "${BLUE}Example: https://api.us-south.watson-orchestrate.cloud.ibm.com/instances/12345-67890-abcde${NC}"
get_input "Service instance URL" SERVICE_URL false

[[ $SERVICE_URL =~ ^(https?://[^/]+)/instances/([a-zA-Z0-9-]+)$ ]] && { API_URL="${BASH_REMATCH[1]}"; WXO_INSTANCE_ID="${BASH_REMATCH[2]}"; echo -e "${GREEN}API URL: $API_URL${NC}"; echo -e "${GREEN}Instance ID: $WXO_INSTANCE_ID${NC}"; } || { echo -e "${RED}Invalid URL format.${NC}"; exit 1; }

echo -e "\n${BOLD}Step 1: Getting IBM Cloud API Key${NC}"
get_input "Enter your IBM Cloud API Key" IBM_CLOUD_API_KEY true

echo -e "\n${BLUE}Exchanging API Key for IAM Token...${NC}"
TOKEN_RESPONSE=$(curl -sS -X POST 'https://iam.cloud.ibm.com/identity/token' -H 'Content-Type: application/x-www-form-urlencoded' -d "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=$IBM_CLOUD_API_KEY" 2>&1)
[ $? -ne 0 ] && { echo -e "${RED}Failed to obtain IAM token.${NC}"; exit 1; }
ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
[ -z "$ACCESS_TOKEN" ] && { echo -e "${RED}Failed to extract access token.${NC}"; exit 1; }
echo -e "${GREEN}Successfully obtained IAM token!${NC}"

echo -e "\n${BOLD}Getting current embed security configuration...${NC}"
CONFIG_RESPONSE=$(curl -sS -X GET "$API_URL/instances/$WXO_INSTANCE_ID/v1/embed/secure/config" -H "Authorization: Bearer $ACCESS_TOKEN" -H "accept: application/json" 2>&1)
[ $? -eq 0 ] && { IS_SECURITY_ENABLED=$(echo $CONFIG_RESPONSE | grep -o '"is_security_enabled":[^,}]*' | cut -d':' -f2 | tr -d ' '); echo -e "Current security status: ${BOLD}$([ "$IS_SECURITY_ENABLED" = "true" ] && echo "ENABLED" || echo "DISABLED")${NC}"; } || echo -e "${YELLOW}Could not retrieve current configuration.${NC}"

generate_ibm_key() {
    echo -e "\n${BOLD}Step 2: Generating IBM Public Key${NC}"
    mkdir -p "$OUTPUT_DIR" 2>/dev/null
    IBM_KEY_RESPONSE=$(curl -sS -X POST "$API_URL/instances/$WXO_INSTANCE_ID/v1/embed/secure/generate-key-pair" -H "Authorization: Bearer $ACCESS_TOKEN" -H "accept: application/json" 2>&1)
    [ $? -ne 0 ] && { echo -e "${RED}Failed to generate IBM key pair.${NC}"; exit 1; }
    IBM_PUBLIC_KEY_RAW=$(echo "$IBM_KEY_RESPONSE" | grep -o "\"public_key\":\"[^\"]*\"" | sed 's/"public_key":"//g' | sed 's/"$//g')
    [ -z "$IBM_PUBLIC_KEY_RAW" ] && { echo -e "${RED}Failed to extract IBM public key.${NC}"; exit 1; }
    echo -e "$IBM_PUBLIC_KEY_RAW" | sed 's/\\n/\n/g' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$OUTPUT_DIR/ibm_public_key.key.pub"
    [ ! -s "$OUTPUT_DIR/ibm_public_key.key.pub" ] && { echo -e "${RED}Failed to create IBM public key file.${NC}"; exit 1; }
    IBM_PUBLIC_KEY=$(cat "$OUTPUT_DIR/ibm_public_key.key.pub" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | awk '{printf "%s\\n", $0}')
    echo -e "${GREEN}Successfully generated and saved IBM public key.${NC}"
}

use_existing_client_key() {
    echo -e "\n${BOLD}Step 3: Using Existing Client Public Key${NC}"
    local key_path=""
    while [ -z "$key_path" ]; do
        read -p "Enter path to client PUBLIC key file: " key_path
        [ -z "$key_path" ] && { echo -e "${YELLOW}Path cannot be empty.${NC}"; continue; }
        [ ! -f "$key_path" ] && { echo -e "${RED}File not found: $key_path${NC}"; key_path=""; continue; }
        [ ! -r "$key_path" ] && { echo -e "${RED}File not readable: $key_path${NC}"; key_path=""; continue; }
    done
    CLIENT_PUBLIC_KEY=$(cat "$key_path" | awk '{printf "%s\\n", $0}')
    [ -z "$CLIENT_PUBLIC_KEY" ] || [ ${#CLIENT_PUBLIC_KEY} -lt 100 ] && { echo -e "${RED}Invalid public key file.${NC}"; exit 1; }
    echo -e "${GREEN}Successfully loaded client public key from: $key_path${NC}"
}

generate_client_keys() {
    echo -e "\n${BOLD}Step 3: Generating New Client Key Pair${NC}"
    mkdir -p "$OUTPUT_DIR" 2>/dev/null
    openssl genrsa -out "$OUTPUT_DIR/client_private_key.key" 4096 2>/dev/null || { echo -e "${RED}Failed to generate private key.${NC}"; exit 1; }
    openssl rsa -in "$OUTPUT_DIR/client_private_key.key" -pubout -out "$OUTPUT_DIR/client_public_key.key.pub" 2>/dev/null || { echo -e "${RED}Failed to extract public key.${NC}"; exit 1; }
    CLIENT_PUBLIC_KEY=$(cat "$OUTPUT_DIR/client_public_key.key.pub" | awk '{printf "%s\\n", $0}')
    echo -e "${GREEN}Successfully generated client key pair.${NC}"
    echo -e "Private key: ${BOLD}$OUTPUT_DIR/client_private_key.key${NC}"
    echo -e "Public key: ${BOLD}$OUTPUT_DIR/client_public_key.key.pub${NC}"
}

enable_security() {
    echo -e "\n${BOLD}Step 4: Enabling Security with Custom Keys${NC}"
    local payload="{\"public_key\":\"$IBM_PUBLIC_KEY\",\"client_public_key\":\"$CLIENT_PUBLIC_KEY\",\"is_security_enabled\":true}"
    ENABLE_RESPONSE=$(curl -sS -X POST "$API_URL/instances/$WXO_INSTANCE_ID/v1/embed/secure/config" -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" -d "$payload" 2>&1)
    [ $? -ne 0 ] && { echo -e "${RED}Failed to enable security.${NC}"; echo "$ENABLE_RESPONSE"; exit 1; }
    echo -e "${GREEN}Successfully enabled security with custom keys.${NC}"
}

disable_security() {
    echo -e "\n${BOLD}Disabling Security and Allowing Anonymous Access${NC}"
    echo -e "${RED}WARNING: This will allow anonymous access to your embedded chat.${NC}"
    read -p "Are you sure? (yes/no): " confirmation
    [[ "$confirmation" != "yes" ]] && { echo "Operation cancelled."; return 1; }
    local payload='{"public_key":"","client_public_key":"","is_security_enabled":false}'
    DISABLE_RESPONSE=$(curl -sS -X POST "$API_URL/instances/$WXO_INSTANCE_ID/v1/embed/secure/config" -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" -d "$payload" 2>&1)
    [ $? -ne 0 ] && { echo -e "${RED}Failed to disable security.${NC}"; exit 1; }
    echo -e "${YELLOW}Security has been disabled. Anonymous access enabled.${NC}"
}

verify_configuration() {
    echo -e "\n${BOLD}Security Status${NC}"
    VERIFY_RESPONSE=$(curl -sS -X GET "$API_URL/instances/$WXO_INSTANCE_ID/v1/embed/secure/config" -H "Authorization: Bearer $ACCESS_TOKEN" -H "accept: application/json" 2>&1)
    [ $? -ne 0 ] && { echo -e "${RED}Failed to retrieve configuration.${NC}"; return 1; }
    FINAL_STATUS=$(echo $VERIFY_RESPONSE | grep -o '"is_security_enabled":[^,}]*' | cut -d':' -f2 | tr -d ' ')
    echo -e "Security is now: ${BOLD}$([ "$FINAL_STATUS" = "true" ] && echo "${GREEN}ENABLED${NC}" || echo "${YELLOW}DISABLED${NC}")${NC}"
    [ "$FINAL_STATUS" = "true" ] && echo -e "${GREEN}Security is properly configured.${NC}"
}

view_full_configuration() {
    echo -e "\n${BOLD}Current Configuration${NC}"
    CONFIG_RESPONSE=$(curl -sS -X GET "$API_URL/instances/$WXO_INSTANCE_ID/v1/embed/secure/config" -H "Authorization: Bearer $ACCESS_TOKEN" -H "accept: application/json" 2>&1)
    [ $? -ne 0 ] && { echo -e "${RED}Failed to retrieve configuration.${NC}"; echo "$CONFIG_RESPONSE"; return 1; }
    command -v jq &> /dev/null && echo "$CONFIG_RESPONSE" | jq . || echo "$CONFIG_RESPONSE"
}

check_security_status() {
    local check_response=$(curl -sS -X GET "$API_URL/instances/$WXO_INSTANCE_ID/v1/embed/secure/config" -H "Authorization: Bearer $ACCESS_TOKEN" -H "accept: application/json" 2>&1)
    [ $? -eq 0 ] && { local status=$(echo $check_response | grep -o '"is_security_enabled":[^,}]*' | cut -d':' -f2 | tr -d ' '); [ "$status" = "true" ] && return 0; }
    return 1
}

while true; do
    echo -e "\n${BOLD}Select an action:${NC}"
    echo "1) Configure security with newly generated keys (Recommended)"
    echo "2) Configure security with existing client public key"
    echo "3) Disable security and allow anonymous access"
    echo "4) View current security status"
    echo "5) View current configuration"
    echo "6) Exit"
    read -p "Enter your choice (1-6): " action
    case $action in
        1) check_security_status && { echo -e "\n${YELLOW}⚠️  Security is already enabled!${NC}"; echo -e "${YELLOW}You must disable security first (option 3) before reconfiguring.${NC}"; echo -e "${YELLOW}This prevents accidental overwriting of existing keys.${NC}"; continue; }; generate_ibm_key; generate_client_keys; enable_security; verify_configuration; echo -e "\n${BOLD}Configuration Summary${NC}"; echo -e "Key files saved in ${BOLD}$OUTPUT_DIR${NC}:"; echo -e "- IBM public key: ibm_public_key.key.pub"; echo -e "- Client private key: client_private_key.key"; echo -e "- Client public key: client_public_key.key.pub"; echo -e "\n${GREEN}Configuration completed successfully!${NC}";;
        2) check_security_status && { echo -e "\n${YELLOW}⚠️  Security is already enabled!${NC}"; echo -e "${YELLOW}You must disable security first (option 3) before reconfiguring.${NC}"; echo -e "${YELLOW}This prevents accidental overwriting of existing keys.${NC}"; continue; }; generate_ibm_key; use_existing_client_key; enable_security; verify_configuration; echo -e "\n${BOLD}Configuration Summary${NC}"; echo -e "Key files saved in ${BOLD}$OUTPUT_DIR${NC}:"; echo -e "- IBM public key: ibm_public_key.key.pub"; echo -e "- Used existing client public key from provided path"; echo -e "\n${GREEN}Configuration completed successfully!${NC}";;
        3) disable_security; verify_configuration;;
        4) verify_configuration;;
        5) view_full_configuration;;
        6) echo -e "${BLUE}Exiting.${NC}"; exit 0;;
        *) echo -e "${YELLOW}Invalid selection. Please enter 1-6.${NC}";;
    esac
done
