import ast
import contextlib
import itertools
import math
import os
import re
import struct
import sys
import traceback
from typing import ClassVar

import gdb


class R:
    @staticmethod
    def attributes():
        return {
            "ansi": {
                "doc": "Control the ANSI output of the dashboard.",
                "default": True,
                "type": bool,
            },
            "syntax_highlighting": {
                "doc": """Pygments style to use for syntax highlighting.

Using an empty string (or a name not in the list) disables this feature. The
list of all the available styles can be obtained with (from GDB itself):

    python from pygments.styles import *
    python for style in get_all_styles(): print(style)""",
                "default": "monokai",
            },
            "discard_scrollback": {
                "doc": """Discard the scrollback buffer at each redraw.

This makes scrolling less confusing by discarding the previously printed
dashboards but only works with certain terminals.""",
                "default": True,
                "type": bool,
            },
            "compact_values": {
                "doc": "Display complex objects in a single line.",
                "default": True,
                "type": bool,
            },
            "max_value_length": {
                "doc": "Maximum length of displayed values before truncation.",
                "default": 100,
                "type": int,
            },
            "value_truncation_string": {
                "doc": "String to use to mark value truncation.",
                "default": "…",
            },
            "dereference": {
                "doc": "Annotate pointers with the pointed value.",
                "default": True,
                "type": bool,
            },
            "prompt": {
                "doc": """GDB prompt.

This value is used as a Python format string where `{status}` is expanded with
the substitution of either `prompt_running` or `prompt_not_running` attributes,
according to the target program status. The resulting string must be a valid GDB
prompt, see the command `python print(gdb.prompt.prompt_help())`""",
                "default": "{status}",
            },
            "prompt_running": {
                "doc": """Define the value of `{status}` when the target program is running.

See the `prompt` attribute. This value is used as a Python format string where
`{pid}` is expanded with the process identifier of the target program.""",
                "default": r"\[\e[1;35m\]>>>\[\e[0m\]",
            },
            "prompt_not_running": {
                "doc": """Define the value of `{status}` when the target program is running.

See the `prompt` attribute. This value is used as a Python format string.""",
                "default": r"\[\e[90m\]>>>\[\e[0m\]",
            },
            "omit_divider": {
                "doc": "Omit the divider in external outputs when only one module is displayed.",
                "default": False,
                "type": bool,
            },
            "divider_fill_char_primary": {
                "doc": "Filler around the label for primary dividers",
                "default": "─",
            },
            "divider_fill_char_secondary": {
                "doc": "Filler around the label for secondary dividers",
                "default": "─",
            },
            "divider_fill_style_primary": {
                "doc": "Style for `divider_fill_char_primary`",
                "default": "36",
            },
            "divider_fill_style_secondary": {
                "doc": "Style for `divider_fill_char_secondary`",
                "default": "90",
            },
            "divider_label_style_on_primary": {
                "doc": "Label style for non-empty primary dividers",
                "default": "1;33",
            },
            "divider_label_style_on_secondary": {
                "doc": "Label style for non-empty secondary dividers",
                "default": "1;37",
            },
            "divider_label_style_off_primary": {
                "doc": "Label style for empty primary dividers",
                "default": "33",
            },
            "divider_label_style_off_secondary": {
                "doc": "Label style for empty secondary dividers",
                "default": "90",
            },
            "divider_label_skip": {
                "doc": "Gap between the aligning border and the label.",
                "default": 3,
                "type": int,
                "check": check_ge_zero,
            },
            "divider_label_margin": {
                "doc": "Number of spaces around the label.",
                "default": 1,
                "type": int,
                "check": check_ge_zero,
            },
            "divider_label_align_right": {
                "doc": "Label alignment flag.",
                "default": False,
                "type": bool,
            },
            "style_selected_1": {"default": "1;32"},
            "style_selected_2": {"default": "32"},
            "style_low": {"default": "90"},
            "style_high": {"default": "1;37"},
            "style_error": {"default": "31"},
            "style_critical": {"default": "0;41"},
        }


class Beautifier:
    def __init__(self, hint, tab_size=4):
        self.tab_spaces = " " * tab_size if tab_size else None
        self.active = False
        if not R.ansi or not R.syntax_highlighting:
            return
        try:
            import pygments
            from pygments.formatters import Terminal256Formatter
            from pygments.lexers import GasLexer, NasmLexer

            if hint == "att":
                self.lexer = GasLexer()
            elif hint == "intel":
                self.lexer = NasmLexer()
            else:
                from pygments.lexers import get_lexer_for_filename

                self.lexer = get_lexer_for_filename(hint, stripnl=False)
            self.formatter = Terminal256Formatter(style=R.syntax_highlighting)
            self.active = True
        except ImportError:
            pass
        except pygments.util.ClassNotFound:
            pass

    def process(self, source):
        if self.tab_spaces:
            source = source.replace("\t", self.tab_spaces)
        if self.active:
            import pygments

            source = pygments.highlight(source, self.lexer, self.formatter)
        return source.rstrip("\n")


def run(command):
    return gdb.execute(command, to_string=True)


def ansi(string, style):
    if R.ansi:
        return f"\x1b[{style}m{string}\x1b[0m"
    else:
        return string


def divider(width, label="", primary=False, active=True):
    if primary:
        divider_fill_style = R.divider_fill_style_primary
        divider_fill_char = R.divider_fill_char_primary
        divider_label_style_on = R.divider_label_style_on_primary
        divider_label_style_off = R.divider_label_style_off_primary
    else:
        divider_fill_style = R.divider_fill_style_secondary
        divider_fill_char = R.divider_fill_char_secondary
        divider_label_style_on = R.divider_label_style_on_secondary
        divider_label_style_off = R.divider_label_style_off_secondary
    if label:
        if active:
            divider_label_style = divider_label_style_on
        else:
            divider_label_style = divider_label_style_off
        skip = R.divider_label_skip
        margin = R.divider_label_margin
        before = ansi(divider_fill_char * skip, divider_fill_style)
        middle = ansi(label, divider_label_style)
        after_length = width - len(label) - skip - 2 * margin
        after = ansi(divider_fill_char * after_length, divider_fill_style)
        if R.divider_label_align_right:
            before, after = after, before
        return "".join([before, " " * margin, middle, " " * margin, after])
    else:
        return ansi(divider_fill_char * width, divider_fill_style)


def check_gt_zero(x):
    return x > 0


def check_ge_zero(x):
    return x >= 0


def to_unsigned(value, size=8):
    mask = (2 ** (size * 8)) - 1
    return int(value.cast(gdb.Value(mask).type)) & mask


def to_string(value):
    try:
        value_string = str(value)
    except UnicodeEncodeError:
        value_string = str(value).encode("utf8")
    except gdb.error as e:
        value_string = ansi(e, R.style_error)
    return value_string


def format_address(address):
    pointer_size = gdb.parse_and_eval("$pc").type.sizeof
    return (f"0x{{:0{pointer_size * 2}x}}").format(address)


def format_value(value, compact=None):
    if value.type.code in (
        getattr(gdb, "TYPE_CODE_REF", None),
        getattr(gdb, "TYPE_CODE_RVALUE_REF", None),
    ):
        try:
            value = value.referenced_value()
        except gdb.error as e:
            return ansi(e, R.style_error)
    out = to_string(value)
    if R.dereference and value.type.code == gdb.TYPE_CODE_PTR:
        while value.type.code == gdb.TYPE_CODE_PTR:
            try:
                value = value.dereference()
            except gdb.error:
                break
        else:
            formatted = to_string(value)
            out += "{} {}".format(ansi(":", R.style_low), formatted)
    if (compact is not None and compact) or R.compact_values:
        out = re.sub(r"$\s*", "", out, flags=re.MULTILINE)
    if R.max_value_length > 0 and len(out) > R.max_value_length:
        out = out[0 : R.max_value_length] + ansi(
            R.value_truncation_string, R.style_critical
        )
    return out


