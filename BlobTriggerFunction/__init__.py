import logging
import azure.functions as func
import os
import pyodbc
from datetime import datetime

def main(inputBlob: func.InputStream):
    logging.info("=== BlobTriggerFunction STARTED ===")
    logging.info("Blob name: %s, size=%d bytes", inputBlob.name, inputBlob.length)
    
    # Read blob content for potential processing
    blob_content = inputBlob.read()
    logging.info("Read blob content: %d bytes", len(blob_content))

    try:
        # Get SQL connection string from App Settings
        conn_str = os.environ.get("SQLConnectionString")
        if not conn_str:
            raise ValueError("SQLConnectionString environment variable not found")
        
        logging.info("Connecting to SQL database...")

        # Connect with retry logic
        cn = pyodbc.connect(conn_str, timeout=30)
        cur = cn.cursor()
        logging.info("Connected to SQL successfully.")

        # Create BlobAudit table if it doesn't exist
        create_table_sql = """
        IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='BlobAudit' AND xtype='U')
        CREATE TABLE BlobAudit (
            Id INT IDENTITY PRIMARY KEY,
            BlobName NVARCHAR(500),
            BlobSize BIGINT,
            ProcessedAt DATETIME DEFAULT GETDATE(),
            ContentType NVARCHAR(100),
            Status NVARCHAR(50) DEFAULT 'Processed'
        )
        """
        cur.execute(create_table_sql)
        cn.commit()
        logging.info("BlobAudit table ready")

        # Extract file extension and content type
        file_extension = os.path.splitext(inputBlob.name)[1].lower()
        content_type = 'text/plain'  # Default
        if file_extension == '.txt':
            content_type = 'text/plain'
        elif file_extension == '.edi':
            content_type = 'application/edi'
        elif file_extension == '.xml':
            content_type = 'application/xml'
        elif file_extension == '.json':
            content_type = 'application/json'

        # Insert audit record with more details
        insert_sql = """
        INSERT INTO BlobAudit (BlobName, BlobSize, ContentType, Status) 
        VALUES (?, ?, ?, ?)
        """
        cur.execute(insert_sql, (inputBlob.name, inputBlob.length, content_type, 'Processed'))
        cn.commit()
        logging.info("Inserted audit record for blob: %s", inputBlob.name)

        # Get total processed files count
        cur.execute("SELECT COUNT(*) FROM BlobAudit")
        total_count = cur.fetchone()[0]
        logging.info("Total files processed so far: %d", total_count)

        # Close connections
        cur.close()
        cn.close()
        
        logging.info("=== BlobTriggerFunction COMPLETED SUCCESSFULLY ===")

    except pyodbc.Error as db_error:
        logging.error("Database error occurred: %s", str(db_error))
        logging.error("SQL State: %s", getattr(db_error, 'args', ['Unknown'])[0] if hasattr(db_error, 'args') else 'Unknown')
        raise
    except Exception as e:
        logging.error("Unexpected error in BlobTriggerFunction: %s", str(e))
        logging.error("Error type: %s", type(e).__name__)
        raise
    finally:
        # Ensure connections are closed
        try:
            if 'cur' in locals() and cur:
                cur.close()
            if 'cn' in locals() and cn:
                cn.close()
        except:
            pass
