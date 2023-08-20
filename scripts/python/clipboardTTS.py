#!/usr/bin/env python3
from pathlib import Path
import threading, queue, time, sys, os, string, re, random, logging, clipboard, multiprocessing, tempfile, subprocess
import mylib

# sudo apt install xclip

logging.basicConfig(stream=sys.stderr, level=logging.INFO)

TEMPO = 1
OUTPUT_DIR = tempfile.gettempdir()
MODEL_PATH = mylib.TTS_DIR + "/models/en_GB-jenny_dioco-medium.onnx"
GPU = True
RETRY_TIMES = 5
DELIMETERS = "[?.!]"
RAND_SIZE = 16
MAX_STR_SIZE = 20000
INFERENCE_TIMEOUT = 2.85
PLAY_TIMEOUT = 20
EXIT_TIMEOUT = 2
MIN_SPEED = 0.6
MAX_SPEED = 3
PREFERRED_SPEED = 1.7
DEFAULT_SPEED = 1
BANNED_CHARACTERS = """\/*<>|`[]()^#%&@:+=}"{'~“”—"""
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
                except:
                    logging.warning(
                        "Exception thrown when attempting to run %s, attempt "
                        "%d of %d" % (func, attempt, times)
                    )
                    attempt += 1
            return func(*args, **kwargs)

        return newfn

    return decorator


@retry(times=RETRY_TIMES)
def tts_to_file(txt, file_path):
    piper_path = os.path.abspath(f"{mylib.TTS_DIR}/piper")
    command = (
        f"echo '{txt}' | {piper_path} --output_file {file_path} --model {MODEL_PATH}"
    )
    print(command)
    subprocess.run(command, shell=True)


def convert_txt_to_wav(txt_queue, wav_queue):
    t = threading.current_thread()
    while getattr(t, "do_run", True):
        txts = txt_queue.get()
        for txt in txts:
            file_path = OUTPUT_DIR + f"/{mylib.getRandomFileName('.wav')}"
            t0 = threading.Thread(target=tts_to_file, args=[txt, file_path])
            t0.start()
            t0.join(INFERENCE_TIMEOUT)
            if not t0.is_alive():
                wav_queue.put(file_path)


def change_wav_speed(wav_file):
    f = Path(wav_file)
    tf = f.stem + (mylib.getRandomFileName(".wav"))
    subprocess.call(
        f'ffmpeg -i {f} -filter:a "atempo={TEMPO}" {tf}  > /dev/null',
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.STDOUT,
    )
    os.remove(f"{f}")
    os.system(f"mv {tf} {f}")


def play_wav(wav_queue):
    t = threading.current_thread()
    while getattr(t, "do_run", True):
        wav_file = wav_queue.get()
        if TEMPO != 1:
            change_wav_speed(wav_file)
        try:
            subprocess.call(
                [
                    "ffplay",
                    "-nodisp",
                    "-autoexit",
                    "-t",
                    str(float(get_duration(wav_file)) - 0.2),
                    wav_file,
                ]
            )
        except:
            pass
        try:
            os.remove(wav_file)
        except:
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


def sanitizeString(in_str):
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
    return in_str


def listen_clipboard(txt_queue, wav_queue):
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
            for idx, txt in enumerate(txts):
                if (txt == "") or (txt == " "):
                    continue
                if txt[-1] not in DELIMETERS[1:-1]:
                    txt = txt + "."
                txts_clean.append(txt)
            txt_queue.queue.clear()
            wav_queue.queue.clear()
            txt_queue.put(txts_clean)
        time.sleep(0.8)


if __name__ == "__main__":
    threads = []

    txt_queue = queue.Queue()
    wav_queue = queue.Queue()
    threads.append(
        threading.Thread(target=listen_clipboard, args=[txt_queue, wav_queue])
    )
    threads.append(
        threading.Thread(target=convert_txt_to_wav, args=[txt_queue, wav_queue])
    )
    threads.append(threading.Thread(target=play_wav, args=[wav_queue]))
    for thread in threads:
        thread.start()

    toggle = False
    while True:
        try:
            time.sleep(1)
            command = input(str)
            if (command == "u") and (TEMPO < MAX_SPEED):
                TEMPO = TEMPO + 0.1
            if (command == "d") and (TEMPO > MIN_SPEED):
                TEMPO = TEMPO - 0.1
            if command == "g":
                toggle = not toggle
                if toggle:
                    TEMPO = PREFERRED_SPEED
                else:
                    TEMP = DEFAULT_SPEED
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
