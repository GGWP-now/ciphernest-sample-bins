const { contextBridge } = require("electron");
const crypto = require("node:crypto");

contextBridge.exposeInMainWorld("victim", {
  hash(value) {
    return crypto.createHash("sha256").update(value).digest("hex").slice(0, 24);
  }
});
