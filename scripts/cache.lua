local _M = {}

local lrucache = require "resty.lrucache"

local ITEMS_COUNT = 2
local CACHE_MIN_USES = 2

local cache, err = lrucache.new(ITEMS_COUNT)
if not cache then
    error("failed to create the cache: " .. (err or "unknown"))
end

function _M.get_static()
    local filepath = get_static_path()
    local content, staledata, use_count = cache:get(filepath)
    use_count = not use_count and 0 or use_count

    if content then
        ngx.header["X-Cache-Status"] = "HIT"
    else
        ngx.header["X-Cache-Status"] = "MISS"
        content = read_file_or_404(filepath)
        local do_cache = CACHE_MIN_USES - use_count == 1
        cache:set(filepath, do_cache and content or false, nil, use_count + 1)
    end
    ngx.print(content)
end

function _M.purge_static()
    cache:delete(get_static_path())
    ngx.exit(ngx.HTTP_NO_CONTENT)
end

function read_file_or_404(filepath)
    local f = io.open(filepath, "rb")
    if not f then
        ngx.exit(ngx.HTTP_NOT_FOUND)
    end
    local content = f:read("*all")
    f:close()
    return content
end

function get_static_path()
    return ngx.var.document_root..ngx.var.uri
end

return _M