def fetch_breakpoints(watchpoints=False, pending=False):
    parsed_breakpoints = {}
    catch_what_regex = re.compile(r'([^,]+".*")?[^,]*')
    for line in run("info breakpoints").split("\n"):
        if not line or not line[0].isdigit():
            continue
        fields = line.split()
        number = int(fields[0].split(".")[0])
        try:
            if len(fields) >= 5 and fields[1] == "breakpoint":
                is_pending = fields[4] == "<PENDING>"
                is_multiple = fields[4] == "<MULTIPLE>"
                address = None if is_multiple or is_pending else int(fields[4], 16)
                is_enabled = fields[3] == "y"
                address_info = address, is_enabled
                parsed_breakpoints[number] = [address_info], is_pending, ""
            elif len(fields) >= 5 and fields[1] == "catchpoint":
                what = catch_what_regex.search(" ".join(fields[4:])).group(0).strip()
                parsed_breakpoints[number] = [], False, what
            elif len(fields) >= 3 and number in parsed_breakpoints:
                address = int(fields[2], 16)
                is_enabled = fields[1] == "y"
                address_info = address, is_enabled
                parsed_breakpoints[number][0].append(address_info)
            else:
                parsed_breakpoints[number] = [], False, ""
        except ValueError:
            pass
    breakpoints = []
    for gdb_breakpoint in gdb.breakpoints() or []:
        if gdb_breakpoint.number < 0:
            continue
        addresses, is_pending, what = parsed_breakpoints[gdb_breakpoint.number]
        is_pending = getattr(gdb_breakpoint, "pending", is_pending)
        if not pending and is_pending:
            continue
        if not watchpoints and gdb_breakpoint.type != gdb.BP_BREAKPOINT:
            continue
        breakpoint = {}
        breakpoint["number"] = gdb_breakpoint.number
        breakpoint["type"] = gdb_breakpoint.type
        breakpoint["enabled"] = gdb_breakpoint.enabled
        breakpoint["location"] = gdb_breakpoint.location
        breakpoint["expression"] = gdb_breakpoint.expression
        breakpoint["condition"] = gdb_breakpoint.condition
        breakpoint["temporary"] = gdb_breakpoint.temporary
        breakpoint["hit_count"] = gdb_breakpoint.hit_count
        breakpoint["pending"] = is_pending
        breakpoint["what"] = what
        breakpoint["addresses"] = []
        for address, is_enabled in addresses:
            if address:
                sal = gdb.find_pc_line(address)
            breakpoint["addresses"].append(
                {
                    "address": address,
                    "enabled": is_enabled,
                    "file_name": sal.symtab.filename
                    if address and sal.symtab
                    else None,
                    "file_line": sal.line if address else None,
                }
            )
        breakpoints.append(breakpoint)
    return breakpoints


