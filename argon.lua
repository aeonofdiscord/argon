argon = {}
argon.null = {}
argon.undefined = {}
argon.indent_objects = true

function argon.isalpha(c)
	local b = string.byte(c)
	local lower = b >= string.byte('a') and b <= string.byte('z')
	local upper = b >= string.byte('A') and b <= string.byte('Z')
	return lower or upper
end

function argon.isnumeric(c)
	local b = string.byte(c)
	return b >= string.byte('0') and b <= string.byte('9')
end

function argon.isalnum(c)
	return argon.isalpha(c) or argon.isnumeric(c)
end

function argon.isspace(c)
	return c == ' ' or c == '\t' or c == '\r' or c == '\n'
end

function argon.error(str)
	error("argon: " .. str)
end

function argon.expected(c)
	argon.error("'" .. c .. "' expected")
end

function argon.strip(str)
	while argon.isspace(string.sub(str, 1, 1)) do
		str = string.sub(str, 2)
	end
	return str
end

function argon.getc(str)
	local c = string.sub(str, 1, 1)
	local tail = string.sub(str, 2)
	if c == '' then
		argon.error("unexpected eof.")
	end
	return c,tail
end

function argon.readkey(str)
	local key = ''
	str = argon.strip(str)
	local c = argon.getc(str)
	if c == '"' then
		key,str = argon.readstring(str)
	else
		if not (c == '_' or argon.isalpha(c)) then
			argon.error("key expected.")
		end
		
		while true do
			c = argon.getc(str)
			if argon.isalnum(c) or c == '_' then
				key = key .. c
				c,str = argon.getc(str)
			else
				break
			end
		end
	end	
	
	str = argon.strip(str)
	if argon.getc(str) ~= ':' then
		argon.expected(':')	
	end
	return key,str	
end

function argon.readstring(str)
	c,str = argon.getc(str)
	local value = ''
	local done = false
	while not done do
		c,str = argon.getc(str)		
		if c == '\\' then
			local n = ''
			n, str = argon.getc(str)
			if n == '\\' then
				value = value .. '\\'
			elseif n == 't' then
				value = value .. '\t'
			elseif n == 'r' then
				value = value .. '\r'
			elseif n == 'n' or n == '\n' then
				value = value .. '\n'
			elseif n == '"' then
				value = value .. '"'
			else
				argon.error("unknown special character: '\\" ..n .."' (use \\\\ for backslash).")
			end
		elseif c == '"' then
			return value,str
		elseif c ~= '\n' then
			value = value .. c
		end	
	end
end

function argon.readnumber(str)
	local value = ''
	local dot = true
	while true do
		local c = argon.getc(str)		
		if argon.isnumeric(c) then
			value = value .. c
			c,str = argon.getc(str)
		elseif c == '.' then
			value = value .. c
			dot = true
			c,str = argon.getc(str)
		else
			local n = tonumber(value)
			if n == nil then argon.error("number expected.") end
			return n,str
		end
	end
end

function argon.readsymbol(str)
	local value = ''
	
	while true do
		local c = argon.getc(str)
		if argon.isalpha(c) then		
			value = value .. c
			c,str = argon.getc(str)
		elseif c == ',' or c == '}' then
			break			
		else
			argon.error("character expected (got '" .. c .."').")
		end
	end
	
	local v = argon.null
	if value == 'null' then
		v = argon.null
	elseif value == 'true' then
		v = true
	elseif value == 'false' then
		v = false
	else
		argon.error("undefined constant: '"..value.."'")
	end
	return v,str
end

function argon.readarray(str)
	local array = {}
	local c = argon.getc(str)
	if c ~= '[' then
		argon.error("'[' expected.")
	end
	c,str = argon.getc(str)
	while true do		
		local value = argon.null
		c = argon.getc(str)
		if c == ']' then
			c,str = argon.getc(str)
			break
		else
			value,str = argon.readvalue(str)
			
			if value ~= argon.undefined then
				table.insert(array, value)
			end
			c = argon.getc(str)
			if c == ',' then
				c,str = argon.getc(str)
			elseif c ~= ']' then
				argon.error("',' or ']' expected.")
			end
		end
	end
	return array,str
