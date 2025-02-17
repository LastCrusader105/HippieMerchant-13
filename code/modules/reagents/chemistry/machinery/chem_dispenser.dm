/proc/translate_legacy_chem_id(id)
	switch (id)
		if ("sacid")
			return "sulphuricacid"
		if ("facid")
			return "fluorosulfuricacid"
		if ("co2")
			return "carbondioxide"
		if ("mine_salve")
			return "minerssalve"
		else
			return ckey(id)

/obj/machinery/chem_dispenser
	name = "chem dispenser"
	desc = "Creates and dispenses chemicals."
	density = TRUE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "dispenser"
	base_icon_state = "dispenser"
	use_power = IDLE_POWER_USE
	idle_power_usage = 40
	interaction_flags_machine = INTERACT_MACHINE_OPEN | INTERACT_MACHINE_ALLOW_SILICON | INTERACT_MACHINE_OFFLINE
	resistance_flags = FIRE_PROOF | ACID_PROOF
	circuit = /obj/item/circuitboard/machine/chem_dispenser
	processing_flags = NONE

	var/obj/item/stock_parts/cell/cell
	var/powerefficiency = 0.1
	var/amount = 30
	var/recharge_amount = 10
	var/recharge_counter = 0
	var/dispensed_temperature = DEFAULT_REAGENT_TEMPERATURE
	///If the UI has the pH meter shown
	var/show_ph = TRUE
	var/mutable_appearance/beaker_overlay
	var/working_state = "dispenser_working"
	var/nopower_state = "dispenser_nopower"
	var/has_panel_overlay = TRUE
	var/macroresolution = 1
	var/obj/item/reagent_containers/beaker = null
	//dispensable_reagents is copypasted in plumbing synthesizers. Please update accordingly. (I didn't make it global because that would limit custom chem dispensers)
	var/list/dispensable_reagents = list(
		/datum/reagent/aluminium,
		/datum/reagent/bromine,
		/datum/reagent/carbon,
		/datum/reagent/chlorine,
		/datum/reagent/copper,
		/datum/reagent/consumable/ethanol,
		/datum/reagent/fluorine,
		/datum/reagent/hydrogen,
		/datum/reagent/iodine,
		/datum/reagent/iron,
		/datum/reagent/lithium,
		/datum/reagent/mercury,
		/datum/reagent/nitrogen,
		/datum/reagent/oxygen,
		/datum/reagent/phosphorus,
		/datum/reagent/potassium,
		/datum/reagent/uranium/radium,
		/datum/reagent/silicon,
		/datum/reagent/silver,
		/datum/reagent/sodium,
		/datum/reagent/stable_plasma,
		/datum/reagent/consumable/sugar,
		/datum/reagent/sulfur,
		/datum/reagent/toxin/acid,
		/datum/reagent/water,
		/datum/reagent/fuel
	)
	//these become available once the manipulator has been upgraded to tier 4 (femto)
	var/list/upgrade_reagents = list(
		/datum/reagent/acetone,
		/datum/reagent/ammonia,
		/datum/reagent/ash,
		/datum/reagent/diethylamine,
		/datum/reagent/fuel/oil,
		/datum/reagent/saltpetre
	)
	var/list/emagged_reagents = list(
		/datum/reagent/toxin/carpotoxin,
		/datum/reagent/medicine/mine_salve,
		/datum/reagent/medicine/morphine,
		/datum/reagent/drug/space_drugs,
		/datum/reagent/toxin
	)


	var/list/saved_recipes = list()

/obj/machinery/chem_dispenser/Initialize()
	. = ..()
	dispensable_reagents = sortList(dispensable_reagents, /proc/cmp_reagents_asc)
	if(emagged_reagents)
		emagged_reagents = sortList(emagged_reagents, /proc/cmp_reagents_asc)
	if(upgrade_reagents)
		upgrade_reagents = sortList(upgrade_reagents, /proc/cmp_reagents_asc)
	if(is_operational)
		begin_processing()
	update_appearance()

