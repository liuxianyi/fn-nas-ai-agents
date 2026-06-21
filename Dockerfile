FROM docker.m.daocloud.io/library/node:20-bullseye-slim

# Change Debian sources to USTC mirror for China speedup
RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list

# Install system dependencies (Git, curl, bash, openssh-client, python3, pip, compilers)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    bash \
    ca-certificates \
    openssh-client \
    python3 \
    python3-pip \
    python3-dev \
    libcairo2-dev \
    pkg-config \
    make \
    g++ \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages for ppt-master skill
RUN pip3 install --no-cache-dir \
    python-pptx \
    edge-tts \
    svglib \
    reportlab \
    PyMuPDF \
    mammoth \
    markdownify \
    ebooklib \
    nbconvert \
    openpyxl \
    Pillow \
    numpy \
    requests \
    beautifulsoup4 \
    curl_cffi \
    google-genai \
    flask \
    -i https://pypi.tuna.tsinghua.edu.cn/simple

# Configure npm registry mirror for China speedup
RUN npm config set registry https://registry.npmmirror.com

# Install Botmux and OpenAI Codex CLI globally
RUN npm install -g botmux @openai/codex

# Install Antigravity CLI (agy)
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

# Create the gemini wrapper script to intercept the --yolo flag and support AGY_MODEL
RUN echo '#!/bin/bash\n\
args=()\n\
for arg in "$@"; do\n\
  if [ "$arg" = "--yolo" ]; then\n\
    args+=("--dangerously-skip-permissions")\n\
  else\n\
    args+=("$arg")\n\
  fi\n\
done\n\
if [ -n "$AGY_MODEL" ]; then\n\
  has_model=false\n\
  for a in "${args[@]}"; do\n\
    if [ "$a" = "--model" ]; then\n\
      has_model=true\n\
    fi\n\
  done\n\
  if [ "$has_model" = false ]; then\n\
    exec agy --model "$AGY_MODEL" "${args[@]}"\n\
  else\n\
    exec agy "${args[@]}"\n\
  fi\n\
else\n\
  exec agy "${args[@]}"\n\
fi' > /root/.local/bin/gemini && chmod +x /root/.local/bin/gemini

# Ensure agy is in the PATH for all sessions
ENV PATH="/root/.local/bin:${PATH}"

# Set default working directory
WORKDIR /app

# Expose Botmux webhook port
EXPOSE 3000

CMD ["botmux", "start"]
