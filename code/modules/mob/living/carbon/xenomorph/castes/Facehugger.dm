/datum/caste_datum/facehugger
	caste_type = XENO_CASTE_FACEHUGGER
	tier = 0
	plasma_gain = 0.1
	plasma_max = 10
	melee_damage_lower = 5
	melee_damage_upper = 5
	max_health = XENO_HEALTH_LARVA
	caste_desc = "Ewwww, that's disgusting!"
	speed = XENO_SPEED_TIER_8

	evolution_allowed = FALSE
	can_be_revived = FALSE

	minimap_icon = "facehugger"

/mob/living/carbon/xenomorph/facehugger
	name = XENO_CASTE_FACEHUGGER
	caste_type = XENO_CASTE_FACEHUGGER
	speak_emote = list("hisses")
	icon_state = "Facehugger"
	icon_size = 48
	pixel_x = -8
	pixel_y = -6
	old_x = -8
	old_y = -6
	layer = MOB_LAYER
	mob_flags = NOBIOSCAN
	see_in_dark = 8
	tier = 0  //Facehuggers don't count towards Pop limits
	acid_blood_damage = 5
	crit_health = 0
	crit_grace_time = 0
	gib_chance = 75
	mob_size = MOB_SIZE_SMALL
	death_fontsize = 2
	life_value = 0
	default_honor_value = 0
	show_only_numbers = TRUE
	counts_for_slots = FALSE
	counts_for_roundend = FALSE
	refunds_larva_if_banished = FALSE
	can_hivemind_speak = FALSE
	/// The lifetime hugs from this hugger
	var/total_facehugs = 0
	/// How many hugs the hugger needs to age
	var/next_facehug_goal = FACEHUG_TIER_1
	base_actions = list(
		/datum/action/xeno_action/onclick/xeno_resting,
		/datum/action/xeno_action/watch_xeno,
		/datum/action/xeno_action/onclick/xenohide,
		/datum/action/xeno_action/activable/pounce/facehugger,
	)
	inherent_verbs = list(
		/mob/living/carbon/xenomorph/proc/vent_crawl,
	)
	mutation_type = "Normal"

	icon_xeno = 'icons/mob/xenos/facehugger.dmi'
	icon_xenonid = 'icons/mob/xenonids/facehugger.dmi'

/mob/living/carbon/xenomorph/facehugger/initialize_pass_flags(datum/pass_flags_container/PF)
	..()
	if (PF)
		PF.flags_pass = PASS_MOB_THRU|PASS_FLAGS_CRAWLER
		PF.flags_can_pass_all = PASS_ALL^PASS_OVER_THROW_ITEM

/mob/living/carbon/xenomorph/facehugger/Life(delta_time)
	if(stat != DEAD && !lying && !(locate(/obj/effect/alien/weeds) in get_turf(src)))
		adjustBruteLoss(1)
	return ..()

/mob/living/carbon/xenomorph/facehugger/update_icons(is_pouncing)
	if(!caste)
		return

	if(stat == DEAD)
		icon_state = "[mutation_type] [caste.caste_type] Dead"
	else if(lying)
		if((resting || sleeping) && (!knocked_down && !knocked_out && health > 0))
			icon_state = "[mutation_type] [caste.caste_type] Sleeping"
		else
			icon_state = "[mutation_type] [caste.caste_type] Knocked Down"
	else if(is_pouncing)
		icon_state = "[mutation_type] [caste.caste_type] Thrown"
	else
		icon_state = "[mutation_type] [caste.caste_type] Running"

	update_fire() //the fire overlay depends on the xeno's stance, so we must update it.
	update_wounds()

/mob/living/carbon/xenomorph/facehugger/start_pulling(atom/movable/AM)
	return

/mob/living/carbon/xenomorph/facehugger/pull_response(mob/puller)
	return TRUE

/mob/living/carbon/xenomorph/facehugger/UnarmedAttack(atom/A, proximity, click_parameters, tile_attack, ignores_resin = FALSE)
	a_intent = INTENT_HELP //Forces help intent for all interactions.
	if(!caste)
		return FALSE

	if(lying) //No attacks while laying down
		return FALSE

	if(istype(A, /obj/effect/alien/resin/special/eggmorph))
		var/obj/effect/alien/resin/special/eggmorph/morpher = A
		if(time_of_birth + 3 SECONDS > world.time)
			return
		if(morpher.linked_hive.hivenumber != hivenumber)
			to_chat(src, SPAN_XENOWARNING("This isn't your hive's eggmorpher!"))
			return
		if(morpher.stored_huggers >= morpher.huggers_to_grow_max)
			to_chat(src, SPAN_XENOWARNING("\The [morpher] is already full of children."))
			return
		visible_message(SPAN_WARNING("\The [src] climbs back into \the [morpher]."), SPAN_XENONOTICE("You climb into \the [morpher]."))
		morpher.stored_huggers++
		qdel(src)
		return

	if(ishuman(A))
		var/mob/living/carbon/human/human = A
		if(!human.lying)
			to_chat(src, SPAN_WARNING("You can't reach \the [human], they need to be lying down."))
			return
		if(!can_hug(human, hivenumber))
			to_chat(src, SPAN_WARNING("You can't infect \the [human]..."))
			return
		visible_message(SPAN_WARNING("\The [src] starts climbing onto \the [human]'s face..."), SPAN_XENONOTICE("You start climbing onto \the [human]'s face..."))
		if(!do_after(src, 6 SECONDS, INTERRUPT_ALL, BUSY_ICON_HOSTILE, human, INTERRUPT_MOVED, BUSY_ICON_HOSTILE))
			return
		if(!human.lying)
			to_chat(src, SPAN_WARNING("You can't reach \the [human], they need to be lying down."))
			return
		if(!can_hug(human, hivenumber))
			to_chat(src, SPAN_WARNING("You can't infect \the [human]..."))
			return
		handle_hug(human)
		return

	A.attack_larva(src)
	xeno_attack_delay(src) //Adds some lag to the 'attack'

