Helpers = {}

Helpers.CreateDropId = function(dropId)
    return ('drop-%s'):format(dropId)
end

Helpers.ParseDecayRate = function(name)
    local num = name and string.match(name:lower(), "decay(%d+)")
    return num and (tonumber(num) / 100) or false
end