/obj/machinery/chem_dispenser/Destroy()
	QDEL_NULL(beaker)
	QDEL_NULL(cell)
	return ..()

/obj/machinery/chem_dispenser/examine(mob/user)
	. = ..()
	if(panel_open)
		. += span_notice("[src]'s maintenance hatch is open!")
	if(in_range(user, src) || isobserver(user))
		. += "<span class='notice'>The status display reads:\n\
		Recharging <b>[recharge_amount]</b> power units per interval.\n\
		Power efficiency increased by <b>[round((powerefficiency*1000)-100, 1)]%</b>.</span>"


/obj/machinery/chem_dispenser/on_set_is_operational(old_value)
	if(old_value) //Turned off
		end_processing()
	else //Turned on
		begin_processing()


/obj/machinery/chem_dispenser/process(delta_time)
	if (recharge_counter >= 8)
		var/usedpower = cell.give(recharge_amount)
		if(usedpower)
			use_power(250*recharge_amount)
		recharge_counter = 0
		return
	recharge_counter += delta_time

/obj/machinery/chem_dispenser/proc/display_beaker()
	var/mutable_appearance/b_o = beaker_overlay || mutable_appearance(icon, "disp_beaker")
	b_o.pixel_y = -4
	b_o.pixel_x = -7
	return b_o

/obj/machinery/chem_dispenser/proc/work_animation()
	if(working_state)
		flick(working_state,src)

/obj/machinery/chem_dispenser/update_icon_state()
	icon_state = "[(nopower_state && !powered()) ? nopower_state : base_icon_state]"
	return ..()

/obj/machinery/chem_dispenser/update_overlays()
	. = ..()
	if(has_panel_overlay && panel_open)
		. += mutable_appearance(icon, "[base_icon_state]_panel-o")

	if(beaker)
		beaker_overlay = display_beaker()
		. += beaker_overlay


/obj/machinery/chem_dispenser/emag_act(mob/user)
	if(obj_flags & EMAGGED)
		to_chat(user, span_warning("[src] has no functional safeties to emag."))
		return
	to_chat(user, span_notice("You short out [src]'s safeties."))
	dispensable_reagents |= emagged_reagents//add the emagged reagents to the dispensable ones
	obj_flags |= EMAGGED

/obj/machinery/chem_dispenser/ex_act(severity, target)
	if(severity <= EXPLODE_LIGHT)
		return FALSE
	return ..()

/obj/machinery/chem_dispenser/contents_explosion(severity, target)
	..()
	if(!beaker)
		return

	switch(severity)
		if(EXPLODE_DEVASTATE)
			SSexplosions.high_mov_atom += beaker
		if(EXPLODE_HEAVY)
			SSexplosions.med_mov_atom += beaker
		if(EXPLODE_LIGHT)
			SSexplosions.low_mov_atom += beaker

/obj/machinery/chem_dispenser/handle_atom_del(atom/A)
	..()
	if(A == beaker)
		beaker = null
		cut_overlays()

/obj/machinery/chem_dispenser/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ChemDispenser", name)
		if(user.hallucinating())
			ui.set_autoupdate(FALSE) //to not ruin the immersion by constantly changing the fake chemicals
		ui.open()