class Dashboard(gdb.Command):

    def __init__(self):
        gdb.Command.__init__(
            self, "dashboard", gdb.COMMAND_USER, gdb.COMPLETE_NONE, True
        )
        Dashboard.ConfigurationCommand(self)
        Dashboard.OutputCommand(self)
        Dashboard.EnabledCommand(self)
        Dashboard.LayoutCommand(self)
        Dashboard.StyleCommand(self, "dashboard", R, R.attributes())
        self.output = None
        self.inhibited = None
        self.enabled = None
        self.enable()

    def on_continue(self, _):
        enabled_modules = list(
            filter(lambda m: not m.output and m.enabled, self.modules)
        )
        if self.is_running() and not self.output and len(enabled_modules) > 0:
            width, _ = Dashboard.get_term_size()
            gdb.write(Dashboard.clear_screen())
            gdb.write(divider(width, "Output/messages", True))
            gdb.write("\n")
            gdb.flush()

    def on_stop(self, _):
        if self.is_running():
            self.render(clear_screen=False)

    def on_exit(self, _):
        if not self.is_running():
            return
        outputs = set()
        outputs.add(self.output)
        outputs.update(module.output for module in self.modules)
        outputs.remove(None)
        for output in outputs:
            try:
                with open(output, "w") as fs:
                    fs.write(Dashboard.reset_terminal())
            except Exception:
                pass

    def enable(self):
        if self.enabled:
            return
        self.enabled = True
        gdb.events.cont.connect(self.on_continue)
        gdb.events.stop.connect(self.on_stop)
        gdb.events.exited.connect(self.on_exit)

    def disable(self):
        if not self.enabled:
            return
        self.enabled = False
        gdb.events.cont.disconnect(self.on_continue)
        gdb.events.stop.disconnect(self.on_stop)
        gdb.events.exited.disconnect(self.on_exit)

    def load_modules(self, modules):
        self.modules = []
        for module in modules:
            info = Dashboard.ModuleInfo(self, module)
            self.modules.append(info)

    def redisplay(self, style_changed=False):
        if self.is_running() and not self.inhibited:
            self.render(True, style_changed)

    def inferior_pid(self):
        return gdb.selected_inferior().pid

    def is_running(self):
        return self.inferior_pid() != 0

    def render(self, clear_screen, style_changed=False):
        all_disabled = True
        display_map = {}
        for module in self.modules:
            output = module.output or self.output
            if module.enabled:
                all_disabled = False
                instance = module.instance
            else:
                instance = None
            display_map.setdefault(output, []).append(instance)
        for output, instances in display_map.items():
            try:
                buf = ""
                fs = None
                with contextlib.ExitStack() as stack:
                    if output:
                        fs = stack.enter_context(open(output, "w"))
                        fd = fs.fileno()
                        fs.write(Dashboard.setup_terminal())
                    else:
                        fs = gdb
                        fd = 1
                    try:
                        width, height = Dashboard.get_term_size(fd)
                    except Exception:
                        width, height = Dashboard.get_term_size()
                    if fs is not gdb or clear_screen:
                        buf += Dashboard.clear_screen()
                    if not any(instances):
                        if fs is gdb:
                            continue
                        buf += divider(width, "Warning", True)
                        buf += "\n"
                        if self.modules:
                            buf += "No module to display (see `dashboard -layout`)"
                        else:
                            buf += "No module loaded"
                        buf += "\n"
                        fs.write(buf)
                        continue
                    for n, instance in enumerate(instances, 1):
                        if not instance:
                            continue
                        try:
                            lines = instance.lines(width, height, style_changed)
                        except Exception:
                            stacktrace = traceback.format_exc().strip()
                            lines = [ansi(stacktrace, R.style_error)]
                        div = []
                        if not R.omit_divider or len(instances) > 1 or fs is gdb:
                            div = [divider(width, instance.label(), True, lines)]
                        buf += "\n".join(div + lines)
                        if n != len(instances) or fs is gdb:
                            buf += "\n"
                    if fs is gdb and not all_disabled:
                        buf += divider(width, primary=True)
                        buf += "\n"
                    fs.write(buf)
            except Exception:
                cause = traceback.format_exc().strip()
                Dashboard.err(f"Cannot write the dashboard\n{cause}")

    @staticmethod
    def start():
        global dashboard
        dashboard = Dashboard()
        Dashboard.set_custom_prompt(dashboard)
        dashboard.inhibited = True
        Dashboard.parse_inits(True)
        modules = Dashboard.get_modules()
        dashboard.load_modules(modules)
        Dashboard.parse_inits(False)
        dashboard.inhibited = False
        run("set pagination off")
        if dashboard.enabled:
            dashboard.redisplay()

    @staticmethod
    def get_term_size(fd=1):
        try:
            if sys.platform == "win32":
                import curses

                height, width = curses.initscr().getmaxyx()
                curses.endwin()
                return int(width), int(height)
            else:
                import fcntl
                import termios

                raw = fcntl.ioctl(fd, termios.TIOCGWINSZ, " " * 4)
                height, width = struct.unpack("hh", raw)
                return int(width), int(height)
        except (ImportError, OSError):
            return 80, 24

    @staticmethod
    def set_custom_prompt(dashboard):
        def custom_prompt(_):
            if dashboard.is_running():
                pid = dashboard.inferior_pid()
                status = R.prompt_running.format(pid=pid)
            else:
                status = R.prompt_not_running
            prompt = R.prompt.format(status=status)
            prompt = gdb.prompt.substitute_prompt(prompt)
            return prompt + " "

        gdb.prompt_hook = custom_prompt

    @staticmethod
    def parse_inits(python):
        search_paths = [
            "/etc/gdb-dashboard",
            "{}/gdb-dashboard".format(os.getenv("XDG_CONFIG_HOME", "~/.config")),
            "~/Library/Preferences/gdb-dashboard",
            "~/.gdbinit.d",
        ]
        inits_dirs = (os.walk(os.path.expanduser(path)) for path in search_paths)
        for root, dirs, files in itertools.chain.from_iterable(inits_dirs):
            dirs.sort()
            for init in sorted(file for file in files if not file.startswith(".")):
                path = os.path.join(root, init)
                _, ext = os.path.splitext(path)
                if python == (ext == ".py"):
                    gdb.execute("source " + path)

    @staticmethod
    def get_modules():
        modules = []
        for name in globals():
            obj = globals()[name]
            try:
                if issubclass(obj, Dashboard.Module):
                    modules.append(obj)
            except TypeError:
                continue
        modules.sort(key=lambda x: x.__name__)
        return modules

    @staticmethod
    def create_command(name, invoke, doc, is_prefix, complete=None):
        if callable(complete):
            Class = type(
                "",
                (gdb.Command,),
                {"__doc__": doc, "invoke": invoke, "complete": complete},
            )
            Class(name, gdb.COMMAND_USER, prefix=is_prefix)
        else:
            Class = type("", (gdb.Command,), {"__doc__": doc, "invoke": invoke})
            Class(name, gdb.COMMAND_USER, complete or gdb.COMPLETE_NONE, is_prefix)

    @staticmethod
    def err(string):
        print(ansi(string, R.style_error))

    @staticmethod
    def complete(word, candidates):
        return filter(lambda candidate: candidate.startswith(word), candidates)

    @staticmethod
    def parse_arg(arg):
        if type(arg) is not str:
            arg = arg.encode("utf8")
        return arg

    @staticmethod
    def clear_screen():
        return "\x1b[H\x1b[2J" + ("\x1b[3J" if R.discard_scrollback else "")

    @staticmethod
    def setup_terminal():
        return "\x1b[?1049h\x1b[?25l"

    @staticmethod
    def reset_terminal():
        return "\x1b[?1049l\x1b[?25h"

    class ModuleInfo:
        def __init__(self, dashboard, module):
            self.name = module.__name__.lower()
            self.enabled = True
            self.output = None
            self.instance = module()
            self.doc = self.instance.__doc__ or "(no documentation)"
            self.prefix = f"dashboard {self.name}"
            self.add_main_command(dashboard)
            self.add_output_command(dashboard)
            self.add_style_command(dashboard)
            self.add_subcommands(dashboard)

        def add_main_command(self, dashboard):
            module = self

            def invoke(self, arg, from_tty, info=self):
                arg = Dashboard.parse_arg(arg)
                if arg == "":
                    info.enabled ^= True
                    if dashboard.is_running():
                        dashboard.redisplay()
                    else:
                        status = "enabled" if info.enabled else "disabled"
                        print(f"{module.name} module {status}")
                else:
                    Dashboard.err(f'Wrong argument "{arg}"')

            doc_brief = f"Configure the {self.name} module, with no arguments toggles its visibility."
            doc = f"{doc_brief}\n\n{self.doc}"
            Dashboard.create_command(self.prefix, invoke, doc, True)

        def add_output_command(self, dashboard):
            Dashboard.OutputCommand(dashboard, self.prefix, self)

        def add_style_command(self, dashboard):
            Dashboard.StyleCommand(
                dashboard, self.prefix, self.instance, self.instance.attributes()
            )

        def add_subcommands(self, dashboard):
            for name, command in self.instance.commands().items():
                self.add_subcommand(dashboard, name, command)

        def add_subcommand(self, dashboard, name, command):
            action = command["action"]
            doc = command["doc"]
            complete = command.get("complete")

            def invoke(self, arg, from_tty, info=self):
                arg = Dashboard.parse_arg(arg)
                if info.enabled:
                    try:
                        action(arg)
                    except Exception as e:
                        Dashboard.err(e)
                        return
                    dashboard.redisplay()
                else:
                    Dashboard.err("Module disabled")

            prefix = f"{self.prefix} {name}"
            Dashboard.create_command(prefix, invoke, doc, False, complete)

    def invoke(self, arg, from_tty):
        arg = Dashboard.parse_arg(arg)
        if arg != "":
            Dashboard.err(f'Wrong argument "{arg}"')
        elif not self.is_running():
            Dashboard.err("Is the target program running?")
        else:
            self.redisplay()

    class ConfigurationCommand(gdb.Command):

        def __init__(self, dashboard):
            gdb.Command.__init__(
                self,
                "dashboard -configuration",
                gdb.COMMAND_USER,
                gdb.COMPLETE_FILENAME,
            )
            self.dashboard = dashboard

        def invoke(self, arg, from_tty):
            arg = Dashboard.parse_arg(arg)
            if arg:
                with open(os.path.expanduser(arg), "w") as fs:
                    fs.write("# auto generated by GDB dashboard\n\n")
                    self.dump(fs)
            self.dump(gdb)

        def dump(self, fs):
            self.dump_layout(fs)
            self.dump_style(fs, R)
            for module in self.dashboard.modules:
                self.dump_style(fs, module.instance, module.prefix)
            self.dump_output(fs, self.dashboard)
            for module in self.dashboard.modules:
                self.dump_output(fs, module, module.prefix)

        def dump_layout(self, fs):
            layout = ["dashboard -layout"]
            for module in self.dashboard.modules:
                mark = "" if module.enabled else "!"
                layout.append(f"{mark}{module.name}")
            fs.write(" ".join(layout))
            fs.write("\n")

        def dump_style(self, fs, obj, prefix="dashboard"):
            attributes = getattr(obj, "attributes", lambda: {})()
            for name, attribute in attributes.items():
                real_name = attribute.get("name", name)
                default = attribute.get("default")
                value = getattr(obj, real_name)
                if value != default:
                    fs.write(f"{prefix} -style {name} {value!r}\n")

        def dump_output(self, fs, obj, prefix="dashboard"):
            output = obj.output
            if output:
                fs.write(f"{prefix} -output {output}\n")

    class OutputCommand(gdb.Command):

        def __init__(self, dashboard, prefix=None, obj=None):
            if not prefix:
                prefix = "dashboard"
            if not obj:
                obj = dashboard
            prefix = prefix + " -output"
            gdb.Command.__init__(self, prefix, gdb.COMMAND_USER, gdb.COMPLETE_FILENAME)
            self.dashboard = dashboard
            self.obj = obj

        def invoke(self, arg, from_tty):
            arg = Dashboard.parse_arg(arg)
            if self.obj.output:
                try:
                    with open(self.obj.output, "w") as fs:
                        fs.write(Dashboard.reset_terminal())
                except Exception:
                    pass
            if arg == "":
                self.obj.output = None
            else:
                self.obj.output = arg
            self.dashboard.redisplay()

    class EnabledCommand(gdb.Command):

        def __init__(self, dashboard):
            gdb.Command.__init__(self, "dashboard -enabled", gdb.COMMAND_USER)
            self.dashboard = dashboard

        def invoke(self, arg, from_tty):
            arg = Dashboard.parse_arg(arg)
            if arg == "":
                status = "enabled" if self.dashboard.enabled else "disabled"
                print(f"The dashboard is {status}")
            elif arg == "on":
                self.dashboard.enable()
                self.dashboard.redisplay()
            elif arg == "off":
                self.dashboard.disable()
            else:
                msg = 'Wrong argument "{}"; expecting "on" or "off"'
                Dashboard.err(msg.format(arg))

        def complete(self, text, word):
            return Dashboard.complete(word, ["on", "off"])

    class LayoutCommand(gdb.Command):

        def __init__(self, dashboard):
            gdb.Command.__init__(self, "dashboard -layout", gdb.COMMAND_USER)
            self.dashboard = dashboard

        def invoke(self, arg, from_tty):
            arg = Dashboard.parse_arg(arg)
            directives = str(arg).split()
            if directives:
                if directives == ["!"]:
                    self.reset()
                else:
                    if not self.layout(directives):
                        return
                if from_tty:
                    if self.dashboard.is_running():
                        self.dashboard.redisplay()
                    else:
                        self.show()
            else:
                self.show()

        def reset(self):
            modules = self.dashboard.modules
            modules.sort(key=lambda module: module.name)
            for module in modules:
                module.enabled = True

        def show(self):
            global_str = "Dashboard"
            default = "(default TTY)"
            max_name_len = max(len(module.name) for module in self.dashboard.modules)
            max_name_len = max(max_name_len, len(global_str))
            fmt = f"{{}}{{:{max_name_len + 2}s}}{{}}"
            print(
                (fmt + "\n").format(" ", global_str, self.dashboard.output or default)
            )
            for module in self.dashboard.modules:
                mark = " " if module.enabled else "!"
                style = R.style_high if module.enabled else R.style_low
                line = fmt.format(mark, module.name, module.output or default)
                print(ansi(line, style))

        def layout(self, directives):
            modules = self.dashboard.modules
            parsed_directives = []
            selected_modules = set()
            for directive in directives:
                enabled = directive[0] != "!"
                name = directive[not enabled :]
                if name in selected_modules:
                    Dashboard.err(f'Module "{name}" already set')
                    return False
                if next((False for module in modules if module.name == name), True):
                    Dashboard.err(f'Cannot find module "{name}"')
                    return False
                parsed_directives.append((name, enabled))
                selected_modules.add(name)
            for module in modules:
                module.enabled = False
            for last, (name, enabled) in enumerate(parsed_directives):
                todo = enumerate(modules[last:], start=last)
                index = next(index for index, module in todo if name == module.name)
                modules[index].enabled = enabled
                modules.insert(last, modules.pop(index))
            return True

        def complete(self, text, word):
            all_modules = (m.name for m in self.dashboard.modules)
            return Dashboard.complete(word, all_modules)

    class StyleCommand(gdb.Command):

        def __init__(self, dashboard, prefix, obj, attributes):
            self.prefix = prefix + " -style"
            gdb.Command.__init__(
                self, self.prefix, gdb.COMMAND_USER, gdb.COMPLETE_NONE, True
            )
            self.dashboard = dashboard
            self.obj = obj
            self.attributes = attributes
            self.add_styles()

        def add_styles(self):
            this = self
            for name, attribute in self.attributes.items():
                attr_name = attribute.get("name", name)
                attr_type = attribute.get("type", str)
                attr_check = attribute.get("check", lambda _: True)
                attr_default = attribute["default"]
                value = attr_type(attr_default)
                setattr(self.obj, attr_name, value)

                def invoke(
                    self,
                    arg,
                    from_tty,
                    name=name,
                    attr_name=attr_name,
                    attr_type=attr_type,
                    attr_check=attr_check,
                ):
                    new_value = Dashboard.parse_arg(arg)
                    if new_value == "":
                        value = getattr(this.obj, attr_name)
                        print(f"{name} = {value!r}")
                    else:
                        try:
                            parsed = ast.literal_eval(new_value)
                            value = attr_type(parsed)
                            if not attr_check(value):
                                msg = 'Invalid value "{}" for "{}"'
                                raise Exception(msg.format(new_value, name))
                        except Exception as e:
                            Dashboard.err(e)
                        else:
                            setattr(this.obj, attr_name, value)
                            this.dashboard.redisplay(True)

                prefix = self.prefix + " " + name
                doc = attribute.get("doc", "This style is self-documenting")
                Dashboard.create_command(prefix, invoke, doc, False)

        def invoke(self, arg, from_tty):
            if arg:
                Dashboard.err(f'Invalid argument "{arg}"')
                return
            for name, attribute in self.attributes.items():
                attr_name = attribute.get("name", name)
                value = getattr(self.obj, attr_name)
                print(f"{name} = {value!r}")

    class Module:

        def label(self):
            pass

        def lines(self, term_width, term_height, style_changed):
            pass

        def attributes(self):
            return {}

        def commands(self):
            return {}


