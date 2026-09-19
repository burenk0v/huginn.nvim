local M = {}

local function storage_path()
  local dir = vim.fn.stdpath("data") .. "/huginn"
  vim.fn.mkdir(dir, "p")
  pcall(vim.fn.setfperm, dir, "rwx------")
  return dir .. "/credentials.json"
end

local function read_all()
  local file = io.open(storage_path(), "r")
  if not file then return {} end
  local content = file:read("*a")
  file:close()
  local ok, data = pcall(vim.json.decode, content)
  return ok and type(data) == "table" and data or {}
end

local write_sequence = 0

local function write_all(data)
  local path = storage_path()
  local content = vim.json.encode(data)
  write_sequence = write_sequence + 1
  local temp_path = ("%s.tmp.%d.%d"):format(path, vim.fn.getpid(), write_sequence)

  local fd, err = vim.uv.fs_open(temp_path, "w", 384)
  if not fd then
    vim.notify("Huginn: failed to open temporary credential storage: " .. err, vim.log.levels.ERROR)
    return false
  end

  local offset = 0
  while offset < #content do
    local written, write_err = vim.uv.fs_write(fd, content, offset)
    if not written or written == 0 then
      vim.uv.fs_close(fd)
      pcall(os.remove, temp_path)
      vim.notify("Huginn: failed to write credential storage: " .. (write_err or "no bytes written"), vim.log.levels.ERROR)
      return false
    end
    offset = offset + written
  end

  vim.uv.fs_close(fd)

  local renamed, rename_err = vim.uv.fs_rename(temp_path, path)
  if not renamed then
    pcall(os.remove, temp_path)
    vim.notify("Huginn: failed to replace credential storage: " .. rename_err, vim.log.levels.ERROR)
    return false
  end

  pcall(vim.fn.setfperm, path, "rw-------")
  return true
end

function M.get(provider)
  local credentials = read_all()[provider]
  if not credentials then
    return nil
  end

  if credentials.expires_at and tonumber(credentials.expires_at) and tonumber(credentials.expires_at) <= os.time() then
    return nil
  end

  return credentials
end

function M.status(provider)
  return M.get(provider) ~= nil
end

function M.logout(provider)
  local data = read_all()
  data[provider] = nil
  if next(data) then
    return write_all(data)
  end

  local path = storage_path()
  local ok, err = os.remove(path)
  if ok then
    return true
  end
  if vim.fn.filereadable(path) ~= 1 then
    return true
  end
  vim.notify("Huginn: failed to remove credential storage: " .. (err or "unknown error"), vim.log.levels.ERROR)
  return false
end

local function random_hex(bytes)
  local result = vim.fn.system(("openssl rand -hex %d"):format(bytes))
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.trim(result)
end

local function pkce_challenge(verifier)
  local command = "printf %s " .. vim.fn.shellescape(verifier)
    .. " | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=\n'"
  local result = vim.fn.system(command)
  if vim.v.shell_error ~= 0 or result == "" then
    return nil
  end
  return result
end

local function run_curl(args, callback)
  vim.system(args, { text = true }, function(result)
    if result.code ~= 0 then
      callback(nil, result.stderr ~= "" and result.stderr or "request failed")
      return
    end
    local ok, data = pcall(vim.json.decode, result.stdout)
    if not ok or type(data) ~= "table" or vim.tbl_islist(data) then
      callback(nil, "invalid JSON object response")
      return
    end
    callback(data)
  end)
end

local function open_browser(url)
  local _, err = vim.ui.open(url)
  if err then
    vim.notify("Huginn: failed to open browser: " .. err, vim.log.levels.ERROR)
    return false
  end
  return true
end

local function python_executable()
  for _, executable in ipairs({ "python", "python3" }) do
    local path = vim.fn.exepath(executable)
    if path ~= "" then
      return path
    end
  end
  return nil
end

local function exchange_code(provider_name, client_id, redirect_uri, verifier, token_endpoint, params)
  if params.error then
    vim.notify("Huginn: OIDC authorization failed: " .. params.error, vim.log.levels.ERROR)
    return
  end

  if not params.code then
    vim.notify("Huginn: OIDC callback did not contain an authorization code", vim.log.levels.ERROR)
    return
  end

  local body = table.concat({
    "grant_type=authorization_code",
    "code=" .. vim.uri_encode(params.code),
    "client_id=" .. vim.uri_encode(client_id),
    "redirect_uri=" .. vim.uri_encode(redirect_uri),
    "code_verifier=" .. vim.uri_encode(verifier),
  }, "&")

  run_curl({
    "curl", "-fsSL", "-X", "POST",
    "-H", "Content-Type: application/x-www-form-urlencoded",
    "--data", body,
    token_endpoint,
  }, function(tokens, err)
    if not tokens or not tokens.access_token then
      vim.notify("Huginn: OIDC token exchange failed: " .. (err or "missing access_token"), vim.log.levels.ERROR)
      return
    end

    local data = read_all()
    local expires_in = tonumber(tokens.expires_in)
    data[provider_name] = {
      access_token = tokens.access_token,
      refresh_token = tokens.refresh_token,
      token_type = tokens.token_type or "Bearer",
      expires_in = expires_in,
      expires_at = expires_in and expires_in > 0 and (os.time() + expires_in) or nil,
    }
    if not write_all(data) then
      return
    end
    vim.notify("Huginn: AI authentication successful", vim.log.levels.INFO)
  end)