/obj/machinery/chem_dispenser/ui_data(mob/user)
	var/data = list()
	data["amount"] = amount
	data["energy"] = cell.charge ? cell.charge * powerefficiency : "0" //To prevent NaN in the UI.
	data["maxEnergy"] = cell.maxcharge * powerefficiency
	data["isBeakerLoaded"] = beaker ? 1 : 0
	data["showpH"] = show_ph

	var/beakerContents[0]
	var/beakerCurrentVolume = 0
	if(beaker && beaker.reagents && beaker.reagents.reagent_list.len)
		for(var/datum/reagent/R in beaker.reagents.reagent_list)
			beakerContents.Add(list(list("name" = R.name, "volume" = round(R.volume, 0.01), "pH" = R.ph, "purity" = R.purity))) // list in a list because Byond merges the first list...
			beakerCurrentVolume += R.volume
	data["beakerContents"] = beakerContents

	if (beaker)
		data["beakerCurrentVolume"] = round(beakerCurrentVolume, 0.01)
		data["beakerMaxVolume"] = beaker.volume
		data["beakerTransferAmounts"] = beaker.possible_transfer_amounts
		data["beakerCurrentpH"] = round(beaker.reagents.ph, 0.01)
	else
		data["beakerCurrentVolume"] = null
		data["beakerMaxVolume"] = null
		data["beakerTransferAmounts"] = null
		data["beakerCurrentpH"] = null

	var/chemicals[0]
	var/is_hallucinating = FALSE
	if(user.hallucinating())
		is_hallucinating = TRUE
	for(var/re in dispensable_reagents)
		var/datum/reagent/temp = GLOB.chemical_reagents_list[re]
		if(temp)
			var/chemname = temp.name
			if(is_hallucinating && prob(5))
				chemname = "[pick_list_replacements("hallucination.json", "chemicals")]"
			chemicals.Add(list(list("title" = chemname, "id" = ckey(temp.name), "pH" = temp.ph, "pHCol" = convert_ph_to_readable_color(temp.ph))))
	data["chemicals"] = chemicals
	data["recipes"] = saved_recipes

	data["recipeReagents"] = list()
	if(beaker?.reagents.ui_reaction_id)
		var/datum/chemical_reaction/reaction = get_chemical_reaction(beaker.reagents.ui_reaction_id)
		for(var/_reagent in reaction.required_reagents)
			var/datum/reagent/reagent = find_reagent_object_from_type(_reagent)
			data["recipeReagents"] += ckey(reagent.name)
	return data

/obj/machinery/chem_dispenser/ui_act(action, params)
	. = ..()
	if(.)
		return
	switch(action)
		if("amount")
			if(!is_operational || QDELETED(beaker))
				return
			var/target = text2num(params["target"])
			if(target in beaker.possible_transfer_amounts)
				amount = target
				work_animation()
				. = TRUE
		if("dispense")
			if(!is_operational || QDELETED(cell))
				return
			var/reagent_name = params["reagent"]
			var/reagent = GLOB.name2reagent[reagent_name]
			if(beaker && dispensable_reagents.Find(reagent))

				var/datum/reagents/holder = beaker.reagents
				var/to_dispense = max(0, min(amount, holder.maximum_volume - holder.total_volume))
				if(!cell?.use(to_dispense / powerefficiency))
					say("Not enough energy to complete operation!")
					return
				holder.add_reagent(reagent, to_dispense, reagtemp = dispensed_temperature)

				work_animation()
			. = TRUE
		if("remove")
			if(!is_operational)
				return
			var/amount = text2num(params["amount"])
			if(beaker && (amount in beaker.possible_transfer_amounts))
				beaker.reagents.remove_all(amount)
				work_animation()
				. = TRUE
		if("eject")
			replace_beaker(usr)
			. = TRUE
		if("dispense_recipe")
			if(!is_operational || QDELETED(cell))
				return
			var/recipe_to_use = params["recipe"]
			var/list/chemicals_to_dispense = process_recipe_list(recipe_to_use)
			if(!LAZYLEN(chemicals_to_dispense))
				return
			for(var/key in chemicals_to_dispense) // i suppose you could edit the list locally before passing it
				var/list/keysplit = splittext(key," ")
				var/r_id = GLOB.name2reagent[translate_legacy_chem_id(keysplit[1])]
				if(beaker && dispensable_reagents.Find(r_id)) // but since we verify we have the reagent, it'll be fine
					var/datum/reagents/R = beaker.reagents
					var/free = R.maximum_volume - R.total_volume
					var/rounded = is_resolution(chemicals_to_dispense[key]) ? chemicals_to_dispense[key] : round(chemicals_to_dispense[key], macroresolution)
					var/actual = min(rounded, (cell.charge * powerefficiency)*10, free)
					if(actual)
						if(!cell?.use(abs(actual) / powerefficiency))
							say("Not enough energy to complete operation!")
							return
						if(actual > 0)
							R.add_reagent(r_id, actual)
						if(actual < 0)
							R.remove_reagent(r_id, abs(actual))
						work_animation()
		if("clear_recipes")
			if(!is_operational)
				return
			var/yesno = tgui_alert(usr, "Clear all recipes?",, list("Yes","No"))
			if(yesno == "Yes")
				saved_recipes = list()
			. = TRUE
		if("record_recipe") //I'm not renaming this lol
			if(!is_operational)
				return
			var/name = stripped_input(usr,"Name","What do you want to name this recipe?", "Recipe", MAX_NAME_LEN)
			var/recipe = stripped_input(usr,"Recipe","Insert recipe with chem IDs")
			if(!usr.canUseTopic(src, !issilicon(usr)))
				return
			if(name && recipe)
				var/list/first_process = splittext(recipe, ";")
				if(!LAZYLEN(first_process))
					return
				var/resmismatch = FALSE
				for(var/reagents in first_process)
					var/list/reagent = splittext(reagents, "=")
					var/amt = text2num(reagent[2]) || 0
					var/reagent_id = GLOB.name2reagent[translate_legacy_chem_id(reagent[1])]
					if(dispensable_reagents.Find(reagent_id) || (reagent_id && amt < 0))
						if (!resmismatch && !check_macro_part(reagents))
							resmismatch = TRUE
						continue
					else
						var/chemid = reagent[1]
						visible_message("<span class='warning'>[src] buzzes.</span>", "<span class='italics'>You hear a faint buzz.</span>")
						to_chat(usr, "<span class='danger'>[src] cannot find Chemical ID: <b>[chemid]</b>!</span>")
						playsound(src, 'sound/machines/buzz-two.ogg', 50, 1)
						return
				if (resmismatch && alert("[src] is not yet capable of replicating this recipe with the precision it needs, do you want to save it anyway?",, "Yes","No") == "No")
					return
				saved_recipes[name] = recipe
		if("reaction_lookup")
			if(beaker)
				beaker.reagents.ui_interact(usr)

