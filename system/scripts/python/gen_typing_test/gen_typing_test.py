#!/usr/bin/env python3
import argparse
import random
import pathlib
import os


class ContentGenerator:
    def __init__(self, num_words, symbols, capitalize=False):
        self.num_words = num_words
        self.characters = symbols
        self.capitalize = capitalize

    def get_words_from_file(self):
        script_dir = pathlib.Path(os.path.realpath(__file__)).parent.absolute()
        words_file = script_dir / "words.txt"
        with open(words_file, "r") as f:
            words = f.read().splitlines()
        return words

    def generate_with_symbols(self):
        words = [
            "".join(random.choice(self.characters) for _ in range(random.randint(2, 6)))
            for _ in range(self.num_words)
        ]
        return words

    def generate_with_numbers(self, digits="0123456789"):
        random_numbers = [
            "".join(random.choice(digits) for _ in range(random.randint(1, 5)))
            for _ in range(self.num_words)
        ]
        return random_numbers

    def random_capitalize(self, word):
        return "".join(char.upper() if random.random() < 0.5 else char for char in word)

    def generate_content(self, args):
        words = self.get_words_from_file()
        content = []

        if args.n:
            numbers = self.generate_with_numbers(args.digits)
            content += numbers

        if args.s:
            symbols = self.generate_with_symbols()
            content += symbols

        if args.w:
            random_words = random.sample(words, args.w)
            if self.capitalize:
                random_words = [self.random_capitalize(word) for word in random_words]
            content += random_words

        random.shuffle(content)
        return " ".join(content)


def main():
    parser = argparse.ArgumentParser(
        description="Generate content for touch typing tests."
    )
    parser.add_argument("-n", type=int, help="Number of numbers to generate")
    parser.add_argument("-s", type=int, help="Number of symbols to generate")
    parser.add_argument("-w", type=int, help="Number of words to generate")
    parser.add_argument(
        "--capital", action="store_true", help="Randomly capitalize words"
    )
    parser.add_argument(
        "--digits",
        type=str,
        default="0123456789",
        help="Digits to use when generating numbers",
    )
    parser.add_argument(
        "--symbols",
        type=str,
        default="~`%!-+=&*^@#|'\"{}",
        help="Symbols to use when generating symbols",
    )

    args = parser.parse_args()
    generator = ContentGenerator(args.n or args.s or args.w, args.symbols, args.capital)
    print(generator.generate_content(args))


if __name__ == "__main__":
    main()
