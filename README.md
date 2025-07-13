# Homebrew Tap for getmethatdawg

This is the official Homebrew tap for [getmethatdawg](https://github.com/Dwij1704/getmethatdawg) - Zero-config deployment for Python AI agents and web services.

## Installation

```bash
# Add the tap
brew tap Dwij1704/getmethatdawg

# Install getmethatdawg
brew install getmethatdawg
```

Or in one command:
```bash
brew install Dwij1704/getmethatdawg/getmethatdawg
```

## Usage

After installation, you can deploy Python AI agents with zero configuration:

```bash
# Deploy with auto-detection
getmethatdawg deploy my_agent.py --auto-detect

# Check version
getmethatdawg --version

# Get help
getmethatdawg --help
```

## Features

- 🔍 **Auto-detection**: Automatically converts Python functions to API endpoints
- 🌐 **One-command deployment**: Deploy to production with a single command
- 🤖 **CrewAI support**: Full support for multi-agent AI systems
- 🔐 **Environment management**: Automatic handling of secrets and environment variables
- 📦 **Zero configuration**: No decorators or configuration files needed

## Examples

Deploy a simple AI agent:
```python
# simple_agent.py
def get_greeting(name="World"):
    return f"Hello, {name}!"

def process_data(data, format="json"):
    return {"processed": data, "format": format}
```

```bash
getmethatdawg deploy simple_agent.py --auto-detect
# Creates endpoints: /get-greeting and /process-data
```

Deploy a CrewAI multi-agent system:
```bash
getmethatdawg deploy ai_contentgen_crew.py --auto-detect
# Auto-detects and deploys all crew functions
```

## Links

- 📦 [Main Repository](https://github.com/Dwij1704/getmethatdawg)
- 📚 [Documentation](https://github.com/Dwij1704/getmethatdawg#readme)
- 🐛 [Issues](https://github.com/Dwij1704/getmethatdawg/issues)

## License

MIT License - see the [LICENSE](https://github.com/Dwij1704/getmethatdawg/blob/main/LICENSE) file for details.
