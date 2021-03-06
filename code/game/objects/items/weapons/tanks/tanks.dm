/obj/item/weapon/tank
	name = "tank"
	icon = 'icons/obj/tank.dmi'
	flags = CONDUCT
	slot_flags = SLOT_BACK
	hitsound = 'sound/weapons/smash.ogg'

	pressure_resistance = ONE_ATMOSPHERE*5

	force = 5
	throwforce = 10
	throw_speed = 1
	throw_range = 4

	var/datum/gas_mixture/air_contents = null
	var/distribute_pressure = ONE_ATMOSPHERE
	var/integrity = 3
	var/volume = 70

/obj/item/weapon/tank/suicide_act(mob/user)
	var/mob/living/carbon/human/H = user
	user.visible_message("<span class='suicide'>[user] is putting the [src]'s valve to their lips! I don't think they're gonna stop!</span>")
	playsound(loc, 'sound/effects/spray.ogg', 10, 1, -3)
	if (H && !qdeleted(H))
		for(var/obj/item/W in H)
			H.unEquip(W)
			if(prob(50))
				step(W, pick(alldirs))
		H.hair_style = "Bald"
		H.update_hair()
		H.blood_max = 5
		gibs(H.loc, H.viruses, H.dna)
		H.adjustBruteLoss(1000) //to make the body super-bloody

	return (BRUTELOSS)

/obj/item/weapon/tank/New()
	..()

	src.air_contents = new /datum/gas_mixture()
	src.air_contents.volume = volume //liters
	src.air_contents.temperature = T20C

	SSobj.processing |= src

	return

/obj/item/weapon/tank/Destroy()
	if(air_contents)
		qdel(air_contents)

	SSobj.processing.Remove(src)

	return ..()

/obj/item/weapon/tank/examine(mob/user)
	var/obj/icon = src
	..()
	if (istype(src.loc, /obj/item/assembly))
		icon = src.loc
	if (!in_range(src, user))
		if (icon == src) user << "<span class='notice'>If you want any more information you'll need to get closer.</span>"
		return

	user << "<span class='notice'>The pressure gauge reads [src.air_contents.return_pressure()] kPa.</span>"

	var/celsius_temperature = src.air_contents.temperature-T0C
	var/descriptive

	if (celsius_temperature < 20)
		descriptive = "cold"
	else if (celsius_temperature < 40)
		descriptive = "room temperature"
	else if (celsius_temperature < 80)
		descriptive = "lukewarm"
	else if (celsius_temperature < 100)
		descriptive = "warm"
	else if (celsius_temperature < 300)
		descriptive = "hot"
	else
		descriptive = "furiously hot"

	user << "<span class='notice'>It feels [descriptive].</span>"

/obj/item/weapon/tank/blob_act()
	if(prob(50))
		var/turf/location = src.loc
		if (!( istype(location, /turf) ))
			qdel(src)

		if(src.air_contents)
			location.assume_air(air_contents)

		qdel(src)

/obj/item/weapon/tank/attackby(obj/item/weapon/W, mob/user, params)
	..()

	add_fingerprint(user)
	if (istype(src.loc, /obj/item/assembly))
		icon = src.loc

	if ((istype(W, /obj/item/device/analyzer)) && get_dist(user, src) <= 1)
		atmosanalyzer_scan(air_contents, user)

	if(istype(W, /obj/item/device/assembly_holder))
		bomb_assemble(W,user)

/obj/item/weapon/tank/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = 0, \
									datum/tgui/master_ui = null, datum/ui_state/state = hands_state)
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "tanks", name, 420, 200, master_ui, state)
		ui.open()

/obj/item/weapon/tank/get_ui_data()
	var/list/data = list()
	data["tankPressure"] = round(air_contents.return_pressure() ? air_contents.return_pressure() : 0)
	data["releasePressure"] = round(distribute_pressure ? distribute_pressure : 0)
	data["defaultReleasePressure"] = round(TANK_DEFAULT_RELEASE_PRESSURE)
	data["minReleasePressure"] = round(TANK_MIN_RELEASE_PRESSURE)
	data["maxReleasePressure"] = round(TANK_MAX_RELEASE_PRESSURE)

	var/mob/living/carbon/user = null
	if(istype(loc, /mob/living/carbon))
		user = loc
	else if(istype(loc.loc, /mob/living/carbon))
		user = loc.loc

	if(user && user.internal == src)
		data["valveOpen"] = TRUE
	else
		data["valveOpen"] = FALSE

	if(user.wear_mask && (user.wear_mask.flags & MASKINTERNALS))
		if(data["valveOpen"] || ((src in user) && !user.internal))
			data["maskConnected"] = TRUE
		else
			data["maskConnected"] = FALSE
	return data

