// Android WebView polyfills for Chrome Extension APIs
// Provides compatibility for Chrome extension features in WebView environment

// ============================================================================
// DEBUG MODE - Set to true for verbose logging during development
// ============================================================================
const POLYFILL_DEBUG = false;

// Helper function for debug logging
function debugLog(...args) {
  if (POLYFILL_DEBUG) console.log(...args);
}

// Buffer polyfill with base64 support
if (typeof window.Buffer === 'undefined') {
  window.Buffer = {
    from: function(data, encoding) {
      if (typeof data === 'string' && encoding === 'base64') {
        // Decode base64 string to Uint8Array
        debugLog('Buffer.from base64: input length =', data.length);
        try {
          const binaryString = atob(data);
          const bytes = new Uint8Array(binaryString.length);
          for (let i = 0; i < binaryString.length; i++) {
            bytes[i] = binaryString.charCodeAt(i);
          }
          debugLog('Buffer.from base64: output length =', bytes.length);
          return bytes;
        } catch (error) {
          console.error('Buffer.from base64 ERROR:', error);
          throw error;
        }
      }
      if (typeof data === 'string' && encoding === 'hex') {
        // Decode hex string to Uint8Array
        debugLog('Buffer.from hex: input length =', data.length);
        try {
          const cleanHex = data.replace(/[^0-9a-fA-F]/g, '');
          if (cleanHex.length % 2 !== 0) {
            throw new Error('Invalid hex string length');
          }
          const bytes = new Uint8Array(cleanHex.length / 2);
          for (let i = 0; i < cleanHex.length; i += 2) {
            bytes[i / 2] = parseInt(cleanHex.substr(i, 2), 16);
          }
          debugLog('Buffer.from hex: output length =', bytes.length);
          return bytes;
        } catch (error) {
          console.error('Buffer.from hex ERROR:', error);
          throw error;
        }
      }
      if (typeof data === 'string') {
        // Convert string to Uint8Array (UTF-8)
        const encoder = new TextEncoder();
        return encoder.encode(data);
      }
      if (data instanceof Uint8Array) {
        return data;
      }
      if (data instanceof ArrayBuffer) {
        return new Uint8Array(data);
      }
      if (Array.isArray(data)) {
        return new Uint8Array(data);
      }
      // For other types, try to convert to Uint8Array
      return new Uint8Array(data);
    },
    alloc: function(size, fill = 0) {
      const arr = new Uint8Array(size);
      if (fill !== 0) {
        arr.fill(fill & 0xff);
      }
      return arr;
    },
    isBuffer: function(obj) {
      return obj instanceof Uint8Array;
    }
  };
}

// Add toString method to Uint8Array prototype for base64/hex encoding
if (!Uint8Array.prototype.hasOwnProperty('__originalToString')) {
  const originalToString = Uint8Array.prototype.toString;
  Object.defineProperty(Uint8Array.prototype, '__originalToString', {
    value: originalToString,
    writable: false,
    configurable: false,
    enumerable: false
  });

  Uint8Array.prototype.toString = function(encoding) {
    if (encoding === 'base64') {
      debugLog('Uint8Array.toString base64: input length =', this.length);
      try {
        let binary = '';
        const len = this.byteLength;
        for (let i = 0; i < len; i++) {
          binary += String.fromCharCode(this[i]);
        }
        const result = btoa(binary);
        debugLog('Uint8Array.toString base64: output length =', result.length);
        return result;
      } catch (error) {
        console.error('Uint8Array.toString base64 ERROR:', error);
        throw error;
      }
    }
    if (encoding === 'hex') {
      debugLog('Uint8Array.toString hex: input length =', this.length);
      const result = Array.from(this, byte => byte.toString(16).padStart(2, '0')).join('');
      debugLog('Uint8Array.toString hex: output length =', result.length);
      return result;
    }
    if (encoding === 'utf8' || encoding === 'utf-8') {
      // Decode bytes into a UTF-8 string for compatibility with Node Buffer.toString
      const decoder = new TextDecoder();
      return decoder.decode(this);
    }
    // Default behavior
    return originalToString.call(this);
  };
}

