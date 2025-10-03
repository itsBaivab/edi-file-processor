# Azure EDI File Processor - Deployment Guide

This project provides an automated Azure deployment for an EDI file processing workflow:
**File Upload → Blob Storage → Azure Function → SQL Database**

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI installed and configured**
   ```bash
   # Install Azure CLI (if not already installed)
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Login to Azure
   az login
   
   # Verify your subscription
   az account show
   ```

2. **Required permissions**: Contributor access to your Azure subscription

### Step-by-Step Deployment

1. **Clone and navigate to the project**
   ```bash
   cd /path/to/your/project
   ```

2. **Create your environment configuration**
   ```bash
   cp .env.template .env
   nano .env  # or use your preferred editor
   ```

3. **Configure your .env file**
   - Set your `AZURE_SUBSCRIPTION_ID`
   - Choose a unique `STORAGE_ACCOUNT_NAME` (3-24 chars, lowercase + numbers)
   - Choose a unique `FUNCTION_APP_NAME`
   - Choose a unique `SQL_SERVER_NAME`
   - Set a strong `SQL_ADMIN_PASSWORD` (see requirements in template)
   - Adjust other settings as needed

4. **Run the deployment script**
   ```bash
   ./deploy-azure.sh
   ```

5. **Wait for completion** (typically 5-10 minutes)

## 📋 What Gets Created

The deployment script creates these Azure resources:

| Resource Type | Name Pattern | Purpose |
|---------------|--------------|---------|
| Resource Group | `rg-edi-processor-demo` | Container for all resources |
| Storage Account | `stedidemo[timestamp]` | Blob storage for file uploads |
| Blob Container | `edibaivabuploads` | Specific container for EDI files |
| SQL Server | `sql-edi-demo-[timestamp]` | Database server |
| SQL Database | `EdiProcessorDB` | Database for processed file records |
| Function App | `func-edi-processor-demo-[timestamp]` | Serverless function processing |

## 🔧 Architecture

```
[File Upload] → [Blob Storage] → [Function Trigger] → [SQL Database]
     ↓               ↓                    ↓               ↓
 User uploads    Stores file        Processes file    Logs audit info
    files       automatically      when blob added   in BlobAudit table
```

### Function Behavior
- **Trigger**: Automatically runs when files are uploaded to `edibaivabuploads` container
- **Processing**: Reads file metadata and content
- **Database**: Creates `BlobAudit` table and logs each processed file
- **Logging**: Comprehensive logging for monitoring and debugging

### Database Schema
The function creates a `BlobAudit` table:
```sql
CREATE TABLE BlobAudit (
    Id INT IDENTITY PRIMARY KEY,
    BlobName NVARCHAR(500),
    BlobSize BIGINT,
    ProcessedAt DATETIME DEFAULT GETDATE(),
    ContentType NVARCHAR(100),
    Status NVARCHAR(50) DEFAULT 'Processed'
)
```

## 🧪 Testing Your Deployment

### 1. Upload a Test File
```bash
# Using Azure CLI
az storage blob upload \
    --file your-test-file.txt \
    --container-name edibaivabuploads \
    --name test-upload.txt \
    --connection-string "your-storage-connection-string"
```

### 2. Monitor Function Execution
```bash
# View real-time logs
az functionapp log tail \
    --name your-function-app-name \
    --resource-group your-resource-group-name
```

### 3. Check Database Records
Use Azure Data Studio, SSMS, or Azure portal to connect to your SQL database and verify records in the `BlobAudit` table.

## 🔍 Monitoring & Troubleshooting

### View Function Logs
```bash
# Real-time logs
az functionapp log tail --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP_NAME

# Download logs
az functionapp log download --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP_NAME
```

### Check Function Status
```bash
az functionapp show --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP_NAME --query state
```

### Common Issues

1. **Function not triggering**
   - Check if files are uploaded to the correct container (`edibaivabuploads`)
   - Verify function app is running: `az functionapp start`
   - Check function app logs for errors

2. **SQL Connection Issues**
   - Verify firewall rules allow Azure services
   - Check if connection string is correctly configured
   - Ensure SQL database is active (not paused)

3. **Deployment Failures**
   - Ensure resource names are unique globally
   - Check Azure subscription limits and quotas
   - Verify you have sufficient permissions

## 🔐 Security Considerations

**⚠️ Important**: This deployment is configured for demo purposes with basic security:

- SQL Server allows Azure services (firewall rule `0.0.0.0`)
- Basic SQL authentication (consider Azure AD integration for production)
- Storage account has private containers but allows Azure services

### For Production Environments:
1. Enable Azure AD authentication for SQL
2. Use managed identities instead of connection strings
3. Implement private endpoints
4. Enable storage account encryption
5. Set up proper monitoring and alerting
6. Configure backup and disaster recovery

## 🧹 Cleanup

To remove all created resources:
```bash
az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait
```

## 📝 Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID | `12345678-1234-1234-1234-123456789012` |
| `LOCATION` | Azure region | `eastus`, `westus2`, `centralus` |
| `RESOURCE_GROUP_NAME` | Resource group name | `rg-edi-processor-demo` |
| `STORAGE_ACCOUNT_NAME` | Globally unique storage name | `stedidemo123456` |
| `FUNCTION_APP_NAME` | Globally unique function app name | `func-edi-processor-demo-123456` |
| `SQL_SERVER_NAME` | Globally unique SQL server name | `sql-edi-demo-123456` |
| `SQL_DATABASE_NAME` | Database name | `EdiProcessorDB` |
| `SQL_ADMIN_USERNAME` | SQL admin username | `ediadmin` |
| `SQL_ADMIN_PASSWORD` | SQL admin password | `YourSecureP@ssw0rd123!` |

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Azure function logs
3. Verify all environment variables are correctly set
4. Ensure Azure CLI is properly authenticated

## 📄 License

This project is for demonstration purposes. Modify as needed for your specific requirements.