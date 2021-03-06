/obj/machinery/portable_atmospherics/scrubber
	name = "portable air scrubber"

	icon = 'icons/obj/atmos.dmi'
	icon_state = "pscrubber:0"
	density = 1

	var/on = 0
	var/volume_rate = 800
	var/widenet = 0 //is this scrubber acting on the 3x3 area around it.

	volume = 750

	var/list/gases_to_scrub = list("plasma", "co2", "agent_b", "n2o") //datum var so we can VV it and maybe even change it in the future



/obj/machinery/portable_atmospherics/scrubber/emp_act(severity)
	if(stat & (BROKEN|NOPOWER))
		..(severity)
		return

	if(prob(50/severity))
		on = !on
		update_icon()

	..(severity)


/obj/machinery/portable_atmospherics/scrubber/update_icon()
	src.overlays = 0

	if(on)
		icon_state = "pscrubber:1"
	else
		icon_state = "pscrubber:0"

	if(holding)
		overlays += "scrubber-open"

	if(connected_port)
		overlays += "scrubber-connector"

	return

/obj/machinery/portable_atmospherics/scrubber/process_atmos()
	..()

	if(!on)
		return
	scrub(loc)
	if (widenet)
		var/turf/T = loc
		if (istype(T))
			for (var/turf/simulated/tile in T.GetAtmosAdjacentTurfs(alldir=1))
				scrub(tile)


/obj/machinery/portable_atmospherics/scrubber/proc/scrub(var/turf/simulated/tile)
	var/datum/gas_mixture/environment
	if(holding)
		environment = holding.air_contents
	else
		environment = tile.return_air()
	var/transfer_moles = min(1, volume_rate/environment.volume)*environment.total_moles()

	//Take a gas sample
	var/datum/gas_mixture/removed
	if(holding)
		removed = environment.remove(transfer_moles)
	else
		removed = tile.remove_air(transfer_moles)

	//Filter it
	if (removed)
		var/datum/gas_mixture/filtered_out = new
		var/list/filtered_gases = filtered_out.gases
		var/list/removed_gases = removed.gases

		for(var/id in removed_gases & gases_to_scrub)
			filtered_out.assert_gas(id)
			filtered_gases[id][MOLES] = removed_gases[id][MOLES]
			removed_gases[id][MOLES] = 0

		filtered_out.temperature = removed.temperature
		removed.garbage_collect()

	//Remix the resulting gases
		air_contents.merge(filtered_out)

		if(holding)
			environment.merge(removed)
		else
			tile.assume_air(removed)
			tile.air_update_turf()

/obj/machinery/portable_atmospherics/scrubber/process()
	..()
	src.updateDialog()
	return

/obj/machinery/portable_atmospherics/scrubber/return_air()
	return air_contents

/obj/machinery/portable_atmospherics/scrubber/attack_ai(mob/user)
	return src.attack_hand(user)

/obj/machinery/portable_atmospherics/scrubber/attack_paw(mob/user)
	return src.attack_hand(user)

/obj/machinery/portable_atmospherics/scrubber/attack_hand(mob/user)

	user.set_machine(src)
	var/holding_text

	if(holding)
		holding_text = {"<BR><B>Tank Pressure</B>: [holding.air_contents.return_pressure()] KPa<BR>
<A href='?src=\ref[src];remove_tank=1'>Remove Tank</A><BR>
"}
	var/output_text = {"<TT><B>[name]</B><BR>
Pressure: [air_contents.return_pressure()] KPa<BR>
Port Status: [(connected_port)?("Connected"):("Disconnected")]
[holding_text]
<BR>
Power Switch: <A href='?src=\ref[src];power=1'>[on?("On"):("Off")]</A><BR>
Power regulator: <A href='?src=\ref[src];volume_adj=-1000'>-</A> <A href='?src=\ref[src];volume_adj=-100'>-</A> <A href='?src=\ref[src];volume_adj=-10'>-</A> <A href='?src=\ref[src];volume_adj=-1'>-</A> [volume_rate] <A href='?src=\ref[src];volume_adj=1'>+</A> <A href='?src=\ref[src];volume_adj=10'>+</A> <A href='?src=\ref[src];volume_adj=100'>+</A> <A href='?src=\ref[src];volume_adj=1000'>+</A><BR>

<HR>
<A href='?src=\ref[user];mach_close=scrubber'>Close</A><BR>
"}

	user << browse(output_text, "window=scrubber;size=600x300")
	onclose(user, "scrubber")
	return

/obj/machinery/portable_atmospherics/scrubber/Topic(href, href_list)
	..()
	if (usr.stat || usr.restrained())
		return

	if (((get_dist(src, usr) <= 1) && istype(src.loc, /turf)))
		usr.set_machine(src)

		if(href_list["power"])
			on = !on

		if (href_list["remove_tank"])
			if(holding)
				holding.loc = loc
				holding = null

		if (href_list["volume_adj"])
			var/diff = text2num(href_list["volume_adj"])
			volume_rate = min(10*ONE_ATMOSPHERE, max(0, volume_rate+diff))

		src.updateUsrDialog()
		src.add_fingerprint(usr)
		update_icon()
	else
		usr << browse(null, "window=scrubber")
		return
	return



/obj/machinery/portable_atmospherics/scrubber/huge
	name = "huge air scrubber"
	icon_state = "scrubber:0"
	anchored = 1
	volume = 50000
	widenet = 1

	var/static/gid = 1
	var/id = 0
	var/stationary = 0

/obj/machinery/portable_atmospherics/scrubber/huge/New()
	..()
	id = gid
	gid++

	name = "[name] (ID [id])"

/obj/machinery/portable_atmospherics/scrubber/huge/attack_hand(var/mob/user as mob)
	usr << "<span class='warning'>You can't directly interact with this machine! Use the area atmos computer.</span>"

/obj/machinery/portable_atmospherics/scrubber/huge/update_icon()
	src.overlays = 0

	if(on)
		icon_state = "scrubber:1"
	else
		icon_state = "scrubber:0"

/obj/machinery/portable_atmospherics/scrubber/huge/attackby(obj/item/weapon/W, mob/user)
	if(istype(W, /obj/item/weapon/wrench))
		if(stationary)
			user << "<span class='warning'>The bolts are too tight for you to unscrew!</span>"
			return
		if(on)
			user << "<span class='warning'>Turn it off first!</span>"
			return

		anchored = !anchored
		playsound(src.loc, 'sound/items/Ratchet.ogg', 50, 1)
		user << "<span class='notice'>You [anchored ? "wrench" : "unwrench"] \the [src].</span>"

	else if ((istype(W, /obj/item/device/analyzer)) && get_dist(user, src) <= 1)
		atmosanalyzer_scan(air_contents, user)


/obj/machinery/portable_atmospherics/scrubber/huge/stationary
	name = "stationary air scrubber"
	stationary = 0