// Minimal Buffer-like numeric/write helpers needed by transaction builder
if (typeof Uint8Array.prototype.writeUInt32LE !== 'function') {
  Uint8Array.prototype.writeUInt32LE = function(value, offset = 0) {
    const v = Number(value) >>> 0; // ensure uint32
    this[offset] = v & 0xff;
    this[offset + 1] = (v >>> 8) & 0xff;
    this[offset + 2] = (v >>> 16) & 0xff;
    this[offset + 3] = (v >>> 24) & 0xff;
    return offset + 4; // match Node Buffer return
  };
}

if (typeof Uint8Array.prototype.writeBigUInt64LE !== 'function') {
  Uint8Array.prototype.writeBigUInt64LE = function(value, offset = 0) {
    const v = BigInt(value);
    for (let i = 0n; i < 8n; i++) {
      this[offset + Number(i)] = Number((v >> (8n * i)) & 0xffn);
    }
    return offset + 8;
  };
}

if (typeof Uint8Array.prototype.copy !== 'function') {
  Uint8Array.prototype.copy = function(target, targetStart = 0, sourceStart = 0, sourceEnd = this.length) {
    const srcEnd = Math.min(sourceEnd, this.length);
    let t = targetStart;
    for (let i = sourceStart; i < srcEnd; i++, t++) {
      target[t] = this[i];
    }
    return t - targetStart; // bytes copied
  };
}

// If Buffer exists (native/polyfilled), ensure its prototype also exposes these methods
if (typeof window.Buffer !== 'undefined' && window.Buffer.prototype) {
  ['writeUInt32LE', 'writeBigUInt64LE', 'copy', 'toString'].forEach(fn => {
    if (typeof Uint8Array.prototype[fn] === 'function') {
      window.Buffer.prototype[fn] = Uint8Array.prototype[fn]; // set unconditionally to avoid gaps
    }
  });
}

// Ensure any Buffer instances returned by alloc/from carry required methods
function ensureBufferMethods(buf) {
  if (!buf) return buf;
  if (typeof buf.writeUInt32LE !== 'function') buf.writeUInt32LE = Uint8Array.prototype.writeUInt32LE;
  if (typeof buf.writeBigUInt64LE !== 'function') buf.writeBigUInt64LE = Uint8Array.prototype.writeBigUInt64LE;
  if (typeof buf.copy !== 'function') buf.copy = Uint8Array.prototype.copy;
  if (typeof buf.toString !== 'function') buf.toString = Uint8Array.prototype.toString;
  return buf;
}

if (typeof window.Buffer !== 'undefined') {
  const originalAlloc = window.Buffer.alloc || ((size, fill = 0) => {
    const arr = new Uint8Array(size);
    if (fill !== 0) arr.fill(fill & 0xff);
    return arr;
  });
  const originalAllocUnsafe = window.Buffer.allocUnsafe || originalAlloc;
  window.Buffer.alloc = function(size, fill = 0) {
    const b = originalAlloc(size, fill);
    return ensureBufferMethods(b);
  };
  window.Buffer.allocUnsafe = function(size) {
    const b = originalAllocUnsafe(size);
    return ensureBufferMethods(b);
  };

  const originalFrom = window.Buffer.from || ((data, encoding) => new Uint8Array(data));
  window.Buffer.from = function(data, encoding) {
    const b = originalFrom(data, encoding);
    return ensureBufferMethods(b);
  };

  // Patch existing prototype if present
  if (window.Buffer.prototype) ensureBufferMethods(window.Buffer.prototype);
}

