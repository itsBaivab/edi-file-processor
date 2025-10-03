#!/bin/bash

# Test script for Azure EDI File Processor
# This script helps you test the deployed Azure workflow

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
    print_status "Loaded environment variables from .env file"
else
    echo "Error: .env file not found. Please create one and deploy first."
    exit 1
fi

# Create a test EDI file
TEST_FILE="test-edi-file-$(date +%s).txt"
cat > "$TEST_FILE" << 'EOF'
ISA*00*          *00*          *ZZ*SENDER_ID      *ZZ*RECEIVER_ID    *210101*1200*^*00501*000000001*0*P*:~
GS*PO*SENDER*RECEIVER*20210101*1200*1*X*005010~
ST*850*0001~
BEG*00*SA*PO123456**20210101~
REF*DP*DEPT123~
DTM*002*20210101~
N1*ST*SHIP TO NAME~
N3*123 MAIN STREET~
N4*CITY*ST*12345*US~
PO1*001*10*EA*1.50*PE*VP*PRODUCT123~
CTT*1~
SE*10*0001~
GE*1*1~
IEA*1*000000001~
EOF

print_status "Created test EDI file: $TEST_FILE"

# Upload test file to blob storage
print_status "Uploading test file to Azure Blob Storage..."

# Get storage connection string
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query connectionString \
    --output tsv)

# Upload the file
az storage blob upload \
    --file "$TEST_FILE" \
    --container-name "edibaivabuploads" \
    --name "$TEST_FILE" \
    --connection-string "$STORAGE_CONNECTION_STRING" \
    --output table

print_success "Test file uploaded successfully!"

# Wait a moment for function to process
print_status "Waiting 10 seconds for Azure Function to process the file..."
sleep 10

# Check function logs
print_status "Checking recent function logs..."
az functionapp log tail \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --timeout 30 || true

print_info "To continue monitoring logs in real-time, run:"
echo "az functionapp log tail --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP_NAME"

print_info "To check database records, connect to SQL Server and query:"
echo "SELECT * FROM BlobAudit ORDER BY ProcessedAt DESC"

print_info "SQL Server details:"
echo "Server: ${SQL_SERVER_NAME}.database.windows.net"
echo "Database: $SQL_DATABASE_NAME"
echo "Username: $SQL_ADMIN_USERNAME"

# Cleanup test file
rm -f "$TEST_FILE"
print_status "Cleaned up local test file"

echo ""
print_success "Test completed! Check the function logs and database for processing results."