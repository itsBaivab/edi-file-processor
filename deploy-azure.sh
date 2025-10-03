#!/bin/bash

# Azure EDI File Processor Deployment Script
# This script creates all Azure resources needed for the EDI file processing workflow
# Workflow: File Upload to Blob -> Azure Function Trigger -> SQL Database Processing

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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
    print_status "Loaded environment variables from .env file"
else
    print_error ".env file not found. Please create one based on .env.template"
    exit 1
fi

# Validate required environment variables
required_vars=("AZURE_SUBSCRIPTION_ID" "RESOURCE_GROUP_NAME" "LOCATION" "STORAGE_ACCOUNT_NAME" "FUNCTION_APP_NAME" "SQL_SERVER_NAME" "SQL_DATABASE_NAME" "SQL_ADMIN_USERNAME" "SQL_ADMIN_PASSWORD")

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable $var is not set"
        exit 1
    fi
done

print_status "Starting Azure deployment..."
print_status "Subscription ID: $AZURE_SUBSCRIPTION_ID"
print_status "Resource Group: $RESOURCE_GROUP_NAME"
print_status "Location: $LOCATION"

# Set the subscription
print_status "Setting Azure subscription..."
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# Create Resource Group
print_status "Creating resource group: $RESOURCE_GROUP_NAME..."
az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --output table

print_success "Resource group created successfully"

# Create Storage Account
print_status "Creating storage account: $STORAGE_ACCOUNT_NAME..."
az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --access-tier Hot \
    --output table

print_success "Storage account created successfully"

# Get storage account connection string
print_status "Getting storage account connection string..."
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query connectionString \
    --output tsv)

# Create blob container for uploads
print_status "Creating blob container: edibaivabuploads..."
az storage container create \
    --name "edibaivabuploads" \
    --connection-string "$STORAGE_CONNECTION_STRING" \
    --public-access off \
    --output table

print_success "Blob container created successfully"

# Create SQL Server
print_status "Creating SQL Server: $SQL_SERVER_NAME..."
az sql server create \
    --name "$SQL_SERVER_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --admin-user "$SQL_ADMIN_USERNAME" \
    --admin-password "$SQL_ADMIN_PASSWORD" \
    --output table

print_success "SQL Server created successfully"

# Configure SQL Server firewall to allow Azure services
print_status "Configuring SQL Server firewall rules..."
az sql server firewall-rule create \
    --name "AllowAzureServices" \
    --server "$SQL_SERVER_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0 \
    --output table

# Add your current IP to firewall (optional for testing)
if [ "$ALLOW_LOCAL_ACCESS" = "true" ]; then
    print_status "Adding local IP to SQL Server firewall..."
    LOCAL_IP=$(curl -s https://ipinfo.io/ip)
    az sql server firewall-rule create \
        --name "AllowLocalIP" \
        --server "$SQL_SERVER_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --start-ip-address "$LOCAL_IP" \
        --end-ip-address "$LOCAL_IP" \
        --output table
    print_success "Local IP $LOCAL_IP added to firewall"
fi

print_success "SQL Server firewall configured successfully"

# Create SQL Database
print_status "Creating SQL Database: $SQL_DATABASE_NAME..."
az sql db create \
    --name "$SQL_DATABASE_NAME" \
    --server "$SQL_SERVER_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --service-objective Basic \
    --max-size 2GB \
    --output table

print_success "SQL Database created successfully"

# Build SQL connection string
SQL_CONNECTION_STRING="Driver={ODBC Driver 18 for SQL Server};Server=tcp:${SQL_SERVER_NAME}.database.windows.net,1433;Database=${SQL_DATABASE_NAME};Uid=${SQL_ADMIN_USERNAME};Pwd=${SQL_ADMIN_PASSWORD};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"

# Create Function App
print_status "Creating Function App: $FUNCTION_APP_NAME..."
az functionapp create \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --storage-account "$STORAGE_ACCOUNT_NAME" \
    --consumption-plan-location "$LOCATION" \
    --runtime python \
    --runtime-version 3.9 \
    --functions-version 4 \
    --os-type Linux \
    --output table

print_success "Function App created successfully"

# Configure Function App settings
print_status "Configuring Function App settings..."
az functionapp config appsettings set \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --settings \
    "AzureWebJobsStorage=$STORAGE_CONNECTION_STRING" \
    "SQLConnectionString=$SQL_CONNECTION_STRING" \
    "FUNCTIONS_WORKER_RUNTIME=python" \
    "FUNCTIONS_EXTENSION_VERSION=~4" \
    --output table

print_success "Function App settings configured successfully"

# Deploy the function code
print_status "Deploying function code..."

# Create a temporary zip file for deployment
TEMP_DIR=$(mktemp -d)
cp -r * "$TEMP_DIR/"
cd "$TEMP_DIR"

# Remove deployment script and other non-function files from temp directory
rm -f deploy-azure.sh .env .env.template README.md *.txt 2>/dev/null || true

# Create deployment package
zip -r function-app.zip . -x "*.git*" "*.DS_Store*" "__pycache__/*" "*.pyc"

# Deploy to Azure
az functionapp deployment source config-zip \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --src function-app.zip \
    --build-remote true

cd - > /dev/null
rm -rf "$TEMP_DIR"

print_success "Function code deployed successfully"

# Wait for function app to be ready
print_status "Waiting for function app to be fully deployed..."
sleep 30

# Display deployment summary
echo ""
echo "======================================"
echo "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉"
echo "======================================"
echo ""
echo "📋 DEPLOYMENT SUMMARY:"
echo "----------------------"
echo "Resource Group:     $RESOURCE_GROUP_NAME"
echo "Storage Account:    $STORAGE_ACCOUNT_NAME"
echo "Blob Container:     edibaivabuploads"
echo "SQL Server:         $SQL_SERVER_NAME.database.windows.net"
echo "SQL Database:       $SQL_DATABASE_NAME"
echo "Function App:       $FUNCTION_APP_NAME"
echo ""
echo "🔗 USEFUL LINKS:"
echo "----------------"
echo "Function App URL:   https://${FUNCTION_APP_NAME}.azurewebsites.net"
echo "Azure Portal:       https://portal.azure.com"
echo ""
echo "📝 CONNECTION STRINGS:"
echo "----------------------"
echo "Storage Connection: $STORAGE_CONNECTION_STRING"
echo ""
echo "SQL Connection:     $SQL_CONNECTION_STRING"
echo ""
echo "🧪 TESTING:"
echo "-----------"
echo "1. Upload a file to the 'edibaivabuploads' container in your storage account"
echo "2. Check the Function App logs to see the processing"
echo "3. Verify the BlobAudit table in your SQL database for processed files"
echo ""
echo "📖 To view logs:"
echo "az functionapp log tail --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP_NAME"
echo ""
print_success "All resources are ready for use!"