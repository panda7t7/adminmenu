PAM = PAM or {}

function PAM.DebugPrint(...)
    if Config and Config.Debug then
        print('^5[PAM DEBUG]^7', ...)
    end
end

function PAM.Trim(value)
    if type(value) ~= 'string' then return '' end
    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

function PAM.SafeString(value, maxLength)
    if type(value) ~= 'string' then return nil end
    value = PAM.Trim(value)
    if value == '' or #value > (maxLength or 250) then return nil end
    return value
end

function PAM.IsInteger(value)
    return type(value) == 'number' and value == math.floor(value)
end
