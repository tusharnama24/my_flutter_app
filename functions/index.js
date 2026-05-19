const { onObjectFinalized } = require('firebase-functions/v2/storage');

const admin = require('firebase-admin');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegPath = require('ffmpeg-static');

const path = require('path');
const os = require('os');
const fs = require('fs');

admin.initializeApp();

ffmpeg.setFfmpegPath(ffmpegPath);

exports.processVideo = onObjectFinalized(
  async (event) => {

    try {

      const object = event.data;

      const filePath = object.name;

      // only process raw uploads
      if (!filePath.startsWith('videos/raw/')) {
        return null;
      }

      const bucket = admin.storage().bucket(object.bucket);

      const fileName = path.basename(filePath);

      // remove extension
      const videoId = path.parse(fileName).name;

      // temp working directory
      const tempDir = path.join(os.tmpdir(), videoId);

      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir);
      }

      // local raw file
      const localInput = path.join(tempDir, fileName);

      // download raw video
      await bucket.file(filePath).download({
        destination: localInput,
      });

      console.log('Raw video downloaded');

      // ─────────────────────────────────────────────────────────
      // OUTPUT PATHS
      // ─────────────────────────────────────────────────────────

      const optimizedMp4 = path.join(
        tempDir,
        'optimized.mp4'
      );

      const thumbnailPath = path.join(
        tempDir,
        'thumb.jpg'
      );

      const hlsDir = path.join(
        tempDir,
        'hls'
      );

      if (!fs.existsSync(hlsDir)) {
        fs.mkdirSync(hlsDir);
      }

      const hlsPlaylist = path.join(
        hlsDir,
        'playlist.m3u8'
      );

      // ─────────────────────────────────────────────────────────
      // GENERATE OPTIMIZED MP4
      // ─────────────────────────────────────────────────────────

      await new Promise((resolve, reject) => {

        ffmpeg(localInput)

          .outputOptions([

            // video
            '-c:v libx264',
            '-preset veryfast',
            '-crf 23',
            '-pix_fmt yuv420p',

            // scaling
            '-vf scale=720:-2',

            // fps normalization
            '-r 30',

            // audio
            '-c:a aac',
            '-b:a 128k',

            // fast streaming
            '-movflags +faststart',
          ])

          .output(optimizedMp4)

          .on('end', () => {
            console.log('Optimized MP4 generated');
            resolve();
          })

          .on('error', (err) => {
            console.error('MP4 generation error', err);
            reject(err);
          })

          .run();
      });

      // ─────────────────────────────────────────────────────────
      // GENERATE HLS
      // ─────────────────────────────────────────────────────────

      await new Promise((resolve, reject) => {

        ffmpeg(localInput)

          .outputOptions([

            '-c:v libx264',
            '-preset veryfast',
            '-crf 23',

            '-vf scale=720:-2',
            '-r 30',

            '-c:a aac',
            '-b:a 128k',

            // HLS
            '-hls_time 4',
            '-hls_playlist_type vod',
            '-hls_list_size 0',

            '-f hls',
          ])

          .output(hlsPlaylist)

          .on('end', () => {
            console.log('HLS generated');
            resolve();
          })

          .on('error', (err) => {
            console.error('HLS generation error', err);
            reject(err);
          })

          .run();
      });

      // ─────────────────────────────────────────────────────────
      // GENERATE THUMBNAIL
      // ─────────────────────────────────────────────────────────

      await new Promise((resolve, reject) => {

        ffmpeg(localInput)

          .screenshots({
            timestamps: ['1'],
            filename: 'thumb.jpg',
            folder: tempDir,
            size: '720x1280',
          })

          .on('end', () => {
            console.log('Thumbnail generated');
            resolve();
          })

          .on('error', (err) => {
            console.error('Thumbnail generation error', err);
            reject(err);
          });
      });

      // ─────────────────────────────────────────────────────────
      // STORAGE DESTINATIONS
      // ─────────────────────────────────────────────────────────

      const processedBase =
        `videos/processed/${videoId}`;

      // upload optimized mp4
      await bucket.upload(optimizedMp4, {
        destination: `${processedBase}/optimized.mp4`,
      });

      // upload thumbnail
      await bucket.upload(thumbnailPath, {
        destination: `${processedBase}/thumb.jpg`,
      });

      // upload HLS files
      const hlsFiles = fs.readdirSync(hlsDir);

      for (const file of hlsFiles) {

        await bucket.upload(
          path.join(hlsDir, file),
          {
            destination:
              `${processedBase}/hls/${file}`,
          }
        );
      }

      console.log('Processed files uploaded');

      // ─────────────────────────────────────────────────────────
      // GET DOWNLOAD URLS
      // ─────────────────────────────────────────────────────────

      const mp4File = bucket.file(
        `${processedBase}/optimized.mp4`
      );

      const thumbFile = bucket.file(
        `${processedBase}/thumb.jpg`
      );

      const hlsFile = bucket.file(
        `${processedBase}/hls/playlist.m3u8`
      );

      const [mp4Url] = await mp4File.getSignedUrl({
        action: 'read',
        expires: '03-01-2500',
      });

      const [thumbUrl] = await thumbFile.getSignedUrl({
        action: 'read',
        expires: '03-01-2500',
      });

      const [hlsUrl] = await hlsFile.getSignedUrl({
        action: 'read',
        expires: '03-01-2500',
      });

      // ─────────────────────────────────────────────────────────
      // UPDATE FIRESTORE
      // ─────────────────────────────────────────────────────────

      await admin.firestore()
        .collection('reels')
        .doc(videoId)
        .update({

          processed: true,

          videoUrl: mp4Url,

          hlsUrl: hlsUrl,

          thumbnailUrl: thumbUrl,

          processedAt:
            admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log('Firestore updated');

      // ─────────────────────────────────────────────────────────
      // CLEANUP
      // ─────────────────────────────────────────────────────────

      fs.rmSync(tempDir, {
        recursive: true,
        force: true,
      });

      console.log('Cleanup complete');

      return null;

    } catch (err) {

      console.error('PROCESS VIDEO ERROR:', err);

      return null;
    }
  });

