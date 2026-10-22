/* Shared transport. Sessions are server-issued cookies; no token or personal data is persisted in browser storage. */
(() => {
  const mode = new URLSearchParams(location.search).get("mode") === "demo" ? "demo" : "real";
  const meta = document.querySelector('meta[name="arena-api-base"]');
  const base = (meta && meta.content ? meta.content : "/api").replace(/\/$/, "");
  const cookie = name => {
    const entry = document.cookie.split("; ").find(part => part.startsWith(name + "="));
    return entry ? decodeURIComponent(entry.slice(name.length + 1)) : "";
  };
  async function request(path, options = {}) {
    if (mode === "demo") throw new Error("A API não é usada no modo demonstração.");
    if (!path.startsWith("/") || path.startsWith("//")) throw new Error("Rota de API inválida.");
    const method = (options.method || "GET").toUpperCase();
    const headers = { Accept: "application/json", ...(options.headers || {}) };
    const init = { method, headers, credentials: "include", cache: "no-store" };
    if (options.body !== undefined) {
      headers["Content-Type"] = "application/json";
      init.body = JSON.stringify(options.body);
    }
    if (!["GET", "HEAD", "OPTIONS"].includes(method)) {
      const csrf = cookie("arena_csrf");
      if (csrf) headers["X-CSRF-Token"] = csrf;
    }
    const response = await fetch(base + path, init);
    const raw = await response.text();
    let data = {};
    try { data = raw ? JSON.parse(raw) : {}; } catch (_) {}
    if (!response.ok) {
      const error = new Error(data.message || "Falha na comunicação com o servidor.");
      error.status = response.status;
      throw error;
    }
    return data;
  }
  window.ArenaApp = Object.freeze({ mode, request });
})();