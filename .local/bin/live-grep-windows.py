#! /usr/bin/env python3

# ~/.vscode/extensions/find_within_files.ps1
# Override it with the following:
# python D:\rep\dotfiles\.local\bin\live-grep-windows.py


import subprocess

# Define the rg command as a list of arguments
rg_command = [
    "rg",
    "--color=always",
    "--line-number",
    "--no-heading",
    "--smart-case",
    ".*",
]

CATPPUCCIN_GREEN = "#a6da95"
CATPPUCCIN_MAUVE = "#c6a0f6"

# Define the fzf command as a list of arguments
fzf_command = [
    "fzf",
    "--ansi",
    "--border",
    f'--color "hl+:{CATPPUCCIN_GREEN}:reverse,hl:{CATPPUCCIN_MAUVE}:reverse"',
    '--delimiter ":"',
    '--height "100%"',
    "--multi",
    "--print-query --exit-0",
    '--preview "bat  {1} --highlight-line {2} --color=always --style=numbers "',
    '--preview-window "right,+{2}+3/3,~3"',
    '--scrollbar "▍"',
]

fzf_command = " ".join(fzf_command)
print(fzf_command)
print("")


try:
    # Run the rg command and pipe its output to fzf
    rg_process = subprocess.Popen(
        rg_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    fzf_process = subprocess.Popen(
        fzf_command,
        stdin=rg_process.stdout,
        stdout=subprocess.PIPE,
        text=True,
    )

    # Close the standard output of rg process since it's being piped to fzf
    rg_process.stdout.close()

    # Wait for the user to interact with fzf and press Enter
    selected_string, stderr = fzf_process.communicate()

    # Check if there was any error
    if fzf_process.returncode != 0:
        print("An error occurred:", stderr)
    else:
        # Print the selected string
        selected_string = selected_string.strip()
        selected_string = (
            selected_string.split("\n")[1]
            if "\n" in selected_string
            else selected_string
        )
        print("Selected string:", selected_string)
        file_path, line_number, *_ = selected_string.split(":")
        # Split the selected string into file path and line number

        # Construct the code command to open the file in Visual Studio Code
        code_command = f'code -g "./{file_path}:{line_number}"'

        # Execute the code command
        code_process = subprocess.Popen(
            code_command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        code_process.communicate()

except FileNotFoundError:
    print(
        "rg, fzf, or code command not found. Please install them and ensure they're in your PATH."
    )
except KeyboardInterrupt:
    print("\nOperation canceled by the user.")
