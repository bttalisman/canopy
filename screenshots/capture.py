#!/usr/bin/env python3
"""Generate App Store screenshots with phone frames and taglines."""

from PIL import Image, ImageDraw, ImageFont
import os

DIR = os.path.dirname(os.path.abspath(__file__))
OUT_W, OUT_H = 1290, 2796

SCREENS = [
    {
        "file": "IPhone15ProMax_2/discover.png",
        "title": "Discover Seattle",
        "subtitle": "Every festival, concert, \nand fair in one app",
        "bg": [(15, 32, 39), (32, 58, 67)],
    },
    {
        "file": "IPhone15ProMax_2/mapView.png",
        "title": "Explore the Map",
        "subtitle": "See what's happening\nacross the city",
        "bg": [(26, 26, 46), (15, 52, 96)],
    },
    
    {
        "file": "IPhone15ProMax_2/mapViewEastSide.png",
        "title": "Explore the \nEast Side",
        "subtitle": "See what's happening\nacross the region",
        "bg": [(26, 26, 46), (15, 52, 96)],
    },    
    {
        "file": "IPhone15ProMax_2/eventDetails.png",
        "title": "Event Details",
        "subtitle": "Schedules, maps, tickets,\nand more",
        "bg": [(13, 27, 42), (26, 42, 26)],
    },
    {
        "file": "IPhone15ProMax_2/transit.png",
        "title": "Arrive by Transit",
        "subtitle": "Real-time bus arrivals\nand route planning",
        "bg": [(26, 10, 46), (15, 32, 39)],
    },
    {
        "file": "IPhone15ProMax_2/eventMap.png",
        "title": "Explore \nthe Venue",
        "subtitle": "Find stages, food,\nrestrooms, and exits",
        "bg": [(45, 27, 0), (15, 32, 39)],
    },
    {
        "file": "IPhone15ProMax_2/mySchedule.png",
        "title": "Your Schedule",
        "subtitle": "Save sessions and\nnever miss a set",
        "bg": [(10, 26, 10), (20, 40, 30)],
    },
    {
        "file": "IPhone15ProMax_2/artistProfile.png",
        "title": "Meet \nthe Artists",
        "subtitle": "Bios, photos,\nand social links",
        "bg": [(15, 32, 39), (26, 42, 26)],
    },
]

GREEN = (74, 222, 128)
WHITE = (255, 255, 255)
GRAY = (160, 160, 180)

def gradient(w, h, c1, c2):
    img = Image.new("RGB", (w, h))
    for y in range(h):
        t = y / h
        r = int(c1[0] * (1 - t) + c2[0] * t)
        g = int(c1[1] * (1 - t) + c2[1] * t)
        b = int(c1[2] * (1 - t) + c2[2] * t)
        for x in range(w):
            img.putpixel((x, y), (r, g, b))
    return img

def round_corners(img, radius):
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), img.size], radius, fill=255)
    result = img.copy()
    result.putalpha(mask)
    return result

def make_screenshot(screen, index):
    # Background gradient
    canvas = gradient(OUT_W, OUT_H, screen["bg"][0], screen["bg"][1])
    draw = ImageDraw.Draw(canvas)

    # Try to load a nice font, fall back to default
    try:
        title_font = ImageFont.truetype("/System/Library/Fonts/SFProDisplay-Bold.otf", 105)
        sub_font = ImageFont.truetype("/System/Library/Fonts/SFProDisplay-Regular.otf", 90)
    except (IOError, OSError):
        try:
            title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 150)
            sub_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 100)
        except (IOError, OSError):
            title_font = ImageFont.load_default()
            sub_font = ImageFont.load_default()

    # Phone screenshot — large, filling ~80% of height
    phone_img = Image.open(os.path.join(DIR, screen["file"]))

    # Scale phone to fill most of the frame
    phone_target_h = int(OUT_H * 0.78)
    scale = phone_target_h / phone_img.height
    phone_target_w = int(phone_img.width * scale)
    phone_img = phone_img.resize((phone_target_w, phone_target_h), Image.LANCZOS)

    # Add rounded corners
    phone_img = round_corners(phone_img, 55)

    # Add phone border
    border_pad = 12
    border_w = phone_target_w + border_pad * 2
    border_h = phone_target_h + border_pad * 2
    border_img = Image.new("RGBA", (border_w, border_h), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border_img)
    border_draw.rounded_rectangle([(0, 0), (border_w - 1, border_h - 1)], 65, fill=(42, 42, 42, 255))
    border_img.paste(phone_img, (border_pad, border_pad), phone_img)

    # Position phone centered at bottom
    phone_x = (OUT_W - border_w) // 2
    phone_y = OUT_H - border_h + 200

    # Title above phone
    title = screen["title"]
    title_lines = title.split("\n")

    # Center text in the space above the phone
    text_area_h = phone_y
    title_line_h = 160  # line spacing for title
    total_title_h = len(title_lines) * title_line_h
    y_title = text_area_h // 2 - total_title_h // 2 - 40

    for tline in title_lines:
        words = tline.split(" ")
        accent_word = words[-1]
        normal_part = " ".join(words[:-1]) + " " if len(words) > 1 else ""

        normal_bbox = draw.textbbox((0, 0), normal_part, font=title_font) if normal_part.strip() else (0, 0, 0, 0)
        accent_bbox = draw.textbbox((0, 0), accent_word, font=title_font)
        total_w = (normal_bbox[2] - normal_bbox[0]) + (accent_bbox[2] - accent_bbox[0])
        x_start = (OUT_W - total_w) // 2

        if normal_part.strip():
            draw.text((x_start, y_title), normal_part, fill=WHITE, font=title_font)
            x_accent = x_start + (normal_bbox[2] - normal_bbox[0])
        else:
            x_accent = x_start
        draw.text((x_accent, y_title), accent_word, fill=GREEN, font=title_font)
        y_title += title_line_h

    # Subtitle
    sub_lines = screen["subtitle"].split("\n")
    y_sub = y_title + 15
    for line in sub_lines:
        sub_bbox = draw.textbbox((0, 0), line, font=sub_font)
        sub_w = sub_bbox[2] - sub_bbox[0]
        draw.text(((OUT_W - sub_w) // 2, y_sub), line, fill=GRAY, font=sub_font)
        y_sub += 115

    # Paste onto canvas
    canvas = canvas.convert("RGBA")
    canvas.paste(border_img, (phone_x, phone_y), border_img)
    canvas = canvas.convert("RGB")

    # Save
    out_path = os.path.join(DIR, f"appstore-{index + 1:02d}.png")
    canvas.save(out_path, "PNG")
    print(f"Saved: {out_path} ({OUT_W}x{OUT_H})")

if __name__ == "__main__":
    for i, screen in enumerate(SCREENS):
        make_screenshot(screen, i)
    print(f"\nDone! {len(SCREENS)} screenshots saved.")
