#!/bin/bash

set -o allexport

LAST_COMMAND=$? # Must come first!
RED="\033[0;31m"
LIGHTRED="\033[1;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
NOCOLOR="\033[0m"

echo '           __________
         .'\''----------'\''.
         | .--------. |
         | |########| |       __________
         | |########| |      /__________\
.--------| '\''--------'\'' |------|    --=-- |-------------.
|        '\''----,-.-----'\''      |o ======  |             |
|       ______|_|_______     |__________|             |
|      /  %%%%%%%%%%%%  \                             |
|     /  %%%%%%%%%%%%%%  \                            |
|     ^^^^^^^^^^^^^^^^^^^^                            |
+-----------------------------------------------------+
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^'

# Run ssh-agent/ssh-add to make sure SSH key is added to ssh agent
eval "$(ssh-agent)"
ssh-add

# Source /srv/.env
if [ -f /srv/.env ]; then
  # shellcheck source=/dev/null
  source /srv/.env
fi

# Activate virtualenv
# shellcheck source=/dev/null
source /tmp/.venv/bin/activate

# If found ~/.kube/config, then get use context.
if [ -f ~/.kube/config ]; then
  KUBECTL_CONTEXT=$(kubectl config get-contexts -o name)
  echo "Switching to kubectl context: $KUBECTL_CONTEXT"
  kubectl config use-context "$KUBECTL_CONTEXT"
fi

# Check terraform status
function terraform_status() {
  DIR="$(pwd)"

  # Check if the folder contains the file "backend.tf"
  if [ -f "$DIR/backend.tf" ]; then
    TERRAFORM_WORKSPACE="$(terraform workspace show)"
    if [ "$TERRAFORM_WORKSPACE" == "default" ]; then
      echo "\[$CYAN\][Terraform: \[$RED\]${TERRAFORM_WORKSPACE^^}\[$CYAN\]]"
    else
      echo "\[$CYAN\][Terraform: \[$GREEN\]${TERRAFORM_WORKSPACE^^}\[$CYAN\]]"
    fi
  else
    echo "[Terraform: N/A]"
  fi
}

# Check Ansible status
function ansible_status() {
  DIR="$(pwd)"

  # Check if the folder contains the file "inventories"
  if [ -f "$DIR/inventories/inventory.yml" ]; then
    ANSIBLE_STATUS=$(ansible all -i "inventories/inventory.yml" -m ping)

    ANSIBLE_SUCCESS=$(echo "$ANSIBLE_STATUS" | grep -o "SUCCESS" | wc -l)
    ANSIBLE_SUCCESS_COLOUR=$([ "$ANSIBLE_SUCCESS" == "0" ] && echo "\[${LIGHTRED}\]" || echo "\[${GREEN}\]")

    ANSIBLE_UNREACHABLE=$(echo "$ANSIBLE_STATUS" | grep -o "UNREACHABLE" | wc -l)
    ANSIBLE_UNREACHABLE_COLOUR=$([ "$ANSIBLE_UNREACHABLE" == "0" ] && echo "\[${NOCOLOR}\]" || echo "\[${RED}\]")

    echo "\[$CYAN\][Ansible: ${ANSIBLE_SUCCESS_COLOUR}${ANSIBLE_SUCCESS} Success, ${ANSIBLE_UNREACHABLE_COLOUR}${ANSIBLE_UNREACHABLE} Unreachable\[$CYAN\]]"
  else
    echo "[Ansible: N/A]"
  fi
}

function display_ps1() {
  MESSAGE="\[$CYAN\]\342\224\214\342\224\200"

  # Show error message
  if [[ $LAST_COMMAND != 0 ]]; then
    MESSAGE+="\[${LIGHTRED}\][Error: \[${LIGHTRED}\]${LAST_COMMAND}]\[$NOCOLOR\]-"
  fi

  # Show date/time
  MESSAGE+="\[$BLUE\][\D{%F %T}]" # Time

  MESSAGE+="\[$NOCOLOR\]-"

  # Show Terraform
  MESSAGE+=$(terraform_status)
  MESSAGE+="\[$NOCOLOR\]-"

  # Show Ansible
  MESSAGE+=$(ansible_status)

  MESSAGE+="\[$NOCOLOR\]\n"

  printf "%s\[$CYAN\]\342\224\224>\[$NOCOLOR\]\w\\$ " "$MESSAGE"
}

export PROMPT_COMMAND='PS1=$(display_ps1)'