/mob/living/carbon/xenomorph/facehugger/proc/handle_hug(mob/living/carbon/human/human)
	var/obj/item/clothing/mask/facehugger/hugger = new /obj/item/clothing/mask/facehugger(loc, hivenumber)
	var/did_hug = hugger.attach(human, TRUE, 0.5)
	if(client)
		client?.player_data?.adjust_stat(PLAYER_STAT_FACEHUGS, STAT_CATEGORY_XENO, 1)
	var/area/hug_area = get_area(src)
	if(hug_area)
		for(var/mob/dead/observer/observer as anything in GLOB.observer_list)
			to_chat(observer, SPAN_DEADSAY("<b>[human]</b> has been facehugged by <b>[src]</b> at \the <b>[hug_area]</b>" + " [OBSERVER_JMP(observer, human)]"))
		to_chat(src, SPAN_DEADSAY("<b>[human]</b> has been facehugged by <b>[src]</b> at \the <b>[hug_area]</b>"))
	else
		for(var/mob/dead/observer/observer as anything in GLOB.observer_list)
			to_chat(observer, SPAN_DEADSAY("<b>[human]</b> has been facehugged by <b>[src]</b>" + " [OBSERVER_JMP(observer, human)]"))
		to_chat(src, SPAN_DEADSAY("<b>[human]</b> has been facehugged by <b>[src]</b>"))
	qdel(src)
	if(hug_area)
		xeno_message(SPAN_XENOMINORWARNING("You sense that [src] has facehugged a host at \the [hug_area]!"), 1, src.hivenumber)
	else
		xeno_message(SPAN_XENOMINORWARNING("You sense that [src] has facehugged a host!"), 1, src.hivenumber)
	return did_hug

/mob/living/carbon/xenomorph/facehugger/age_xeno()
	if(stat == DEAD || !caste || QDELETED(src) || !client)
		return

	age = XENO_NORMAL

	total_facehugs = get_client_stat(client, PLAYER_STAT_FACEHUGS)
	switch(total_facehugs)
		if(FACEHUG_TIER_1 to FACEHUG_TIER_2)
			age = XENO_MATURE
			next_facehug_goal = FACEHUG_TIER_2
		if(FACEHUG_TIER_2 to FACEHUG_TIER_3)
			age = XENO_ELDER
			next_facehug_goal = FACEHUG_TIER_3
		if(FACEHUG_TIER_3 to FACEHUG_TIER_4)
			age = XENO_ANCIENT
			next_facehug_goal = FACEHUG_TIER_4
		if(FACEHUG_TIER_4 to INFINITY)
			age = XENO_PRIME
			next_facehug_goal = null

	// For people who wish to remain anonymous
	if(!client.prefs.playtime_perks)
		age = XENO_NORMAL

	switch(age)
		if(XENO_NORMAL)
			age_prefix = "Young "
		if(XENO_MATURE)
			age_prefix = "Fledgling "
		if(XENO_ELDER)
			age_prefix = "Veteran "
		if(XENO_ANCIENT)
			age_prefix = "Baneful "
		if(XENO_PRIME)
			age_prefix = "Royal "

	hud_update() //update the age level insignia on our xeno hud.

	//One last shake for the sake of it
	xeno_jitter(25)

/mob/living/carbon/xenomorph/facehugger/handle_screech_act(mob/self, mob/living/carbon/xenomorph/queen/queen)
	return null

/mob/living/carbon/xenomorph/facehugger/handle_queen_screech(mob/living/carbon/xenomorph/queen/queen)
	to_chat(src, SPAN_DANGER("The mighty roar of the queen makes you tremble and fall over!"))
	adjust_effect(6, STUN)
	apply_effect(6, WEAKEN)

/mob/living/carbon/xenomorph/facehugger/add_xeno_shield(added_amount, shield_source, type = /datum/xeno_shield, duration = -1, decay_amount_per_second = 1, add_shield_on = FALSE, max_shield = 200)
	return

/mob/living/carbon/xenomorph/facehugger/proc/scuttle(obj/structure/current_structure)
	var/move_dir = get_dir(src, loc)
	for(var/atom/movable/atom in get_turf(current_structure))
		if(atom != current_structure && atom.density && atom.BlockedPassDirs(src, move_dir))
			to_chat(src, SPAN_WARNING("\The [atom] prevents you from squeezing under \the [current_structure]!"))
			return
	// Is it an airlock?
	if(istype(current_structure, /obj/structure/machinery/door/airlock))
		var/obj/structure/machinery/door/airlock/current_airlock = current_structure
		if(current_airlock.locked || current_airlock.welded) //Can't pass through airlocks that have been bolted down or welded
			to_chat(src, SPAN_WARNING("\The [current_airlock] is locked down tight. You can't squeeze underneath!"))
			return
	visible_message(SPAN_WARNING("\The [src] scuttles underneath \the [current_structure]!"), \
	SPAN_WARNING("You squeeze and scuttle underneath \the [current_structure]."), null, 5)
	forceMove(current_structure.loc)

/mob/living/carbon/xenomorph/facehugger/emote(act, m_type, message, intentional, force_silence)
	playsound(loc, "alien_roar_larva", 15)

/mob/living/carbon/xenomorph/facehugger/get_status_tab_items()
	. = ..()
	if(next_facehug_goal)
		. += "Lifetime Hugs: [total_facehugs] / [next_facehug_goal]"
	else
		. += "Lifetime Hugs: [total_facehugs]"
