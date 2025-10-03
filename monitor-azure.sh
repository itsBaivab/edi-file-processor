#!/bin/bash

# Monitoring script for Azure EDI File Processor
# Use this to check the status of your deployed resources

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[STATUS]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    print_error ".env file not found"
    exit 1
fi

echo "========================================"
echo "🔍 Azure EDI Processor Status Monitor"
echo "========================================"
echo ""

# Check Resource Group
print_status "Checking Resource Group: $RESOURCE_GROUP_NAME"
if az group show --name "$RESOURCE_GROUP_NAME" >/dev/null 2>&1; then
    print_success "Resource Group exists"
else
    print_error "Resource Group not found"
    exit 1
fi

# Check Storage Account
print_status "Checking Storage Account: $STORAGE_ACCOUNT_NAME"
STORAGE_STATUS=$(az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query provisioningState -o tsv 2>/dev/null || echo "NotFound")
if [ "$STORAGE_STATUS" = "Succeeded" ]; then
    print_success "Storage Account is running"
    
    # Check blob container
    STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query connectionString -o tsv)
    if az storage container show --name "edibaivabuploads" --connection-string "$STORAGE_CONNECTION_STRING" >/dev/null 2>&1; then
        print_success "Blob container 'edibaivabuploads' exists"
        
        # Count files in container
        FILE_COUNT=$(az storage blob list --container-name "edibaivabuploads" --connection-string "$STORAGE_CONNECTION_STRING" --query "length(@)" -o tsv 2>/dev/null || echo "0")
        print_status "Files in container: $FILE_COUNT"
    else
        print_warning "Blob container 'edibaivabuploads' not found"
    fi
else
    print_error "Storage Account not found or not ready"
fi

# Check SQL Server
print_status "Checking SQL Server: $SQL_SERVER_NAME"
SQL_STATUS=$(az sql server show --name "$SQL_SERVER_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query state -o tsv 2>/dev/null || echo "NotFound")
if [ "$SQL_STATUS" = "Ready" ]; then
    print_success "SQL Server is ready"
    
    # Check SQL Database
    DB_STATUS=$(az sql db show --name "$SQL_DATABASE_NAME" --server "$SQL_SERVER_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query status -o tsv 2>/dev/null || echo "NotFound")
    if [ "$DB_STATUS" = "Online" ]; then
        print_success "SQL Database is online"
    else
        print_warning "SQL Database status: $DB_STATUS"
    fi
else
    print_error "SQL Server not found or not ready"
fi

# Check Function App
print_status "Checking Function App: $FUNCTION_APP_NAME"
FUNC_STATUS=$(az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query state -o tsv 2>/dev/null || echo "NotFound")
if [ "$FUNC_STATUS" = "Running" ]; then
    print_success "Function App is running"
    
    # Check function deployment status
    print_status "Checking function deployment..."
    FUNC_URL="https://${FUNCTION_APP_NAME}.azurewebsites.net"
    if curl -s -o /dev/null -w "%{http_code}" "$FUNC_URL" | grep -q "200\|401\|403"; then
        print_success "Function App is accessible"
    else
        print_warning "Function App may not be fully deployed yet"
    fi
else
    print_error "Function App status: $FUNC_STATUS"
fi

echo ""
echo "========================================"
echo "📊 Summary"
echo "========================================"

# Resource URLs and connection info
echo "🔗 Resource URLs:"
echo "   Function App:    https://${FUNCTION_APP_NAME}.azurewebsites.net"
echo "   Storage Account: https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
echo "   SQL Server:      ${SQL_SERVER_NAME}.database.windows.net"
echo ""

echo "📋 Quick Commands:"
echo "   Monitor logs:    az functionapp log tail --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP_NAME"
echo "   Upload test:     ./test-deployment.sh"
echo "   View resources:  az resource list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""

echo "💾 Database Connection:"
echo "   Server:   ${SQL_SERVER_NAME}.database.windows.net"
echo "   Database: $SQL_DATABASE_NAME"
echo "   Username: $SQL_ADMIN_USERNAME"
echo "   Query:    SELECT * FROM BlobAudit ORDER BY ProcessedAt DESC"
echo ""

print_success "Status check completed!"