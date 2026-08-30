FROM node:22-bookworm-slim

# --- base tools opencode / its bash tool will want ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        git \
        bash \
        ripgrep \
    && rm -rf /var/lib/apt/lists/*

# --- non-root user; this is who actually runs the agent ---
RUN useradd -m -s /bin/bash agent
USER agent
ENV HOME=/home/agent
WORKDIR /home/agent

# --- install opencode as the agent user (lands under $HOME) ---
RUN curl -fsSL https://opencode.ai/install | bash
ENV PATH="/home/agent/.opencode/bin:${PATH}"

# fail the build early if the install didn't work / path is wrong
RUN opencode --version

# this is the only folder the agent should ever operate on
WORKDIR /workspace

ENTRYPOINT ["opencode"]
