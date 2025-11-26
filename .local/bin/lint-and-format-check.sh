#!/usr/bin/env bash
set -euo pipefail

get_python_scripts() {
  find . -type f -not -path "./.git/*" -exec sh -c '
        head -n1 "$1" 2>/dev/null | grep -Eq "^#!/usr/bin/env[[:space:]]+python[3]?([[:space:]]|$)"
    ' _ {} \; -print
}
get_env_bash_scripts() {
  find . -type f -not -path "./.git/*" -exec sh -c '
        head -n1 "$1" 2>/dev/null | grep -Eq "^#!/usr/bin/env[[:space:]]+bash$"
    ' _ {} \; -print
}

check_no_absolute_bash() {
  local found=0
  local file

  while IFS= read -r -d '' file; do
    if head -n1 "$file" 2> /dev/null | grep -Eq '^#!/(bin/|usr/bin/)bash([[:space:]]|$)'; then
      echo "ERROR: Absolute path shebang found in: $file" >&2
      head -n1 "$file" >&2
      found=1
    fi
  done < <(find . -type f -not -path "./.git/*" -print0)

  return "$found"
}

check_no_absolute_python() {
  local found=0
  local file

  while IFS= read -r -d '' file; do
    if head -n1 "$file" 2> /dev/null | grep -Eq '^#!/(bin/|usr/bin/)python[3]?([[:space:]]|$)'; then
      echo "ERROR: Absolute python path shebang found in: $file" >&2
      head -n1 "$file" >&2
      found=1
    fi
  done < <(find . -type f -not -path "./.git/*" -print0)

  return "$found"
}

run_check() {
  local cmd=$1
  shift
  echo "Running: $cmd $*"
  nix run "nixpkgs#$cmd" -- "$@"
}

main() {
  local mode="check"
  if [[ ${1:-} == "fix" ]]; then
    mode="fix"
    echo "Running in FIX mode. Files will be modified."
  else
    echo "Running in CHECK mode. No files will be modified."
  fi

  cd "$(dirname "$0")/../.."

  check_no_absolute_bash || {
    echo "❌ Fix absolute path shebangs before continuing" >&2
    exit 1
  }
  check_no_absolute_python || {
    echo "❌ Fix absolute python path shebangs before continuing" >&2
    exit 1
  }

  if [[ $mode == "check" ]]; then
    run_check deadnix --fail .
    run_check statix check .
    run_check nixfmt-tree --fail-on-change .
  else
    run_check deadnix --edit .
    run_check statix fix .
    run_check nixfmt-tree .
  fi

  mapfile -t bash_scripts < <(
    {
      find . -type f \( -name "*.sh" -o -name "*.bash" \) -not -path "./.git/*"
      get_env_bash_scripts
    } | sort -u
  )

  if [ ${#bash_scripts[@]} -eq 0 ]; then
    echo "No bash scripts found"
  else
    echo "Found ${#bash_scripts[@]} bash script(s)"

    printf '%s\0' "${bash_scripts[@]}" | xargs -0 nix run nixpkgs#shellcheck --

    local -a shfmt_flags=(-i 2 -ln bash -s -ci -bn -sr)

    if [[ $mode == "check" ]]; then
      echo "Checking shell script formatting..."
      printf '%s\0' "${bash_scripts[@]}" | xargs -0 nix run nixpkgs#shfmt -- "${shfmt_flags[@]}" -d
    else
      echo "Fixing shell script formatting..."
      printf '%s\0' "${bash_scripts[@]}" | xargs -0 nix run nixpkgs#shfmt -- "${shfmt_flags[@]}" -w
    fi
  fi

  mapfile -t python_files < <(
    {
      find . -type f \( -name "*.py" -o -name "*.pyi" \) -not -path "./.git/*"
      get_python_scripts
    } | sort -u
  )

  if [ ${#python_files[@]} -eq 0 ]; then
    echo "No python files found"
  else
    echo "Found ${#python_files[@]} python file(s) to check"

    # E, W: pycodestyle errors and warnings
    # F: Pyflakes
    # I: isort (for import sorting)
    # B: flake8-bugbear (finds likely bugs)
    # C4: flake8-comprehensions (encourages simpler comprehensions)
    # UP: pyupgrade (upgrades syntax to newer versions)
    # SIM: flake8-simplify (simplifies complex code)
    # RUF: Ruff-specific rules
    local ruff_select="E,W,F,I,B,C4,UP,SIM,RUF"

    # Ignore rules that conflict with the autoformatter.
    # E501: Line length is handled by the formatter.
    # W191, E111, E114, E117: Indentation is handled by the formatter.
    local ruff_ignore="E501,W191,E111,E114,E117"

    if [[ $mode == "check" ]]; then
      echo ""
      echo "Checking Python formatting with ruff..."
      run_check ruff format --check -- "${python_files[@]}"

      echo ""
      echo "Checking Python linting with strict rules (including import sorting)..."
      run_check ruff check --select "$ruff_select" --ignore "$ruff_ignore" -- "${python_files[@]}"
    else
      echo ""
      echo "Fixing Python linting with strict rules (including import sorting)..."
      run_check ruff check --select "$ruff_select" --ignore "$ruff_ignore" --fix -- "${python_files[@]}"

      echo ""
      echo "Formatting Python code with ruff..."
      run_check ruff format -- "${python_files[@]}"
    fi
  fi

  echo ""
  echo "✅ All checks passed!"
}

main "$@"