/obj/machinery/chem_dispenser/proc/check_macro(macro)
	for (var/reagent in splittext(trim(macro), ";"))
		if (!check_macro_part(reagent))
			return FALSE
	return TRUE

/obj/machinery/chem_dispenser/proc/check_macro_part(part, res = macroresolution)
	var/detail = splittext(part, "=")
	return is_resolution(text2num(detail[2]), res)

/obj/machinery/chem_dispenser/proc/is_resolution(amt, res = macroresolution)
	. = FALSE
	for(var/i in 5 to macroresolution step -1)
		if(amt % i == 0)
			return TRUE

/obj/machinery/chem_dispenser/proc/process_recipe_list(recipe)
	var/list/key_list = list()
	var/list/final_list = list()
	var/list/first_process = splittext(recipe, ";")
	for(var/reagents in first_process)
		var/list/splitreagent = splittext(reagents, "=")
		final_list[avoid_assoc_duplicate_keys(splitreagent[1], key_list)] = text2num(splitreagent[2])
	return final_list

/obj/machinery/chem_dispenser/attackby(obj/item/I, mob/living/user, params)
	if(default_unfasten_wrench(user, I))
		return
	if(default_deconstruction_screwdriver(user, icon_state, icon_state, I))
		update_appearance()
		return
	if(default_deconstruction_crowbar(I))
		return
	if(istype(I, /obj/item/reagent_containers) && !(I.item_flags & ABSTRACT) && I.is_open_container())
		var/obj/item/reagent_containers/B = I
		. = TRUE //no afterattack
		if(!user.transferItemToLoc(B, src))
			return
		replace_beaker(user, B)
		to_chat(user, span_notice("You add [B] to [src]."))
		updateUsrDialog()
	else if(!user.istate.harm && !istype(I, /obj/item/card/emag))
		to_chat(user, span_warning("You can't load [I] into [src]!"))
		return ..()
	else
		return ..()

/obj/machinery/chem_dispenser/get_cell()
	return cell

