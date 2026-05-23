-- KEYS[1] = bucket key
-- ARGV[1] = capacity (int)
-- ARGV[2] = refill tokens per millisecond (float)
-- ARGV[3] = now in millis-since-epoch
-- ARGV[4] = ttl seconds (int)
-- returns 1 if allowed, 0 if throttled

local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refillPerMs = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local ttl = tonumber(ARGV[4])

local data = redis.call('HMGET', key, 'tokens', 'ts')
local tokens = tonumber(data[1])
local ts = tonumber(data[2])

if tokens == nil then
    tokens = capacity
    ts = now
end

local elapsed = now - ts
if elapsed < 0 then elapsed = 0 end
tokens = tokens + elapsed * refillPerMs
if tokens > capacity then tokens = capacity end

local allowed = 0
if tokens >= 1.0 then
    tokens = tokens - 1.0
    allowed = 1
end

redis.call('HSET', key, 'tokens', tokens, 'ts', now)
redis.call('EXPIRE', key, ttl)

return allowed