// Also patch Buffer from bundled 'buffer' module if present
try {
  if (typeof window.require === 'function') {
    const bufferModule = window.require('buffer');
    if (bufferModule && bufferModule.Buffer) {
      const B = bufferModule.Buffer;
      ['writeUInt32LE', 'writeBigUInt64LE', 'copy', 'toString'].forEach(fn => {
        if (typeof B.prototype[fn] !== 'function' && typeof Uint8Array.prototype[fn] === 'function') {
          B.prototype[fn] = Uint8Array.prototype[fn];
        }
      });
      const originalAlloc = B.alloc;
      const originalAllocUnsafe = B.allocUnsafe || originalAlloc;
      const originalFrom = B.from;
      if (originalAlloc) {
        B.alloc = function(size, fill = 0) {
          return ensureBufferMethods(originalAlloc.call(B, size, fill));
        };
      }
      if (originalAllocUnsafe) {
        B.allocUnsafe = function(size) {
          return ensureBufferMethods(originalAllocUnsafe.call(B, size));
        };
      }
      if (originalFrom) {
        B.from = function(data, encoding) {
          return ensureBufferMethods(originalFrom.call(B, data, encoding));
        };
      }
      // Keep global Buffer in sync
      window.Buffer = B;
    }
  }
} catch (e) {
  debugLog('Buffer module patch skipped:', e);
}

// Ensure global aliases
if (typeof globalThis !== 'undefined') {
  globalThis.Buffer = window.Buffer;
  if (typeof globalThis.global === 'object') {
    globalThis.global.Buffer = window.Buffer;
  }
}

// Chrome extension API polyfills
if (typeof window.chrome === 'undefined') {
  window.chrome = {};
}

// Mark this as an Android WebView environment so the app knows not to show extension-only features
window.__MOCHI_ANDROID_WEBVIEW__ = true;

window.chrome.runtime = {
  id: 'android-webview-mock',
  getURL: function(path) {
    return 'file:///android_asset/' + path;
  },
  connect: function(connectInfo) {
    debugLog('Chrome runtime connect called:', connectInfo);
    const messageListeners = [];
    const port = {
      onDisconnect: {
        addListener: function(callback) {
          debugLog('onDisconnect listener added');
        }
      },
      onMessage: {
        addListener: function(callback) {
          debugLog('onMessage listener added');
          messageListeners.push(callback);
        }
      },
      postMessage: function(message) {
        debugLog('postMessage called:', message);
        // Auto-respond to session manager messages
        if (message.type && message.messageId) {
          const response = {
            messageId: message.messageId,
            success: true
          };
          
          // Handle different message types
          switch(message.type) {
            case 'checkSession':
              response.data = { active: false }; // No active session by default
              break;
            case 'startSession':
              response.success = true;
              break;
            case 'endSession':
              response.success = true;
              break;
            case 'extendSession':
              response.success = true;
              break;
            case 'recordActivity':
              response.success = true;
              break;
            default:
              response.success = true;
              response.data = {};
          }
          
          // Send response back to listeners
          setTimeout(() => {
            messageListeners.forEach(listener => listener(response));
          }, 0);
        }
      },
      disconnect: function() {
        debugLog('disconnect called');
      }
    };
    return port;
  },
  sendMessage: function(message, responseCallback) {
    debugLog('Chrome runtime sendMessage called:', message);
    if (responseCallback) {
      setTimeout(() => responseCallback({ success: true }), 0);
    }
    return Promise.resolve({ success: true });
  },
  onMessage: {
    addListener: function(callback) {
      debugLog('Chrome runtime onMessage listener added');
    }
  }
};

window.chrome.tabs = {
  query: function(queryInfo, callback) {
    debugLog('Chrome tabs query called:', queryInfo);
    const fakeTab = {
      id: 1,
      active: true,
      url: 'file:///android_asset/index.html',
      title: 'Mochi Wallet'
    };
    if (callback) {
      callback([fakeTab]);
    }
    return Promise.resolve([fakeTab]);
  },
  getCurrent: function(callback) {
    debugLog('Chrome tabs getCurrent called');
    const fakeTab = {
      id: 1,
      active: true,
      url: 'file:///android_asset/index.html',
      title: 'Mochi Wallet'
    };
    if (callback) {
      callback(fakeTab);
    }
    return Promise.resolve(fakeTab);
  }
};

