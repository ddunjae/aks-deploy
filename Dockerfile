# Multi-stage build for React + Node.js application
# Stage 1: Build React frontend
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend

# Copy frontend package files
COPY frontend/package*.json ./

# Install dependencies
RUN npm install

# Copy frontend source
COPY frontend/ ./

# Build React app
RUN npm run build

# Stage 2: Production Node.js server
FROM node:20-alpine

# Security: Run as non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

WORKDIR /app

# Copy backend package files
COPY backend/package*.json ./

# Install production dependencies only
RUN npm install --omit=dev

# Copy backend source
COPY --chown=appuser:appgroup backend/server.js ./

# Copy built React app to public folder
COPY --from=frontend-builder --chown=appuser:appgroup /app/frontend/build ./public

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8080

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Start the server
CMD ["node", "server.js"]
