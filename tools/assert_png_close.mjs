import { decodePngRgba8 } from "./png_rgba.mjs";

const [expectedPath, actualPath, maximumDifferenceText = "1", maximumChangedText = "16"] =
  process.argv.slice(2);
if (!expectedPath || !actualPath) {
  throw new Error(
    "usage: node tools/assert_png_close.mjs <expected.png> <actual.png> [max-channel-difference] [max-changed-channels]",
  );
}

const maximumDifference = Number(maximumDifferenceText);
const maximumChanged = Number(maximumChangedText);

const expected = decodePngRgba8(expectedPath);
const actual = decodePngRgba8(actualPath);
if (expected.width !== actual.width || expected.height !== actual.height) {
  throw new Error(
    `PNG dimensions differ: ${expected.width}x${expected.height} versus ${actual.width}x${actual.height}`,
  );
}

let changed = 0;
let largestDifference = 0;
for (let index = 0; index < expected.pixels.length; index += 1) {
  const difference = Math.abs(expected.pixels[index] - actual.pixels[index]);
  if (difference > 0) {
    changed += 1;
    largestDifference = Math.max(largestDifference, difference);
  }
}
if (largestDifference > maximumDifference || changed > maximumChanged) {
  throw new Error(
    `PNG pixels differ too much: ${changed} changed channels, maximum difference ${largestDifference}; allowed ${maximumChanged} and ${maximumDifference}`,
  );
}