class Source(Dashboard.Module):

    def __init__(self):
        self.file_name = None
        self.source_lines = []
        self.ts = None
        self.highlighted = False
        self.offset = 0

    def label(self):
        label = "Source"
        if self.show_path and self.file_name:
            label += f": {self.file_name}"
        return label

    def lines(self, term_width, term_height, style_changed):
        if not gdb.selected_thread().is_stopped():
            return []
        sal = gdb.selected_frame().find_sal()
        current_line = sal.line
        if current_line == 0:
            self.file_name = None
            return []
        candidates = [
            sal.symtab.fullname(),
            sal.symtab.filename,
            os.path.basename(sal.symtab.filename),
        ]
        for candidate in candidates:
            file_name = candidate
            ts = None
            try:
                ts = os.path.getmtime(file_name)
                break
            except OSError:
                continue
        if style_changed or file_name != self.file_name or (ts and ts > self.ts):
            try:
                with open(file_name, errors="replace") as source_file:
                    highlighter = Beautifier(file_name, self.tab_size)
                    self.highlighted = highlighter.active
                    source = highlighter.process(source_file.read())
                    self.source_lines = source.split("\n")
                self.file_name = file_name
                self.ts = ts
            except OSError:
                msg = f'Cannot display "{file_name}"'
                return [ansi(msg, R.style_error)]
        height = self.height or (term_height - 1)
        start = current_line - 1 - int(height / 2) + self.offset
        end = start + height
        extra_start = 0
        if start < 0:
            extra_start = min(-start, height)
            start = 0
        extra_end = 0
        if end > len(self.source_lines):
            extra_end = min(end - len(self.source_lines), height)
            end = len(self.source_lines)
        else:
            end = max(end, 0)
        breakpoints = fetch_breakpoints()
        out = []
        number_format = f"{{:>{len(str(end))}}}"
        for number, line in enumerate(self.source_lines[start:end], start + 1):
            line = to_string(line)
            if int(number) == current_line:
                if R.ansi:
                    if self.highlighted and not self.highlight_line:
                        line_format = (
                            "{}" + ansi(number_format, R.style_selected_1) + "  {}"
                        )
                    else:
                        line_format = "{}" + ansi(
                            number_format + "  {}", R.style_selected_1
                        )
                else:
                    line_format = "{}" + number_format + "> {}"
            else:
                line_format = "{}" + ansi(number_format, R.style_low) + "  {}"
            enabled = None
            for breakpoint in breakpoints:
                addresses = breakpoint["addresses"]
                is_root_enabled = addresses[0]["enabled"]
                for address in addresses:
                    if (
                        address["file_line"] == number
                        and address["file_name"] == sal.symtab.filename
                    ):
                        enabled = enabled or (address["enabled"] and is_root_enabled)
            if enabled is None:
                breakpoint = " "
            else:
                breakpoint = (
                    ansi("!", R.style_critical) if enabled else ansi("-", R.style_low)
                )
            out.append(line_format.format(breakpoint, number, line.rstrip("\n")))
        if len(out) <= height:
            extra = [ansi("~", R.style_low)]
            return extra_start * extra + out + extra_end * extra
        else:
            return out

    def commands(self):
        return {
            "scroll": {
                "action": self.scroll,
                "doc": "Scroll by relative steps or reset if invoked without argument.",
            }
        }

    def attributes(self):
        return {
            "height": {
                "doc": """Height of the module.

A value of 0 uses the whole height.""",
                "default": 10,
                "type": int,
                "check": check_ge_zero,
            },
            "tab-size": {
                "doc": "Number of spaces used to display the tab character.",
                "default": 4,
                "name": "tab_size",
                "type": int,
                "check": check_gt_zero,
            },
            "path": {
                "doc": "Path visibility flag in the module label.",
                "default": False,
                "name": "show_path",
                "type": bool,
            },
            "highlight-line": {
                "doc": "Decide whether the whole current line should be highlighted.",
                "default": False,
                "name": "highlight_line",
                "type": bool,
            },
        }

    def scroll(self, arg):
        if arg:
            self.offset += int(arg)
        else:
            self.offset = 0