end

function M.login(name, provider)
  local auth = provider.auth
  if not auth or auth.type ~= "oidc" then
    vim.notify("Huginn: AI provider does not use OIDC", vim.log.levels.ERROR)
    return
  end

  local issuer = auth.issuer:gsub("/+$", "")
  local client_id = auth.client_id
  if issuer == "" or client_id == "" then
    vim.notify("Huginn: OIDC issuer and client_id are required", vim.log.levels.ERROR)
    return
  end

  local verifier = random_hex(32)
  local state = random_hex(24)
  if not verifier or not state then
    vim.notify("Huginn: OpenSSL is required for secure OIDC authentication", vim.log.levels.ERROR)
    return
  end

  local challenge = pkce_challenge(verifier)
  if not challenge then
    vim.notify("Huginn: OpenSSL is required for OIDC PKCE", vim.log.levels.ERROR)
    return
  end

  run_curl({ "curl", "-fsSL", issuer .. "/.well-known/openid-configuration" }, function(discovery, err)
    if not discovery then
      vim.notify("Huginn: OIDC discovery failed: " .. err, vim.log.levels.ERROR)
      return
    end

    if not discovery.authorization_endpoint or not discovery.token_endpoint then
      vim.notify("Huginn: OIDC discovery is missing required endpoints", vim.log.levels.ERROR)
      return
    end

    local script = [[
import http.server
import urllib.parse
import sys

expected = sys.argv[1]

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/callback":
            self.send_error(404)
            return

        query = urllib.parse.parse_qs(parsed.query)
        if query.get("state", [""])[0] != expected:
            self.send_error(400)
            return
        print(urllib.parse.urlencode({k: v[0] for k, v in query.items()}), flush=True)
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(b"<html><body>Authentication complete. Return to Neovim.</body></html>")

    def do_POST(self):
        self.send_error(405)

    def log_message(self, *_):
        pass

server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
print("PORT=" + str(server.server_port), flush=True)
server.handle_request()
]]

    local python = python_executable()
    if not python then
      vim.notify("Huginn: Python is required for the OIDC callback server", vim.log.levels.ERROR)
      return
    end

    local stdout = ""
    local port
    local server_job
    local server_finished = false
    local function stop_server()
      if server_job and not server_finished then
        server_job:kill(15)
      end
    end

    vim.defer_fn(stop_server, 5 * 60 * 1000)

    server_job = vim.system({ python, "-u", "-c", script, state }, {
      text = true,
      stdout = function(_, data)
        if not data then return end
        stdout = stdout .. data

        while true do
          local line_end = stdout:find("\n", 1, true)
          if not line_end then return end
          local line = stdout:sub(1, line_end - 1)
          stdout = stdout:sub(line_end + 1)

          local discovered_port = line:match("^PORT=(%d+)$")
          if discovered_port then
            port = tonumber(discovered_port)
            local redirect_uri = ("http://127.0.0.1:%d/callback"):format(port)
            local query = table.concat({
              "response_type=code",
              "client_id=" .. vim.uri_encode(client_id),
              "redirect_uri=" .. vim.uri_encode(redirect_uri),
              "scope=" .. vim.uri_encode(auth.scope or "openid profile"),
              "state=" .. vim.uri_encode(state),
              "code_challenge=" .. vim.uri_encode(challenge),
              "code_challenge_method=S256",
            }, "&")
            if not open_browser(discovery.authorization_endpoint .. "?" .. query) then
              stop_server()
              return
            end
            vim.notify("Huginn: complete AI authentication in your browser", vim.log.levels.INFO)
          else
            local params = {}
            for key, value in line:gmatch("([^&=]+)=([^&]*)") do
              params[key] = vim.uri_decode(value)
            end
            if params.code or params.error then
              stop_server()
              exchange_code(
                name,
                client_id,
                ("http://127.0.0.1:%d/callback"):format(port),
                verifier,
                discovery.token_endpoint,
                params
              )
            end
          end
        end
      end,
      on_exit = function(result)
        server_finished = true
        if result.code ~= 0 and result.signal ~= 15 then
          vim.notify(
            ("Huginn: OIDC callback server exited unexpectedly (code %d, signal %d)"):format(
              result.code,
              result.signal
            ),
            vim.log.levels.ERROR
          )
        end
      end,
    })
  end)
end

return M
