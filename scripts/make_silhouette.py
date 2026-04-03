from PIL import Image
import sys

input_path = sys.argv[1] if len(sys.argv) > 1 else "images/half2.jpg"
output_path = sys.argv[2] if len(sys.argv) > 2 else "iconIdeas/half2-silhouette.png"
threshold = int(sys.argv[3]) if len(sys.argv) > 3 else 180

img = Image.open(input_path).convert("RGBA")
pixels = img.load()
w, h = img.size

for x in range(w):
    for y in range(h):
        r, g, b, a = pixels[x, y]
        brightness = (r + g + b) / 3
        if brightness < threshold:
            pixels[x, y] = (255, 255, 255, 255)
        else:
            pixels[x, y] = (0, 0, 0, 0)

img.save(output_path)
print(f"Done: {output_path} (threshold={threshold})")
