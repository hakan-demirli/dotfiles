#!/usr/bin/env python3
import logging
import os
import pathlib
import random
import re
import signal
import string
import subprocess
import sys
import tempfile
import threading
import time
from queue import Queue

import clipboard
import requests
from gradio_client import Client

# sudo apt install xclip

logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)

TEMPO = 1  # 1.3
OUTPUT_DIR = tempfile.gettempdir()

script_dir = pathlib.Path(os.path.realpath(__file__)).parent.absolute()
MODEL_PATH = str(script_dir / "en_GB-jenny_dioco-medium.onnx")
RVC_API_URL = "http://127.0.0.1:7860/"
RVC_COMMAND = "/mnt/second/software/rvc_api/infer.py"  # ABS_PATH: fix pls
RVC_MODEL = "/mnt/second/software/rvc_api/weights/amber.pth"  # ABS_PATH: fix pls
RVC_INDEX = "/mnt/second/software/rvc_api/weights/amber.index"  # ABS_PATH: fix pls

GPU = True
RETRY_TIMES = 5
DELIMETERS = "[?.!]"
RAND_SIZE = 16
MAX_STR_SIZE = 20000
INFERENCE_TIMEOUT = 2.85
PLAY_TIMEOUT = 20
EXIT_TIMEOUT = 2
MIN_SPEED = 0.6
MAX_SPEED = 10
PREFERRED_SPEED = 1  # 1.7
DEFAULT_SPEED = 1
CUTOFF_DEFAULT = 0.35
CUTOFF = CUTOFF_DEFAULT / (TEMPO)
BANNED_CHARACTERS = """\\/*<>|`’[]()^#%&@:+=}"{'~“”"""
CONTRACTIONS = {
    "can't've": "cannot have",
    "'cause": "because",
    "could've": "could have",
    "couldn't've": "could not have",
    "didn't": "did not",
    "doesn't": "does not",
    "don't": "do not",
    "hadn't": "had not",
    "hadn't've": "had not have",
    "hasn't": "has not",
    "haven't": "have not",
    "he'd": "he would",
    "he'd've": "he would have",
    "he'll": "he will",
    "he'll've": "he will have",
    "he's": "he is",
    "how'd": "how did",
    "how'd'y": "how do you",
    "how'll": "how will",
    "how's": "how is",
    "I'd": "I would",
    "I'd've": "I would have",
    "I'll": "I will",
    "I'll've": "I will have",
    "I'm": "I am",
    "I've": "I have",
    "isn't": "is not",
    "it'd": "it would",
    "it'd've": "it would have",
    "it'll": "it will",
    "it'll've": "it will have",
    "it's": "it is",
    "let's": "let us",
    "mayn't": "may not",
    "might've": "might have",
    "mightn't": "might not",
    "mightn't've": "might not have",
    "must've": "must have",
    "mustn't": "must not",
    "mustn't've": "must not have",
    "needn't": "need not",
    "needn't've": "need not have",
    "o'clock": "of the clock",
    "oughtn't": "ought not",
    "oughtn't've": "ought not have",
    "shan't": "shall not",
    "sha'n't": "shall not",
    "shan't've": "shall not have",
    "she'd": "she would",
    "she'd've": "she would have",
    "she'll": "she will",
    "she'll've": "she will have",
    "she's": "she is",
    "should've": "should have",
    "shouldn't": "should not",
    "shouldn't've": "should not have",
    "so've": "so have",
    "so's": "so is",
    "that'd": "that would",
    "that'd've": "that would have",
    "that's": "that is",
    "there'd": "there would",
    "there'd've": "there would have",
    "there's": "there is",
    "they'd": "they would",
    "they'd've": "they would have",
    "they'll": "they will",
    "they'll've": "they will have",
    "they're": "they are",
    "they've": "they have",
    "to've": "to have",
    "wasn't": "was not",
    "we'd": "we had",
    "we'd've": "we would have",
    "we'll": "we will",
    "we'll've": "we will have",
    "we're": "we are",
    "what'll": "what will",
    "what'll've": "what will have",
    "what're": "what are",
    "what's": "what is",
    "what've": "what have",
    "when's": "when is",
    "when've": "when have",
    "where'd": "where did",
    "who'll": "who will",
    "who'll've": "who will have",
    "why's": "why has / why is",
    "why've": "why have",
    "will've": "will have",
    "won't": "will not",
    "won't've": "will not have",
    "would've": "would have",
    "wouldn't've": "would not have",
    "y'all": "you all",
    "y'all'd": "you all would",
    "y'all'd've": "you all would have",
    "y'all're": "you all are",
    "y'all've": "you all have",
    "you'd": "you would",
    "you'd've": "you would have",
    "you'll": "you will",
    "you'll've": "you will have",
    "you've": "you have",
    " multiline ": "multi line",
    "- ": "",
    " to ": " 2 ",
    " CPU ": " see pi you ",
    " CPU": " see pi you",
}


