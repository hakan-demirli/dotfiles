import os
import re
import pty
import subprocess
from typing import List


class TerminalRunner:
    def __init__(self) -> None:
        self.output_bytes = []

    def read(self, fd):
        data = os.read(fd, 1024)
        self.output_bytes.append(data)
        return data

    def run(self, command):
        result = subprocess.run(command, capture_output=True, text=True)
        output = result.stdout
        # solve duplicate printing problem
        patterns = [
            r"\n\d+\s*tasks",
            r"\n\d+\s*task",
            r"\n\d+\s*projects",
            r"\n\d+\s*project",
        ]
        for pattern in patterns:
            match = re.search(pattern, output)
            if match:
                return output[: match.start()]
        return output

    def run_colored(self, command):
        self.output_bytes = []  # Clear the output bytes at the beginning

        # Save the original stdout
        original_stdout = os.dup(1)
        # Open the null device
        null = os.open(os.devnull, os.O_RDWR)
        # Duplicate the null device to stdout
        os.dup2(null, 1)

        try:
            pty.spawn(command, self.read)
        finally:
            # Restore the original stdout
            os.dup2(original_stdout, 1)
            os.close(original_stdout)
            os.close(null)

        output = b"".join(self.output_bytes).decode("utf-8")

        # solve duplicate printing problem
        patterns = [
            r"\n\d+\s*tasks",
            r"\n\d+\s*task",
            r"\n\d+\s*projects",
            r"\n\d+\s*project",
        ]
        for pattern in patterns:
            match = re.search(pattern, output)
            if match:
                return output[: match.start()]
        return output

    def strip_color_codes(self, line: str) -> str:
        # ANSI color code regex
        ansi_escape = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
        return ansi_escape.sub("", line)

    def get_colored_lines(self, command) -> List[str]:
        clines = self.run_colored(command).splitlines()
        clines = [line for line in clines if line]
        return clines

    def get_colorless_lines(self, command) -> List[str]:
        lines = self.run(command).splitlines()
        lines = [line for line in lines if line]
        return lines

    def render_screen(self, lines: List[str], typing_line: str = "") -> None:
        print("\033[?25l", end="")  # Hide the cursor
        print("\033[s", end="")  # Save cursor position
        print("\033[J", end="")  # clear to the end

        print("\n".join(lines))
        if typing_line:
            print(": ", end="")
            print(typing_line, end="")

        # Restore cursor position
        print("\033[u", end="", flush=True)

    def highlight_line(self, index, lines, color_code) -> List[str]:
        for i, line in enumerate(lines):
            if i == index:
                lines[i] = self.strip_color_codes(lines[i])
                lines[i] = "\033[" + color_code + "m" + lines[i] + "\033[0m"
        return lines
