#!/usr/bin/env python3
"""
Convert a city skyline photo into a silhouette SVG.

Usage:
    python3 scripts/skyline_to_svg.py <input_image> <output.svg>
"""

import sys
import cv2
import numpy as np
from scipy.ndimage import median_filter, gaussian_filter1d
from pathlib import Path


def find_skyline_contour(image_path, smooth_window=7):
    """Extract skyline silhouette from a photo."""

    img = cv2.imread(str(image_path))
    if img is None:
        print(f"Error: Could not read {image_path}")
        sys.exit(1)

    h, w = img.shape[:2]
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (7, 7), 0)
    normalized = blurred.astype(float) / 255.0

    skyline_y = []

    for x in range(w):
        col = normalized[:, x]

        # Strategy: scan from top down, looking for the point where
        # brightness drops and STAYS dark for at least 15 pixels.
        # This skips clouds and finds the actual building line.
        best_y = int(h * 0.6)  # fallback

        for y in range(5, int(h * 0.75)):
            # Check if there's a sustained dark region below this point
            look_ahead = min(25, h - y)
            region_below = col[y:y + look_ahead]
            avg_below = np.mean(region_below)
            avg_above = np.mean(col[max(0, y - 10):y]) if y > 10 else col[0]

            # The skyline is where brightness drops and stays below 0.35
            if avg_below < 0.35 and avg_above > avg_below + 0.08:
                best_y = y
                break

        skyline_y.append(best_y)

    skyline_y = np.array(skyline_y, dtype=float)

    # Median filter to remove noise/spikes
    skyline_y = median_filter(skyline_y, size=smooth_window)

    # Gentle smoothing
    skyline_y = gaussian_filter1d(skyline_y, sigma=2)

    return skyline_y, w, h


def skyline_to_svg(skyline_y, orig_w, orig_h, output_width=1200, output_height=400):
    """Convert skyline contour to SVG path."""

    x_scale = output_width / orig_w

    # Scale Y: map the skyline range to fill the output height nicely
    # Leave ~20% at top for the tallest building peaks
    y_min = np.min(skyline_y)
    y_range = orig_h - y_min
    y_scale = output_height / y_range

    # Subsample to ~600 points
    step = max(1, orig_w // 600)
    indices = range(0, len(skyline_y), step)

    points = []
    for i in indices:
        x = i * x_scale
        y = (skyline_y[i] - y_min) * y_scale
        points.append((round(x, 1), round(y, 1)))

    # Build SVG path — fill everything below the skyline contour
    path_parts = [f"M0 {output_height}"]
    path_parts.append(f"L{points[0][0]} {points[0][1]}")

    for x, y in points[1:]:
        path_parts.append(f"L{x} {y}")

    path_parts.append(f"L{output_width} {points[-1][1]}")
    path_parts.append(f"L{output_width} {output_height}")
    path_parts.append("Z")

    path_d = " ".join(path_parts)

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {output_width} {output_height}">
  <path d="{path_d}" fill="white"/>
</svg>'''

    return svg


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 skyline_to_svg.py <input_image> <output.svg>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    print(f"Processing {input_path}...")

    skyline_y, w, h = find_skyline_contour(input_path)
    svg = skyline_to_svg(skyline_y, w, h)

    Path(output_path).write_text(svg)
    print(f"Saved silhouette to {output_path}")


if __name__ == "__main__":
    main()
