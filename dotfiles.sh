#!/usr/bin/env bash

echo "Running Tyler's custom dotfiles installer..."

# Git branch names to consider as the main branch
MAIN_BRANCH_NAMES=("main" "master" "trunk")
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
OH_MY_POSH_CONFIG=$DOTFILES_DIR/.oh-my-posh.json


function is_installed() {
  if command -v "$1" &> /dev/null; then
    return 0
  else
    echo "$1 is not installed. Please install it to use this function."
    return 1
  fi
}

function are_you_sure() {
  if [ -n "$1" ]; then
    read -q "REPLY?$1 (y/n) "
  else
    read -q "REPLY?Are you sure? (y/n) "
  fi
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    return 1
  fi
  return 0
}

function is_a_git_repo() {
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    return 0
  else
    return 1
  fi
}

function is_on_main_branch() {
  # Be sure we are in a git repository
  if ! is_a_git_repo; then
    return 1
  fi

  # Check if branch is any of the branches defined in constants
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  for branch in "${MAIN_BRANCH_NAMES[@]}"; do
    if [[ "$current_branch" = "$branch" ]]; then
      return 0
    fi
  done

  # If we reach here, we are not on a main branch
  return 1
}

function get_main_branch() {
  # Find the first main branch that exists in the repository
  for branch in "${MAIN_BRANCH_NAMES[@]}"; do
    if git rev-parse --verify "$branch" &>/dev/null; then
      echo "$branch"
      return 0
    fi
  done
  # If no main branch exists, return the first one (will likely error later, which is appropriate)
  echo "${MAIN_BRANCH_NAMES[0]}"
  return 1
}

function files_touched_by_current_branch() {
  if ! is_a_git_repo; then
    echo "Not a git repository. Please run this command inside a git repository."
    return 1
  fi

  if is_on_main_branch; then
    echo "You are on a main branch. Please provide a branch name other than main."
    return 1
  fi

  # Gather untracked files (add a leading space for formatting)
  untracked_files=$(git ls-files --others --exclude-standard | sed 's/^/ /')

  # Show untracked files if any
  if [ -n "$untracked_files" ]; then
    echo "Untracked files:"
    echo "$untracked_files"
  fi

  # Show tracked files changed since branching from main (with heading if untracked files were shown as well)
  if [ -n "$untracked_files" ]; then
    echo "Tracked files:"
  fi
  local main_branch=$(get_main_branch) || return 1
  local merge_base=$(git merge-base "$main_branch" HEAD 2>/dev/null)
  if [ -z "$merge_base" ]; then
    echo "Error: Unable to find common ancestor between current branch and $main_branch"
    return 1
  fi
  git diff --stat "$merge_base"
}

function amend() {
  # Be sure you aren't on main
  if is_on_main_branch; then
    echo "You are on the main branch. Please switch to a different branch before amending commits."
    return 1
  fi

  # Be sure the last commit was made by me
  git_user_email=$(git config --get user.email)
  if [ -z "$git_user_email" ]; then
    echo "user.email is not configured. Please run: git config --global user.email 'your-email@example.com'"
    return 1
  fi

  last_commit_author_email=$(git log -1 --pretty=format:'%ae')
  if [[ "$last_commit_author_email" != "$git_user_email" ]]; then
    echo "The last commit was not made by you. Please check the commit history."
    return 1
  fi

  git add .
  git commit --amend --no-edit
}

function switch() {
  # Check that gum is installed which we use gum to make an interactive selection menu
  is_installed "gum" || return 1

  if ! is_a_git_repo; then
    echo "Not a git repository. Please run this command inside a git repository."
    return 1
  fi

  local main_branch=$(get_main_branch) || return 1
  local branch_info=$(git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short) %(committerdate:relative) %(HEAD)')

  # Exit if there are no branches to switch to (more than just the current branch)
  local branch_count=$(git branch --list | wc -l)
  if [ "$branch_count" -le 1 ]; then
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo "No branches to switch to. On $current_branch."
    return 0
  fi

  # Capture the selected branch and verify it's not empty before switching
  local selected_branch=$(while read -r branch; do
    branch_name=$(echo "$branch" | awk '{print $1}')
    ahead_behind=$(git rev-list --left-right --count "$main_branch"...$branch_name 2>/dev/null)
    ahead=$(echo "$ahead_behind" | awk '{print $1}')
    behind=$(echo "$ahead_behind" | awk '{print $2}')
    relative_commiter_date=$(echo "$branch" | awk '{print $2 " " $3}')

    if [[ "$branch_name" == "$(git rev-parse --abbrev-ref HEAD)" ]]; then
      branch_name="* $branch_name"
    fi

    echo -e "$branch_name\t$ahead↓$behind↑\t$relative_commiter_date"
  done <<< "$branch_info" | column -t -s $'\t' | gum choose | awk '{print $1}')

  # Check if a branch was selected (user may have cancelled)
  if [ -z "$selected_branch" ]; then
    echo "No branch selected."
    return 0
  fi

  git switch "$selected_branch"
}

function ls_replacement() {
  if is_installed "eza"; then
    if is_a_git_repo; then
      eza --git --header --icons --group-directories-first --no-user -lba "$@"
    else
      eza --header --icons --group-directories-first --no-user -lba "$@"
    fi
  else
    echo "eza is not installed. Falling back to ls."
    ls -lba "$@"
  fi
}

function delete_all_branches_but_main() {
  if ! is_a_git_repo; then
    echo "Not a git repository. Please run this command inside a git repository."
    return 1
  fi

  if ! is_on_main_branch; then
    echo "You are not on a main branch. Please switch to a main branch before deleting other branches."
    return 1
  fi

  force_flag="-d"

  # If the --hard flag is passed then we will delete branches even if they are not merged
  if [[ $1 == "--hard" ]]; then
    force_flag="-D"
  fi

  # Build regex pattern from all main branch names (e.g., "main|master|trunk")
  local pattern=$(IFS='|'; echo "${MAIN_BRANCH_NAMES[*]}")
  git branch | grep -vE "^\*?\s+($pattern)$" | awk '{print $NF}' | while read -r branch; do
    git branch "$force_flag" "$branch"
  done
}

####################################################################################################
## Dependencies ####################################################################################
####################################################################################################

if ! is_installed "oh-my-posh"; then
  echo "Installing oh-my-posh"
  curl -s https://ohmyposh.dev/install.sh | bash -s
fi
echo "Initializng oh-my-posh"
eval "$(oh-my-posh init zsh --config $OH_MY_POSH_CONFIG)"

####################################################################################################
## Aliases #########################################################################################
####################################################################################################

# Utilities
alias c="clear"

# Navigation
alias ..="cd .."

# Git and GitHub
alias gp="git push"
alias ghpr="gh pr view --web"
alias ghrepo="gh repo view --web"
alias justmain="delete_all_branches_but_main"
alias justmainhard="delete_all_branches_but_main --hard"
alias amend="amend"
alias main="git checkout main"
alias s="switch"
alias b="switch"
alias wtn="new_worktree"
alias wtd="delete_worktree"
alias filediff="files_touched_by_current_branch"
alias yolo="claude --dangerously-skip-permissions"

# Git aliases (invoked as `git s`, `git b`, etc.)
git config --global alias.s status
git config --global alias.b branch
git config --global alias.d diff
git config --global alias.c commit
git config --global alias.cob "checkout -b"

echo "Finished Tyler's custom dotfiles installer..."