end

function argon.readvalue(str)
	str = argon.strip(str)
	local value = argon.undefined
	
	c = argon.getc(str)
	if c == '"' then
		value,str = argon.readstring(str)
	elseif argon.isnumeric(c) then
		value,str = argon.readnumber(str)
	elseif argon.isalpha(c) then
		value,str = argon.readsymbol(str)
	elseif c == '{' then
		value,str = argon.readobject(str)
	elseif c == '[' then
		value,str = argon.readarray(str)
	end
	str = argon.strip(str)
	
	return value,str
end

function argon.readobject(str)
	local data = {}
	
	local c = ''
	str = argon.strip(str)
	
	c,str = argon.getc(str)
	
	if c ~= '{' then
		argon.expected('{')
	end
	
	while true do
		local key = ''
		local value = argon.null
		str = argon.strip(str)
		c = argon.getc(str)
		
		if c == '}' then
			c,str = argon.getc(str)
			return data,str
		end
		
		key,str = argon.readkey(str)
		str = argon.strip(str)
		c,str = argon.getc(str)
		
		if c ~= ':' then argon.expected(':') end
		str = argon.strip(str)
		value,str = argon.readvalue(str)
		
		data[key] = value
		
		str = argon.strip(str)
		c = argon.getc(str)
		
		if c == ',' then
			c,str = argon.getc(str)
			str = argon.strip(str)
		elseif c ~= '}' then
			argon.error("',' or '}' expected.")
		end
	end
	
	return data,str
end

function argon.load(str)
	local data, str = argon.readobject(str)
	return data
end

function argon.iskey(str)	
	for i=1,#str do
		local c = string.sub(str, i, i)
		
		if i == 1 and not (argon.isalpha(c) or c == '_') then 
			return false
		elseif not (argon.isalnum(c) or c == '_') then 
			return false
		end
	end
	return true
end

function argon.isarray(t)
	if not #t then return false end	
	for k,v in pairs(t) do
		if type(k) ~= 'number' or math.floor(k) ~= k then
			return false
		end
	end	
	return true
end

function argon.encode(v, indent)
	if not indent then indent = 1 end
	
	if v == nil or v == argon.null then
		return 'null'
	elseif v == true then
		return 'true'
	elseif v == false then
		return 'false'
	elseif type(v) == 'string' then
		return '"' .. v .. '"'
	elseif type(v) == 'number' then
		return tostring(v)
	elseif type(v) == 'table' then
		if argon.isarray(v) then
			local str = '['
			if argon.indent_arrays then str = str .. '\n' end
			
			for i=1,#v do
				if argon.indent_arrays then
					for i=1,indent do str = str .. '\t' end
				end
				str = str .. argon.encode(v[i]) .. ','
				if argon.indent_arrays then
					str = str .. '\n'
				end
			end
			if argon.indent_arrays then
				for i=1,indent-1 do str = str .. '\t' end
			end
			return str .. ']'
		else
			local str = '{'
			if argon.indent_objects then
				str = str .. '\n'
			end
	
			for k,iv in pairs(v) do				
				if argon.indent_objects then
					for i=1,indent do str = str .. '\t' end
				end
				
				if argon.iskey(k) then
					str = str .. k
				else
					str = str .. '"' .. tostring(k) .. '"'
				end
				str = str .. ': '				
				str = str .. argon.encode(iv, indent+1)
				str = str .. ','
				if argon.indent_objects then
					str = str .. '\n'
				end
			end
			
			for i=1,indent-1 do str = str .. '\t' end
			return str .. '}'
		end
	end
end

function argon.save(data)
	return argon.encode(data)
end
