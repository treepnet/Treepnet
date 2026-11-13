// Puts a stand-in in place of a module under src/, before anything requires it.
const path = require('path');

const src = path.join(__dirname, '..', 'src');

function stub(relative, exports) {
    const file = path.join(src, relative);
    require.cache[file] = { id: file, filename: file, loaded: true, exports };
}

module.exports = { src, stub };