class Assembly(Dashboard.Module):

    def __init__(self):
        self.offset = 0
        self.cache_key = None
        self.cache_asm = None

    def label(self):
        return "Assembly"

    def lines(self, term_width, term_height, style_changed):
        if not gdb.selected_thread().is_stopped():
            return []
        if style_changed:
            self.cache_key = None
        try:
            flavor = gdb.parameter("disassembly-flavor")
        except (gdb.error, RuntimeError):
            flavor = "att"
        highlighter = Beautifier(flavor, tab_size=None)
        line_info = None
        frame = gdb.selected_frame()
        height = self.height or (term_height - 1)
        try:
            asm_start, asm_end = self.fetch_function_boundaries()
            asm = self.fetch_asm(asm_start, asm_end, False, highlighter)
            pc_index = next(
                index for index, instr in enumerate(asm) if instr["addr"] == frame.pc()
            )
            start = pc_index - int(height / 2) + self.offset
            end = start + height
            extra_start = 0
            if start < 0:
                extra_start = min(-start, height)
                start = 0
            extra_end = 0
            if end > len(asm):
                extra_end = min(end - len(asm), height)
                end = len(asm)
            else:
                end = max(end, 0)
            asm = asm[start:end]
            line_info = gdb.find_pc_line(frame.pc())
            line_info = line_info if line_info.last else None
        except (gdb.error, RuntimeError, StopIteration):
            try:
                extra_start = 0
                extra_end = 0
                clamped_offset = min(self.offset, 0)
                asm = self.fetch_asm(
                    frame.pc(), height - clamped_offset, True, highlighter
                )
                asm = asm[-clamped_offset:]
            except gdb.error as e:
                msg = f"{e}"
                return [ansi(msg, R.style_error)]
        func_start = None
        if self.show_function and frame.function():
            func_start = to_unsigned(frame.function().value())
        if asm and func_start:
            max_offset = max(
                len(str(abs(asm[0]["addr"] - func_start))),
                len(str(abs(asm[-1]["addr"] - func_start))),
            )
        breakpoints = fetch_breakpoints()
        max_length = max(instr["length"] for instr in asm) if asm else 0
        inferior = gdb.selected_inferior()
        out = []
        for instr in asm:
            addr = instr["addr"]
            length = instr["length"]
            text = instr["asm"]
            addr_str = format_address(addr)
            if self.show_opcodes:
                region = inferior.read_memory(addr, length)
                opcodes = " ".join(f"{ord(byte):02x}" for byte in region)
                opcodes += (max_length - len(region)) * 3 * " " + "  "
            else:
                opcodes = ""
            if self.show_function:
                if func_start:
                    offset = f"{addr - func_start:+d}"
                    offset = offset.ljust(max_offset + 1)
                    func_info = f"{frame.function()}{offset}"
                else:
                    func_info = "?"
            else:
                func_info = ""
            format_string = "{}{}{}{}{}{}"
            indicator = "  "
            text = " " + text
            if addr == frame.pc():
                if not R.ansi:
                    indicator = "> "
                addr_str = ansi(addr_str, R.style_selected_1)
                indicator = ansi(indicator, R.style_selected_1)
                opcodes = ansi(opcodes, R.style_selected_1)
                func_info = ansi(func_info, R.style_selected_1)
                if not highlighter.active or self.highlight_line:
                    text = ansi(text, R.style_selected_1)
            elif line_info and line_info.pc <= addr < line_info.last:
                if not R.ansi:
                    indicator = ": "
                addr_str = ansi(addr_str, R.style_selected_2)
                indicator = ansi(indicator, R.style_selected_2)
                opcodes = ansi(opcodes, R.style_selected_2)
                func_info = ansi(func_info, R.style_selected_2)
                if not highlighter.active or self.highlight_line:
                    text = ansi(text, R.style_selected_2)
            else:
                addr_str = ansi(addr_str, R.style_low)
                func_info = ansi(func_info, R.style_low)
            enabled = None
            for breakpoint in breakpoints:
                addresses = breakpoint["addresses"]
                is_root_enabled = addresses[0]["enabled"]
                for address in addresses:
                    if address["address"] == addr:
                        enabled = enabled or (address["enabled"] and is_root_enabled)
            if enabled is None:
                breakpoint = " "
            else:
                breakpoint = (
                    ansi("!", R.style_critical) if enabled else ansi("-", R.style_low)
                )
            out.append(
                format_string.format(
                    breakpoint, addr_str, indicator, opcodes, func_info, text
                )
            )
        if len(out) <= height:
            extra = [ansi("~", R.style_low)]
            return extra_start * extra + out + extra_end * extra
        else:
            return out

    def commands(self):
        return {
            "scroll": {
                "action": self.scroll,
                "doc": "Scroll by relative steps or reset if invoked without argument.",
            }
        }

    def attributes(self):
        return {
            "height": {
                "doc": """Height of the module.

A value of 0 uses the whole height.""",
                "default": 10,
                "type": int,
                "check": check_ge_zero,
            },
            "opcodes": {
                "doc": "Opcodes visibility flag.",
                "default": False,
                "name": "show_opcodes",
                "type": bool,
            },
            "function": {
                "doc": "Function information visibility flag.",
                "default": True,
                "name": "show_function",
                "type": bool,
            },
            "highlight-line": {
                "doc": "Decide whether the whole current line should be highlighted.",
                "default": False,
                "name": "highlight_line",
                "type": bool,
            },
        }

    def scroll(self, arg):
        if arg:
            self.offset += int(arg)
        else:
            self.offset = 0

    def fetch_function_boundaries(self):
        frame = gdb.selected_frame()
        disassemble = run("disassemble")
        for block_start, block_end in re.findall(
            r"Address range 0x([0-9a-f]+) to 0x([0-9a-f]+):", disassemble
        ):
            block_start = int(block_start, 16)
            block_end = int(block_end, 16)
            if block_start <= frame.pc() < block_end:
                return block_start, block_end - 1
        block = frame.block()
        if frame.function():
            while block and (
                not block.function or block.function.name != frame.function().name
            ):
                block = block.superblock
            block = block or frame.block()
        return block.start, block.end - 1

    def fetch_asm(self, start, end_or_count, relative, highlighter):
        if self.cache_key == (start, end_or_count):
            asm = self.cache_asm
        else:
            kwargs = {
                "start_pc": start,
                "count" if relative else "end_pc": end_or_count,
            }
            asm = gdb.selected_frame().architecture().disassemble(**kwargs)
            self.cache_key = (start, end_or_count)
            self.cache_asm = asm
            for instr in asm:
                instr["asm"] = highlighter.process(instr["asm"])
        return asm


