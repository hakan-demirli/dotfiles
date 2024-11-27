import os
import re
import sys
import time
import queue
import logging
import threading
from pathlib import Path
import pyclip

# Configuration and Constants
logging.basicConfig(stream=sys.stderr, level=logging.INFO)

CONFIG = {
    "TEMPO": 1.0,
    "OUTPUT_DIR": Path("/tmp/piper"),
    "PIPER_MODEL": "/mnt/second/software/lin/piper/models/en_GB-jenny_dioco-medium.onnx",
    "RVC_MODEL_PATH": "/home/emre/.config/rvc-cli/models/custom/Pod042EN_e250_s14250.pth",
    "RVC_INDEX_PATH": "/home/emre/.config/rvc-cli/models/custom/added_IVF2047_Flat_nprobe_1_Pod042EN_v2.index",
    "RVC_INPUT_DIR": Path("/home/emre/Desktop/rvc-cli"),
    "DELIMITERS": "[?.!]",
    "RAND_SIZE": 16,
    "MAX_STR_SIZE": 20000,
    "BANNED_CHARACTERS": r"""\/*<>|`[]()^#%&@:+=}"{'~“”—""",
    "CONTRACTIONS": {
        "can't": "cannot",
        "I'm": "I am",
        "he's": "he is",
        # Add other contractions as needed
    },
}


# Utility Functions
def get_random_string(length):
    import random
    import string

    return "".join(random.choice(string.ascii_lowercase) for _ in range(length))


def sanitize_string(input_str):
    for char in CONFIG["BANNED_CHARACTERS"]:
        input_str = input_str.replace(char, "")
    for contraction, expanded in CONFIG["CONTRACTIONS"].items():
        input_str = input_str.replace(contraction, expanded)
    input_str = " ".join(input_str.splitlines())
    input_str = re.sub(
        r"\d+\.\d+", lambda m: m.group(0).replace(".", " point "), input_str
    )
    logging.info(f"Sanitized string: {input_str}")
    return input_str


def text_to_speech_with_piper(text, output_file):
    command = f"echo '{text}' | piper --model {CONFIG['PIPER_MODEL']} --output_file {output_file}"
    result = os.system(command)
    if result != 0:
        logging.error(f"Piper TTS failed for text: {text}")
    else:
        logging.info(f"Generated TTS output at {output_file}")


def apply_rvc_voice(input_file, output_file):
    command = (
        f"rvc_cli infer --pth_path {CONFIG['RVC_MODEL_PATH']} "
        f"--index_path {CONFIG['RVC_INDEX_PATH']} "
        f"--input_path {input_file} "
        f"--output_path {output_file}"
    )
    result = os.system(command)
    if result != 0:
        logging.error(f"RVC voice conversion failed for file: {input_file}")
    else:
        logging.info(f"Generated RVC output at {output_file}")


def process_sentence(sentence, seq_num, wav_queue):
    try:
        sanitized_text = sanitize_string(sentence)
        temp_wav = (
            CONFIG["OUTPUT_DIR"] / f"{get_random_string(CONFIG['RAND_SIZE'])}.wav"
        )
        final_wav = CONFIG["OUTPUT_DIR"] / f"final_{seq_num}.wav"

        text_to_speech_with_piper(sanitized_text, temp_wav)
        apply_rvc_voice(temp_wav, final_wav)

        wav_queue.put((seq_num, final_wav))
    except Exception as e:
        logging.error(f"Error processing sentence {seq_num}: {e}")


def process_text_to_audio(txt_queue, wav_queue):
    while True:
        try:
            texts = txt_queue.get()
            threads = []
            for seq_num, text in enumerate(texts):
                thread = threading.Thread(
                    target=process_sentence,
                    args=(text, seq_num, wav_queue),
                    daemon=True,
                )
                threads.append(thread)
                thread.start()

            for thread in threads:
                thread.join()
        except Exception as e:
            logging.error(f"Error in process_text_to_audio: {e}")


def play_audio(wav_queue):
    next_seq = 0
    buffers = {}

    while True:
        try:
            seq_num, wav_file = wav_queue.get()
            buffers[seq_num] = wav_file

            while next_seq in buffers:
                # Ensure file exists before attempting to play
                if os.path.exists(buffers[next_seq]):
                    os.system(f"ffplay -autoexit -nodisp {buffers[next_seq]}")
                else:
                    logging.error(f"File {buffers[next_seq]} does not exist.")
                del buffers[next_seq]
                next_seq += 1
        except Exception as e:
            logging.error(f"Error in play_audio: {e}")


def listen_clipboard(txt_queue):
    recent_value = ""
    while True:
        try:
            new_value = pyclip.paste(text=True)
            if new_value != recent_value and len(new_value) < CONFIG["MAX_STR_SIZE"]:
                recent_value = new_value
                sanitized = sanitize_string(new_value)
                sentences = re.split(CONFIG["DELIMITERS"], sanitized)
                txt_queue.queue.clear()
                txt_queue.put([s.strip() for s in sentences if s.strip()])
        except Exception as e:
            logging.error(f"Error in listen_clipboard: {e}")
        time.sleep(0.8)


if __name__ == "__main__":
    os.makedirs(CONFIG["OUTPUT_DIR"], exist_ok=True)

    txt_queue = queue.Queue()
    wav_queue = queue.Queue()

    threads = [
        threading.Thread(target=listen_clipboard, args=(txt_queue,), daemon=True),
        threading.Thread(
            target=process_text_to_audio, args=(txt_queue, wav_queue), daemon=True
        ),
        threading.Thread(target=play_audio, args=(wav_queue,), daemon=True),
    ]

    for thread in threads:
        thread.start()

    while True:
        try:
            time.sleep(1)
        except KeyboardInterrupt:
            logging.info("Ctrl+C pressed...")
            sys.exit(1)