def retry(times):
    """
    Retry Decorator. Retries the wrapped function/method `times` times.
    """

    def decorator(func):
        def newfn(*args, **kwargs):
            attempt = 0
            while attempt < times:
                try:
                    return func(*args, **kwargs)
                except Exception:
                    logging.warning(
                        "Exception thrown when attempting to run %s, attempt "
                        "%d of %d" % (func, attempt, times)
                    )
                    attempt += 1
            return func(*args, **kwargs)

        return newfn

    return decorator


# @retry(times=RETRY_TIMES)
def tts_to_file(txt, file_path):
    command = f"echo '{txt}' | piper --output_file {file_path} --model {MODEL_PATH}"
    subprocess.run(command, shell=True)
    print(command)


def convert_txt_to_wav(txt_queue: Queue, wav_queue: Queue):
    t = threading.current_thread()
    while getattr(t, "do_run", True):
        txts = txt_queue.get()
        for txt in txts:
            letters = string.ascii_lowercase
            random_file_name = (
                "".join(random.choice(letters) for _ in range(32)) + ".wav"
            )
            file_path = OUTPUT_DIR + random_file_name
            t0 = threading.Thread(target=tts_to_file, args=[txt, file_path])
            t0.start()
            t0.join(INFERENCE_TIMEOUT)
            if not t0.is_alive():
                wav_queue.put(file_path)


def change_wav_speed(wav_file):
    letters = string.ascii_lowercase
    random_file_name = "".join(random.choice(letters) for _ in range(32)) + ".wav"

    o_path = OUTPUT_DIR + random_file_name
    try:
        command = ["ffmpeg", "-i", wav_file, "-filter:a", f"atempo={TEMPO}", o_path]
        print(" ".join(command))
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True,
        )
        print("Command output:", result.stdout)
    except subprocess.CalledProcessError as e:
        print("Error:", e)
    return o_path


def play_wav(wav_queue: Queue):
    t = threading.current_thread()
    while getattr(t, "do_run", True):
        wav_file = wav_queue.get()
        f_wav_file = wav_file
        if TEMPO != 1:
            f_wav_file = change_wav_speed(wav_file)
        try:
            subprocess.call(
                [
                    "ffplay",
                    "-nodisp",
                    "-autoexit",
                    "-t",
                    str(float(get_duration(f_wav_file)) - CUTOFF),
                    f_wav_file,
                ]
            )
        except Exception:
            pass

        try:
            os.remove(f_wav_file)
        except Exception:
            pass

        try:
            os.remove(wav_file)
        except Exception:
            pass


def get_duration(wav_file):
    result = subprocess.run(
        [
            "ffprobe",
            "-i",
            wav_file,
            "-show_entries",
            "format=duration",
            "-v",
            "quiet",
            "-of",
            "csv=p=0",
        ],
        capture_output=True,
        text=True,
    )
    duration = result.stdout.strip()
    return duration


def sanitizeString(in_str: str) -> str:
    for banned_character in BANNED_CHARACTERS:
        in_str = str(in_str).replace(banned_character, "")
    for key, value in CONTRACTIONS.items():
        in_str.replace(key, value)

    in_str = " ".join(in_str.splitlines())
    pattern = r"\d+\.\d+"
    floats = re.findall(pattern, in_str)
    for f in floats:
        in_str = in_str.replace(f, f.replace(".", " point "))

    logging.info(f"Value changed: {in_str}")
    in_str = in_str.replace("-\n", "")
    pattern = "- "
    in_str = in_str.replace(pattern, "")
    logging.info(f"Value changed again: {in_str}")
    return in_str


def listen_clipboard(txt_queue: Queue, wav_queue: Queue):
    t = threading.current_thread()
    recent_value = ""
    new_value = ""
    while getattr(t, "do_run", True):
        new_value = clipboard.paste()
        if (new_value != recent_value) and (len(new_value) < MAX_STR_SIZE):
            recent_value = new_value
            val = sanitizeString(new_value)
            logging.info(f"Value changed: {val}")
            txts = re.split(DELIMETERS, val)
            txts_clean = []
            for txt in txts:
                if (txt == "") or (txt == " "):
                    continue
                if txt[-1] not in DELIMETERS[1:-1]:
                    txt = txt + "."
                txts_clean.append(txt)
            txt_queue.queue.clear()
            wav_queue.queue.clear()
            txt_queue.put(txts_clean)
        time.sleep(0.8)