class Variables(Dashboard.Module):

    def __init__(self):
        self.previous_values = {}

    def label(self):
        return "Variables"

    def lines(self, term_width, term_height, style_changed):
        return Variables.format_frame(
            gdb.selected_frame(),
            self.show_arguments,
            self.show_locals,
            self.compact,
            self.align,
            self.sort,
            self,
        )

    def attributes(self):
        return {
            "arguments": {
                "doc": "Frame arguments visibility flag.",
                "default": True,
                "name": "show_arguments",
                "type": bool,
            },
            "locals": {
                "doc": "Frame locals visibility flag.",
                "default": True,
                "name": "show_locals",
                "type": bool,
            },
            "compact": {
                "doc": "Single-line display flag.",
                "default": True,
                "type": bool,
            },
            "align": {
                "doc": "Align variables in column flag (only if not compact).",
                "default": False,
                "type": bool,
            },
            "sort": {"doc": "Sort variables by name.", "default": False, "type": bool},
        }

    @staticmethod
    def format_frame(frame, show_arguments, show_locals, compact, align, sort, myself):
        out = []
        decorator = gdb.FrameDecorator.FrameDecorator(frame)
        separator = ansi(", ", R.style_low)
        if show_arguments:

            def prefix(line):
                return Stack.format_line("arg", line)

            frame_args = decorator.frame_args()
            args_lines = Variables.fetch(
                frame, frame_args, compact, align, sort, myself
            )
            if args_lines:
                if compact:
                    args_line = separator.join(args_lines)
                    single_line = prefix(args_line)
                    out.append(single_line)
                else:
                    out.extend(map(prefix, args_lines))
        if show_locals:

            def prefix(line):
                return Stack.format_line("loc", line)

            frame_locals = decorator.frame_locals()
            locals_lines = Variables.fetch(
                frame, frame_locals, compact, align, sort, myself
            )
            if locals_lines:
                if compact:
                    locals_line = separator.join(locals_lines)
                    single_line = prefix(locals_line)
                    out.append(single_line)
                else:
                    out.extend(map(prefix, locals_lines))
        return out

    @staticmethod
    def fetch(frame, data, compact, align, sort, myself):
        lines = []
        name_width = 0
        if align and not compact:
            name_width = max(len(str(elem.sym)) for elem in data) if data else 0
        for elem in data or []:
            raw_name = str(elem.sym)
            name = ansi(elem.sym, R.style_high) + " " * (name_width - len(raw_name))
            equal = ansi("=", R.style_low)
            value = format_value(elem.sym.value(frame), compact)
            changed = myself and (myself.previous_values.get(raw_name, "") != value)
            if myself:
                myself.previous_values[raw_name] = value
            style = R.style_selected_1 if changed else ""
            lines.append(f"{name} {equal} {ansi(value, style)}")
        if sort:
            lines.sort()
        return lines


class Stack(Dashboard.Module):

    def label(self):
        return "Stack"

    def lines(self, term_width, term_height, style_changed):
        if not gdb.selected_thread().is_stopped():
            return []
        start_level = 0
        frame = gdb.newest_frame()
        while frame:
            if frame == gdb.selected_frame():
                break
            frame = frame.older()
            start_level += 1
        more = False
        frames = [gdb.selected_frame()]
        going_down = True
        while True:
            if len(frames) == self.limit:
                more = True
                break
            if going_down:
                frame = frames[-1].older()
                if frame:
                    frames.append(frame)
                else:
                    frame = frames[0].newer()
                    if frame:
                        frames.insert(0, frame)
                        start_level -= 1
                    else:
                        break
            else:
                frame = frames[0].newer()
                if frame:
                    frames.insert(0, frame)
                    start_level -= 1
                else:
                    frame = frames[-1].older()
                    if frame:
                        frames.append(frame)
                    else:
                        break
            going_down = not going_down
        lines = []
        for number, frame in enumerate(frames, start=start_level):
            selected = frame == gdb.selected_frame()
            lines.extend(self.get_frame_lines(number, frame, selected))
        if more:
            lines.append("[{}]".format(ansi("+", R.style_selected_2)))
        return lines

    def attributes(self):
        return {
            "limit": {
                "doc": "Maximum number of displayed frames (0 means no limit).",
                "default": 10,
                "type": int,
                "check": check_ge_zero,
            },
            "arguments": {
                "doc": "Frame arguments visibility flag.",
                "default": False,
                "name": "show_arguments",
                "type": bool,
            },
            "locals": {
                "doc": "Frame locals visibility flag.",
                "default": False,
                "name": "show_locals",
                "type": bool,
            },
            "compact": {
                "doc": "Single-line display flag.",
                "default": False,
                "type": bool,
            },
            "align": {
                "doc": "Align variables in column flag (only if not compact).",
                "default": False,
                "type": bool,
            },
            "sort": {"doc": "Sort variables by name.", "default": False, "type": bool},
        }

    def get_frame_lines(self, number, frame, selected=False):
        style = R.style_selected_1 if selected else R.style_selected_2
        frame_id = ansi(str(number), style)
        info = Stack.get_pc_line(frame, style)
        frame_lines = []
        frame_lines.append(f"[{frame_id}] {info}")
        variables = Variables.format_frame(
            frame,
            self.show_arguments,
            self.show_locals,
            self.compact,
            self.align,
            self.sort,
            False,
        )
        frame_lines.extend(variables)
        return frame_lines

    @staticmethod
    def format_line(prefix, line):
        prefix = ansi(prefix, R.style_low)
        return f"{prefix} {line}"

    @staticmethod
    def get_pc_line(frame, style):
        frame_pc = ansi(format_address(frame.pc()), style)
        info = f"from {frame_pc}"
        if frame.function():
            name = ansi(frame.function(), style)
            func_start = to_unsigned(frame.function().value())
            offset = ansi(str(frame.pc() - func_start), style)
            info += f" in {name}+{offset}"
        elif frame.name():
            name = ansi(frame.name(), style)
            info += f" in {name}"
        sal = frame.find_sal()
        if sal and sal.symtab:
            file_name = ansi(sal.symtab.filename, style)
            file_line = ansi(str(sal.line), style)
            info += f" at {file_name}:{file_line}"
        return info


class History(Dashboard.Module):

    def label(self):
        return "History"

    def lines(self, term_width, term_height, style_changed):
        out = []
        for i in range(-self.limit + 1, 1):
            try:
                value = format_value(gdb.history(i))
                value_id = ansi("$${}", R.style_high).format(abs(i))
                equal = ansi("=", R.style_low)
                line = f"{value_id} {equal} {value}"
                out.append(line)
            except gdb.error:
                continue
        return out

    def attributes(self):
        return {
            "limit": {
                "doc": "Maximum number of values to show.",
                "default": 3,
                "type": int,
                "check": check_gt_zero,
            }
        }


