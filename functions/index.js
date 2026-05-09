const { onObjectFinalized } = require("firebase-functions/v2/storage");
const admin = require("firebase-admin");
const ffmpeg = require("fluent-ffmpeg");
const ffmpegPath = require("ffmpeg-static");
const fs = require("fs");
const path = require("path");

admin.initializeApp();
ffmpeg.setFfmpegPath(ffmpegPath);

exports.convertToHLS = onObjectFinalized(async (event) => {
  const object = event.data;
  const filePath = object.name;

  if (!filePath || !filePath.endsWith(".mp4")) return;

  const fileName = path.basename(filePath);
  const postId = fileName.split(".")[0];

  const bucket = admin.storage().bucket();

  const tempInput = path.join("/tmp", fileName);
  const tempOutputDir = path.join("/tmp", postId);

  if (!fs.existsSync(tempOutputDir)) {
    fs.mkdirSync(tempOutputDir);
  }

  await bucket.file(filePath).download({ destination: tempInput });

  await new Promise((resolve, reject) => {
    ffmpeg(tempInput)
      .outputOptions([
        "-profile:v baseline",
        "-level 3.0",
        "-start_number 0",
        "-hls_time 4",
        "-hls_list_size 0",
        "-f hls",
        "-hls_segment_filename",
        path.join(tempOutputDir, "segment%03d.ts"),
      ])
      .output(path.join(tempOutputDir, "index.m3u8"))
      .on("end", resolve)
      .on("error", reject)
      .run();
  });

  const files = fs.readdirSync(tempOutputDir);

  const uploadPromises = files.map((file) => {
    return bucket.upload(path.join(tempOutputDir, file), {
      destination: `hls/${postId}/${file}`,
      metadata: {
        contentType: file.endsWith(".m3u8")
          ? "application/vnd.apple.mpegurl"
          : "video/mp2t",
      },
    });
  });

  await Promise.all(uploadPromises);

  const hlsUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/hls%2F${postId}%2Findex.m3u8?alt=media`;

  await admin.firestore().collection("posts").doc(postId).update({
    hlsUrl: hlsUrl,
    status: "ready",
  });

  fs.unlinkSync(tempInput);
  fs.rmSync(tempOutputDir, { recursive: true, force: true });

  console.log("HLS conversion complete:", hlsUrl);
});