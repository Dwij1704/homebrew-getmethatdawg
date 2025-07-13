class Getmethatdawg < Formula
  desc "Zero-config deployment for Python AI agents and web services"
  homepage "https://github.com/Dwij1704/getmethatdawg"
  url "https://github.com/Dwij1704/getmethatdawg/archive/v0.0.4.tar.gz"
  sha256 "54e312598f17f87e2bc1e50531cb8f7c498b06ccf8c9adc7dc46c53d78b1011c"
  license "MIT"

  depends_on "python@3.11"
  depends_on "docker"
  # flyctl is now optional - only needed for regular mode

  def install
    # Install Python dependencies
    system "python3.11", "-m", "pip", "install", "--target", "#{libexec}/lib/python", "-r", "getmethatdawg-sdk/requirements.txt"
    
    # Install getmethatdawg-sdk
    system "python3.11", "-m", "pip", "install", "--target", "#{libexec}/lib/python", "-e", "getmethatdawg-sdk/"
    
    # Create the main getmethatdawg executable (unified version with both modes)
    (bin/"getmethatdawg").write <<~EOS
      #!/bin/bash
      
      # getmethatdawg - Zero-config deploy for Python agents
      # Supports both regular (flyctl) and pre-authenticated modes
      
      set -euo pipefail
      
      # Set up Python path to find getmethatdawg modules
      export PYTHONPATH="#{libexec}/lib/python:${PYTHONPATH:-}"
      export GETMETHATDAWG_HOME="#{libexec}"
      export GETMETHATDAWG_LIBEXEC="#{libexec}/libexec"
      
      # Colors for output
      RED='\\033[0;31m'
      GREEN='\\033[0;32m'
      YELLOW='\\033[1;33m'
      BLUE='\\033[0;34m'
      NC='\\033[0m' # No Color
      
      # Logging functions
      log_info() {
          echo -e "${BLUE}ℹ${NC} $1"
      }
      
      log_success() {
          echo -e "${GREEN}✓${NC} $1"
      }
      
      log_warning() {
          echo -e "${YELLOW}⚠${NC} $1"
      }
      
      log_error() {
          echo -e "${RED}✗${NC} $1"
      }
      
      # Check dependencies for regular mode
      check_dependencies_regular() {
          local deps_ok=true
          
          if ! command -v docker &> /dev/null; then
              log_error "Docker is required but not installed. Please install Docker."
              deps_ok=false
          fi
          
          if ! command -v flyctl &> /dev/null; then
              log_error "flyctl is required for regular mode but not installed."
              log_info "Install flyctl with: brew install flyctl"
              log_info "Or use pre-auth mode with: --pre-auth (no flyctl needed)"
              deps_ok=false
          fi
          
          if ! docker info &> /dev/null; then
              log_error "Docker is not running. Please start Docker."
              deps_ok=false
          fi
          
          if [[ "$deps_ok" == false ]]; then
              exit 1
          fi
      }
      
      # Check dependencies for pre-auth mode (Docker only)
      check_dependencies_preauth() {
          local deps_ok=true
          
          if ! command -v docker &> /dev/null; then
              log_error "Docker is required but not installed. Please install Docker."
              deps_ok=false
          fi
          
          if ! docker info &> /dev/null; then
              log_error "Docker is not running. Please start Docker."
              deps_ok=false
          fi
          
          if [[ "$deps_ok" == false ]]; then
              exit 1
          fi
      }
      
      # Show usage
      show_usage() {
          cat << EOF
      getmethatdawg - Zero-config deploy for Python agents
      
      Usage:
          getmethatdawg deploy <python_file>                       Deploy using flyctl (default)
          getmethatdawg deploy <python_file> --auto-detect         Deploy with auto-detection using flyctl
          getmethatdawg deploy <python_file> --pre-auth            Deploy using pre-authenticated container
          getmethatdawg deploy <python_file> --auto-detect --pre-auth  Auto-detect with pre-auth
          getmethatdawg --help                                     Show this help message
          getmethatdawg --version                                  Show version information
      
      Deployment Modes:
          Default Mode (requires flyctl):
              - Uses your local flyctl installation and authentication
              - Requires: Docker + flyctl + Fly.io account setup
              - Full control over deployments
      
          Pre-authenticated Mode (--pre-auth):
              - Uses pre-authenticated container with embedded credentials
              - Requires: Docker only (no flyctl or Fly.io setup needed)
              - Deployments go to the project maintainer's Fly.io account
      
      Examples:
          getmethatdawg deploy my_agent.py                         # Regular mode
          getmethatdawg deploy my_agent.py --pre-auth              # Pre-auth mode
          getmethatdawg deploy story_agent.py --auto-detect        # Regular with auto-detect
          getmethatdawg deploy story_agent.py --auto-detect --pre-auth  # Pre-auth with auto-detect
      
      Environment Variables:
          GETMETHATDAWG_MODE=pre-auth                              # Default to pre-auth mode
          
      The Python file can use the getmethatdawg SDK:
          import getmethatdawg
          
          @getmethatdawg.expose(method="GET", path="/hello")
          def greet(name: str = "world"):
              return {"msg": f"Hello {name}"}
      
      OR with auto-detection, just write regular Python functions:
          def greet(name: str = "world"):
              return {"msg": f"Hello {name}"}
      
      EOF
      }
      
      # Show version
      show_version() {
          echo "getmethatdawg version 0.0.4"
          echo "Zero-config deploy for Python agents"
          echo "Supports both regular and pre-authenticated modes"
          echo "Installed via Homebrew"
      }
      
      # Parse arguments and determine mode
      parse_args_and_deploy() {
          local python_file=""
          local auto_detect=""
          local pre_auth=""
          
          # Parse arguments
          for arg in "$@"; do
              case "$arg" in
                  --auto-detect)
                      auto_detect="--auto-detect"
                      ;;
                  --pre-auth)
                      pre_auth="yes"
                      ;;
                  -*)
                      log_error "Unknown option: $arg"
                      show_usage
                      exit 1
                      ;;
                  *)
                      if [[ -z "$python_file" ]]; then
                          python_file="$arg"
                      else
                          log_error "Multiple Python files specified: $python_file and $arg"
                          exit 1
                      fi
                      ;;
              esac
          done
          
          if [[ -z "$python_file" ]]; then
              log_error "Please specify a Python file to deploy"
              show_usage
              exit 1
          fi
          
          # Check environment variable for default mode
          if [[ -z "$pre_auth" && "${GETMETHATDAWG_MODE:-}" == "pre-auth" ]]; then
              pre_auth="yes"
              log_info "Using pre-auth mode (set by GETMETHATDAWG_MODE environment variable)"
          fi
          
          # Deploy based on mode
          if [[ "$pre_auth" == "yes" ]]; then
              check_dependencies_preauth
              "${GETMETHATDAWG_LIBEXEC}/getmethatdawg-deploy-preauth.sh" "$python_file" "$auto_detect"
          else
              check_dependencies_regular
              "${GETMETHATDAWG_LIBEXEC}/getmethatdawg-deploy.sh" "$python_file" "$auto_detect"
          fi
      }
      
      # Main function
      main() {
          case "${1:-}" in
              deploy)
                  shift
                  parse_args_and_deploy "$@"
                  ;;
              --help|-h)
                  show_usage
                  ;;
              --version|-v)
                  show_version
                  ;;
              "")
                  log_error "No command specified"
                  show_usage
                  exit 1
                  ;;
              *)
                  log_error "Unknown command: $1"
                  show_usage
                  exit 1
                  ;;
          esac
      }
      
      # Run main function with all arguments
      main "$@"
    EOS
    
    # Install libexec files
    libexec.install "libexec/getmethatdawg-cli.py"
    
    # Install the deployment scripts (both regular and pre-auth)
    (libexec/"libexec").mkpath
    
    # Regular deployment script (fixed with proper requirements.txt mounting)
    (libexec/"libexec"/"getmethatdawg-deploy.sh").write <<~EOS
      #!/bin/bash
      
      # getmethatdawg deployment script - Regular mode (flyctl)
      # This script contains the main deployment logic for regular mode
      
      set -euo pipefail
      
      # Import logging functions (extract them to avoid circular sourcing)
      
      # Colors for output
      RED='\\033[0;31m'
      GREEN='\\033[0;32m'
      YELLOW='\\033[1;33m'
      BLUE='\\033[0;34m'
      NC='\\033[0m' # No Color
      
      # Logging functions
      log_info() {
          echo -e "${BLUE}ℹ${NC} $1"
      }
      
      log_success() {
          echo -e "${GREEN}✓${NC} $1"
      }
      
      log_warning() {
          echo -e "${YELLOW}⚠${NC} $1"
      }
      
      log_error() {
          echo -e "${RED}✗${NC} $1"
      }
      
      deploy_python_file() {
          local python_file="$1"
          local auto_detect_arg="${2:-}"
          local abs_python_file="$(realpath "$python_file")"
          
          # Validate input file
          if [[ ! -f "$abs_python_file" ]]; then
              log_error "File '$python_file' not found"
              exit 1
          fi
          
          if [[ ! "$abs_python_file" =~ \\.py$ ]]; then
              log_error "File '$python_file' is not a Python file"
              exit 1
          fi
          
          log_info "Deploying $python_file (regular mode - using flyctl)..."
          
          # Create temporary directory for build output
          local temp_dir="$(mktemp -d)"
          local output_dir="$temp_dir/out"
          mkdir -p "$output_dir"
          
          # Cleanup function
          cleanup() {
              if [[ -n "${temp_dir:-}" ]] && [[ -d "${temp_dir:-}" ]]; then
                  rm -rf "$temp_dir"
              fi
          }
          trap cleanup EXIT
          
          # Use the builder container to process the Python file
          log_info "Analyzing Python file..."
          
          # Check if getmethatdawg/builder image exists, if not build it
          if ! docker image inspect getmethatdawg/builder:latest &> /dev/null; then
              log_warning "Builder image 'getmethatdawg/builder:latest' not found."
              log_info "Building getmethatdawg/builder image..."
              
              # Build the builder image using the installed SDK
              docker build -t getmethatdawg/builder:latest -f - "$GETMETHATDAWG_HOME" << 'EOF'
      FROM python:3.11-slim
      
      WORKDIR /opt/getmethatdawg
      
      # Copy Python dependencies
      COPY lib/python/ ./lib/python/
      
      # Set up Python path
      ENV PYTHONPATH="/opt/getmethatdawg/lib/python:${PYTHONPATH:-}"
      
      # Copy libexec
      COPY libexec/ ./libexec/
      
      # Create the builder entry point
      RUN echo '#!/bin/bash' > /opt/getmethatdawg/bin/getmethatdawg-builder
      RUN echo 'exec python -m getmethatdawg.builder "$@"' >> /opt/getmethatdawg/bin/getmethatdawg-builder
      RUN chmod +x /opt/getmethatdawg/bin/getmethatdawg-builder
      
      ENV PATH="/opt/getmethatdawg/bin:$PATH"
      
      ENTRYPOINT ["/opt/getmethatdawg/bin/getmethatdawg-builder"]
      EOF
          fi
          
          # Run the builder container
          log_info "Building deployment artifacts..."
          
          # Check if auto-detect flag is passed
          auto_detect_flag=""
          if [[ "$auto_detect_arg" == "--auto-detect" ]]; then
              auto_detect_flag="--auto-detect"
              log_info "Auto-detection mode enabled"
          fi
          
          # Check if there's a requirements.txt file in the same directory
          local source_dir="$(dirname "$abs_python_file")"
          local requirements_file="$source_dir/requirements.txt"
          local env_file="$source_dir/.env"
          local docker_volumes="-v $abs_python_file:/tmp/source.py:ro -v $output_dir:/tmp/out"
          
          # CRITICAL FIX: Mount requirements.txt to /tmp/requirements.txt in container
          if [[ -f "$requirements_file" ]]; then
              log_info "Found custom requirements.txt, including in deployment"
              docker_volumes="$docker_volumes -v $requirements_file:/tmp/requirements.txt:ro"
          fi
          
          if [[ -f "$env_file" ]]; then
              log_info "Found .env file, including for secrets management"
              docker_volumes="$docker_volumes -v $env_file:/tmp/.env:ro"
          fi
          
          docker run --rm \\
              $docker_volumes \\
              getmethatdawg/builder:latest /tmp/source.py "$(basename "$python_file" .py)" $auto_detect_flag
          
          # Check if build was successful
          if [[ ! -f "$output_dir/flask_app.py" ]]; then
              log_error "Build failed - no Flask app generated"
              exit 1
          fi
          
          log_success "Built container artifacts"
          
          # Deploy to Fly.io
          log_info "Deploying to Fly.io..."
          
          # Change to output directory for deployment
          cd "$output_dir"
          
          # Check if fly app exists, if not create it
          local app_name="$(basename "$python_file" .py | tr '_' '-')"
          
          if ! flyctl apps list | grep -q "$app_name"; then
              log_info "Creating new Fly.io app: $app_name"
              flyctl apps create "$app_name" --generate-name
          fi
          
          # Deploy the app (check for secrets script first)
          if [[ -f "deploy-with-secrets.sh" ]]; then
              log_info "Deploying with secrets management..."
              chmod +x deploy-with-secrets.sh
              ./deploy-with-secrets.sh
          else
              log_info "Deploying without secrets..."
              flyctl deploy --remote-only --config fly.toml --dockerfile Dockerfile
          fi
          
          # Get the app URL
          local app_url="$(flyctl apps list | grep "$app_name" | awk '{print $2}' | head -1)"
          if [[ -z "$app_url" ]]; then
              app_url="$app_name.fly.dev"
          fi
          
          log_success "Pushed to Fly.io"
          echo -e "${GREEN}🌐 https://$app_url${NC}"
          
          # Show endpoints
          log_info "Available endpoints:"
          echo "  GET  https://$app_url/ (health check)"
          
          # Parse endpoints from generated flask app (basic parsing)
          if [[ -f "$output_dir/flask_app.py" ]]; then
              grep -E "@app\\.route\\(" "$output_dir/flask_app.py" | while read -r line; do
                  if [[ "$line" =~ @app\\.route\\(\\'([^\\']+)\\',.*methods=\\[\\'([^\\']+)\\' ]]; then
                      local path="${BASH_REMATCH[1]}"
                      local method="${BASH_REMATCH[2]}"
                      echo -e "  ${method}  https://$app_url$path"
                  fi
              done
          fi
      }
      
      # Execute the deployment
      deploy_python_file "$@"
    EOS
    
    # Pre-auth deployment script (also fixed with proper requirements.txt mounting)
    (libexec/"libexec"/"getmethatdawg-deploy-preauth.sh").write <<~EOS
      #!/bin/bash
      
      # getmethatdawg deployment script - Pre-auth mode (no flyctl needed)
      # This script uses pre-authenticated containers for deployment
      
      set -euo pipefail
      
      # Colors for output
      RED='\\033[0;31m'
      GREEN='\\033[0;32m'
      YELLOW='\\033[1;33m'
      BLUE='\\033[0;34m'
      NC='\\033[0m' # No Color
      
      # Logging functions
      log_info() {
          echo -e "${BLUE}ℹ${NC} $1"
      }
      
      log_success() {
          echo -e "${GREEN}✓${NC} $1"
      }
      
      log_warning() {
          echo -e "${YELLOW}⚠${NC} $1"
      }
      
      log_error() {
          echo -e "${RED}✗${NC} $1"
      }
      
      deploy_python_file() {
          local python_file="$1"
          local auto_detect_arg="${2:-}"
          local abs_python_file="$(realpath "$python_file")"
          
          # Validate input file
          if [[ ! -f "$abs_python_file" ]]; then
              log_error "File '$python_file' not found"
              exit 1
          fi
          
          if [[ ! "$abs_python_file" =~ \\.py$ ]]; then
              log_error "File '$python_file' is not a Python file"
              exit 1
          fi
          
          log_info "Deploying $python_file (pre-authenticated mode - no flyctl needed)..."
          
          # Create temporary directory for build output
          local temp_dir="$(mktemp -d)"
          local output_dir="$temp_dir/out"
          mkdir -p "$output_dir"
          
          # Cleanup function
          cleanup() {
              if [[ -n "${temp_dir:-}" ]] && [[ -d "${temp_dir:-}" ]]; then
                  rm -rf "$temp_dir"
              fi
          }
          trap cleanup EXIT
          
          # Use the builder container to process the Python file
          log_info "Analyzing Python file..."
          
          # Check if getmethatdawg/builder image exists, if not build it
          if ! docker image inspect getmethatdawg/builder:latest &> /dev/null; then
              log_warning "Builder image 'getmethatdawg/builder:latest' not found."
              log_info "Building getmethatdawg/builder image..."
              
              # Build the builder image using the installed SDK
              docker build -t getmethatdawg/builder:latest -f - "$GETMETHATDAWG_HOME" << 'EOF'
      FROM python:3.11-slim
      
      WORKDIR /opt/getmethatdawg
      
      # Copy Python dependencies
      COPY lib/python/ ./lib/python/
      
      # Set up Python path
      ENV PYTHONPATH="/opt/getmethatdawg/lib/python:${PYTHONPATH:-}"
      
      # Copy libexec
      COPY libexec/ ./libexec/
      
      # Create the builder entry point
      RUN echo '#!/bin/bash' > /opt/getmethatdawg/bin/getmethatdawg-builder
      RUN echo 'exec python -m getmethatdawg.builder "$@"' >> /opt/getmethatdawg/bin/getmethatdawg-builder
      RUN chmod +x /opt/getmethatdawg/bin/getmethatdawg-builder
      
      ENV PATH="/opt/getmethatdawg/bin:$PATH"
      
      ENTRYPOINT ["/opt/getmethatdawg/bin/getmethatdawg-builder"]
      EOF
          fi
          
          # Run the builder container
          log_info "Building deployment artifacts..."
          
          # Check if auto-detect flag is passed
          auto_detect_flag=""
          if [[ "$auto_detect_arg" == "--auto-detect" ]]; then
              auto_detect_flag="--auto-detect"
              log_info "Auto-detection mode enabled"
          fi
          
          # Check if there's a requirements.txt file in the same directory
          local source_dir="$(dirname "$abs_python_file")"
          local requirements_file="$source_dir/requirements.txt"
          local env_file="$source_dir/.env"
          local docker_volumes="-v $abs_python_file:/tmp/source.py:ro -v $output_dir:/tmp/out"
          
          # CRITICAL FIX: Mount requirements.txt to /tmp/requirements.txt in container
          if [[ -f "$requirements_file" ]]; then
              log_info "Found custom requirements.txt, including in deployment"
              docker_volumes="$docker_volumes -v $requirements_file:/tmp/requirements.txt:ro"
          fi
          
          if [[ -f "$env_file" ]]; then
              log_info "Found .env file, including for secrets management"
              docker_volumes="$docker_volumes -v $env_file:/tmp/.env:ro"
          fi
          
          docker run --rm \\
              $docker_volumes \\
              getmethatdawg/builder:latest /tmp/source.py "$(basename "$python_file" .py)" $auto_detect_flag
          
          # Check if build was successful
          if [[ ! -f "$output_dir/flask_app.py" ]]; then
              log_error "Build failed - no Flask app generated"
              exit 1
          fi
          
          log_success "Built container artifacts"
          
          # Deploy using pre-authenticated container
          log_info "Deploying using pre-authenticated container..."
          
          # Change to output directory for deployment
          cd "$output_dir"
          
          # Use pre-authenticated container for deployment
          log_info "Using pre-authenticated deployment container..."
          
          # Create a deployment script that will run inside the container
          local deploy_script="$output_dir/deploy-script.sh"
          cat > "$deploy_script" << 'DEPLOY_EOF'
      #!/bin/bash
      set -euo pipefail
      
      echo "🔧 Building deployment artifacts..."
      getmethatdawg-builder /tmp/source.py "$1" $2
      
      echo "📁 Changing to build output directory..."
      cd /tmp/out
      
      echo "🚀 Starting deployment to Fly.io..."
      
      # Get app name from the parameter
      APP_NAME="$1"
      
      # Check if fly app exists, if not create it
      if ! flyctl apps list | grep -q "$APP_NAME"; then
          echo "📱 Creating new Fly.io app: $APP_NAME"
          flyctl apps create "$APP_NAME" --generate-name || true
      fi
      
      # Deploy the app (check for secrets script first)
      if [[ -f "deploy-with-secrets.sh" ]]; then
          echo "🔐 Deploying with secrets management..."
          chmod +x deploy-with-secrets.sh
          ./deploy-with-secrets.sh
      else
          echo "🚀 Deploying without secrets..."
          flyctl deploy --remote-only --config fly.toml --dockerfile Dockerfile
      fi
      
      echo "✅ Deployment completed successfully!"
      
      # Get the app URL
      APP_URL=$(flyctl status --app "$APP_NAME" | grep "Hostname" | awk '{print $2}' | head -1 || echo "$APP_NAME.fly.dev")
      echo "🌐 App URL: https://$APP_URL"
      
      # Show endpoints
      echo "📡 Available endpoints:"
      echo "  GET  https://$APP_URL/ (health check)"
      
      # Parse endpoints from generated flask app (basic parsing)
      if [[ -f "/tmp/out/flask_app.py" ]]; then
          grep -E "@app\\.route\\(" "/tmp/out/flask_app.py" | while read -r line; do
              if [[ "$line" =~ @app\\.route\\(\\'([^\\']+)\\',.*methods=\\[\\'([^\\']+)\\' ]]; then
                  path="${BASH_REMATCH[1]}"
                  method="${BASH_REMATCH[2]}"
                  echo "  ${method}  https://$APP_URL$path"
              fi
          done
      fi
      DEPLOY_EOF
          chmod +x "$deploy_script"
          
          # Run the container with the deployment script, streaming output in real-time
          docker run --rm \\
              $docker_volumes \\
              -v "$deploy_script:/tmp/deploy.sh:ro" \\
              dwijptl/getmethatdawg-authenticated-builder:latest \\
              /tmp/deploy.sh "$(basename "$python_file" .py | tr '_' '-')" "$auto_detect_flag"
          
          log_success "Deployed using pre-authenticated container"
          
          # The pre-authenticated container will output the deployment URL
          log_info "Deployment completed! Check the output above for the app URL."
      }
      
      # Execute the deployment
      deploy_python_file "$@"
    EOS

    # Make scripts executable
    chmod_R "+x", libexec/"libexec"
  end

  test do
    # Test that the executable works
    system "#{bin}/getmethatdawg", "--version"
  end

  def caveats
    <<~EOS
      getmethatdawg has been installed!
      
      To get started:
        1. Make sure Docker is running
        2. For regular mode: Install flyctl and authenticate with Fly.io
        3. For pre-auth mode: No additional setup needed
      
      Usage:
        getmethatdawg deploy my_agent.py              # Regular mode (requires flyctl)
        getmethatdawg deploy my_agent.py --pre-auth   # Pre-auth mode (no flyctl needed)
      
      Examples:
        getmethatdawg deploy examples/crewai_examples/ai_contentgen_crew.py
        getmethatdawg deploy my_agent.py --auto-detect
      
      The tool will automatically detect and use requirements.txt files in the same directory as your Python file.
      
      For more information, run:
        getmethatdawg --help
    EOS
  end
end 