#!/usr/bin/env bash

# Initialize the status variable
all_okay=true

# Define a map with different urls of how to install make
declare -A make_os_urls
make_os_urls["Linux"]=""
make_os_urls["Unknown"]=""
make_os_urls["macOS"]="https://stackoverflow.com/questions/10265742/how-to-install-make-and-gcc-on-a-mac"
make_os_urls["Windows"]="https://stackoverflow.com/questions/32127524/how-to-install-and-use-make-in-windows"

# Function to check if a command exists and store the result
check_tool() {
  local tool_name=$1
  local install_message=$2
  local tool_url=$3
  local result="✅ $tool_name is installed."

  if ! command -v "$tool_name" >/dev/null 2>&1; then
    result="⚠️ $tool_name is not installed. $install_message"
    if [ -n "$tool_url" ]; then
      result="$result For more info, visit: $tool_url"
    fi
    all_okay=false
  fi

  echo "$result"
}

# Try to detect os
detect_os() {
  case "$(uname -s)" in
    Linux*)         os="Linux" ;;
    Darwin*)        os="macOS" ;;
    CYGWIN*|MINGW*) os="Windows" ;;
    *)              os="Unknown" ;;
  esac

  echo "$os"
}

os=$(detect_os)

# Check if the OS is unknown
if [ "$os" == "Unknown" ]; then
  echo "⚠️ Your OS may not be supported. Please raise an issue at https://github.com/Mirantis/k0rdent-demos"
  echo ""
fi

# Check Docker, Make, and Git with optional URLs for installation guides
check_tool "docker" "Please install Docker." "https://docs.docker.com/get-docker/"
check_tool "make" "Please install Make." "${make_os_urls[$os]}" 
check_tool "git" "Please install Git." "https://git-scm.com/book/en/v2/Getting-Started-Installing-Git"

# Print final status
if $all_okay; then
  echo "✅ All required tools are installed."
else
  echo "⚠️ One or more required tools are missing."
fi

