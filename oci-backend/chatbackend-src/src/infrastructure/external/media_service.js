const ffmpeg = require('fluent-ffmpeg');
const fs = require('fs');
const path = require('path');

// Logic to find ffmpeg/ffprobe
let finalFfmpegPath = require('ffmpeg-static');
let finalFfprobePath = require('ffprobe-static').path;

// In Docker Alpine, use system binaries if available
if (process.platform === 'linux') {
    if (fs.existsSync('/usr/bin/ffmpeg')) finalFfmpegPath = '/usr/bin/ffmpeg';
    if (fs.existsSync('/usr/bin/ffprobe')) finalFfprobePath = '/usr/bin/ffprobe';
}

ffmpeg.setFfmpegPath(finalFfmpegPath);
ffmpeg.setFfprobePath(finalFfprobePath);

class MediaService {
    async getDuration(filePath) {
        return new Promise((resolve) => {
            ffmpeg.ffprobe(filePath, (err, metadata) => {
                if (err) return resolve(0);
                resolve(metadata.format.duration || 0);
            });
        });
    }

    async generateThumbnail(filePath, outPath) {
        return new Promise((resolve) => {
            ffmpeg(filePath)
                .on('end', () => resolve(true))
                .on('error', () => resolve(false))
                .screenshots({
                    count: 1,
                    timemarks: ['1'],
                    filename: path.basename(outPath),
                    folder: path.dirname(outPath)
                });
        });
    }

    generateWaveformSvg(peaks) {
        const width = 100;
        const height = 40;
        const barWidth = width / peaks.length;
        let bars = "";
        peaks.forEach((peak, i) => {
            const h = Math.max(6, (peak / 100) * height);
            const x = i * barWidth;
            const y = (height - h) / 2;
            bars += `<rect x="${x.toFixed(2)}" y="${y.toFixed(2)}" width="${(barWidth * 0.85).toFixed(2)}" height="${h.toFixed(2)}" rx="1.5" />`;
        });
        return `<svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" preserveAspectRatio="none" fill="currentColor">${bars}</svg>`;
    }

    formatDuration(seconds) {
        if (!seconds || isNaN(seconds)) return "0:00";
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    }

    // Add other media methods here...
}

module.exports = new MediaService();