/obj/machinery/chem_dispenser/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	var/list/datum/reagents/R = list()
	var/total = min(rand(7,15), FLOOR(cell.charge*powerefficiency, 1))
	var/datum/reagents/Q = new(total*10)
	if(beaker?.reagents)
		R += beaker.reagents
	for(var/i in 1 to total)
		Q.add_reagent(pick(dispensable_reagents), 10, reagtemp = dispensed_temperature)
	R += Q
	chem_splash(get_turf(src), null, 3, R)
	if(beaker?.reagents)
		beaker.reagents.remove_all()
	cell.use(total/powerefficiency)
	cell.emp_act(severity)
	work_animation()
	visible_message(span_danger("[src] malfunctions, spraying chemicals everywhere!"))

/obj/machinery/chem_dispenser/RefreshParts()
	recharge_amount = initial(recharge_amount)
	var/newpowereff = 0.0666666
	macroresolution = 5
	for(var/obj/item/stock_parts/cell/P in component_parts)
		cell = P
	for(var/obj/item/stock_parts/matter_bin/M in component_parts)
		newpowereff += 0.0166666666*M.rating
	for(var/obj/item/stock_parts/capacitor/C in component_parts)
		recharge_amount *= C.rating
	for(var/obj/item/stock_parts/manipulator/M in component_parts)
		if (M.rating > 1)
			macroresolution -= M.rating		//5 for t1, 3 for t2, 2 for t3, 1 for t4
		if (M.rating > 3)
			dispensable_reagents |= upgrade_reagents
	powerefficiency = round(newpowereff, 0.01)

/obj/machinery/chem_dispenser/proc/replace_beaker(mob/living/user, obj/item/reagent_containers/new_beaker)
	if(!user)
		return FALSE
	if(beaker)
		try_put_in_hand(beaker, user)
		beaker = null
	if(new_beaker)
		beaker = new_beaker
	update_appearance()
	return TRUE

/obj/machinery/chem_dispenser/on_deconstruction()
	cell = null
	if(beaker)
		beaker.forceMove(drop_location())
		beaker = null
	return ..()

/obj/machinery/chem_dispenser/AltClick(mob/living/user)
	. = ..()
	if(!can_interact(user) || !user.canUseTopic(src, BE_CLOSE, FALSE, NO_TK))
		return
	replace_beaker(user)

/obj/machinery/chem_dispenser/drinks/Initialize()
	. = ..()
	AddComponent(/datum/component/simple_rotation, ROTATION_ALTCLICK | ROTATION_CLOCKWISE)

/obj/machinery/chem_dispenser/drinks/setDir()
	var/old = dir
	. = ..()
	if(dir != old)
		update_appearance()  // the beaker needs to be re-positioned if we rotate

/obj/machinery/chem_dispenser/drinks/display_beaker()
	var/mutable_appearance/b_o = beaker_overlay || mutable_appearance(icon, "disp_beaker")
	switch(dir)
		if(NORTH)
			b_o.pixel_y = 7
			b_o.pixel_x = rand(-9, 9)
		if(EAST)
			b_o.pixel_x = 4
			b_o.pixel_y = rand(-5, 7)
		if(WEST)
			b_o.pixel_x = -5
			b_o.pixel_y = rand(-5, 7)
		else//SOUTH
			b_o.pixel_y = -7
			b_o.pixel_x = rand(-9, 9)
	return b_o

