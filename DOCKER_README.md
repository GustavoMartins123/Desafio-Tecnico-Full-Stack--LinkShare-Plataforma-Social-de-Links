# LinkShare - Docker Setup

## 🐳 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+

### 1. Configure Environment Variables

Copy the example environment file and customize it:

```bash
cp .env.example .env
```

Edit `.env` and update the values (especially `JWT_SECRET_KEY` and `POSTGRES_PASSWORD`).

### 2. Start the Application

Build and start all services:

```bash
docker-compose up -d
```

This will start:
- **PostgreSQL** (port 5432)
- **LinkShare API** (port 8080)

### 3. Check Status

View running containers:

```bash
docker-compose ps
```

View logs:

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
docker-compose logs -f db
```

### 4. Access the Application

- **API**: http://localhost:8080
- **Swagger UI**: http://localhost:8080/swagger
- **Health Check**: http://localhost:8080/health

---

## 📋 Common Commands

### Start Services

```bash
# Start in foreground (with logs)
docker-compose up

# Start in background
docker-compose up -d

# Rebuild and start
docker-compose up --build
```

### Stop Services

```bash
# Stop containers (preserves data)
docker-compose stop

# Stop and remove containers (preserves volumes)
docker-compose down

# Stop, remove containers AND volumes (⚠️ deletes all data)
docker-compose down -v
```

### View Logs

```bash
# All services
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100

# Specific service
docker-compose logs -f api
```

### Execute Commands in Containers

```bash
# Open shell in API container
docker-compose exec api bash

# Open PostgreSQL CLI
docker-compose exec db psql -U postgres -d linkshare

# Run migrations manually (if needed)
docker-compose exec api dotnet ef database update
```

### Rebuild Images

```bash
# Rebuild API image
docker-compose build api

# Rebuild without cache
docker-compose build --no-cache api
```

---

## 🗄️ Data Persistence

Data is persisted using Docker named volumes:

- **postgres_data**: Database files
- **api_uploads**: User uploaded files
- **api_logs**: Application logs

### Backup Database

```bash
# Create backup
docker-compose exec db pg_dump -U postgres linkshare > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore backup
docker-compose exec -T db psql -U postgres linkshare < backup_20240101_120000.sql
```

### View Volumes

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect linkshare_postgres_data
```

---

## 🔧 Troubleshooting

### Container Won't Start

1. Check logs:
   ```bash
   docker-compose logs api
   docker-compose logs db
   ```

2. Verify ports are not in use:
   ```bash
   # Check if port 8080 is free
   lsof -i :8080

   # Check if port 5432 is free
   lsof -i :5432
   ```

3. Rebuild image:
   ```bash
   docker-compose build --no-cache api
   docker-compose up -d
   ```

### Database Connection Errors

1. Ensure database is healthy:
   ```bash
   docker-compose ps
   ```

   Look for `healthy` status on `db` service.

2. Check connection from API:
   ```bash
   docker-compose exec api ping db
   ```

3. Restart services:
   ```bash
   docker-compose restart
   ```

### Reset Everything

⚠️ **WARNING**: This will delete all data!

```bash
# Stop and remove everything
docker-compose down -v

# Remove images
docker rmi linkshare-api

# Start fresh
docker-compose up --build
```

---

## 🔐 Security Best Practices

### In Production

1. **Change Default Credentials**:
   - Update `POSTGRES_PASSWORD` in `.env`
   - Generate a strong `JWT_SECRET_KEY` (min 32 characters)

2. **Use Secrets Management**:
   - Consider Docker Secrets or external secret management
   - Never commit `.env` to version control

3. **Enable HTTPS**:
   - Add reverse proxy (Nginx/Traefik)
   - Use Let's Encrypt for SSL certificates

4. **Limit Exposure**:
   - Don't expose PostgreSQL port publicly
   - Use firewall rules

5. **Regular Updates**:
   ```bash
   # Update base images
   docker-compose pull
   docker-compose up -d
   ```

---

## 📊 Monitoring

### Health Checks

Both services have health checks configured:

```bash
# Check health status
docker-compose ps

# API health endpoint
curl http://localhost:8080/health
```

### Resource Usage

```bash
# View resource consumption
docker stats

# Specific containers
docker stats linkshare-api linkshare-db
```

---

## 🌐 Production Deployment

### Recommended Setup

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  db:
    # ... same as development
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G

  api:
    # ... same as development
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1'
          memory: 512M
```

### Deploy

```bash
# Production deployment
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 📝 Notes

- Database migrations run automatically on API startup
- API waits for database to be healthy before starting
- Data persists across container restarts
- Containers run as non-root user for security
- Automatic restart on failure (unless-stopped)

---

## 🆘 Support

For issues:
1. Check logs: `docker-compose logs -f`
2. Verify health: `docker-compose ps`
3. Review configuration in `docker-compose.yml`
4. Consult documentation: `docs/modulo3.md`

---

**Happy containerizing! 🐳**
