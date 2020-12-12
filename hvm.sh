#!/usr/bin/env bash

VERSION="${1}"
CURRENT_VERSION=''
GITHUB_PROJ='helm'
GITHUB_ORG="$GITHUB_PROJ"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_ORG}/${GITHUB_PROJ}"
GITHUB_RELEASES_URL="$GITHUB_API_URL/releases"

OS=''
OS_ARCH='amd64'

FILE_NAME=''
DL_DIR='/tmp'
BIN_ROOT="$HOME/.cloud-tools/bin"
BIN_DIR="$BIN_ROOT/$GITHUB_PROJ-bin"

function getUserInput() {
  local message="${1}"
  local confirmation="${2}"
  declare options=()
  options=( $(echo ${4}) )
  local prompt='Your choice: '
  local choice=-1
  local index=1
  local quit="q"

  echo -e "\n${message}"

  for option in "${options[@]}"; do
    echo -e "\t${index}) ${option}"
    ((index++))
  done

  echo "${prompt}"
  read -r choice

  if [[ "${choice}" -eq $quit ]]; then
    echo "Aborting operation..."
    exit 1
  fi

  if [[ $((choice >= 0)) -eq 1 ]] && [[ $((choice < index)) -eq 1 ]]; then
    local res
    res="${options[$choice]}"

    eval "${3}"="${res}"
    echo -e "\n$confirmation: $res"
  else
    echo "Invalid choice: $choice! Try again, or press 'q' to quit"
    read -r choice
  fi
}

function getAvailableReleases() {
  curl --request GET -sL \
    --url $GITHUB_RELEASES_URL |
    jq '[ .[] | select(.tag_name | contains("-") | not) | { tag_name: .tag_name }]' |
    jq '.[].tag_name' |
    jq @sh |
    sed -e "s/'v//g" |
    sed -e "s/'//g" |
    tr '\n' ' '
}

function currentVersion() {
  current=$("$GITHUB_PROJ" version 2> /dev/null)
  if [[ $current == Client:* ]]; then
    current="${current//Client: &version.Version\{SemVer:/}"
  else
    current="${current//version.BuildInfo\{Version:/}"
  fi
    CURRENT_VERSION=$(echo "$current" | sed -r 's/, Git.*//g')
}

function init() {
  currentVersion
  local opts="yes no"
  local msg
  local confirm="Continue to change version"
  local continue
  msg="Version manager for $(echo $GITHUB_PROJ | tr '[:lower:]' '[:upper:]')\n"
  if [ -z "$VERSION" ]; then
    msg+="Current version: ${CURRENT_VERSION}\n\nDo you want to select a different version?"
    getUserInput "$msg" "$confirm" continue "$opts"
    if [[ "$continue" == 'no' ]]; then

      exit 0
    fi
  elif [[ "$CURRENT_VERSION" == *"$VERSION"* ]]; then
    echo -e "$msg\nDesired version [$VERSION] is already installed, exiting ... "
    exit 0
  else
    echo "$msg"
  fi

    setVersion
    if [ ! -f "$BIN_DIR/$VERSION/$GITHUB_PROJ" ]; then
      echo "Fetching $(echo $GITHUB_PROJ | tr '[:lower:]' '[:upper:]') version $VERSION ..."
      downloadBinary
      extractBinary
    fi

    useVersion
}

function setVersion() {
  local msg="Select $GITHUB_PROJ version to use:"
  local confirm="Setting $GITHUB_PROJ version to"
  local versions
  versions=$(getAvailableReleases)
  if [ -z "$VERSION" ]; then
    getUserInput "$msg" "$confirm" VERSION "$versions"
  else
    echo "$confirm: \"$VERSION\""
  fi
}

function downloadBinary() {
  OS="$(uname | tr "[:upper:]" "[:lower:]")"
  echo "OS: $OS"
  FILE_NAME="$GITHUB_PROJ-v${VERSION}-$OS-$OS_ARCH.tar.gz"
  curl "https://get.helm.sh/${FILE_NAME}" -o "$DL_DIR/$FILE_NAME"
}

function extractBinary() {
  local target
  local source
  target="$BIN_DIR/$VERSION"
  source="$DL_DIR/$FILE_NAME"
  mkdir -p "$target"
  tar --strip-components=1 -C "$target" -xzvf "$source" "$OS-$OS_ARCH"
}

function updateLink() {
  if test -f "$BIN_DIR/$VERSION/$1"; then
    echo "Setting link for: $1"
    ln -sf "$BIN_DIR/$VERSION/$1" "$BIN_ROOT/$1"
  else
    echo "Removing link for: $1"
    rm -f "$BIN_ROOT/$1"
  fi
}

function useVersion() {
  updateLink 'tiller'
  updateLink 'helm'
}


init
#currentVersion
#echo "CURR: $CURRENT_VERSION"
#setVersion
#
#if [ ! -f "$BIN_DIR/$VERSION/$GITHUB_PROJ" ]; then
#  echo "Fetching $GITHUB_PROJ version $VERSION ..."
#  downloadBinary
#  extractBinary
#fi
#
#useVersion