/obj/item/weapon/tank/ui_act(action, params)
	if(..())
		return
	switch(action)
		if("pressure")
			var/pressure = params["pressure"]
			if(pressure == "reset")
				distribute_pressure = TANK_DEFAULT_RELEASE_PRESSURE
				. = TRUE
			else if(pressure == "min")
				distribute_pressure = TANK_MIN_RELEASE_PRESSURE
				. = TRUE
			else if(pressure == "max")
				distribute_pressure = TANK_MAX_RELEASE_PRESSURE
				. = TRUE
			else if(pressure == "input")
				pressure = input("New release pressure ([TANK_MIN_RELEASE_PRESSURE]-[TANK_MAX_RELEASE_PRESSURE] kPa):", name, distribute_pressure) as num|null
				. = .(action, list("pressure" = pressure))
			else if(text2num(pressure) != null)
				distribute_pressure = Clamp(round(text2num(pressure)), TANK_MIN_RELEASE_PRESSURE, TANK_MAX_RELEASE_PRESSURE)
				. = TRUE
		if("valve")
			var/mob/living/carbon/user = loc
			if(!istype(user))
				return
			if(user.internal == src)
				user.internal = null
				user.internals.icon_state = "internal0"
				usr << "<span class='notice'>You close the tank release valve.</span>"
				. = TRUE
			else
				if(user.wear_mask && (user.wear_mask.flags & MASKINTERNALS))
					user.internal = src
					user.internals.icon_state = "internal1"
					usr << "<span class='notice'>You open \the [src] valve.</span>"
					. = TRUE
				else
					usr << "<span class='warning'>You need something to connect to [src]!</span>"


/obj/item/weapon/tank/remove_air(amount)
	return air_contents.remove(amount)

/obj/item/weapon/tank/return_air()
	return air_contents

/obj/item/weapon/tank/assume_air(datum/gas_mixture/giver)
	air_contents.merge(giver)

	check_status()
	return 1

/obj/item/weapon/tank/proc/remove_air_volume(volume_to_return)
	if(!air_contents)
		return null

	var/tank_pressure = air_contents.return_pressure()
	if(tank_pressure < distribute_pressure)
		distribute_pressure = tank_pressure

	var/moles_needed = distribute_pressure*volume_to_return/(R_IDEAL_GAS_EQUATION*air_contents.temperature)

	return remove_air(moles_needed)

/obj/item/weapon/tank/process()
	//Allow for reactions
	air_contents.react()
	check_status()


/obj/item/weapon/tank/proc/check_status()
	//Handle exploding, leaking, and rupturing of the tank

	if(!air_contents)
		return 0

	var/pressure = air_contents.return_pressure()
	if(pressure > TANK_FRAGMENT_PRESSURE)
		if(!istype(src.loc,/obj/item/device/transfer_valve))
			message_admins("Explosive tank rupture! Last key to touch the tank was [src.fingerprintslast].")
			log_game("Explosive tank rupture! Last key to touch the tank was [src.fingerprintslast].")
		//world << "\blue[x],[y] tank is exploding: [pressure] kPa"
		//Give the gas a chance to build up more pressure through reacting
		air_contents.react()
		air_contents.react()
		air_contents.react()
		pressure = air_contents.return_pressure()
		var/range = (pressure-TANK_FRAGMENT_PRESSURE)/TANK_FRAGMENT_SCALE
		var/turf/epicenter = get_turf(loc)

		//world << "\blue Exploding Pressure: [pressure] kPa, intensity: [range]"

		explosion(epicenter, round(range*0.25), round(range*0.5), round(range), round(range*1.5))
		if(istype(src.loc,/obj/item/device/transfer_valve))
			qdel(src.loc)
		else
			qdel(src)

	else if(pressure > TANK_RUPTURE_PRESSURE)
		//world << "\blue[x],[y] tank is rupturing: [pressure] kPa, integrity [integrity]"
		if(integrity <= 0)
			var/turf/simulated/T = get_turf(src)
			if(!T)
				return
			T.assume_air(air_contents)
			playsound(src.loc, 'sound/effects/spray.ogg', 10, 1, -3)
			qdel(src)
		else
			integrity--

	else if(pressure > TANK_LEAK_PRESSURE)
		//world << "\blue[x],[y] tank is leaking: [pressure] kPa, integrity [integrity]"
		if(integrity <= 0)
			var/turf/simulated/T = get_turf(src)
			if(!T)
				return
			var/datum/gas_mixture/leaked_gas = air_contents.remove_ratio(0.25)
			T.assume_air(leaked_gas)
		else
			integrity--

	else if(integrity < 3)
		integrity++
