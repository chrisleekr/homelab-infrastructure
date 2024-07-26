#!/bin/bash

# Fail on any error.
set -Eeuo pipefail

PYTHON_VERSION=3.12

# This script is used to setup the repository for the first time.

if [ ! -f .env ]; then
  echo "Error: .env file does not exist. Please create a .env file based on .env.example file."
  exit 1
else
  echo ".env file exists."
fi

# Setup pyenv for pre-commit
if ! command -v pyenv &>/dev/null; then
  echo "pyenv is not installed. Installing pyenv..."
  brew install pyenv

else
  echo "pyenv is already installed."
fi

# Setting up pyenv in fish shell
if ! grep -q "PYENV_ROOT" ~/.config/fish/config.fish; then
  echo "Setting up pyenv in fish shell..."
  # shellcheck disable=SC2016
  {
    echo 'set -Ux PYENV_ROOT $HOME/.pyenv'
    echo 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths'
    echo 'pyenv init - | source'
  } >>~/.config/fish/config.fish

  echo "Added following lines to ~/.config/fish/config.fish:"
  # shellcheck disable=SC2016
  echo 'set -Ux PYENV_ROOT $HOME/.pyenv'
  # shellcheck disable=SC2016
  echo 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths'
  echo 'pyenv init - | source'

  echo "Please restart the terminal to apply the changes."
fi

# If python version is not installed, install it
if ! pyenv versions | grep -q "$PYTHON_VERSION"; then
  echo "Python $PYTHON_VERSION is not installed. Installing Python $PYTHON_VERSION..."
  pyenv install "$PYTHON_VERSION"
else
  echo "Python $PYTHON_VERSION is already installed."
fi

# If current python version is not python version, then switch to python version
if ! pyenv version | grep -q "$PYTHON_VERSION"; then
  echo "Switching to Python $PYTHON_VERSION..."
  pyenv global "$PYTHON_VERSION"
else
  echo "Python $PYTHON_VERSION is already activated."
fi

if ! command -v ansible &>/dev/null; then
  echo "ansible is not installed. Installing ansible..."
  brew install ansible
else
  echo "ansible is already installed."
fi

if ! command -v terraform &>/dev/null; then
  echo "terraform is not installed. Installing terraform..."
  brew tap hashicorp/tap
  brew install hashicorp/tap/terraform
else
  echo "terraform is already installed."
fi

if ! command -v tflint &>/dev/null; then
  echo "tflint is not installed. Installing tflint..."
  brew install tflint
else
  echo "tflint is already installed."
fi

if ! command -v gitleaks &>/dev/null; then
  echo "gitleaks is not installed. Installing gitleaks..."
  brew install gitleaks
else
  echo "gitleaks is already installed."
fi

if ! command -v pre-commit &>/dev/null; then
  echo "pre-commit is not installed. Installing pre-commit..."
  pip install pre-commit
  pre-commit install
else
  echo "pre-commit is already installed."
  echo "Updating pre-commit..."
  pre-commit autoupdate
fi

echo "Installing ansible-galaxy roles..."
ansible-galaxy install -r stage1/requirements.yml
echo "Installing pip requirements..."
pip install --no-cache-dir -r stage1/requirements-pip.txt
