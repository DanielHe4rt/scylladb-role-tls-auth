#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default host and port
HOST="localhost"
PORT="9142"

# Parse command-line arguments

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "-> ---------------------------------"
    echo "-> ${YELLOW}Usage: $0 [port] [host]${NC}"
    echo "->   port - Port number to connect to (default: 9142)"
    echo "->   host - Hostname or IP address to connect to (default: localhost)"
    echo "-> ---------------------------------"
    exit 0
fi

if [ ! -z "$1" ]; then
    PORT="$1"
fi

if [ ! -z "$2" ]; then
    HOST="$2"
fi

echo "-> ---------------------------------"
echo  "-> ${CYAN}Connecting to ${HOST}:${PORT}${NC}"

# Run the openssl s_client command and capture the output
OUTPUT=$(openssl s_client -connect "${HOST}:${PORT}" 2>&1)

# Check connection status
if echo "$OUTPUT" | grep -q 'CONNECTED'; then
    echo  "-> ${GREEN}Connection successful${NC}"
else
    echo  "-> ${RED}Connection failed${NC}"
    echo "$OUTPUT" | grep 'error'
    exit 1
fi

# # Check for SSL errors
# if echo "$OUTPUT" | grep -q 'error:'; then
#     echo  "-> ${RED}SSL error detected:${NC}"
#     echo "$OUTPUT" | grep 'error:' | while read -r line; do
#         echo  "-> ${RED}$line${NC}"
#     done
# fi

# Check for verification errors
# if echo "$OUTPUT" | grep -q 'verify error'; then
#     echo  "-> ${RED}Verification errors detected:${NC}"
#     echo "$OUTPUT" | grep 'verify error' | while read -r line; do
#         echo  "-> ${RED}$line${NC}"
#     done
# elif echo "$OUTPUT" | grep -q 'Verification: OK'; then
#     echo  "-> ${GREEN}Verification: OK${NC}"
# else
#     echo  "-> ${YELLOW}Verification status unknown${NC}"
# fi

# Check if peer certificate is available
if echo "$OUTPUT" | grep -q 'no peer certificate available'; then
    echo  "-> ${RED}No peer certificate available${NC}"
else
    # Extract server certificate information
    SUBJECT=$(echo "$OUTPUT" | grep 'subject=' | sed 's/subject=//')
    ISSUER=$(echo "$OUTPUT" | grep 'issuer=' | sed 's/issuer=//')

    echo  "-> ${CYAN}Server Certificate:${NC}"
    echo  "->   ${YELLOW}Subject: ${NC} $SUBJECT"
    echo  "->   ${YELLOW}Issuer:  ${NC} $ISSUER"

    # Extract certificate validity dates from Certificate chain section
    DATE_LINE=$(echo "$OUTPUT" | grep -A10 'Certificate chain' | grep 'v:NotBefore')
    if [ -z "$DATE_LINE" ]; then
        echo  "-> ${RED}Could not find certificate validity dates${NC}"
    else
        NOTBEFORE=$(echo "$DATE_LINE" | sed -n 's/.*NotBefore: \(.*GMT\); NotAfter:.*$/\1/p')
        NOTAFTER=$(echo "$DATE_LINE" | sed -n 's/.*NotAfter: \(.*GMT\)$/\1/p')

        echo  "->   ${YELLOW}Validity:${NC}"
        echo  "->     Not Before: ${BLUE}$NOTBEFORE${NC}"
        echo  "->     Not After : ${BLUE}$NOTAFTER${NC}"

        # Check if certificate is expired
        NB_EPOCH=$(date -d "$NOTBEFORE" +%s 2>/dev/null)
        NA_EPOCH=$(date -d "$NOTAFTER" +%s 2>/dev/null)
        NOW_EPOCH=$(date +%s)

        if [ -z "$NB_EPOCH" ] || [ -z "$NA_EPOCH" ]; then
            echo  "-> ${RED}Error parsing certificate dates${NC}"
        else
            if [ "$NOW_EPOCH" -lt "$NB_EPOCH" ]; then
                echo  "->     ${YELLOW}Certificate is not yet valid${NC}"
            elif [ "$NOW_EPOCH" -gt "$NA_EPOCH" ]; then
                echo  "->     ${RED}Certificate has expired${NC}"
            else
                echo  "->     ${GREEN}Certificate is currently valid${NC}"
            fi
        fi
    fi
fi

# Extract SSL/TLS information
TLS_INFO=$(echo "$OUTPUT" | grep '^New,')
CIPHER=$(echo "$TLS_INFO" | sed 's/.*Cipher is //')
TLS_VERSION=$(echo "$TLS_INFO" | sed 's/, Cipher.*//' | sed 's/New, //')

echo  "-> ${CYAN}SSL/TLS Connection:${NC}"
echo  "->   ${YELLOW}TLS Version:${NC} ${TLS_VERSION:-N/A}"
echo  "->   ${YELLOW}Cipher Suite:${NC} ${CIPHER:-N/A}"

# Extract server public key size if available
PUBKEY_SIZE=$(echo "$OUTPUT" | grep 'Server public key is' | sed 's/Server public key is //')

if [ ! -z "$PUBKEY_SIZE" ]; then
    echo  "->   ${YELLOW}Server Public Key Size:${NC} $PUBKEY_SIZE"
else
    echo  "->   ${YELLOW}Server Public Key Size:${NC} N/A"
fi

# Extract acceptable client certificate CA names
if echo "$OUTPUT" | grep -q 'Acceptable client certificate CA names'; then
    echo  "-> ${CYAN}Acceptable Client Certificate CA Names:${NC}"
    CA_NAMES=$(echo "$OUTPUT" | awk '/Acceptable client certificate CA names/,/Requested Signature Algorithms/' | grep -v 'Acceptable client certificate CA names' | grep -v 'Requested Signature Algorithms')
    echo "$CA_NAMES" | while read -r line; do
        echo  "->   ${BLUE}$line${NC}"
    done
else
    echo  "-> ${YELLOW}No acceptable client certificate CA names sent${NC}"
fi


echo "-> ${GREEN}All checks completed${NC}"
echo "-> ---------------------------------"
echo "-> ${BLUE}You can run the openssl s_client command manually to get more detailed information${NC}"
echo "-> ${BLUE}Example${NC}: openssl s_client -connect ${HOST}:${PORT}"
echo "-> ---------------------------------"

exit 0