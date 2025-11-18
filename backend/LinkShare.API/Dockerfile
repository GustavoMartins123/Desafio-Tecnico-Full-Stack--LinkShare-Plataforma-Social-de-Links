# Stage 1: Base runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app

# Install CA certificates for HTTPS
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Stage 2: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies (cached layer)
COPY ["LinkShare.API.csproj", "."]
RUN dotnet restore "LinkShare.API.csproj"

# Copy source code and build
COPY . .
RUN dotnet build "LinkShare.API.csproj" \
    -c Release \
    -o /app/build

# Stage 3: Publish
FROM build AS publish
RUN dotnet publish "LinkShare.API.csproj" \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false

# Stage 4: Final runtime image
FROM base AS final
WORKDIR /app

# Create non-root user for security
RUN groupadd -r appgroup --gid=1001 && \
    useradd -r -g appgroup --uid=1001 --home-dir=/app --shell=/sbin/nologin appuser

# Create necessary directories with proper permissions
RUN mkdir -p /app/config /app/logs /app/keys /app/wwwroot/uploads && \
    chown -R appuser:appgroup /app && \
    chmod 750 /app/config /app/logs /app/keys && \
    chmod 770 /app/wwwroot/uploads

# Copy published application
COPY --from=publish --chown=appuser:appgroup /app/publish .

# Copy entrypoint script
COPY --chown=appuser:appgroup entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