// Custom serialization for binary data (Buffers, Uint8Array, ArrayBuffer)
const StorageSerializer = {
  serialize: function(obj) {
    // Log the top-level object structure before serialization
    if (POLYFILL_DEBUG) {
      debugLog('StorageSerializer.serialize: obj type=' + (obj && obj.constructor ? obj.constructor.name : typeof obj));
      if (obj && typeof obj === 'object') {
        Object.keys(obj).forEach(function(k) {
          const v = obj[k];
          const vType = v && v.constructor ? v.constructor.name : typeof v;
          const isUint8 = v instanceof Uint8Array;
          debugLog('StorageSerializer.serialize: obj.' + k + ' type=' + vType + ' isUint8Array=' + isUint8);
        });
      }
    }
    
    return JSON.stringify(obj, function(key, value) {
      // Handle Uint8Array - check instanceof first
      if (value instanceof Uint8Array) {
        debugLog('StorageSerializer: Serializing Uint8Array for key:', key, 'length:', value.length);
        return { 
          __type: 'Uint8Array', 
          __data: Array.from(value)
        };
      }
      // Fallback check by constructor name
      if (value && value.constructor && value.constructor.name === 'Uint8Array') {
        debugLog('StorageSerializer: Serializing Uint8Array (by name) for key:', key, 'length:', value.length);
        return { 
          __type: 'Uint8Array', 
          __data: Array.from(value)
        };
      }
      // Handle Buffer (Node.js Buffer object)
      if (value && value.type === 'Buffer' && Array.isArray(value.data)) {
        debugLog('StorageSerializer: Serializing Buffer for key:', key, 'length:', value.data.length);
        return { 
          __type: 'Buffer', 
          __data: value.data 
        };
      }
      // Handle ArrayBuffer
      if (value instanceof ArrayBuffer) {
        debugLog('StorageSerializer: Serializing ArrayBuffer for key:', key, 'byteLength:', value.byteLength);
        return { 
          __type: 'ArrayBuffer', 
          __data: Array.from(new Uint8Array(value)) 
        };
      }
      if (value && value.constructor && value.constructor.name === 'ArrayBuffer') {
        debugLog('StorageSerializer: Serializing ArrayBuffer (by name) for key:', key, 'byteLength:', value.byteLength);
        return { 
          __type: 'ArrayBuffer', 
          __data: Array.from(new Uint8Array(value)) 
        };
      }
      return value;
    });
  },
  
  deserialize: function(str) {
    return JSON.parse(str, function(key, value) {
      if (value && typeof value === 'object' && value.__type) {
        switch(value.__type) {
          case 'Uint8Array':
            debugLog('StorageSerializer: Deserializing Uint8Array for key:', key, 'length:', value.__data.length);
            return new Uint8Array(value.__data);
          case 'Buffer':
            debugLog('StorageSerializer: Deserializing Buffer for key:', key, 'length:', value.__data.length);
            // Create a Uint8Array and add Buffer-like properties
            const uint8 = new Uint8Array(value.__data);
            uint8.type = 'Buffer';
            return uint8;
          case 'ArrayBuffer':
            debugLog('StorageSerializer: Deserializing ArrayBuffer for key:', key, 'length:', value.__data.length);
            return new Uint8Array(value.__data).buffer;
        }
      }
      return value;
    });
  }
};

