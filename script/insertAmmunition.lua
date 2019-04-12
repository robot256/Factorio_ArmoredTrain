
--[[

	Copyright 2019 by robot256 (MIT License)
 
	Take ammunition from one inventory (wagon) and load it into another (turret)
    until there are maxCount items in the target.
	Use whatever ammunition is available, and prefer earlier slots in the source inventory.
	Return the number of items transferred, or nil if inventories are invalid.

	Parameters:
	  source: the source inventory (wagon)
	  target: the target inventory (turret)
	  maxCount: desired number of items in the target inventory
	  ammoType: the type ammo to insert (optional)
	
	
	--]]
    


function insertAmmunitionType(target, source, maxCount, ammoType)

	-- Step 1: Make sure inventories are valid
	if not(source and source.valid and target and target.valid) then
		return nil
	end
	
	-- Step 2: Check if target is satisfied or source is empty
	local needed = maxCount - target.get_item_count()
	if needed <= 0 or source.is_empty() then
		return 0
	end
	
	-- Step 3: Attempt to insert each source stack after another
	local total_inserted = 0
	for i=1,#source,1 do
		local stack = source[i]
		if stack and stack.valid_for_read then
			if not ammoType or stack.prototype.get_ammo_type().category == ammoType then
				-- Attempt to insert this item
				if target.can_insert(stack) then
					local inserted = target.insert{name=stack.name,count=math.min(needed,stack.count)}
					stack.count = stack.count - inserted
					total_inserted = total_inserted + inserted
					-- Check if we need to try other stacks
					needed = maxCount - target.get_item_count()
					if needed <= 0 or source.is_empty() then
						break
					end
				end
			end
		end
	end
	return total_inserted
end


function insertAmmunitionMap(target, source, maxCount, ammoMap)

	-- Step 1: Make sure inventories are valid
	if not(source and source.valid and target and target.valid) then
		return nil
	end
	
	-- Step 2: Check if target is satisfied or source is empty
	local needed = maxCount - target.get_item_count()
	if needed <= 0 or source.is_empty() then
		return 0
	end
	
	-- Step 3: Attempt to insert each source stack after another
	local total_inserted = 0
	for i=1,#source,1 do
		local stack = source[i]
		if stack and stack.valid_for_read then
			if ammoMap[stack.name] then
				-- Attempt to insert this item
				local newStack = {name=ammoMap[stack.name],count=math.min(needed,stack.count)}
				if target.can_insert(newStack) then
					local inserted = target.insert(newStack)
					stack.count = stack.count - inserted
					total_inserted = total_inserted + inserted
					-- Check if we need to try other stacks
					needed = maxCount - target.get_item_count()
					if needed <= 0 or source.is_empty() then
						break
					end
				end
			end
		end
	end
	return total_inserted
end



return insertAmmunitionType, insertAmmunitionMap