class GradioServer:
    def __init__(self, api_url, app_command, sleep_duration=10):
        self.api_url = api_url
        self.app_command = app_command
        self.sleep_duration = sleep_duration
        self.server_process = None

    def is_server_running(self):
        try:
            response = requests.get(self.api_url)
            return response.status_code == 200
        except requests.exceptions.ConnectionError:
            return False

    def launch_server(self):
        if not self.is_server_running():
            self.server_process = subprocess.Popen(self.app_command, shell=True)
            time.sleep(self.sleep_duration)
            print("Gradio app server launched.")
        else:
            print("Gradio app server is already running.")

    def stop_server(self):
        if self.server_process:
            try:
                os.killpg(os.getpgid(self.server_process.pid), signal.SIGTERM)
                self.server_process = None
                print("Gradio app server stopped.")
            except ProcessLookupError:
                print("Gradio app server process not found.")
        else:
            print("Gradio app server is not running.")


class GradioClient:
    def __init__(self, server_url):
        self.client = Client(server_url)

    def set_pth(self, config):
        self.client.predict(
            config[-1],  # weight
            config[-2],  # voice_protection
            fn_index=9,
        )

    def wav2wav(self, config):
        output_information, output_audio = self.client.predict(
            *config[:-1],  # Exclude the last (weight)
            fn_index=2,
        )
        return output_information, output_audio


def setup_rvc():
    server = GradioServer(RVC_API_URL, RVC_COMMAND)
    server.launch_server()


def apply_rvc(t2wav_queue: Queue, wav2wav_queue: Queue):
    t = threading.current_thread()
    counter = 0
    while True:
        try:
            client = GradioClient(RVC_API_URL)
            break
        except Exception:
            print("failed to connect. Trying again.")
            counter += 1
            if counter == 5:
                raise Exception("failed to connect: tried 5 times.")
            time.sleep(0.5)
    while getattr(t, "do_run", True):
        input_file = t2wav_queue.get()
        config = [
            0,  # speaker_id
            "Upload audio",  # input_voice
            input_file,  # input_audio_path
            input_file,  # upload_audio_file
            "",  # vocal_preview
            "",  # tts_text
            "",  # edgetts_speaker
            4,  # transpose
            input_file,  # f0_curve_file_optional
            "rmvpe",  # pitch_extraction_algorithm
            RVC_INDEX,  # list_of_index_file
            0.7,  # retrieval_feature_ratio
            3,  # apply_median_filtering
            0,  # resample_the_output_audio
            1,  # volume_envelope
            0.5,  # voice_protection
            RVC_MODEL,
        ]

        try:
            client.set_pth(config)
            _, output_audio = client.wav2wav(config)
            wav2wav_queue.put(output_audio)
        except Exception as e:
            print(f"An error occurred: {str(e)}")

        try:
            os.remove(input_file)
        except Exception:
            pass


if __name__ == "__main__":
    threads = []

    setup_rvc()
    txt_queue = Queue()
    t2wav_queue = Queue()
    wav2wav_queue = Queue()
    threads.append(
        threading.Thread(target=listen_clipboard, args=[txt_queue, t2wav_queue])
    )
    threads.append(
        threading.Thread(target=convert_txt_to_wav, args=[txt_queue, t2wav_queue])
    )
    threads.append(
        threading.Thread(target=apply_rvc, args=[t2wav_queue, wav2wav_queue])
    )

    threads.append(threading.Thread(target=play_wav, args=[wav2wav_queue]))
    for thread in threads:
        thread.start()

    toggle = False
    while True:
        try:
            time.sleep(1)
            command = input(str)
            if (command == "d") and (TEMPO < MAX_SPEED):
                TEMPO = TEMPO + 0.1
            if (command == "s") and (TEMPO > MIN_SPEED):
                TEMPO = TEMPO - 0.1
            if command == "g":
                toggle = not toggle
                if toggle:
                    TEMPO = PREFERRED_SPEED
                else:
                    TEMPO = DEFAULT_SPEED
            if (
                (command.isdigit())
                and (int(command, 10) > MIN_SPEED)
                and (int(command, 10) < MAX_SPEED)
            ):
                TEMPO = int(command, 10)
            logging.info(f"Tempo: {TEMPO}")
        except KeyboardInterrupt:
            logging.info("Ctrl+C pressed...")
            for thread in threads:
                thread.do_run = False
            for thread in threads:
                thread.join(EXIT_TIMEOUT)
            sys.exit(1)
