import datetime
import pathlib
import subprocess
import tempfile

from PIL import Image

Image.MAX_IMAGE_PIXELS = 933120000


def getFilesByType(dir: str, types: list) -> list:
    """
    Retrieve files of specified types from the given directory.

    Args:
        dir (str): The directory path.
        types (list): List of file extensions to search for.

    Returns:
        list: List of paths to files of specified types.
    """
    directory = pathlib.Path(dir)
    paths = []

    for path in directory.glob("*"):
        if path.suffix in types:
            paths.append(str(path.absolute()))

    return paths


def overlay_images(
    background_image: str,
    overlay_image: str,
    output_image: str,
    x_offset: int,
    y_offset: int,
) -> None:
    # Open the background and overlay images
    background = Image.open(background_image)
    overlay = Image.open(overlay_image)

    # Create a copy of the background image to work with
    combined = background.copy()

    # Apply transparency to the overlay
    overlay = overlay.convert("RGBA")
    overlay_with_transparency = Image.new("RGBA", overlay.size)
    for x in range(overlay.width):
        for y in range(overlay.height):
            r, g, b, a = overlay.getpixel((x, y))
            overlay_with_transparency.putpixel(
                (x, y), (r, g, b, int(0.85 * a))
            )  # 85% transparency

    # Paste the overlay onto the background
    combined.paste(
        overlay_with_transparency, (x_offset, y_offset), overlay_with_transparency
    )

    # Save the result to the output file
    combined.save(output_image, format="PNG")

    print(f"Overlay complete. Result saved as {output_image}")


def resize_image(input_image: str, output_image: str, width: int, height: int) -> None:
    # Open the input image
    img = Image.open(input_image)

    # Calculate the aspect ratios
    original_aspect_ratio = img.width / img.height
    target_aspect_ratio = width / height

    # Calculate scaling factor to match the biggest dimension
    if original_aspect_ratio > target_aspect_ratio:
        scaling_factor = width / img.width
    else:
        scaling_factor = height / img.height

    # Calculate scaled dimensions
    new_width = max(int(img.width * scaling_factor), width)
    new_height = max(int(img.height * scaling_factor), height)

    # Resize the image while maintaining aspect ratio
    img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

    # Calculate cropping dimensions
    crop_width = min(new_width, width)
    crop_height = min(new_height, height)
    left = (new_width - crop_width) // 2
    top = (new_height - crop_height) // 2
    right = left + crop_width
    bottom = top + crop_height

    # Crop the image
    img = img.crop((left, top, right, bottom))

    # Save the final image
    img.save(output_image)


def main():
    overlayed_file = tempfile.gettempdir() + "/overlayed.png"
    calendar_overlay_file = tempfile.gettempdir() + "/calendar_overlay.png"
    wp_dir = "/mnt/second/rep/images/art/wallpapers_pc"  # TODO: Fix abs path
    types = [".jpg", ".png", ".jpeg", ".webp"]

    wallpapers = getFilesByType(wp_dir, types)
    wallpapers = sorted(wallpapers)

    if len(wallpapers) <= 0:
        print(f"No wallpapers found in '{wp_dir}'. Exiting.")
        exit(1)

    idx = ((datetime.datetime.now() - datetime.datetime(1970, 1, 1)).days) % (
        len(wallpapers)
    )
    monitor_width, monitor_height = (1920, 1080)
    if monitor_width and monitor_height:
        try:
            with tempfile.NamedTemporaryFile(
                suffix=".png", delete=False
            ) as resized_image:
                resize_image(
                    wallpapers[idx], resized_image, monitor_width, monitor_height
                )
                background = Image.open(resized_image)
                overlay = Image.open(calendar_overlay_file)

                # Calculate the position for overlay (top right corner)
                x_offset = background.width - overlay.width
                y_offset = 0
                overlay_images(
                    resized_image,
                    calendar_overlay_file,
                    overlayed_file,
                    x_offset,
                    y_offset,
                )

            resize_image(wallpapers[idx], "/tmp/wp.png", monitor_width, monitor_height)

        except FileNotFoundError:
            print("Input image files not found.")
        except subprocess.CalledProcessError as e:
            print("Image processing error:", e)
    else:
        print("Unable to get monitor resolution. Exiting.")


if __name__ == "__main__":
    main()
