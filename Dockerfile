# ------------------- Stage 1: Build Stage ------------------------------
# Use a multi-stage build to reduce final image size. This stage compiles dependencies.
FROM python:3.14.2-alpine AS build

# Install build tools needed to compile Python packages with native extensions.
RUN apk add --no-cache gcc g++ musl-dev python3-dev libffi-dev openssl-dev cargo pkgconfig

# Copy the uv package manager tool from an official image.
COPY --from=ghcr.io/astral-sh/uv:0.9.14 /uv /uvx /bin/

# Set the working directory where we'll run commands and copy files.
WORKDIR /code

# Copy dependency specifications first (layer caching strategy).
# If dependencies haven't changed, Docker can reuse this layer and skip re-installing.
COPY uv.lock pyproject.toml ./
# Install all Python dependencies from the lock file.
RUN uv sync --locked --no-install-project --python /usr/local/bin/python3

# Copy the entire application code.
COPY . .
# Install the project itself along with dependencies.
RUN uv sync --locked --python /usr/local/bin/python3

# ------------------- Stage 2: Final Stage ------------------------------
# Reuse the build stage as runtime so the uv-managed virtualenv interpreter
# remains valid (avoids broken interpreter symlinks across image stages).
FROM build AS final

# Create a non-root user for security. Running as root is a security risk.
# This user will run the application instead of root.
RUN addgroup -S app && adduser -S app -G app

# The application and virtual environment already exist in this stage.
RUN chown -R app:app /code

WORKDIR /code
# Switch to the app user (non-root). All subsequent commands run as this user.
USER app

# Add the virtual environment's bin directory to PATH so Python packages are accessible.
ENV PATH="/code/.venv/bin:$PATH"

# Tell Docker that the application listens on port 8000.
# This documents which port is used, but doesn't publish it automatically.
EXPOSE 8000
 
# Set the default command to run when the container starts.
CMD ["/code/.venv/bin/python", "server.py"]