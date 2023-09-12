# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import argparse
import asyncio
import datetime
import logging
import os
import sys
import tempfile
from datetime import timedelta
import textwrap

from xdg import xdg_cache_home, xdg_data_home

import googleapi


# python cli.py auth /mnt/second/rep/personal_repo/secrets/credentials.json
def main():
    args = parse_args()

    config_dir = f"{xdg_data_home()}/gtasks-md/{args.user}/"
    os.makedirs(os.path.dirname(config_dir), exist_ok=True)
    cache_dir = f"{xdg_cache_home()}/gtasks-md/{args.user}/"
    os.makedirs(os.path.dirname(cache_dir), exist_ok=True)

    logging.basicConfig(
        filename=f"{xdg_cache_home()}/gtasks-md/log.txt",
        format="%(asctime)s %(levelname)-8s %(message)s",
        encoding="utf-8",
        level=logging.INFO,
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    service = googleapi.GoogleApiService(
        args.user, args.completed_after, args.completed_before, args.status
    )
    match args.subcommand:
        case "auth":
            auth(service, args.credentials_file)
        case "view":
            view_task_lists(service)
        case "fetch":
            fetch_task_lists(service)
        case None:
            print("Please run one of the subcommands.")


def parse_args():
    def parse_date(date):
        return datetime.datetime.strptime(date, "%Y-%m-%d").astimezone()

    # https://stackoverflow.com/a/49977713
    parser = argparse.ArgumentParser(description="Google Tasks declarative management.")
    parser.add_argument(
        "--completed-after",
        dest="completed_after",
        default=(datetime.datetime.now() - timedelta(days=7)).astimezone(),
        help="Only show tasks completed after given date. The date must be in format YYYY-MM-DD. Defaults to one week ago.",
        type=parse_date,
    )
    parser.add_argument(
        "--completed-before",
        dest="completed_before",
        default=None,
        help="Only show tasks completed before given date. The date must be in format YYYY-MM-DD.",
        type=lambda d: parse_date(d) if d else None,
    )
    parser.add_argument(
        "--status",
        dest="status",
        default="",
        help="Task status. One of: needsAction, completed.",
        type=str.lower,
    )
    parser.add_argument(
        "--user",
        dest="user",
        default="default",
        help="Account for which the credentials are sourced. Should match desired Google account.",
        type=str,
    )

    subparsers = parser.add_subparsers(dest="subcommand")

    auth = subparsers.add_parser("auth", help="Authorize.")
    auth.add_argument(
        "credentials_file",
        help="Location of credential file.",
        type=str,
    )

    subparsers.add_parser("fetch", help="fetch Google Tasks.")
    subparsers.add_parser("view", help="View Google Tasks.")

    return parser.parse_args()


def auth(service: googleapi.GoogleApiService, file: str):
    with open(file, "r") as src_file:
        service.save_credentials(src_file.read())


def fetch_task_lists(service: googleapi.GoogleApiService):
    task_lists = service.fetch_task_lists()
    # print(task_lists)
    OUTPUT_DIR = tempfile.gettempdir()
    with open(OUTPUT_DIR + "/gtasks.txt", "w") as f:
        for task_list in task_lists:
            for task in task_list.tasks:
                if task.completed():
                    continue
                print("- " + insert_newlines(task.title, line_length=33), file=f)
                for subtask in task.subtasks:
                    if task.completed():
                        continue
                    print(
                        "    * "
                        + insert_newlines(subtask.title, line_length=31, offset=6),
                        file=f,
                    )
                print("", file=f)


def insert_newlines(text, line_length=33, offset=0):
    lines = textwrap.wrap(text, line_length, break_long_words=False)
    if len(lines) > 1:
        indented_lines = [lines[0]] + [(offset * " ") + line for line in lines[1:]]
        return "\n".join(indented_lines)
    else:
        return text


def view_task_lists(service: googleapi.GoogleApiService):
    fetch_task_lists(service)
    OUTPUT_DIR = tempfile.gettempdir()
    with open(OUTPUT_DIR + "/gtasks.txt", "r") as f:
        for line in f:
            print(line)


if __name__ == "__main__":
    main()
