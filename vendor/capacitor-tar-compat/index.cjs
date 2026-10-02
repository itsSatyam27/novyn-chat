// Capacitor 6 uses TypeScript's __importDefault(require('tar')). tar 7's CJS
// exports set __esModule without providing default. Supply that interop only;
// all archive parsing and extraction remains in the patched upstream package.
const tar = require('tar-patched');
module.exports = { ...tar, default: tar };
Object.defineProperty(module.exports, '__esModule', { value: true });
