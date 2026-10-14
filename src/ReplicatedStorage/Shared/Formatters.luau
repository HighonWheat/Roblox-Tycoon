-- ReplicatedStorage/Shared/Formatters.luau
local Formatters = {}

function Formatters.FormatNumber(n: number): string
	if not n or type(n) ~= "number" then return "0" end
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	else
		return tostring(math.floor(n))
	end
end

function Formatters.FormatTime(seconds: number): string
	if not seconds or type(seconds) ~= "number" then return "00:00" end
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

function Formatters.FormatDuration(seconds: number): string
	if not seconds or seconds <= 0 then return "0s" end
	local s = math.floor(seconds)
	local hours = math.floor(s / 3600)
	local mins = math.floor((s % 3600) / 60)
	local secs = s % 60

	if hours > 0 then
		if mins > 0 then
			return string.format("%dh %dm", hours, mins)
		else
			return string.format("%dh", hours)
		end
	elseif mins > 0 then
		if secs > 0 then
			return string.format("%dm %ds", mins, secs)
		else
			return string.format("%dm", mins)
		end
	else
		return string.format("%ds", secs)
	end
end

return Formatters
