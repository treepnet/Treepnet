/**
 * Admin Logger Utility
 * Markazlashgan log tizimi. ANSI rang kodlari orqali konsolda ma'lumotlarni ajratib ko'rsatadi.
 */

const colors = {
    reset: "\x1b[0m",
    bright: "\x1b[1m",
    dim: "\x1b[2m",
    underscore: "\x1b[4m",
    blink: "\x1b[5m",
    reverse: "\x1b[7m",
    hidden: "\x1b[8m",

    fg: {
        black: "\x1b[30m",
        red: "\x1b[31m",
        green: "\x1b[32m",
        yellow: "\x1b[33m",
        blue: "\x1b[34m",
        magenta: "\x1b[35m",
        cyan: "\x1b[36m",
        white: "\x1b[37m",
        crimson: "\x1b[38m"
    },
    bg: {
        black: "\x1b[40m",
        red: "\x1b[41m",
        green: "\x1b[42m",
        yellow: "\x1b[43m",
        blue: "\x1b[44m",
        magenta: "\x1b[45m",
        cyan: "\x1b[36m",
        white: "\x1b[47m",
        crimson: "\x1b[48m"
    }
};

class Logger {
    /**
     * HTTP so'rovlarni log qilish
     */
    static http(method, path, status, duration) {
        let statusColor = colors.fg.green;
        if (status >= 400 && status < 500) statusColor = colors.fg.yellow;
        if (status >= 500) statusColor = colors.fg.red;

        const timestamp = new Date().toLocaleTimeString();
        console.log(
            `${colors.dim}[${timestamp}]${colors.reset} ` +
            `${colors.fg.magenta}[HTTP]${colors.reset} ` +
            `${colors.bright}${method}${colors.reset} ${path} ` +
            `${statusColor}${status}${colors.reset} ` +
            `${colors.dim}-${colors.reset} ${colors.fg.cyan}${duration}ms${colors.reset}`
        );
    }

    /**
     * Socket.io kiruvchi xabarlarni log qilish
     */
    static socketIn(socketId, event, data) {
        const timestamp = new Date().toLocaleTimeString();
        console.log(
            `${colors.dim}[${timestamp}]${colors.reset} ` +
            `${colors.fg.blue}[WS IN]${colors.reset} ` +
            `${colors.fg.yellow}[${socketId}]${colors.reset} ` +
            `${colors.bright}${event}${colors.reset}:`,
            JSON.stringify(data, null, 2)
        );
    }

    /**
     * Socket.io chiquvchi xabarlarni log qilish
     */
    static socketOut(target, event, data) {
        const timestamp = new Date().toLocaleTimeString();
        console.log(
            `${colors.dim}[${timestamp}]${colors.reset} ` +
            `${colors.fg.green}[WS OUT]${colors.reset} ` +
            `${colors.fg.cyan}[${target}]${colors.reset} ` +
            `${colors.bright}${event}${colors.reset}:`,
            JSON.stringify(data, null, 2)
        );
    }

    /**
     * Umumiy ma'lumotlar uchun
     */
    static info(tag, message) {
        const timestamp = new Date().toLocaleTimeString();
        console.log(
            `${colors.dim}[${timestamp}]${colors.reset} ` +
            `${colors.fg.cyan}[${tag}]${colors.reset} ${message}`
        );
    }

    /**
     * Xatoliklar uchun
     */
    static error(tag, message, error = null) {
        const timestamp = new Date().toLocaleTimeString();
        console.error(
            `${colors.dim}[${timestamp}]${colors.reset} ` +
            `${colors.fg.red}[${tag}] ERROR:${colors.reset} ${message}`
        );
        if (error) console.error(error);
    }
}

module.exports = Logger;
