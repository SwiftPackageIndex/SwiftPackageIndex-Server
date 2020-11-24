# Download today's backup from the production database.
# This is the recommended way to grab the database, if you have SSH access.
scp spi@208.52.185.253:~/Desktop/DB-Backups/spi_prod_$(date +%Y-%m-%d).dump .
