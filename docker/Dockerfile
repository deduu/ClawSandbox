FROM node:22-slim

# Security: run as non-root user
RUN groupadd -r openclaw && useradd -r -g openclaw -m -s /bin/bash openclaw

# Install minimal dependencies for security testing
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    procps \
    net-tools \
    strace \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Create workspace and analysis directories
RUN mkdir -p /home/openclaw/.openclaw /home/openclaw/workspace /home/openclaw/tests \
    && chown -R openclaw:openclaw /home/openclaw

# Copy test scripts into the container
COPY --chown=openclaw:openclaw tests/ /home/openclaw/tests/

# Drop to non-root user
USER openclaw
WORKDIR /home/openclaw

CMD ["bash"]
