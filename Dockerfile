FROM docker.io/cloudflare/sandbox:0.7.0

# Install Node.js 22 (required by clawdbot) and rsync (for R2 backup sync)
# The base image has Node 20, we need to replace it with Node 22
# Using direct binary download for reliability
ENV NODE_VERSION=22.13.1
RUN apt-get update && apt-get install -y xz-utils ca-certificates rsync build-essential procps curl file git sudo \
    && curl -fsSLk https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && node --version \
    && npm --version

# Create brew user for running the gateway (Homebrew requires non-root)
# This user will own all moltbot files and run the gateway process
RUN useradd -m -s /bin/bash brew \
    && echo 'brew ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Install Homebrew as the brew user
USER brew
WORKDIR /home/brew
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add brew to PATH for the brew user
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
RUN echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/brew/.bashrc

# Switch back to root for system installations
USER root

# Install pnpm globally
RUN npm install -g pnpm

# Install moltbot (CLI is still named clawdbot until upstream renames)
# Pin to specific version for reproducible builds
RUN npm install -g clawdbot@2026.1.24-3 \
    && clawdbot --version

# Create moltbot directories in brew user's home instead of root
# Templates are stored in a separate location for initialization
RUN mkdir -p /home/brew/.clawdbot \
    && mkdir -p /home/brew/.clawdbot-templates \
    && mkdir -p /home/brew/clawd \
    && mkdir -p /home/brew/clawd/skills \
    && mkdir -p /data/moltbot \
    && chown -R brew:brew /home/brew/.clawdbot \
    && chown -R brew:brew /home/brew/.clawdbot-templates \
    && chown -R brew:brew /home/brew/clawd \
    && chown -R brew:brew /data/moltbot

# Copy startup script
# Build cache bust: 2026-02-01-brew-user
COPY start-moltbot.sh /usr/local/bin/start-moltbot.sh
RUN chmod +x /usr/local/bin/start-moltbot.sh

# Copy default configuration template
COPY moltbot.json.template /home/brew/.clawdbot-templates/moltbot.json.template
RUN chown brew:brew /home/brew/.clawdbot-templates/moltbot.json.template

# Copy custom skills
COPY skills/ /home/brew/clawd/skills/
RUN chown -R brew:brew /home/brew/clawd/skills/

# Set working directory
WORKDIR /home/brew/clawd

# Run as brew user for Homebrew compatibility
USER brew

# Expose the gateway port
EXPOSE 18789
