import re
import json


def markdownToDictionary(markdown):
    lines = markdown.strip().split("\n")
    tasks_dict = {}
    current_task = None
    current_subtask = None

    task_box = re.compile(r"^\[([x ])\]")
    subtask_box = re.compile(r"^\s{4}\[([x ])\]")
    task_idx = 1
    subtask_idx = 1
    for line in lines:
        match_task = task_box.match(line)
        match_subtask = subtask_box.match(line)

        if match_task:
            checked = match_task.group(1) == "x"
            task_name = line[4:].strip()
            current_task = {
                "title": task_name,
                "checked": checked,
                "subtasks": [],
                "note": "",
                "position": task_idx,
            }
            tasks_dict[task_name] = current_task
            task_idx += 1
            subtask_idx = 1
            current_subtask = None
        elif match_subtask:
            checked = match_subtask.group(1) == "x"
            subtask_name = line[8:].strip()
            current_subtask = {
                "title": subtask_name,
                "checked": checked,
                "note": "",
                "position": subtask_idx,
            }
            subtask_idx += 1
            if current_task:
                current_task["subtasks"].append(current_subtask)
        elif current_subtask:
            current_subtask["note"] += "\n" + line
        elif current_task:
            current_task["note"] += "\n" + line

    # Remove leading newlines from note and title fields
    for task in tasks_dict.values():
        task["note"] = task["note"].lstrip("\n")
        task["title"] = task["title"].lstrip("\n")
        for subtask in task["subtasks"]:
            subtask["note"] = subtask["note"].lstrip("\n")
            subtask["title"] = subtask["title"].lstrip("\n")

    return tasks_dict


def dictionaryToMarkdown(tasks_dict):
    markdown = ""
    for task_name, task_data in tasks_dict.items():
        checked = "x" if task_data["checked"] else " "
        markdown += f"[{checked}] {task_data['title']}\n"
        if task_data["note"]:
            markdown += f"{task_data['note']}\n"
        for subtask in task_data["subtasks"]:
            sub_checked = "x" if subtask["checked"] else " "
            markdown += f"    [{sub_checked}] {subtask['title']}\n"
            if subtask["note"]:
                markdown += f"{subtask['note']}\n"

    return markdown.strip()


markdown = """
[x] A task
    [ ] A subtask
        This is a note of subtask
    [ ] A subtasks
        This is a note of subtask
[] Another task without space in the box
note of the task but weird indent
[x] Final task
a
    [x] sub_checked
"""

tasks_dict = markdownToDictionary(markdown)
print(json.dumps(tasks_dict, indent=4))

markdown_o = dictionaryToMarkdown(tasks_dict)
print(markdown_o)

tasks_dict = markdownToDictionary(markdown_o)
print(json.dumps(tasks_dict, indent=4))

markdown_o = dictionaryToMarkdown(tasks_dict)
print(markdown_o)
CALENDAR_URL = 11
