-- cc:t Lua package manager for ComputerCraft
local json = require("dkjson")
local args = {...}

-- =========================
-- Repo management
-- =========================
local repoFile = "repo.json"
local repos = {}
local f = io.open(repoFile, "r")
if f then
    local content = f:read("*a")
    f:close()
    if content ~= "" then
        repos = json.decode(content)
    end
else
    local f = io.open(repoFile, "w")
    f:write(json.encode({}))
    f:close()
end

local function save_repos()
    local f = io.open(repoFile, "w")
    f:write(json.encode(repos, { indent = true }))
    f:close()
end

-- =========================
-- Helpers
-- =========================
local function file_exists(name)
    local f = io.open(name, "r")
    if f then f:close() return true end
    return false
end

local function download(url, out)
    print("Downloading "..url.." -> "..out)
    local success = shell.run("wget", url, out)
    return success
end

-- =========================
-- Main download functions
-- =========================
local function download_from_repos(package, version, repoList)
    local outDir = "mpt-programs"
    if not fs.exists(outDir) then
        shell.run("mkdir", outDir)
    end
    local outFile = string.format("%s/%s.lua", outDir, package)

    for _, repo in ipairs(repoList) do
        local url = string.format(
            "https://raw.githubusercontent.com/%s/refs/heads/1.0/%s/%s/%s.lua",
            repo,
            package,
            version,
            package
        )
        print("Trying "..url)
        if download(url, outFile) then
            print("Downloaded "..package.." from "..repo)
            return true
        else
            print("Failed from "..repo..", trying next...")
        end
    end
    print("Failed to download "..package.." from all repos")
    return false
end

local function download_dependencies_file(package, version, repoList)
    local tmpDir = ".tmp"
    if not fs.exists(tmpDir) then
        shell.run("mkdir", tmpDir)
    end
    local depFile = string.format("%s/dependencies-%s.json", tmpDir, package)

    for _, repo in ipairs(repoList) do
        local url = string.format(
            "https://raw.githubusercontent.com/%s/refs/heads/1.0/%s/%s/dependencies.json",
            repo,
            package,
            version
        )
        if download(url, depFile) then
            print("Downloaded dependencies for "..package)
            return depFile
        end
    end
    return nil
end

-- =========================
-- Recursive dependency installer
-- =========================
local function resolve_dependencies(package, version, repoList)
    local depFile = download_dependencies_file(package, version, repoList)
    if depFile then
        local f = io.open(depFile, "r")
        if f then
            local content = f:read("*a")
            f:close()
            local deps = json.decode(content)
            if fs.exists(depFile) then fs.delete(depFile) end
            for _, dep in ipairs(deps) do
                local depPackage = dep.package
                local depVersion = dep.version
                local depPath = string.format("mpt-programs/%s.lua", depPackage)
                if not file_exists(depPath) then
                    print("Installing dependency "..depPackage.." version "..depVersion)
                    shell.run(arg[0], "install", depPackage, depVersion)
                end
            end
        else
            print("Failed to open downloaded dependencies for "..package..", skipping.")
        end
    else
        print("No dependencies.json found for "..package..", skipping dependencies.")
    end
end

-- =========================
-- Command handling
-- =========================
if args[1] == "install" and args[2] and args[3] then
    local package = args[2]
    local version = args[3]
    print("Installing package:", package, "version:", version)

    if download_from_repos(package, version, repos) then
        resolve_dependencies(package, version, repos)
    end

elseif args[1] == "repo" and args[2] and args[3] then
    local action = args[2]
    local repoName = args[3]

    if action == "add" then
        local found = false
        for _, r in ipairs(repos) do
            if r == repoName then
                found = true
                break
            end
        end
        if not found then
            table.insert(repos, repoName)
            save_repos()
            print("Added repo: "..repoName)
        else
            print("Repo already exists: "..repoName)
        end

    elseif action == "remove" then
        local newRepos = {}
        local found = false
        for _, r in ipairs(repos) do
            if r ~= repoName then
                table.insert(newRepos, r)
            else
                found = true
            end
        end
        if found then
            repos = newRepos
            save_repos()
            print("Removed repo: "..repoName)
        else
            print("Repo not found: "..repoName)
        end

    else
        print("Unknown repo action. Use 'add' or 'remove'")
    end

else
    print("Usage:")
    print("  install <package> <version>")
    print("  repo add <user/repo>")
    print("  repo remove <user/repo>")
end