const path = require('path');

const fileFilter = (req, file, cb) => {
    // Allow all file types as requested by the user
    cb(null, true);
};

module.exports = { fileFilter };
