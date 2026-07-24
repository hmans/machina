import { decodePngRgba8 } from "./png_rgba.mjs";

const [expectedPath, actualPath, minimumText = "40"] = process.argv.slice(2);
if (!expectedPath || !actualPath) {
  throw new Error(
    "usage: node tools/assert_png_psnr.mjs <expected.png> <actual.png> [minimum-psnr-db]",
  );
}

const minimum = Number(minimumText);
const expected = decodePngRgba8(expectedPath);
const actual = decodePngRgba8(actualPath);
if (expected.width !== actual.width || expected.height !== actual.height) {
  throw new Error(
    `PNG dimensions differ: ${expected.width}x${expected.height} versus ${actual.width}x${actual.height}`,
  );
}

let squaredError = 0;
let channels = 0;
for (let index = 0; index < expected.pixels.length; index += 4) {
  for (let channel = 0; channel < 3; channel += 1) {
    const difference = expected.pixels[index + channel] - actual.pixels[index + channel];
    squaredError += difference * difference;
    channels += 1;
  }
}
const meanSquaredError = squaredError / channels;
const psnr =
  meanSquaredError === 0 ? Number.POSITIVE_INFINITY : 10 * Math.log10((255 * 255) / meanSquaredError);
if (psnr < minimum) {
  throw new Error(`PNG PSNR ${psnr.toFixed(3)} dB is below required ${minimum.toFixed(3)} dB`);
}
console.log(`PNG PSNR ${psnr.toFixed(3)} dB`);
