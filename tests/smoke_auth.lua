local function assert_equal(actual, expected, message)
  assert(actual == expected, ("%s: expected %s, got %s"):format(message, tostring(expected), tostring(actual)))
end

local data_dir = vim.fn.stdpath("data") .. "/huginn"
local credentials_path = data_dir .. "/credentials.json"

vim.fn.mkdir(data_dir, "p")
vim.fn.setfperm(data_dir, "rwxr-xr-x")

local file = assert(io.open(credentials_path, "w"))
file:write(vim.json.encode({
  target = { access_token = "target-token" },
  other = { access_token = "other-token" },
}))
file:close()

local auth = require("huginn.ai.auth")
assert_equal(auth.logout("target"), true, "credential logout succeeds")

assert_equal(vim.fn.getfperm(data_dir), "rwx------", "credential directory permissions")
assert_equal(vim.fn.getfperm(credentials_path), "rw-------", "credential file permissions")

local stored_file = assert(io.open(credentials_path, "r"))
local stored = stored_file:read("*a")
stored_file:close()
local decoded = vim.json.decode(stored)
assert_equal(decoded.target, nil, "logged-out credential is removed")
assert_equal(decoded.other.access_token, "other-token", "remaining credentials are preserved")

local temp_files = vim.fn.glob(credentials_path .. ".tmp.*", false, true)
assert_equal(#temp_files, 0, "temporary credential files are cleaned up")

local malformed_file = assert(io.open(credentials_path, "w"))
malformed_file:write("{not valid json")
malformed_file:close()
assert_equal(auth.status("target"), false, "malformed credential storage is not treated as authenticated")

local invalid_shape = assert(io.open(credentials_path, "w"))
invalid_shape:write(vim.json.encode({ target = "not-a-credential-object" }))
invalid_shape:close()
assert_equal(auth.status("target"), false, "invalid credential record shape is not treated as authenticated")

local invalid_fields = assert(io.open(credentials_path, "w"))
invalid_fields:write(vim.json.encode({
  target = { access_token = "target-token", expires_at = "not-a-timestamp" },
}))
invalid_fields:close()
assert_equal(auth.status("target"), false, "invalid credential expiry is not treated as authenticated")

local missing_token = assert(io.open(credentials_path, "w"))
missing_token:write(vim.json.encode({
  target = { expires_at = os.time() + 3600 },
}))
missing_token:close()
assert_equal(auth.status("target"), false, "credential without access token is not authenticated")

-- Stored credentials with an expired timestamp are never authenticated.
local expired = assert(io.open(credentials_path, "w"))
expired:write(vim.json.encode({ target = { access_token = "target-token", expires_at = os.time() } }))
expired:close()
assert_equal(auth.status("target"), false, "expired credential is not authenticated")


local restored_malformed = assert(io.open(credentials_path, "w"))
restored_malformed:write("{not valid json")
restored_malformed:close()
assert_equal(auth.logout("target"), false, "malformed credential storage rejects destructive updates")
assert_equal(vim.fn.filereadable(credentials_path), 1, "malformed credential storage is preserved")

vim.fn.delete(data_dir, "rf")
print("Huginn credential storage smoke test: OK")
vim.cmd("qa!")
