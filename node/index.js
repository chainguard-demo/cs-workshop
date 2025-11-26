import Jimp from "jimp";
import os from 'os';

const ASCII_CHARS = "@%#*+=-:. "; // Define ASCII gradient

async function imageToAscii(imagePath) {
  const image = await Jimp.read(imagePath);
  image.resize(100, Jimp.AUTO).greyscale(); // Resize and convert to grayscale

  let asciiStr = "";
  for (let y = 0; y < image.bitmap.height; y++) {
    for (let x = 0; x < image.bitmap.width; x++) {
      const { r } = Jimp.intToRGBA(image.getPixelColor(x, y));
      const char = ASCII_CHARS[Math.floor((r / 255) * (ASCII_CHARS.length - 1))];
      asciiStr += char;
    }
    asciiStr += "\n";
  }
  console.log(asciiStr);
}

function printSystemInfo() {
  console.log("User Information:");
  console.log(`Username: ${os.userInfo().username}`);
  console.log(`Home Directory: ${os.userInfo().homedir}`);
  console.log(`Shell: ${os.userInfo().shell}`);

  console.log("\nOperating System Information:");
  console.log(`OS: ${os.type()} ${os.release()} (${os.arch()})`);
  console.log(`Host: ${os.hostname()}`);
  console.log(`CPU: ${os.cpus()[0].model} (${os.cpus().length} cores)`);
  console.log(`Total Memory: ${(os.totalmem() / (1024 ** 3)).toFixed(2)} GB`);
  console.log(`Free Memory: ${(os.freemem() / (1024 ** 3)).toFixed(2)} GB`);
  console.log(`Uptime: ${(os.uptime() / 60).toFixed(2)} minutes`);
}

imageToAscii("./image.jpg").catch(console.error);
printSystemInfo();