class Memory(Dashboard.Module):

    DEFAULT_LENGTH = 16

    class Region:
        def __init__(self, expression, length, module):
            self.expression = expression
            self.length = length
            self.module = module
            self.original = None
            self.latest = None

        def reset(self):
            self.original = None
            self.latest = None

        def format(self, per_line):
            try:
                address = Memory.parse_as_address(self.expression)
                inferior = gdb.selected_inferior()
                memory = inferior.read_memory(address, self.length)
                if not self.original:
                    self.original = memory
            except gdb.error as e:
                msg = "Cannot access {} bytes starting at {}: {}"
                msg = msg.format(self.length, self.expression, e)
                return [ansi(msg, R.style_error)]
            out = []
            for i in range(0, len(memory), per_line):
                region = memory[i : i + per_line]
                pad = per_line - len(region)
                address_str = format_address(address + i)
                hexa = []
                text = []
                for j in range(len(region)):
                    rel = i + j
                    byte = memory[rel]
                    hexa_byte = f"{ord(byte):02x}"
                    text_byte = self.module.format_byte(byte)
                    if self.latest and memory[rel] != self.latest[rel]:
                        hexa_byte = ansi(hexa_byte, R.style_selected_1)
                        text_byte = ansi(text_byte, R.style_selected_1)
                    elif self.module.cumulative and memory[rel] != self.original[rel]:
                        hexa_byte = ansi(hexa_byte, R.style_selected_2)
                        text_byte = ansi(text_byte, R.style_selected_2)
                    else:
                        text_byte = ansi(text_byte, R.style_high)
                    hexa.append(hexa_byte)
                    text.append(text_byte)
                hexa_placeholder = f" {self.module.placeholder[0] * 2}"
                text_placeholder = self.module.placeholder[0]
                out.append(
                    "{}  {}{}  {}{}".format(
                        ansi(address_str, R.style_low),
                        " ".join(hexa),
                        ansi(pad * hexa_placeholder, R.style_low),
                        "".join(text),
                        ansi(pad * text_placeholder, R.style_low),
                    )
                )
            self.latest = memory
            return out

    def __init__(self):
        self.table = {}

    def label(self):
        return "Memory"

    def lines(self, term_width, term_height, style_changed):
        out = []
        for expression, region in self.table.items():
            out.append(divider(term_width, expression))
            out.extend(region.format(self.get_per_line(term_width)))
        return out

    def commands(self):
        return {
            "watch": {
                "action": self.watch,
                "doc": """Watch a memory region by expression and length.

The length defaults to 16 bytes.""",
                "complete": gdb.COMPLETE_EXPRESSION,
            },
            "unwatch": {
                "action": self.unwatch,
                "doc": "Stop watching a memory region by expression.",
                "complete": gdb.COMPLETE_EXPRESSION,
            },
            "clear": {"action": self.clear, "doc": "Clear all the watched regions."},
        }

    def attributes(self):
        return {
            "cumulative": {
                "doc": "Highlight changes cumulatively, watch again to reset.",
                "default": False,
                "type": bool,
            },
            "full": {
                "doc": "Take the whole horizontal space.",
                "default": False,
                "type": bool,
            },
            "placeholder": {
                "doc": "Placeholder used for missing items and unprintable characters.",
                "default": "·",
            },
        }

    def watch(self, arg):
        if arg:
            expression, _, length_str = arg.partition(" ")
            length = (
                Memory.parse_as_address(length_str)
                if length_str
                else Memory.DEFAULT_LENGTH
            )
            region = self.table.get(expression)
            if region and not length_str:
                region.reset()
            else:
                self.table[expression] = Memory.Region(expression, length, self)
        else:
            raise Exception("Specify a memory location")

    def unwatch(self, arg):
        if arg:
            try:
                del self.table[arg]
            except KeyError as e:
                raise Exception("Memory expression not watched") from e
        else:
            raise Exception("Specify a matched memory expression")

    def clear(self, arg):
        self.table.clear()

    def format_byte(self, byte):
        if 0x20 < ord(byte) < 0x7F:
            return chr(ord(byte))
        else:
            return self.placeholder[0]

    def get_per_line(self, term_width):
        if self.full:
            padding = 3
            elem_size = 4
            address_length = gdb.parse_and_eval("$pc").type.sizeof * 2 + 2
            return max(int((term_width - address_length - padding) / elem_size), 1)
        else:
            return Memory.DEFAULT_LENGTH

    @staticmethod
    def parse_as_address(expression):
        value = gdb.parse_and_eval(expression)
        return to_unsigned(value)


class Registers(Dashboard.Module):

    def __init__(self):
        self.table = {}

    def label(self):
        return "Registers"

    def lines(self, term_width, term_height, style_changed):
        if not gdb.selected_thread().is_stopped():
            return []
        if style_changed:
            self.table = {}
        if self.register_list:
            register_list = self.register_list.split()
        else:
            register_list = Registers.fetch_register_list()
        registers = []
        for name in register_list:
            if "." in name:
                continue
            value = gdb.parse_and_eval(f"${name}")
            string_value = Registers.format_value(value)
            if string_value == "<unavailable>":
                continue
            changed = self.table and (self.table.get(name, "") != string_value)
            self.table[name] = string_value
            registers.append((name, string_value, changed))
        if not registers:
            msg = 'No registers to show (check the "dashboard registers -style list" attribute)'
            return [ansi(msg, R.style_error)]
        max_name = max(len(name) for name, _, _ in registers)
        max_value = max(len(value) for _, value, _ in registers)
        max_width = max_name + max_value + 2
        columns = min(int((term_width - 1) / max_width) or 1, len(registers))
        rows = math.ceil(len(registers) / columns)
        if self.column_major:
            matrix = [registers[i : i + rows] for i in range(0, len(registers), rows)]
        else:
            matrix = [registers[i::columns] for i in range(columns)]
        max_names_column = [
            max(len(name) for name, _, _ in column) for column in matrix
        ]
        max_values_column = [
            max(len(value) for _, value, _ in column) for column in matrix
        ]
        line_length = sum(max_names_column) + columns + sum(max_values_column)
        extra = term_width - line_length
        base_padding = int(extra / (columns + 1))
        padding_column = [base_padding] * columns
        rest = extra % (columns + 1)
        while rest:
            padding_column[rest % columns] += 1
            rest -= 1
        out = [""] * rows
        for i, column in enumerate(matrix):
            max_name = max_names_column[i]
            max_value = max_values_column[i]
            for j, (name, value, changed) in enumerate(column):
                name = " " * (max_name - len(name)) + ansi(name, R.style_low)
                style = R.style_selected_1 if changed else ""
                value = ansi(value, style) + " " * (max_value - len(value))
                padding = " " * padding_column[i]
                item = f"{padding}{name} {value}"
                out[j] += item
        return out

    def attributes(self):
        return {
            "column-major": {
                "doc": "Show registers in columns instead of rows.",
                "default": False,
                "name": "column_major",
                "type": bool,
            },
            "list": {
                "doc": """String of space-separated register names to display.

The empty list (default) causes to show all the available registers. For
architectures different from x86 setting this attribute might be mandatory.""",
                "default": "",
                "name": "register_list",
            },
        }

    @staticmethod
    def format_value(value):
        try:
            if value.type.code in [gdb.TYPE_CODE_INT, gdb.TYPE_CODE_PTR]:
                int_value = to_unsigned(value, value.type.sizeof)
                value_format = f"0x{{:0{2 * value.type.sizeof}x}}"
                return value_format.format(int_value)
        except (gdb.error, ValueError):
            pass
        return str(value)

    @staticmethod
    def fetch_register_list(*match_groups):
        names = []
        for line in run("maintenance print register-groups").split("\n"):
            fields = line.split()
            if len(fields) != 7:
                continue
            name, _, _, _, _, _, groups = fields
            if not re.match(r"\w", name):
                continue
            for group in groups.split(","):
                if group in (match_groups or ("general",)):
                    names.append(name)
                    break
        return names