/obj/machinery/chem_dispenser/drinks
	name = "soda dispenser"
	desc = "Contains a large reservoir of soft drinks."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "soda_dispenser"
	base_icon_state = "soda_dispenser"
	has_panel_overlay = FALSE
	dispensed_temperature = (T0C + 0.85) // cold enough that ice won't melt
	amount = 10
	pixel_y = 6
	layer = WALL_OBJ_LAYER
	circuit = /obj/item/circuitboard/machine/chem_dispenser/drinks
	working_state = null
	nopower_state = null
	pass_flags = PASSTABLE
	show_ph = FALSE
	dispensable_reagents = list(
		/datum/reagent/water,
		/datum/reagent/consumable/ice,
		/datum/reagent/consumable/coffee,
		/datum/reagent/consumable/cream,
		/datum/reagent/consumable/tea,
		/datum/reagent/consumable/icetea,
		/datum/reagent/consumable/space_cola,
		/datum/reagent/consumable/spacemountainwind,
		/datum/reagent/consumable/dr_gibb,
		/datum/reagent/consumable/space_up,
		/datum/reagent/consumable/tonic,
		/datum/reagent/consumable/sodawater,
		/datum/reagent/consumable/lemon_lime,
		/datum/reagent/consumable/pwr_game,
		/datum/reagent/consumable/shamblers,
		/datum/reagent/consumable/sugar,
		/datum/reagent/consumable/pineapplejuice,
		/datum/reagent/consumable/orangejuice,
		/datum/reagent/consumable/grenadine,
		/datum/reagent/consumable/limejuice,
		/datum/reagent/consumable/tomatojuice,
		/datum/reagent/consumable/lemonjuice,
		/datum/reagent/consumable/menthol
	)
	upgrade_reagents = null
	emagged_reagents = list(
		/datum/reagent/consumable/ethanol/thirteenloko,
		/datum/reagent/consumable/ethanol/whiskey_cola,
		/datum/reagent/toxin/mindbreaker,
		/datum/reagent/toxin/staminatoxin
	)

/obj/machinery/chem_dispenser/drinks/fullupgrade //fully ugpraded stock parts, emagged
	desc = "Contains a large reservoir of soft drinks. This model has had its safeties shorted out."
	obj_flags = CAN_BE_HIT | EMAGGED
	flags_1 = NODECONSTRUCT_1
	circuit = /obj/item/circuitboard/machine/chem_dispenser/drinks/fullupgrade

/obj/machinery/chem_dispenser/drinks/fullupgrade/Initialize()
	. = ..()
	dispensable_reagents |= emagged_reagents //adds emagged reagents

/obj/machinery/chem_dispenser/drinks/beer
	name = "booze dispenser"
	desc = "Contains a large reservoir of the good stuff."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "booze_dispenser"
	base_icon_state = "booze_dispenser"
	circuit = /obj/item/circuitboard/machine/chem_dispenser/drinks/beer
	dispensable_reagents = list(
		/datum/reagent/consumable/ethanol/beer,
		/datum/reagent/consumable/ethanol/beer/maltliquor,
		/datum/reagent/consumable/ethanol/kahlua,
		/datum/reagent/consumable/ethanol/whiskey,
		/datum/reagent/consumable/ethanol/wine,
		/datum/reagent/consumable/ethanol/vodka,
		/datum/reagent/consumable/ethanol/gin,
		/datum/reagent/consumable/ethanol/rum,
		/datum/reagent/consumable/ethanol/tequila,
		/datum/reagent/consumable/ethanol/vermouth,
		/datum/reagent/consumable/ethanol/cognac,
		/datum/reagent/consumable/ethanol/ale,
		/datum/reagent/consumable/ethanol/absinthe,
		/datum/reagent/consumable/ethanol/hcider,
		/datum/reagent/consumable/ethanol/creme_de_menthe,
		/datum/reagent/consumable/ethanol/creme_de_cacao,
		/datum/reagent/consumable/ethanol/creme_de_coconut,
		/datum/reagent/consumable/ethanol/triple_sec,
		/datum/reagent/consumable/ethanol/sake,
		/datum/reagent/consumable/ethanol/applejack
	)
	upgrade_reagents = null
	emagged_reagents = list(
		/datum/reagent/consumable/ethanol,
		/datum/reagent/iron,
		/datum/reagent/toxin/minttoxin,
		/datum/reagent/consumable/ethanol/atomicbomb,
		/datum/reagent/consumable/ethanol/fernet
	)

/obj/machinery/chem_dispenser/drinks/beer/fullupgrade //fully ugpraded stock parts, emagged
	desc = "Contains a large reservoir of the good stuff. This model has had its safeties shorted out."
	obj_flags = CAN_BE_HIT | EMAGGED
	flags_1 = NODECONSTRUCT_1
	circuit = /obj/item/circuitboard/machine/chem_dispenser/drinks/beer/fullupgrade

