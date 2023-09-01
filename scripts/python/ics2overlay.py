from PIL import Image, ImageDraw, ImageFont
import calendar
import io
import sys
import datetime
import mylib


def dateToEvent(day, month, year, parsed_events):
    target_date = f"{year:04d}{month:02d}{day:02d}"
    events_on_date = []

    for event in parsed_events:
        start_date = event.get("DTSTART;VALUE=DATE")
        if not start_date:
            start_date = event.get("DTSTART")
        end_date = event.get("DTEND;VALUE=DATE")
        if not end_date:
            end_date = event.get("DTEND")
        if start_date and end_date:
            s = int(start_date.split("T")[0])
            t = int(target_date.split("T")[0])
            e = int(end_date.split("T")[0])
            if (s == t) or (s < t < e):
                events_on_date.append(event.get("SUMMARY"))

    return events_on_date


def parseICSFile(filename):
    events = []
    with open(filename, "r") as f:
        lines = f.readlines()

    event = {}
    for line in lines:
        line = line.strip()
        if line.startswith("BEGIN:VEVENT"):
            event = {}
        elif line.startswith("END:VEVENT"):
            events.append(event)
        elif ":" in line:  # Check if line contains a colon
            key, value = line.split(":", 1)
            event[key] = value

    return events


def isPreviousMonth(month_year_string):
    current_date = datetime.datetime.now()
    input_date = datetime.datetime.strptime(month_year_string, "%B %Y")

    if input_date.year < current_date.year:
        return True
    elif input_date.year == current_date.year and input_date.month < current_date.month:
        return True
    else:
        return False


def isThisMonth(month_year_string):
    current_date = datetime.datetime.now()
    input_date = datetime.datetime.strptime(month_year_string, "%B %Y")

    if input_date.year == current_date.year and input_date.month == current_date.month:
        return True
    else:
        return False


def annotateDay(text, target_char, insert_char, pos):
    lines = text.split("\n")
    first_line = lines[0]
    lines[0] = " "
    row_index = -1
    col_index = -1

    # Find the row and column index of the target character
    for i, line in enumerate(lines):
        if target_char in line:
            row_index = i
            col_index = line.index(target_char)
            break

    if row_index == -1 or col_index == -1:
        return text  # Target character not found

    # Calculate the lengths of the lines above and below
    line_lengths = [len(line) for line in lines]
    max_length = max(line_lengths)

    # Adjust the lengths of the lines above
    adjusted_lines = []
    for i, line in enumerate(lines):
        diff = max_length - line_lengths[i]
        adjusted_lines.append(line + " " * diff)

    ri = 0
    ci = 0
    if pos == "u":
        ri = -1
    elif pos == "d":
        ri = 1
    elif pos == "n":
        ri = 0
        ci = 2
    # Insert the character above the target character
    adjusted_lines[row_index + ri] = (
        adjusted_lines[row_index + ri][: col_index + ci]
        + insert_char
        + adjusted_lines[row_index + ri][col_index + ci + len(insert_char) :]
    )

    adjusted_lines[0] = first_line
    return "\n".join(adjusted_lines)


def getTextCalendarMonth(year, month):
    cal_w = 5
    cal_l = 2
    stdout_orig = sys.stdout
    output_buffer = io.StringIO()
    sys.stdout = output_buffer
    cal = calendar.TextCalendar()
    cal_output = cal.formatmonth(year, month, w=cal_w, l=cal_l).replace("\n\n", "\n")
    line_size = len(cal_output.split("\n"))
    if line_size < 9:
        cal_output += "\n"  # Add extra newlines so all of them are 9 rows tall
    output_buffer.write(cal_output)

    sys.stdout = stdout_orig  # Restore stdout
    calendar_output = output_buffer.getvalue()

    output_buffer = io.StringIO()  # Reset the buffer
    return calendar_output