class Threads(Dashboard.Module):

    def label(self):
        return "Threads"

    def lines(self, term_width, term_height, style_changed):
        out = []
        selected_thread = gdb.selected_thread()
        restore_frame = gdb.selected_thread().is_stopped()
        if restore_frame:
            selected_frame = gdb.selected_frame()
        threads = []
        for inferior in gdb.inferiors():
            if self.all_inferiors or inferior == gdb.selected_inferior():
                threads += gdb.Inferior.threads(inferior)
        for thread in threads:
            if self.skip_running and thread.is_running():
                continue
            is_selected = thread.ptid == selected_thread.ptid
            style = R.style_selected_1 if is_selected else R.style_selected_2
            if self.all_inferiors:
                number = f"{thread.inferior.num}.{thread.num}"
            else:
                number = str(thread.num)
            number = ansi(number, style)
            tid = ansi(str(thread.ptid[1] or thread.ptid[2]), style)
            info = f"[{number}] id {tid}"
            if thread.name:
                info += f" name {ansi(thread.name, style)}"
            try:
                thread.switch()
                frame = gdb.newest_frame()
                info += " " + Stack.get_pc_line(frame, style)
            except gdb.error:
                info += " (running)"
            out.append(info)
        selected_thread.switch()
        if restore_frame:
            selected_frame.select()
        return out

    def attributes(self):
        return {
            "skip-running": {
                "doc": "Skip running threads.",
                "default": False,
                "name": "skip_running",
                "type": bool,
            },
            "all-inferiors": {
                "doc": "Show threads from all inferiors.",
                "default": False,
                "name": "all_inferiors",
                "type": bool,
            },
        }


class Expressions(Dashboard.Module):

    def __init__(self):
        self.table = []

    def label(self):
        return "Expressions"

    def lines(self, term_width, term_height, style_changed):
        out = []
        label_width = 0
        if self.align:
            label_width = (
                max(len(expression) for expression in self.table) if self.table else 0
            )
        default_radix = Expressions.get_default_radix()
        for number, expression in enumerate(self.table, start=1):
            label = expression
            match = re.match(r"^/(\d+) +(.+)$", expression)
            try:
                if match:
                    radix, expression = match.groups()
                    run(f"set output-radix {radix}")
                value = format_value(gdb.parse_and_eval(expression))
            except gdb.error as e:
                value = ansi(e, R.style_error)
            finally:
                if match:
                    run(f"set output-radix {default_radix}")
            number = ansi(str(number), R.style_selected_2)
            label = ansi(expression, R.style_high) + " " * (
                label_width - len(expression)
            )
            equal = ansi("=", R.style_low)
            out.append(f"[{number}] {label} {equal} {value}")
        return out

    def commands(self):
        return {
            "watch": {
                "action": self.watch,
                "doc": "Watch an expression using the format `[/<radix>] <expression>`.",
                "complete": gdb.COMPLETE_EXPRESSION,
            },
            "unwatch": {
                "action": self.unwatch,
                "doc": "Stop watching an expression by index.",
            },
            "clear": {
                "action": self.clear,
                "doc": "Clear all the watched expressions.",
            },
        }

    def attributes(self):
        return {
            "align": {
                "doc": "Align variables in column flag.",
                "default": False,
                "type": bool,
            }
        }

    def watch(self, arg):
        if arg:
            if arg not in self.table:
                self.table.append(arg)
            else:
                raise Exception("Expression already watched")
        else:
            raise Exception("Specify an expression")

    def unwatch(self, arg):
        if arg:
            try:
                number = int(arg) - 1
            except ValueError:
                number = -1
            if 0 <= number < len(self.table):
                self.table.pop(number)
            else:
                raise Exception("Expression not watched")
        else:
            raise Exception("Specify an expression")

    def clear(self, arg):
        self.table.clear()

    @staticmethod
    def get_default_radix():
        try:
            return gdb.parameter("output-radix")
        except RuntimeError:
            message = run("show output-radix")
            match = re.match(
                r"^Default output radix for printing of values is (\d+)\.$", message
            )
            return match.groups()[0] if match else 10


gdb.BP_CATCHPOINT = getattr(gdb, "BP_CATCHPOINT", 26)


class Breakpoints(Dashboard.Module):

    NAMES: ClassVar[dict] = {
        gdb.BP_BREAKPOINT: "break",
        gdb.BP_WATCHPOINT: "watch",
        gdb.BP_HARDWARE_WATCHPOINT: "write watch",
        gdb.BP_READ_WATCHPOINT: "read watch",
        gdb.BP_ACCESS_WATCHPOINT: "access watch",
        gdb.BP_CATCHPOINT: "catch",
    }

    def label(self):
        return "Breakpoints"

    def lines(self, term_width, term_height, style_changed):
        out = []
        breakpoints = fetch_breakpoints(watchpoints=True, pending=self.show_pending)
        for breakpoint in breakpoints:
            sub_lines = []
            style = R.style_selected_1 if breakpoint["enabled"] else R.style_selected_2
            number = ansi(breakpoint["number"], style)
            bp_type = ansi(Breakpoints.NAMES[breakpoint["type"]], style)
            if breakpoint["temporary"]:
                bp_type = bp_type + " {}".format(ansi("once", style))
            if not R.ansi and breakpoint["enabled"]:
                bp_type = "disabled " + bp_type
            line = f"[{number}] {bp_type}"
            if breakpoint["type"] == gdb.BP_BREAKPOINT:
                for i, address in enumerate(breakpoint["addresses"]):
                    addr = address["address"]
                    if i == 0 and addr:
                        line += f" at {ansi(format_address(addr), style)}"
                        file_name = address.get("file_name")
                        file_line = address.get("file_line")
                        if file_name and file_line:
                            file_name = ansi(file_name, style)
                            file_line = ansi(file_line, style)
                            line += f" in {file_name}:{file_line}"
                    elif i > 0:
                        sub_style = (
                            R.style_selected_1
                            if address["enabled"]
                            else R.style_selected_2
                        )
                        sub_number = ansi(
                            "{}.{}".format(breakpoint["number"], i), sub_style
                        )
                        sub_line = f"[{sub_number}]"
                        sub_line += f" at {ansi(format_address(addr), sub_style)}"
                        file_name = address.get("file_name")
                        file_line = address.get("file_line")
                        if file_name and file_line:
                            file_name = ansi(file_name, sub_style)
                            file_line = ansi(file_line, sub_style)
                            sub_line += f" in {file_name}:{file_line}"
                        sub_lines += [sub_line]
                location = breakpoint["location"]
                line += f" for {ansi(location, style)}"
            elif breakpoint["type"] == gdb.BP_CATCHPOINT:
                what = breakpoint["what"]
                line += f" {ansi(what, style)}"
            else:
                expression = breakpoint["expression"]
                line += f" for {ansi(expression, style)}"
            condition = breakpoint["condition"]
            if condition:
                line += f" if {ansi(condition, style)}"
            hit_count = breakpoint["hit_count"]
            if hit_count:
                word = "time{}".format("s" if hit_count > 1 else "")
                line += " hit {} {}".format(ansi(breakpoint["hit_count"], style), word)
            out.append(line)
            out.extend(sub_lines)
        return out

    def attributes(self):
        return {
            "pending": {
                "doc": "Also show pending breakpoints.",
                "default": True,
                "name": "show_pending",
                "type": bool,
            }
        }
