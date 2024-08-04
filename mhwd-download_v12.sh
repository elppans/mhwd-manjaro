#!/bin/bash

# +-+-+-+-+-+-
# COLOR CODES
# +-+-+-+-+-+-

BLUE='\033[1;34m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BCK_RED='\033[1;41m'
NC='\033[0m'

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# NEED TO BE RAN WITH ADMIN PRIVILEGES
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

if [ "$EUID" -ne 0 ]
  then
    printf "\n${CYAN}This script needs to be ran with admin privileges to execute properly.\n\n${NC}"
  exit
fi

# +-+-+-+-+-+-+-+-+-+-+-+-
# M A I N   P R O G R A M
# +-+-+-+-+-+-+-+-+-+-+-+-

# Specify the URL of the MANJARO_GPG_FILE
MANJARO_GPG_URL="https://gitlab.manjaro.org/packages/core/manjaro-keyring/-/raw/master/manjaro.gpg"

# Specify the URL of the directory containing the files
MHWD_URL="https://mirror.csclub.uwaterloo.ca/manjaro/stable/extra/x86_64/"

# Specify the directory where the files will be downloaded and extracted
TARGET_DIRECTORY="/tmp/mjr"

# Change to the target directory
mkdir -p ${TARGET_DIRECTORY}
cd ${TARGET_DIRECTORY}

# ld.so.conf
echo -e "${TARGET_DIRECTORY}/lib" > /etc/ld.so.conf.d/mjr.conf

# Print a blank line
echo

# Print the title
echo -e "${WHITE}MHWD MANJARO INSTALLATION${NC}"

# Print a line of asterisks
echo -e "${WHITE}*************************${NC}"

# Print a blank line
echo

# Import manjaro.gpg if not already installed
#if ! gpg --list-keys manjaro >/dev/null 2>&1; then
#    echo -e "${CYAN}Importing manjaro.gpg...${NC}"
#    echo
#    curl -s "$MANJARO_GPG_URL" | gpg --import
#    echo
#    echo -e "${GREEN}manjaro.gpg imported successfully!${NC}"
#else
#    echo -e "${GREEN}manjaro.gpg is already installed.${NC}"
#fi

#echo

printf "${YELLOW}Retrieving list of mhwd-manjaro files..."

# Fetch the HTML content of the URL and extract the file names

# +-+-+-+-+-+-+-+-+-+-+-+
# MHWD AND V86d DOWNLOAD
# +-+-+-+-+-+-+-+-+-+-+-+

# Maximum number of retries
MAX_RETRIES=10

# Initialize the retry counter
RETRY_COUNT=0

# Retry loop
while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))

    # Initialize the FILE_LIST variable
    FILE_LIST=""

    # Count the number of files fetched and dot counter
    COUNT=0
    DOT_COUNT=0

    # Start fetching files with progress indicator
    (curl -s -m 60 "$MHWD_URL" | grep -oP 'mhwd[^"]*\.tar\.zst' > /tmp/file_list) &
    (curl -s -m 60 "$MHWD_URL" | grep -oP 'v86d[^"]*\.tar\.zst' >> /tmp/file_list) &

    # Display dots for every 10 files until the curl command finishes
    while kill -0 $! >/dev/null 2>&1; do
        COUNT=$((COUNT + 1))

        if ((COUNT % 10 == 0)); then
            printf "."
            DOT_COUNT=$((DOT_COUNT + 1))
        fi

        sleep 0.1 # Optional: Add a short delay for visualization purposes
    done

    # Read the temporary file to process the fetched files
    while read -r FILE; do
        COUNT=$((COUNT + 1))

        # Append the file to the FILE_LIST variable
        FILE_LIST+=" $FILE"

        if ((COUNT % 10 == 0)); then
            printf "."
            DOT_COUNT=$((DOT_COUNT + 1))
        fi
    done < /tmp/file_list

    # Remove the temporary file
 #   rm /tmp/file_list

    # Remove duplicate lines
    UNIQUE_FILE_LIST=$(echo "$FILE_LIST" | tr ' ' '\n' | sort | uniq)

    # Check if UNIQUE_FILE_LIST has exactly 9 file names
    FILE_COUNT=$(echo "$UNIQUE_FILE_LIST" | wc -l)

    if [ "$FILE_COUNT" -eq 9 ]; then
        break
    else
        if [ "$RETRY_COUNT" -eq "$MAX_RETRIES" ]; then
            printf "${WHITE}\n\nMaximum retries reached. Exiting.${NC}\n\n"
            exit 1
        fi
    fi
done

# Print a newline and blank line after the progress indicator.
printf "\n\n"


# Function to download and extract files
download_and_extract() {
    local FILE_NAME="$1"
    local PGP_FILE_NAME="$FILE_NAME.sig"

    if [[ ! -e "$FILE_NAME" ]]; then
        echo -e "${YELLOW}Downloading $FILE_NAME...${NC}"
        curl -s -O "$MHWD_URL$FILE_NAME" > /dev/null

        #echo -e "${YELLOW}Downloading $PGP_FILE_NAME...${NC}"
        #curl -s -O "$MHWD_URL$PGP_FILE_NAME" > /dev/null

        #echo -e "${GREEN}Verifying $FILE_NAME...${NC}"
        #GPG_OUTPUT=$(gpg --verify "$PGP_FILE_NAME" "$FILE_NAME" 2>&1)
        #if [[ $GPG_OUTPUT =~ "Good signature" ]]; then
        #    echo -e "${GREEN}Verification successful!${NC}"
        #else
        #    echo -e "${RED}Verification failed:${NC}"
        #    echo "$GPG_OUTPUT"
        #fi

        echo -e "${CYAN}Extracting $FILE_NAME...${NC}"
        tar -xf "$FILE_NAME" -C "$TARGET_DIRECTORY"
        echo -e "${WHITE}Extraction completed!${NC}"
        echo

        local SIG_FILE="${FILE_NAME}.sig"
        if [[ -e "$SIG_FILE" ]]; then
            rm "$SIG_FILE"
        fi
    fi
}

# Download and extract mhwd*.tar.zst files
for FILE in $UNIQUE_FILE_LIST; do
    download_and_extract "$FILE"
done

echo -e "${YELLOW}All files downloaded and extracted.${NC}"

# Clean up downloaded packages
printf "${CYAN}Cleaning up downloaded packages..."
for FILE in $FILE_LIST; do
    if [[ -e "$FILE" ]]; then
        rm "$FILE"
        printf "."
    fi
done

rm ${TARGET_DIRECTORY}/.BUILDINFO >/dev/null 2>&1
rm ${TARGET_DIRECTORY}/.INSTALL >/dev/null 2>&1
rm ${TARGET_DIRECTORY}/.PKGINFO >/dev/null 2>&1
rm ${TARGET_DIRECTORY}/.MTREE >/dev/null 2>&1

echo
echo -e "${GREEN}Cleanup completed${NC}"
echo
