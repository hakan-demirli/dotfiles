#!/usr/bin/env python3

import json
import logging
import os
import queue
import random
import re
import string
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path
from subprocess import PIPE, CalledProcessError, Popen, run

import pyclip

# Configuration and Constants
logging.basicConfig(
    stream=sys.stderr,
    level=logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

CONFIG = {
    "TEMPO": 1.0,
    "OUTPUT_DIR": Path(os.getenv("XDG_RUNTIME_DIR", "/tmp")) / "piper",
    "PIPER_MODEL": Path(os.getenv("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    / "piper/models/jenny_dioco.onnx",
    "PIPER_CONFIG": Path(os.getenv("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    / "piper/models/jenny_dioco.json",
    "RVC_MODEL_PATH": Path(os.getenv("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    / "rvc-cli/models/custom/Pod042EN_e250_s14250.pth",
    "RVC_INDEX_PATH": Path(os.getenv("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    / "rvc-cli/models/custom/added_IVF2047_Flat_nprobe_1_Pod042EN_v2.index",
    "DELIMITERS": r"[?.!]",
    "RAND_SIZE": 16,
    "MAX_STR_SIZE": 20000,
    "BANNED_CHARACTERS": r"""\/*<>|`[]()^#%&@:+=}"{'~“”—""",
    "SUBSTITUTIONS": Path(os.getenv("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    / "piper/substitutions.json",
}


def get_random_string(length):
    random_str = "".join(random.choice(string.ascii_lowercase) for _ in range(length))
    logging.debug(f"Generated random string: {random_str}")
    return random_str


def sanitize_string(input_str):
    banned_characters = CONFIG["BANNED_CHARACTERS"]
    translation_table = str.maketrans("", "", banned_characters)
    input_str = input_str.translate(translation_table)

    substitutions_path = CONFIG["SUBSTITUTIONS"]
    if substitutions_path.exists():
        with open(substitutions_path, "r") as f:
            substitutions = json.load(f)
        for contraction, expanded in substitutions.items():
            input_str = input_str.replace(contraction, expanded)
    else:
        logging.warning(f"Substitutions file not found at {substitutions_path}")

    # Replace newlines with spaces
    input_str = " ".join(input_str.splitlines())

    # Replace floating point numbers
    input_str = re.sub(
        r"\d+\.\d+", lambda m: m.group(0).replace(".", " point "), input_str
    )

    logging.info(f"Sanitized string: {input_str}")
    return input_str


def text_to_speech_with_piper(text, output_file):
    try:
        run_args = [
            "piper",
            "--model",
            str(CONFIG["PIPER_MODEL"]),
            "--config",
            str(CONFIG["PIPER_CONFIG"]),
            "--output_file",
            str(output_file),
        ]
        run(
            run_args,
            input=text,
            text=True,
            check=True,
        )
        logging.info(f"Generated TTS output at {output_file}")
    except CalledProcessError as e:
        logging.error(f"Piper TTS failed for text: {text}. Error: {e}")
        raise


def apply_rvc_voice(input_file, output_file):
    try:
        run_args = [
            "rvc_cli",
            "infer",
            "--pth_path",
            str(CONFIG["RVC_MODEL_PATH"]),
            "--index_path",
            str(CONFIG["RVC_INDEX_PATH"]),
            "--input_path",
            str(input_file),
            "--output_path",
            str(output_file),
        ]
        run(
            run_args,
            check=True,
        )
        logging.info(f"Generated RVC output at {output_file}")
    except CalledProcessError as e:
        logging.error(f"RVC voice conversion failed for file: {input_file}. Error: {e}")
        raise


class BatchManager:
    def __init__(self):
        self.lock = threading.Lock()
        self.current_batch_id = None
        self.cancellation_event = threading.Event()
        self.executor = ThreadPoolExecutor(max_workers=4)  # limited by GPU VRAM
        self.playback_queue = queue.Queue()
        self.futures = []
        self.batch_counter = 0

        # Event to signal playback to terminate
        self.playback_terminate_event = threading.Event()

    def start_new_batch(self, sentences):
        with self.lock:
            self.batch_counter += 1
            new_batch_id = self.batch_counter
            logging.info(f"Starting new batch {new_batch_id}")

            # Signal cancellation to current processing
            self.cancellation_event.set()

            # Create a new cancellation event for the new batch
            self.cancellation_event = threading.Event()

            # Increment batch_id
            self.current_batch_id = new_batch_id

            # Cancel any existing futures
            for future in self.futures:
                future.cancel()
            self.futures = []

            # Signal playback to terminate current playback
            self.playback_terminate_event.set()

            # Clear any existing items in the playback queue
            with self.playback_queue.mutex:
                self.playback_queue.queue.clear()

            # Reset the playback termination event
            self.playback_terminate_event = threading.Event()

            # Submit new processing tasks
            for seq_num, sentence in enumerate(sentences):
                future = self.executor.submit(
                    self.process_sentence,
                    sentence,
                    seq_num,
                    new_batch_id,
                    self.cancellation_event,
                )
                self.futures.append(future)

    def process_sentence(self, sentence, seq_num, batch_id, cancellation_event):
        if cancellation_event.is_set():
            logging.info(f"Batch {batch_id} cancelled before processing started.")
            return
        try:
            logging.debug(f"Processing sentence {seq_num}: {sentence}")
            sanitized_text = sanitize_string(sentence)
            random_string = get_random_string(CONFIG["RAND_SIZE"])
            timestamp = datetime.now().strftime("%Y%m%d%H%M%S%f")

            temp_wav = (
                CONFIG["OUTPUT_DIR"]
                / f"{random_string}_temp_{batch_id}_{seq_num}_{timestamp}.wav"
            )
            final_wav = (
                CONFIG["OUTPUT_DIR"]
                / f"final_{batch_id}_{seq_num}_{random_string}_{timestamp}.wav"
            )

            text_to_speech_with_piper(sanitized_text, temp_wav)
            if cancellation_event.is_set():
                logging.info(f"Batch {batch_id} cancelled during TTS processing.")
                return
            apply_rvc_voice(temp_wav, final_wav)
            if cancellation_event.is_set():
                logging.info(f"Batch {batch_id} cancelled during RVC processing.")
                return

            self.playback_queue.put((batch_id, seq_num, final_wav))

            # Cleanup temporary file
            if temp_wav.exists():
                temp_wav.unlink()
        except Exception as e:
            logging.error(f"Error processing sentence {seq_num}: {e}")

    def get_playback_queue(self):
        return self.playback_queue

    def get_current_batch_id(self):
        with self.lock:
            return self.current_batch_id

    def stop(self):
        with self.lock:
            self.cancellation_event.set()
            self.playback_terminate_event.set()
            for future in self.futures:
                future.cancel()
            self.executor.shutdown(wait=False)
            logging.info("BatchManager stopped.")


def play_audio(playback_queue, get_current_batch_id, playback_terminate_event):
    """Plays audio files in sequence, respecting the current batch."""
    current_batch_id = None
    current_process = None
    buffers = {}
    next_seq = 0

    while True:
        try:
            # Wait for the next audio file
            batch_id, seq_num, wav_file = playback_queue.get()
            logging.debug(
                f"Received wav file {wav_file} for playback, batch_id: {batch_id}, seq_num: {seq_num}"
            )

            # If a new batch is detected, terminate the current playback
            if current_batch_id != batch_id:
                logging.info(f"Switching to new batch {batch_id}")
                current_batch_id = batch_id
                next_seq = 0
                buffers = {}

                # Signal to terminate any ongoing playback
                if current_process and current_process.poll() is None:
                    logging.info("Killing current playback process.")
                    current_process.kill()
                playback_terminate_event.clear()  # Reset termination event for the new batch

            # Queue the audio file for playback
            buffers[seq_num] = wav_file

            # Play files in order
            while next_seq in buffers:
                wav_path = buffers[next_seq]

                if wav_path.exists():
                    logging.info(f"Playing audio file: {wav_path}")

                    # Start ffplay asynchronously
                    current_process = Popen(
                        [
                            "ffplay",
                            "-autoexit",
                            "-nodisp",
                            "-hide_banner",
                            "-loglevel",
                            "error",
                            str(wav_path),
                        ],
                        stdout=PIPE,
                        stderr=PIPE,
                    )

                    # Monitor ffplay process
                    while True:
                        # Check if termination event is set
                        if playback_terminate_event.is_set():
                            logging.info(
                                "Termination event detected. Killing ffplay process."
                            )
                            current_process.kill()
                            break

                        # Check if ffplay process has finished
                        if current_process.poll() is not None:
                            break

                        time.sleep(0.1)  # Avoid busy waiting

                    # Cleanup played file
                    if wav_path.exists():
                        wav_path.unlink()
                    del buffers[next_seq]
                    next_seq += 1

                else:
                    logging.error(f"File {wav_path} does not exist.")
                    del buffers[next_seq]
                    next_seq += 1

        except Exception as e:
            logging.error(f"Error in play_audio: {e}")
            time.sleep(0.1)


def listen_clipboard(batch_manager):
    """Monitors the clipboard for changes and triggers new batch processing."""
    recent_value = ""
    while True:
        try:
            new_value = pyclip.paste(text=True).strip()
            if (
                new_value
                and new_value != recent_value
                and len(new_value) < CONFIG["MAX_STR_SIZE"]
            ):
                recent_value = new_value
                sanitized = sanitize_string(new_value)
                sentences = re.split(CONFIG["DELIMITERS"], sanitized)
                sentences = [s.strip() for s in sentences if s.strip()]
                if sentences:
                    logging.info("New clipboard content detected.")
                    batch_manager.start_new_batch(sentences)
            time.sleep(0.5)  # Polling interval
        except Exception as e:
            logging.error(f"Error in listen_clipboard: {e}")
            time.sleep(0.5)


if __name__ == "__main__":
    os.makedirs(CONFIG["OUTPUT_DIR"], exist_ok=True)
    logging.info(f"Output directory created: {CONFIG['OUTPUT_DIR']}")

    batch_manager = BatchManager()
    playback_queue = batch_manager.get_playback_queue()

    # Start playback thread
    playback_thread = threading.Thread(
        target=play_audio,
        args=(
            playback_queue,
            batch_manager.get_current_batch_id,
            batch_manager.playback_terminate_event,
        ),
        daemon=True,
    )
    playback_thread.start()
    logging.info(f"Started thread: {playback_thread.name}")

    # Start clipboard listener thread
    clipboard_thread = threading.Thread(
        target=listen_clipboard, args=(batch_manager,), daemon=True
    )
    clipboard_thread.start()
    logging.info(f"Started thread: {clipboard_thread.name}")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logging.info("Ctrl+C pressed... Exiting.")
        batch_manager.stop()
        sys.exit(0)