/obj/machinery/chem_dispenser/drinks/beer/fullupgrade/Initialize()
	. = ..()
	dispensable_reagents |= emagged_reagents //adds emagged reagents

/obj/machinery/chem_dispenser/mutagen
	name = "mutagen dispenser"
	desc = "Creates and dispenses mutagen."
	dispensable_reagents = list(/datum/reagent/toxin/mutagen)
	upgrade_reagents = null
	emagged_reagents = list(/datum/reagent/toxin/plasma)


/obj/machinery/chem_dispenser/mutagensaltpeter
	name = "botanical chemical dispenser"
	desc = "Creates and dispenses chemicals useful for botany."
	flags_1 = NODECONSTRUCT_1

	circuit = /obj/item/circuitboard/machine/chem_dispenser/mutagensaltpeter

	dispensable_reagents = list(
		/datum/reagent/toxin/mutagen,
		/datum/reagent/saltpetre,
		/datum/reagent/plantnutriment/eznutriment,
		/datum/reagent/plantnutriment/left4zednutriment,
		/datum/reagent/plantnutriment/robustharvestnutriment,
		/datum/reagent/water,
		/datum/reagent/toxin/plantbgone,
		/datum/reagent/toxin/plantbgone/weedkiller,
		/datum/reagent/toxin/pestkiller,
		/datum/reagent/medicine/cryoxadone,
		/datum/reagent/ammonia,
		/datum/reagent/ash,
		/datum/reagent/diethylamine)
	upgrade_reagents = null

/obj/machinery/chem_dispenser/fullupgrade //fully ugpraded stock parts, emagged
	desc = "Creates and dispenses chemicals. This model has had its safeties shorted out."
	obj_flags = CAN_BE_HIT | EMAGGED
	flags_1 = NODECONSTRUCT_1
	circuit = /obj/item/circuitboard/machine/chem_dispenser/fullupgrade

/obj/machinery/chem_dispenser/fullupgrade/Initialize()
	. = ..()
	dispensable_reagents |= emagged_reagents //adds emagged reagents

/obj/machinery/chem_dispenser/abductor
	name = "reagent synthesizer"
	desc = "Synthesizes a variety of reagents using proto-matter."
	icon = 'icons/obj/abductor.dmi'
	icon_state = "chem_dispenser"
	base_icon_state = "chem_dispenser"
	has_panel_overlay = FALSE
	circuit = /obj/item/circuitboard/machine/chem_dispenser/abductor
	working_state = null
	nopower_state = null
	dispensable_reagents = list(
		/datum/reagent/aluminium,
		/datum/reagent/bromine,
		/datum/reagent/carbon,
		/datum/reagent/chlorine,
		/datum/reagent/copper,
		/datum/reagent/consumable/ethanol,
		/datum/reagent/fluorine,
		/datum/reagent/hydrogen,
		/datum/reagent/iodine,
		/datum/reagent/iron,
		/datum/reagent/lithium,
		/datum/reagent/mercury,
		/datum/reagent/nitrogen,
		/datum/reagent/oxygen,
		/datum/reagent/phosphorus,
		/datum/reagent/potassium,
		/datum/reagent/uranium/radium,
		/datum/reagent/silicon,
		/datum/reagent/silver,
		/datum/reagent/sodium,
		/datum/reagent/stable_plasma,
		/datum/reagent/consumable/sugar,
		/datum/reagent/sulfur,
		/datum/reagent/toxin/acid,
		/datum/reagent/water,
		/datum/reagent/fuel,
		/datum/reagent/acetone,
		/datum/reagent/ammonia,
		/datum/reagent/ash,
		/datum/reagent/diethylamine,
		/datum/reagent/fuel/oil,
		/datum/reagent/saltpetre,
		/datum/reagent/medicine/mine_salve,
		/datum/reagent/medicine/morphine,
		/datum/reagent/drug/space_drugs,
		/datum/reagent/toxin,
		/datum/reagent/toxin/plasma,
		/datum/reagent/uranium
	)
