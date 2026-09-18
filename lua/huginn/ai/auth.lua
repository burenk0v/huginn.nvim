local M = {}

local function storage_path()
  local dir = vim.fn.stdpath("data") .. "/huginn"
  vim.fn.mkdir(dir, "p")
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

local function write_all(data)
  local path = storage_path()
  local file = assert(io.open(path, "w"))
  file:write(vim.json.encode(data))
  file:close()
  pcall(vim.fn.setfperm, path, "rw-------")
end

function M.get(provider)
  return read_all()[provider]
end

function M.status(provider)
  return M.get(provider) ~= nil
end

function M.logout(provider)
  local data = read_all()
  data[provider] = nil
  if next(data) then
    write_all(data)
  else
    pcall(os.remove, storage_path())
  end
end

local function random_hex(bytes)
  local result = {}
  for _ = 1, bytes do
    result[#result + 1] = ("%02x"):format(math.random(0, 255))
  end
  return table.concat(result)
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
    if not ok then
      callback(nil, "invalid JSON response")
      return
    end
    callback(data)
  end)
end

local function open_browser(url)
  vim.ui.open(url)
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
    data[provider_name] = {
      access_token = tokens.access_token,
      refresh_token = tokens.refresh_token,
      token_type = tokens.token_type or "Bearer",
      expires_in = tokens.expires_in,
    }
    write_all(data)
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

    local state = random_hex(24)
    local script = [[
import http.server
import urllib.parse
import sys

expected = sys.argv[1]

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        if query.get("state", [""])[0] != expected:
            self.send_error(400)
            return
        print(urllib.parse.urlencode({k: v[0] for k, v in query.items()}), flush=True)
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(b"<html><body>Authentication complete. Return to Neovim.</body></html>")

    def log_message(self, *_):
        pass

server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
print("PORT=" + str(server.server_port), flush=True)
server.handle_request()
]]

    local stdout = ""
    local port
    vim.system({ "python", "-u", "-c", script, state }, {
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
            open_browser(discovery.authorization_endpoint .. "?" .. query)
            vim.notify("Huginn: complete AI authentication in your browser", vim.log.levels.INFO)
          else
            local params = {}
            for key, value in line:gmatch("([^&=]+)=([^&]*)") do
              params[key] = vim.uri_decode(value)
            end
            if params.code or params.error then
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
    })
  end)
end

return M
