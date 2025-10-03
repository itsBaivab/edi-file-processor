# 🚀 Azure EDI Processor - Quick Reference

## 📋 Setup Checklist
- [ ] Azure CLI installed (`az --version`)
- [ ] Logged into Azure (`az login`)
- [ ] Created `.env` file from template
- [ ] Set unique resource names in `.env`
- [ ] Set strong SQL password

## 🎯 Deployment Commands

```bash
# 1. Setup environment
cp .env.template .env
nano .env  # Configure your values

# 2. Deploy everything
./deploy-azure.sh

# 3. Test the deployment
./test-deployment.sh

# 4. Monitor status
./monitor-azure.sh
```

## 🔍 Monitoring & Debugging

```bash
# Real-time function logs
az functionapp log tail --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP_NAME

# Function app status
az functionapp show --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP_NAME --query state

# List all resources
az resource list --resource-group $RESOURCE_GROUP_NAME --output table

# Upload test file
az storage blob upload --file myfile.txt --container-name edibaivabuploads --name myfile.txt --connection-string "$STORAGE_CONNECTION_STRING"
```

## 🗄️ Database Queries

```sql
-- View all processed files
SELECT * FROM BlobAudit ORDER BY ProcessedAt DESC;

-- Count processed files by type
SELECT ContentType, COUNT(*) as FileCount 
FROM BlobAudit 
GROUP BY ContentType;

-- Recent activity (last 24 hours)
SELECT * FROM BlobAudit 
WHERE ProcessedAt >= DATEADD(day, -1, GETDATE()) 
ORDER BY ProcessedAt DESC;
```

## 🧹 Cleanup

```bash
# Remove everything
az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait
```

## 🔗 Important URLs

- **Azure Portal**: https://portal.azure.com
- **Function App**: https://[your-function-name].azurewebsites.net
- **Storage**: https://[your-storage-name].blob.core.windows.net
- **SQL Server**: [your-sql-server].database.windows.net

## 🚨 Troubleshooting

| Issue | Solution |
|-------|----------|
| Function not triggering | Check blob container name (`edibaivabuploads`) |
| SQL connection fails | Verify firewall rules and connection string |
| Resource name conflicts | Use unique names with timestamps |
| Permission errors | Ensure Contributor access to subscription |
| Function deployment fails | Check function app logs and retry |

## 📱 Environment Variables Quick Reference

| Variable | Example | Notes |
|----------|---------|-------|
| `STORAGE_ACCOUNT_NAME` | `stedidemo123456` | Must be globally unique |
| `FUNCTION_APP_NAME` | `func-edi-demo-123456` | Must be globally unique |
| `SQL_SERVER_NAME` | `sql-edi-demo-123456` | Must be globally unique |
| `SQL_ADMIN_PASSWORD` | `SecureP@ss123!` | 8+ chars, mixed case, numbers, symbols |