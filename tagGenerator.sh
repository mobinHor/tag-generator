#!/bin/bash

instances=("stage" "stage-back" "growth" "growth-back" "platform" "platform-back" "third" "third-back" "body" "body-back" "share-lotus" "storybook" "share")
versions=("patch" "minor" "major")

git fetch --tags

# Function to increment the version
increment_version() {
  local last_version=$1
  local keyword=$2
  local semantic_version=$3
  IFS='-' read -r -a array <<< "$last_version"
  IFS='.' read -r -a parts <<< "${array[0]}"
  if [ "$semantic_version" = "major" ]; then
      new_version="$((parts[0] + 1)).0.0-$keyword"
  fi
  if [ "$semantic_version" = "minor" ]; then
      new_version="${parts[0]}.$((parts[1] + 1)).0-$keyword"
  fi
  if [ "$semantic_version" = "patch" ]; then
      new_version="${parts[0]}.${parts[1]}.$((parts[2] + 1))-$keyword"
  fi
  echo "$new_version"
}

# Function to display select box for instances
select_instance_name() {
  echo "Please select a instance_name:"
  select instance_name in "${instances[@]}"; do
    if [[ -n $instance_name ]]; then
      echo "You have selected: $instance_name"
      break
    else
      echo "Invalid selection. Please try again."
    fi
  done
}

# Function to display select box for versions
select_version() {
  echo "Please select version:"
  select version in "${versions[@]}"; do
    if [[ -n $version ]]; then
      echo "You have selected: $version"
      break
    else
      echo "Invalid selection. Please try again."
    fi
  done
}

# Get INSTANCE name from input and validate, or show select box
if [ -n "$1" ]; then
    if ! grep -q "${1}" <<< "${instances[*]}"; then
      echo "Invalid instance name"
      exit 1
    else
      instance_name=$1
    fi
else
  select_instance_name
fi

# Get VERSION from input and validate, or show select box
if [ -n "$2" ]; then
  if ! grep -q "${2}" <<< "${versions[*]}"; then
      echo "Invalid version"
      exit 1
  else
      version=$2
  fi
else
  select_version
fi

# Find the latest tag containing the INSTANCE
latest_tag=$(git tag --list "*$instance_name" --sort=-creatordate | sort -Vr | head -n 1)

if [ -z "$latest_tag" ]; then
  echo "No tags containing the instance name '$instance_name' found."
  exit 1
fi

echo "Latest tag: $latest_tag"

# Version increment
new_tag=$(increment_version "$latest_tag" "$instance_name" "$version")

# Confirmation on creating and pushing tag
read -p "New tag is $new_tag ,Are you sure? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

echo "Latest tag: $latest_tag"

git tag "$new_tag"

git push origin "$new_tag"


