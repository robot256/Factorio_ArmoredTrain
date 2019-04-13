
require("script.insertAmmunition")

-- Constants mapping entities together.  Could be stored in dummy recipes.
local cannonMap = {}
cannonMap["cannon-shell"] = "platform-turret-cannon-ammo"
cannonMap["uranium-cannon-shell"] = "platform-turret-cannon-uranium-ammo"



--------------------------
--FUNCTIONS---------------
--------------------------
--Is this mod entity? If yes true, othervise false
isModEntity = function(modEntity)
	if modEntity and modEntity.valid then
		--List of known entities
		return (modEntity.name == "armored-platform-minigun-mk1" or 
		        modEntity.name == "armored-wagon-cannon-mk1" or 
		        modEntity.name == "armored-platform-rocket-mk1")
	else
		return false
	end
end


-------------
--ON_EVENTS--
-------------


--ON BUILT \/--
function entityBuilt(event)
	--createdEntity reference (to simplify usage in this context)
	local createdEntity = event.created_entity or event.entity
	
	--createdWagon now defines itself with created platform + turret (later on)
	local createdPlatform = {
		--Actual entity as class
		entity = createdEntity
	}
	
	-- If it is a turret wagon, create a proxy with createdEntity position and surface and force
	if createdEntity.name == "armored-platform-minigun-mk1" then
		createdPlatform.proxy = createdEntity.surface.create_entity{
				name = "platform-turret-minigun-mk1", 
				position = createdEntity.position, 
				force = createdEntity.force
			}
	
	elseif createdEntity.name == "armored-wagon-cannon-mk1" then		
		createdPlatform.proxy = createdEntity.surface.create_entity{
				name = "platform-turret-cannon-mk1", 
				position = createdEntity.position, 
				force = createdEntity.force
			}
	
	elseif createdEntity.name == "armored-platform-rocket-mk1" then		
		createdPlatform.proxy = createdEntity.surface.create_entity{
				name = "platform-turret-rocket-mk1", 
				position = createdEntity.position, 
				force = createdEntity.force
			}
	
	end 
	
	if createdPlatform.proxy then
		--Add created platform and turret to table (list)
		global.turretPlatformList[createdEntity.unit_number] = createdPlatform
		if createdEntity.speed ~= 0 then
			global.movingPlatformList[createdEntity.unit_number] = createdPlatform
			init_events()
		end
	end
end
--ON_BUILT EVENT
script.on_event(defines.events.on_built_entity, entityBuilt)
script.on_event(defines.events.on_robot_built_entity, entityBuilt)
script.on_event(defines.events.script_raised_built, entityBuilt)
--ON BUILT /\--




function onTrainChangedState(event)
	-- Check if a turret wagon started or stopped moving
	if event.train.speed == 0 then
		for _,wagon in pairs(event.train.carriages) do
		-- Stopped moving.  Purge movingPlatformList
			global.movingPlatformList[wagon.unit_number] = nil  -- Doesn't matter if it's not a mod entity
		end
	else
		-- Started moving, add to movingPlatformList
		for _,wagon in pairs(event.train.carriages) do
			-- Add mod entities
			if global.turretPlatformList[wagon.unit_number] then
				global.movingPlatformList[wagon.unit_number] = global.turretPlatformList[wagon.unit_number]
			end
		end
	end
	
	init_events()
end

script.on_event(defines.events.on_train_changed_state, onTrainChangedState)


function updateTurret(platform)
	if not platform then return end
	if platform.entity and platform.entity.valid and platform.proxy and platform.proxy.valid then
		--each ~ 1/3 sec do
		--GET TURRET INVENTORY
		local turretProxyInventory = platform.proxy.get_inventory(defines.inventory.turret_ammo)
		--GET WAGON INVENTORY
		local wagonInventory = platform.entity.get_inventory(defines.inventory.cargo_wagon)
		local neededAmmo = platform.proxy.automated_ammo_count
		
		if platform.entity.name == "armored-platform-minigun-mk1" then
			insertAmmunitionType(turretProxyInventory, wagonInventory, neededAmmo, "bullet")
		
		elseif platform.entity.name == "armored-wagon-cannon-mk1" then
			insertAmmunitionMap(turretProxyInventory, wagonInventory, neededAmmo, cannonMap)
			
		elseif platform.entity.name == "armored-platform-rocket-mk1" then
			insertAmmunitionType(turretProxyInventory, wagonInventory, neededAmmo, "rocket")
			
		end
		
	
		--Taken damge to TURRET is applyed to WAGON
		local damageTaken = platform.proxy.prototype.max_health - platform.proxy.health
		--prevent nullpop
		if (damageTaken > 0) then
			local platformCurrentHealth = platform.entity.health;
			--If health 0 destroy all
			if (platformCurrentHealth <= damageTaken) then
				platform.proxy.destroy();
				platform.entity.die();
			else
				--subtract wagon health by given to turret damage
				platform.entity.health = platformCurrentHealth - damageTaken;
				--redefine proxy health back to full
				platform.proxy.health = platform.proxy.prototype.max_health;
			end
		end
			
	else
		-- Proxy was destroyed. Destroy this wagon
		--remove from table
		if platform.proxy ~= nil and platform.proxy.valid then
			platform.proxy.destroy()
		end
		if platform.entity ~= nil and platform.entity.valid then
			platform.entity.destroy()
		end
		--remove from table
		global.turretPlatformList[platform.entity.unit_number] = nil
		global.movingPlatformList[platform.entity.unit_number] = nil
		init_events()
	end
		
