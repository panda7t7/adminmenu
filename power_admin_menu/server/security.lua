Security = { Requests = {}, RequestIds = {} }

function Security.AllowRequest(src)
    local now = GetGameTimer()
    local bucket = Security.Requests[src]
    if not bucket or now - bucket.started > Config.Security.RateLimitWindowMs then
        Security.Requests[src] = { started = now, count = 1 }
        return true
    end
    bucket.count = bucket.count + 1
    return bucket.count <= Config.Security.RateLimitMaxRequests
end

function Security.ClaimRequestId(src, requestId)
    local clean = PAM.SafeString(requestId, 80)
    if not clean then return false end
    local now = GetGameTimer()
    local bucket = Security.RequestIds[src]
    if not bucket then bucket = { seen = {}, queue = {} }; Security.RequestIds[src] = bucket end
    if bucket.seen[clean] then return false end
    bucket.seen[clean] = now
    bucket.queue[#bucket.queue + 1] = { id = clean, at = now }
    while #bucket.queue > 256 or (bucket.queue[1] and now - bucket.queue[1].at > 60000) do
        local old = table.remove(bucket.queue, 1)
        if old then bucket.seen[old.id] = nil end
    end
    return true
end

AddEventHandler('playerDropped', function()
    Security.Requests[source] = nil
    Security.RequestIds[source] = nil
end)

function Security.ValidTarget(src, target)
    if not PAM.IsInteger(target) or target < 1 or GetPlayerName(target) == nil then return false end
    if not Config.Security.AllowSelfTarget and src == target then return false end
    return true
end

function Security.ValidReason(reason, required)
    if reason == nil and not required then return true, '' end
    local clean = PAM.SafeString(reason, Config.Security.MaxReasonLength)
    if not clean and required then return false end
    return true, clean or ''
end
