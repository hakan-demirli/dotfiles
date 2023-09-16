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
import asyncio
import logging
import os
from collections import defaultdict
from datetime import datetime
from enum import Enum, auto

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

from tasks import Task, TaskList, TaskStatus

CREDENTIALS_FILE = "credentials.json"
SCOPES = ["https://www.googleapis.com/auth/tasks"]


# https://googleapis.github.io/google-api-python-client/docs/dyn/tasks_v1.html
class GoogleApiService:
    def __init__(
        self,
        user: str,
        completed_after: datetime | None,
        completed_before: datetime | None,
        task_status: TaskStatus,
    ):
        self.user = user
        self.completed_after = completed_after
        self.completed_before = completed_before
        self.task_status = TaskStatus(task_status) if task_status else None
        self._service = None

    def tasks(self):
        return self._get_service().tasks()

    def task_lists(self):
        return self._get_service().tasklists()

    def new_batch_http_request(self):
        return self._get_service().new_batch_http_request()

    def fetch_task_lists(self) -> list[TaskList]:
        """
        Fetches all tasks from the server.

        At first the function fetches up to 100 task lists. Then it fetches all
        tasks for these task lists that are either completed at most 30 days ago
        or are still pending completion.
        """
        id_to_task_list = {}
        task_id_to_subtasks = defaultdict(list)

        def create_request_with_callback(task_list_id, completed):
            def fetch_tasks_request(task_list_id, completed, next_page_token=""):
                completed_max = ""
                completed_min = ""
                if completed:
                    if self.completed_before:
                        completed_max = self.completed_before.isoformat()
                    if self.completed_after:
                        completed_min = self.completed_after.isoformat()

                return self.tasks().list(
                    completedMax=completed_max,
                    completedMin=completed_min,
                    maxResults=100,
                    pageToken=next_page_token,
                    showCompleted=completed,
                    showHidden=completed,
                    tasklist=task_list_id,
                )

            def callback(_, response, exception):
                if exception:
                    logging.error(
                        f"Error on fetching Tasks from Task List {task_list_id}: {exception}"
                    )
                    return

                fetched_tasks = response.get("items", [])
                next_page_token = response.get("nextPageToken", "")
                while next_page_token:
                    response = fetch_tasks_request(
                        task_list_id, completed, next_page_token
                    )
                    fetched_tasks += response.get("items", [])
                    next_page_token = response.get("nextPageToken", "")

                for fetched_task in fetched_tasks:
                    task = Task(
                        fetched_task["id"],
                        fetched_task["title"].strip(),
                        fetched_task.get("notes", ""),
                        int(fetched_task["position"]),
                        TaskStatus(fetched_task.get("status", "unknown")),
                        [],
                    )

                    # If a task has a parent then it's definitely a subtask
                    # Subtask's parent might be incompleted so appending it
                    # to it must be deferred.
                    parent = fetched_task.get("parent", "")
                    if parent:
                        task_id_to_subtasks[parent].append(task)
                    else:
                        id_to_task_list[task_list_id].tasks.append(task)

            return fetch_tasks_request(task_list_id, completed), callback

        task_lists = self.task_lists().list(maxResults=100).execute().get("items", [])

        batched_request = self.new_batch_http_request()
        for task_list in task_lists:
            id = task_list["id"]
            id_to_task_list[id] = TaskList(id, task_list["title"], [])

            if not self.task_status or self.task_status == TaskStatus.PENDING:
                batched_request.add(*create_request_with_callback(id, False))
            if not self.task_status or self.task_status == TaskStatus.COMPLETED:
                batched_request.add(*create_request_with_callback(id, True))
        batched_request.execute()

        task_lists = list(id_to_task_list.values())
        task_lists.sort(key=lambda tl: tl.title)
        for task_list in task_lists:
            for task in task_list.tasks:
                task.subtasks = task_id_to_subtasks.get(task.id, [])
                task.subtasks.sort(key=lambda t: t.position)
            task_list.tasks.sort(key=lambda t: t.position)

        return task_lists

    # https://developers.google.com/tasks/quickstart/python#step_2_configure_the_sample
    def get_credentials(self) -> Credentials:
        """
        Read credentials from selected user configuration.

        This function will try to read existing token from
        config directory for the selected user. If file with
        the token doesn't exist, it will try creating a new one after reading
        credentials from config. If there are no credentials
        the process will simply fail.
        """
        creds = None

        config_dir = os.path.expanduser("~/.config/gtasks/")
        os.makedirs(os.path.dirname(config_dir), exist_ok=True)
        credentials_file = config_dir + CREDENTIALS_FILE
        token_file = config_dir + "token.json"
        # The file token.json stores the user's access and refresh tokens, and is
        # created automatically when the authorization flow completes for the first
        # time.
        if os.path.exists(token_file):
            creds = Credentials.from_authorized_user_file(token_file, SCOPES)
        # If there are no (valid) credentials available, let the user log in.
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                flow = InstalledAppFlow.from_client_secrets_file(
                    credentials_file, SCOPES
                )
                creds = flow.run_local_server(port=0)
            # Save the credentials for the next run
            with open(token_file, "w+") as token:
                token.write(creds.to_json())

        return creds

    def save_credentials(self, credentials: str):
        """Save credentials to selected user config directory."""
        config_dir = os.path.expanduser("~/.config/gtasks/")

        with open(f"{config_dir}/{CREDENTIALS_FILE}", "w+") as dest_file:
            dest_file.write(credentials)

    def _get_service(self):
        if not self._service:
            self._service = build("tasks", "v1", credentials=self.get_credentials())
        return self._service
