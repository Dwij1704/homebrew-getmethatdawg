class Getmethatdawg < Formula
  desc "Zero-config deployment for Python AI agents and web services"
  homepage "https://github.com/Dwij1704/getmethatdawg"
  url "https://github.com/Dwij1704/getmethatdawg/releases/download/v0.1.0/getmethatdawg-source.tar.gz"
  sha256 "234b52193cbfc147b14f816c559f076440991776d1124293f0ca6d962795de62"
  license "MIT"

  depends_on "python@3.11"
  depends_on "docker"
  depends_on "flyctl"

  def install
    # Install Python dependencies
    system "python3.11", "-m", "pip", "install", "--target", "#{libexec}/lib/python", "-r", "getmethatdawg-sdk/requirements.txt"
    
    # Install getmethatdawg-sdk
    system "python3.11", "-m", "pip", "install", "--target", "#{libexec}/lib/python", "-e", "getmethatdawg-sdk/"
    
    # Create the main getmethatdawg executable
    (bin/"getmethatdawg").write <<~EOS
      #!/bin/bash
      
      # getmethatdawg - Zero-config deploy for Python agents
      # Homebrew installation version
      
      set -euo pipefail
      
      # Set up Python path to find getmethatdawg modules
      export PYTHONPATH="#{libexec}/lib/python:$PYTHONPATH"
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
      
      # Check dependencies
      check_dependencies() {
          local deps_ok=true
          
          if ! command -v docker &> /dev/null; then
              log_error "Docker is required but not installed. Please install Docker."
              deps_ok=false
          fi
          
          if ! command -v flyctl &> /dev/null; then
              log_error "flyctl is required but not installed. Please install flyctl."
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
           getmethatdawg deploy <python_file>              Deploy a Python file as a web service
           getmethatdawg deploy <python_file> --auto-detect  Deploy with auto-detection (no decorators needed)
           getmethatdawg --help                            Show this help message
           getmethatdawg --version                         Show version information
       
       Examples:
           getmethatdawg deploy my_agent.py                Deploy my_agent.py to the cloud
           getmethatdawg deploy story_agent.py --auto-detect   Auto-detect endpoints without decorators
          
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
           echo "getmethatdawg version #{version}"
           echo "Zero-config deploy for Python agents"
           echo "Installed via Homebrew"
       }
      
             # Deploy function - delegates to the main deployment script
       deploy_python_file() {
           local python_file="$1"
           local auto_detect_arg="${2:-}"
           
           # Use the deployment script from libexec
           exec "${GETMETHATDAWG_LIBEXEC}/getmethatdawg-deploy.sh" "$python_file" "$auto_detect_arg"
       }
      
      # Main function
      main() {
          case "${1:-}" in
              deploy)
                  if [[ -z "${2:-}" ]]; then
                      log_error "Please specify a Python file to deploy"
                      show_usage
                      exit 1
                  fi
                  check_dependencies
                  deploy_python_file "$2" "${3:-}"
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
    
    # Install the deployment script
    (libexec/"libexec").mkpath
    (libexec/"libexec"/"getmethatdawg-deploy.sh").write <<~EOS
      #!/bin/bash
      
      # getmethatdawg deployment script - Homebrew version
      # This script contains the main deployment logic
      
      set -euo pipefail
      
      source "#{bin}/getmethatdawg"  # Import logging functions
      
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
          
          log_info "Deploying $python_file..."
          
          # Create temporary directory for build output
          local temp_dir="$(mktemp -d)"
          local output_dir="$temp_dir/out"
          mkdir -p "$output_dir"
          
          # Cleanup function
          cleanup() {
              rm -rf "$temp_dir"
          }
          trap cleanup EXIT
          
          # Use the builder container to process the Python file
          log_info "Analyzing Python file..."
          
                     # Check if getmethatdawg/builder image exists, if not build it
           if ! docker image inspect getmethatdawg/builder:latest &> /dev/null; then
               log_warning "Builder image 'getmethatdawg/builder:latest' not found."
               log_info "Building getmethatdawg/builder image..."
               
               # Build the builder image from libexec
               docker build -t getmethatdawg/builder:latest -f - "#{libexec}" << 'EOF'
      FROM python:3.11-slim
      
             WORKDIR /opt/getmethatdawg
       
       # Copy the getmethatdawg-sdk
       COPY lib/python/getmethatdawg/ ./getmethatdawg-sdk/getmethatdawg/
       COPY lib/python/getmethatdawg_sdk-0.1.0.dist-info/ ./getmethatdawg-sdk/getmethatdawg_sdk.dist-info/
       
       # Install getmethatdawg-sdk dependencies
       RUN pip install flask gunicorn
       
       # Copy libexec
       COPY libexec/ ./libexec/
       
       # Set up the entry point - use Python to call the builder
       RUN echo '#!/usr/bin/env python3' > /opt/getmethatdawg/bin/getmethatdawg-builder
       RUN echo 'import sys' >> /opt/getmethatdawg/bin/getmethatdawg-builder
       RUN echo 'sys.path.insert(0, "/opt/getmethatdawg")' >> /opt/getmethatdawg/bin/getmethatdawg-builder
       RUN echo 'from getmethatdawg.builder import main' >> /opt/getmethatdawg/bin/getmethatdawg-builder
       RUN echo 'main()' >> /opt/getmethatdawg/bin/getmethatdawg-builder
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
          
          # Check for additional files in the same directory
          local source_dir="$(dirname "$abs_python_file")"
          local requirements_file="$source_dir/requirements.txt"
          local env_file="$source_dir/.env"
          local docker_volumes="-v $abs_python_file:/tmp/source.py:ro -v $output_dir:/tmp/out"
          
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
    
    # Make scripts executable
    chmod 0755, bin/"getmethatdawg"
    chmod 0755, libexec/"libexec"/"getmethatdawg-deploy.sh"
    
    # Install completions for bash and zsh
    bash_completion.install "scripts/completions/getmethatdawg.bash" => "getmethatdawg"
    zsh_completion.install "scripts/completions/_getmethatdawg"
  end

  def caveats
    <<~EOS
      getmethatdawg has been installed! 🚀
      
      To get started:
        1. Make sure Docker is running
        2. Install flyctl if you haven't: brew install flyctl
        3. Create a Python file with functions
        4. Deploy with: getmethatdawg deploy my_agent.py --auto-detect
      
      For examples and documentation:
        - GitHub: https://github.com/Dwij1704/getmethatdawg
        - Examples: #{libexec}/examples/
        - Docs: #{libexec}/docs/
      
      Note: First deployment will download and build the getmethatdawg/builder Docker image.
    EOS
  end

  test do
    # Test that the getmethatdawg command works
    assert_match "getmethatdawg version", shell_output("#{bin}/getmethatdawg --version")
    
    # Test that Python path is set up correctly
    system "python3.11", "-c", "import getmethatdawg; print('getmethatdawg SDK imported successfully')"
  end
end 