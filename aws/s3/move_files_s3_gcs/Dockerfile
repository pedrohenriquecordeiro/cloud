# Use a lightweight Debian-based image
FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    jq \
    python3 \
    python3-pip \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl -O "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    && unzip awscli-exe-linux-x86_64.zip \
    && ./aws/install \
    && rm -rf awscli-exe-linux-x86_64.zip aws

# Install Google Cloud SDK
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-515.0.0-linux-x86_64.tar.gz \
    && tar -xf google-cloud-cli-515.0.0-linux-x86_64.tar.gz \
    && ./google-cloud-sdk/install.sh \
    && rm -rf google-cloud-cli-515.0.0-linux-x86_64.tar.gz

# Set environment variables for CLI tools
ENV PATH="/google-cloud-sdk/bin:/usr/local/bin:$PATH"

# Set working directory
WORKDIR /app

# Copy necessary files
COPY .env /app/.env
COPY main.sh /app/main.sh
COPY entrypoint.sh /app/entrypoint.sh
COPY sa-data-stack-v3.json /app/.secrets/sa-data-stack-v3.json

RUN gcloud auth activate-service-account --key-file="/app/.secrets/sa-data-stack-v3.json" --project="dw-corp-dev"

# Set permissions for scripts
RUN chmod +x /app/entrypoint.sh /app/main.sh

# Define entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]

# Default command
CMD ["/app/main.sh"]
