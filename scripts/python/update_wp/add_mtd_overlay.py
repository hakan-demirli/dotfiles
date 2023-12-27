import tempfile

from PIL import Image


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


def main():
    overlay_file = "/tmp/mtd_overlay.png"
    overlayed_backup_file = tempfile.gettempdir() + "/overlayed_backup.png"
    overlayed_file = tempfile.gettempdir() + "/overlayed.png"

    # Calculate the position for overlay (top right corner)
    x_offset = 1920 - 700
    y_offset = (1080 // 2) + 75
    overlay_images(
        overlayed_backup_file, overlay_file, overlayed_file, x_offset, y_offset
    )


if __name__ == "__main__":
    main()