def getDisplayedMonths(past, future):
    current_year = datetime.datetime.now().year
    current_month = datetime.datetime.now().month

    months_to_display = []

    for i in range(-past, future + 1):
        year_offset = 0
        if (current_month + i) <= 0:
            year_offset = -1
        elif (current_month + i) > 12:
            year_offset = 1

        year = current_year + year_offset
        month = (current_month + i) % 12
        if month == 0:
            month = 12

        months_to_display.append((year, month))

    return months_to_display


def dateTuple(month_year_string):
    input_date = datetime.datetime.strptime(month_year_string, "%B %Y")
    return input_date.month, input_date.year


def smartDrawLayers(raw_cal_txt, ics_events, text_position, draw):
    font = ImageFont.truetype(mylib.ANON_FONT_FILE, size=10)
    # Define the start and end dates for your loop
    start_date = datetime.date(2020, 1, 1)
    end_date = datetime.date(2030, 12, 31)

    # Loop through all days, months, and years
    # Add annotations
    current_date = start_date
    while current_date <= end_date:
        day = current_date.day
        month = current_date.month
        year = current_date.year

        events = dateToEvent(day, month, year, ics_events)
        cal_cur = dateTuple(raw_cal_txt.strip().split("\n")[0])
        if events and (cal_cur == (month, year)):
            pos = ["n", "u", "d"]
            # Annotations should be in yellow
            annotation_color = (255, 255, 0)
            for idx, event in enumerate(events):
                calendar_output = annotateDay(
                    raw_cal_txt, f"{day}", f"{event[0:3]}", pos[idx]
                )
                draw.text(
                    text_position, calendar_output, fill=annotation_color, font=font
                )

        current_date += datetime.timedelta(days=1)  # Move to the next day

    # Texts should be in white
    text_color = (255, 255, 255)
    draw.text(text_position, raw_cal_txt, fill=text_color, font=font)

    # Previous months should be in gray
    if isPreviousMonth(raw_cal_txt.strip().split("\n")[0]):
        text_color = (55, 55, 55)  # gray color
        draw.text(text_position, raw_cal_txt, fill=text_color, font=font)

    # Previous days should be in gray
    month_title = raw_cal_txt.strip().split("\n")[0]
    if isThisMonth(month_title):
        lines = raw_cal_txt.split("\n")
        month_title = lines[0]
        month_title = "\n".join(line for line in month_title if line == "\n")
        raw_cal_txt = "\n".join(lines[1:])
        yesterday = (datetime.date.today() - datetime.timedelta(days=1)).day
        calendar_parts = raw_cal_txt.split(str(yesterday))
        # Delete all characters in the second part except newlines
        if len(calendar_parts) > 1:
            first_part = calendar_parts[0]
        else:
            first_part = ""
            yesterday = ""
        modified_calendar = f"{first_part}{yesterday}"
        modified_calendar = month_title + "\n" + modified_calendar
        text_color = (55, 55, 55)  # gray color
        draw.text(text_position, modified_calendar, fill=text_color, font=font)


def main():
    width, height = 1100, 800
    background_color = (0, 0, 0, 222)
    image = Image.new("RGBA", (width, height), background_color)
    draw = ImageDraw.Draw(image)

    months_to_display = getDisplayedMonths(1, 4)

    num_rows = 2
    num_columns = len(months_to_display) // num_rows + (
        1 if len(months_to_display) % num_rows != 0 else 0
    )
    column_width = width // num_columns
    x_offset = 10

    events = parseICSFile(mylib.ICS_FILE)

    # Draw in a grid.
    for i in range(0, len(months_to_display), num_rows):
        # Get a column
        month_group = months_to_display[i : i + num_rows]

        # Print the current column
        text_height = 0
        for year, month in month_group:
            raw_cal_txt = getTextCalendarMonth(year, month).replace("\n", "\n\n\n")
            text_position = (x_offset, 20 + text_height)
            smartDrawLayers(raw_cal_txt, events, text_position, draw)

            text_height += len(raw_cal_txt.split("\n")) * 14

        text_position = (x_offset, 20)
        # Update the X offset for the next column
        x_offset += column_width

    # Save the image
    image.save(mylib.CALENDAR_OVERLAY_FILE)


if __name__ == "__main__":
    main()
