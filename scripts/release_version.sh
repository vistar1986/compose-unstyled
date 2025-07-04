#!/bin/bash
set -e

echo "Pulling changes..."
git pull

echo "Running tests..."
./gradlew core:jvmTest

echo "All tests passed..."

# Define the root directory as the current directory
root_dir=$(pwd)

# Read the docs version from libs.versions.toml
previous_version=$(grep '^unstyled =' "$root_dir/gradle/libs.versions.toml" | sed 's/^unstyled = "\([^\"]*\)"/\1/')

read -p "🚢 Current version is $previous_version – read from libs.versions.toml. Ship it? (y/n):" confirm
if [[ "$confirm" != "y" ]]; then
    echo "Aborted."
    exit 1
fi

# Read the WIP version from the keyboard
read -p "Enter next version (e.g., 1.8.0): " wip_version

echo "Publishing to Sonar..."

./gradlew publishAllPublicationsToSonatypeRepository closeAndReleaseSonatypeStagingRepository

echo "👍 Published $previous_version"

# Retrieve the last commit hash
last_commit=$(git rev-parse HEAD)

# Tag the last commit with the last version
git tag "$previous_version" $last_commit

# Find and update the version in .md files
find "$root_dir" -type f -name "*.md" -exec sed -i '' "s/implementation(\"com\.composables:core:[^\"]*\")/implementation(\"com.composables:core:$previous_version\")/g" {} +

# Update the version in libs.versions.toml
sed -i '' "s/^unstyled = \".*\"/unstyled = \"$wip_version\"/" "$root_dir/gradle/libs.versions.toml"

# Add all changes to git
git add .

# Commit with the provided version in the message
git commit -m "Prepare version $wip_version"

git push origin
git push origin $previous_version

echo "💯 All done. Working version is $previous_version"

echo "TODO: Open a Github version for $previous_version"
open https://github.com/composablehorizons/compose-unstyled/releases/new