window.chrome.storage = {
  local: {
    get: function(keys, callback) {
      debugLog('chrome.storage.local.get called with keys:', keys);
      return new Promise((resolve) => {
        const result = {};
        if (typeof keys === 'string') {
          const value = localStorage.getItem(keys);
          debugLog('chrome.storage.local.get: key=' + keys + ', value=' + (value ? 'exists' : 'null'));
          if (value) {
            try {
              result[keys] = StorageSerializer.deserialize(value);
            } catch(e) {
              console.error('chrome.storage.local.get: Error parsing value for key=' + keys, e);
            }
          }
        } else if (Array.isArray(keys)) {
          keys.forEach(key => {
            const value = localStorage.getItem(key);
            debugLog('chrome.storage.local.get: key=' + key + ', value=' + (value ? 'exists' : 'null'));
            if (value) {
              try {
                result[key] = StorageSerializer.deserialize(value);
              } catch(e) {
                console.error('chrome.storage.local.get: Error parsing value for key=' + key, e);
              }
            }
          });
        } else if (typeof keys === 'object' && keys !== null) {
          // Handle object with default values
          Object.keys(keys).forEach(key => {
            const value = localStorage.getItem(key);
            debugLog('chrome.storage.local.get: key=' + key + ', value=' + (value ? 'exists' : 'null'));
            if (value) {
              try {
                result[key] = StorageSerializer.deserialize(value);
              } catch(e) {
                console.error('chrome.storage.local.get: Error parsing value for key=' + key, e);
                result[key] = keys[key]; // Use default value
              }
            } else {
              result[key] = keys[key]; // Use default value
            }
          });
        }
        debugLog('chrome.storage.local.get result keys:', Object.keys(result));
        
        // Chrome's storage API calls the callback synchronously
        if (callback) {
          callback(result);
        }
        resolve(result);
      });
    },
    set: function(items, callback) {
      debugLog('chrome.storage.local.set called with items keys:', Object.keys(items));
      return new Promise((resolve) => {
        Object.keys(items).forEach(key => {
          debugLog('chrome.storage.local.set: storing key=' + key);
          try {
            const serialized = StorageSerializer.serialize(items[key]);
            debugLog('chrome.storage.local.set: serialized length=' + serialized.length + ' chars');
            localStorage.setItem(key, serialized);
          } catch(e) {
            console.error('chrome.storage.local.set: Error storing key=' + key, e);
          }
        });
        if (callback) {
          callback();
        }
        resolve();
      });
    },
    remove: function(keys, callback) {
      if (typeof keys === 'string') {
        localStorage.removeItem(keys);
      } else if (Array.isArray(keys)) {
        keys.forEach(key => localStorage.removeItem(key));
      }
      if (callback) callback();
    },
    clear: function(callback) {
      localStorage.clear();
      if (callback) callback();
    }
  },
  sync: {
    get: function(keys, callback) {
      return window.chrome.storage.local.get(keys, callback);
    },
    set: function(items, callback) {
      return window.chrome.storage.local.set(items, callback);
    }
  }
};

// Verify critical APIs are available
if (POLYFILL_DEBUG) {
  console.log('Polyfills: Testing Math.random():', Math.random());
  console.log('Polyfills: Testing crypto.getRandomValues...');
  if (window.crypto && window.crypto.getRandomValues) {
    const testArray = new Uint8Array(10);
    window.crypto.getRandomValues(testArray);
    console.log('Polyfills: crypto.getRandomValues works:', Array.from(testArray).join(','));
  }
  if (window.crypto && window.crypto.subtle) {
    console.log('Polyfills: SubtleCrypto is available');
  }
}

// Critical API availability checks (always log errors)
if (!window.crypto || !window.crypto.getRandomValues) {
  console.error('CRITICAL: crypto.getRandomValues NOT available! Wallet security compromised.');
}
if (!window.crypto || !window.crypto.subtle) {
  console.error('CRITICAL: SubtleCrypto NOT available! Encryption may fail.');
}

debugLog('Android WebView polyfills loaded');

// Intercept Error constructor to log more details about "Invalid tag" errors (debug only)
if (POLYFILL_DEBUG) {
  const OriginalError = window.Error;
  window.Error = function(message) {
    if (message && message.includes('Invalid tag')) {
      console.error('INTERCEPTED: Invalid tag error!');
      console.error('Error stack trace:', new OriginalError().stack);
    }
    return new OriginalError(message);
  };
  window.Error.prototype = OriginalError.prototype;
}

