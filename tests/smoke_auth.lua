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
auth.logout("target")

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

vim.fn.delete(data_dir, "rf")
print("Huginn credential storage smoke test: OK")
vim.cmd("qa!")
