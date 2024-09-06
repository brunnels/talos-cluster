#!/bin/bash

# Stop on any error
set -e

# Default directory
KUSTOMIZATION_DIR="${1:-kubernetes/apps}"
SUBTREE_PREFIX="temp-repo"
REVISION=
REPO_URL=
SOURCE_DIRECTORY=
BRANCH=
CURRENT_REVISION=

# Global cleanup function
cleanup() {
    if git stash list | grep -q "Syncing subtree update"; then
        echo "Reapplying stashed changes..."
        git stash pop > /dev/null 2>&1 || echo "Warning: Failed to reapply stashed changes."
    fi
}

# Trap to ensure cleanup on script exit
trap cleanup EXIT

# Function to extract value from kustomization.yaml
extract_value() {
    grep -A 1 "^.*#.*${1}:.*" "$2" | \
    head -n 1 | awk -F "$1:" '{print $2}' | awk '{print $1}'
}

extract_details() {
    # Extract details from kustomization.yaml
    REVISION=$(extract_value "revison" "$1")
    REPO_URL=$(extract_value "repo" "$1")
    SOURCE_DIRECTORY=$(extract_value "source_dir" "$1")
    BRANCH=$(extract_value "branch" "$1")

    # Check if the values are extracted correctly
    echo "  - revision: $REVISION"
    echo "  - repo_url: $REPO_URL"
    echo "  - source_dir: $SOURCE_DIRECTORY"
    echo "  - branch: $BRANCH"

    # Validate extracted values
    if [ -z "$REPO_URL" ] || [ -z "$SOURCE_DIRECTORY" ] || [ -z "$BRANCH" ]; then
        echo "Error: Could not extract necessary information from $1."
        exit 1
    fi
}

process_kustomization() {
    # Only proceed if the revision has changed
    if [ "$CURRENT_REVISION" != "$REVISION" ]; then
        echo "Updating subtree as the revision has changed."

        # Define target directory
        TARGET_DIR="$(dirname "$1")/resources"

        # Create target directory if it doesn't exist
        mkdir -p "$TARGET_DIR"

        # Temporarily stash local modifications, if any
        if ! git diff-index --quiet HEAD --; then
            echo "Local modifications detected. Stashing changes..."
            git stash push -m "Syncing subtree update" || { echo "Error: Failed to stash local changes."; exit 1; }
        fi

        # Check if the subtree prefix exists
        if git log --format=%b | awk "/$SUBTREE_PREFIX/ { print \$NF }" | sort --unique | grep -q "$SUBTREE_PREFIX"; then
            echo "Subtree prefix exists. Skipping addition."
        else
            # Add the subtree
            echo "Adding subtree..."
            git subtree add --prefix="$SUBTREE_PREFIX" "$REPO_URL" "$BRANCH" --squash || { echo "Error: Failed to add subtree."; exit 1; }
        fi

        # Pull updates from the external repository
        echo "Pulling updates..."
        git subtree pull --prefix="$SUBTREE_PREFIX" "$REPO_URL" "$BRANCH" --squash || { echo "Error: Failed to pull updates."; exit 1; }

        # Handle the target directory
        echo "Clearing contents of target directory..."
        rm -rf "${TARGET_DIR:?}"/*

        # Move the updated directory
        if [ -d "$SUBTREE_PREFIX/$SOURCE_DIRECTORY" ]; then
            mv "$SUBTREE_PREFIX/$SOURCE_DIRECTORY/"* "$TARGET_DIR" || { echo "Error: Failed to move files."; exit 1; }
        else
            echo "Error: Source directory ($SUBTREE_PREFIX/$SOURCE_DIRECTORY) does not exist."
            exit 1
        fi

        # Clean up
        rm -rf "$SUBTREE_PREFIX"
    else
        echo "No updates needed. The repository is up to date."
    fi
}

# Function to update kustomization.yaml with new resources
update_kustomization_resources() {
    TARGET_DIR="$(dirname "$1")/resources"

    echo "Updating kustomization.yaml with new resources..."

    # Clear existing resources in kustomization.yaml
    sed -i '/^resources:/{s/\(resources:\).*/\1/;q}' "$1"


    for file in "$TARGET_DIR"/*; do
        if [ -f "$file" ]; then
            RP=$(realpath --relative-to="$(dirname "$1")" "$file")
            echo "Adding resource $RP to kustomization.yaml"
            sed -i "/^resources:/a\  - ./$RP" "$1"
        fi
    done
}

# Function to update the revision key in kustomization.yaml
update_revision_key() {
    echo "Updating revision in kustomization.yaml..."
    sed -E -i "s/^(.*#.*revison:).*/\0 $2/" "$1"
}

# Find and process kustomization.yaml files annotated with # sync-subtree
while read file; do
    if grep -q "^.*#.*sync-subtree" "$file"; then
        # Convert to absolute path
        KUSTOMIZATION_FILE=$(realpath "$file")

        echo "Processing $KUSTOMIZATION_FILE..."
        extract_details "$KUSTOMIZATION_FILE"

        # Get the current revision hash
        CURRENT_REVISION=$(git ls-remote "$REPO_URL" "$BRANCH" | awk '{print $1}')

        UPDATED="$(process_kustomization "$KUSTOMIZATION_FILE")"
        if [ "$UPDATED" != "No updates needed. The repository is up to date." ]; then
            ls -lah "$KUSTOMIZATION_FILE"
            # Update kustomization.yaml with new resources
            update_kustomization_resources "$KUSTOMIZATION_FILE"

            # Update the revision key in kustomization.yaml
            update_revision_key "$KUSTOMIZATION_FILE" "$CURRENT_REVISION"
        else
            echo "$UPDATED"
        fi
    fi
done < <(find "$KUSTOMIZATION_DIR" -type f -name 'kustomization.yaml')