end




--ON TICK \/--
function onTickMain(event)

	-- Move each turret to follow its wagon
	for id,platform in pairs(global.movingPlatformList) do
		if platform.proxy ~= nil and platform.proxy.valid then	--or if isEntityValid(createdPlatform.proxy) then
			--teleport i turret to i platform (good)
			platform.proxy.teleport{x = platform.entity.position.x, y = platform.entity.position.y}
		end
	end
	
	-- Update ammo and damage for a certain number of turrets each tick (default 10)
	local i = 0
	while next(global.turretsToUpdate) and i < 10 do
		updateTurret(table.remove(global.turretsToUpdate,1))
		i = i + 1
	end
	
	-- Update state of on_tick based on global queues
	init_events()

end
--ON TICK /\--


function onNthTick(event)

	if not next(global.turretsToUpdate) then
		for id , platform in pairs(global.turretPlatformList) do
			if platform.entity and platform.entity.valid and platform.proxy and platform.proxy.valid then
				table.insert(global.turretsToUpdate, platform)
			end
		end
	end
	init_events()
end

-- Update damage and ammo 2 times per second
script.on_nth_tick(30,onNthTick)






--ON REMOVED \/--
--if removed /destroyed
function entityRemoved(event)
	--Is this know enity?
	if isModEntity(event.entity) then
	
		local platform = global.turretPlatformList[event.entity.unit_number]
		
		--if Wagon still there do:
		if platform ~= nil then
			if platform.proxy ~= nil and platform.proxy.valid then
				platform.proxy.destroy()
			end
			--remove from table
			global.turretPlatformList[event.entity.unit_number] = nil
			global.movingPlatformList[event.entity.unit_number] = nil
			init_events()
		end
	end
end
script.on_event(defines.events.on_pre_player_mined_item, entityRemoved)
script.on_event(defines.events.on_robot_pre_mined, entityRemoved)
script.on_event(defines.events.script_raised_destroy, entityRemoved)
--ON REMOVED /\--


function entityDestroyed(event)
	--Is this know enity?
	if isModEntity(event.entity) then
	
		local platform = global.turretPlatformList[event.entity.unit_number]
		
		--if Wagon still there do:
		if platform ~= nil then
			if platform.proxy ~= nil and platform.proxy.valid then
				-- Add explosion?
				platform.proxy.destroy()
			end
			--remove from table
			global.turretPlatformList[event.entity.unit_number] = nil
			global.movingPlatformList[event.entity.unit_number] = nil
			init_events()
		end
	end
end
script.on_event(defines.events.on_entity_died, entityDestroyed)
script.on_event(defines.events.script_raised_destroy, entityDestroyed)



-- Scrub the list for miscataloged platform/proxy entries
function rebuildPlatformList()
	if global.turretPlatformList then
		-- Clear moving list, and rebuild it
		global.movingPlatformList = {}
		local newPlatformList = {}
		local needToRebuild = false
		for id,platform in pairs(global.turretPlatformList) do
			if id ~= platform.entity.unit_number then
				needToRebuild = true
				break
			end
		end
		for _,platform in pairs(global.turretPlatformList) do
			newPlatformList[platform.entity.unit_number] = platform
			if platform.entity.speed ~= 0 then
				global.movingPlatformList[platform.entity.unit_number] = platform
			end
		end
		global.turretPlatformList = newPlatformList
	end
end



function init_events()
	-- Subscribe to events based on global variables
	if (global.movingPlatformList and next(global.movingPlatformList)) or
		(global.turretsToUpdate and next(global.turretsToUpdate)) then
		script.on_event(defines.events.on_tick, onTickMain)
	else
		script.on_event(defines.events.on_tick, nil)
	end
end



script.on_load(
function(event)

	init_events()
end)

script.on_init(function()
	--Create table "turretPlatformList" and store data (if null create else just pass data)
	global.turretPlatformList = {}
	global.movingPlatformList = {}
	global.turretsToUpdate = {}
	init_events()
end)

script.on_configuration_changed(function()
	--Create table "turretPlatformList" and store data (if null create else just pass data)
	global.turretPlatformList = global.turretPlatformList or {}
	global.movingPlatformList = global.movingPlatformList or {}
	global.turretsToUpdate = global.turretsToUpdate or {}
	-- Probably need to rebuild these tables since we might be migrating from the old array-based system
	rebuildPlatformList()
	
	init_events()
end)
