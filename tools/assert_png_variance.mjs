import { decodePngRgba8 } from "./png_rgba8.mjs";

const path = process.argv[2];
if (!path) {
  throw new Error("usage: node tools/assert_png_variance.mjs <image.png>");
}

const { pixels } = decodePngRgba8(path);

const colors = new Set();
let minimum = 255;
let maximum = 0;
for (let index = 0; index < pixels.length; index += 4) {
  const red = pixels[index];
  const green = pixels[index + 1];
  const blue = pixels[index + 2];
  colors.add((red << 16) | (green << 8) | blue);
  minimum = Math.min(minimum, red, green, blue);
  maximum = Math.max(maximum, red, green, blue);
}
if (colors.size < 4 || maximum - minimum < 24) {
  throw new Error(`${path}: frame lacks meaningful rendered color variance`);
}
