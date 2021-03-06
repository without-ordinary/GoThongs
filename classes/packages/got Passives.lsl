#define USE_EVENTS

integer BFL;
#define BFL_SENT 0x1				// Recently sent
#define BFL_QUEUE_SEND 0x2			// Update on send cooldown finish

integer EVT_INDEX;		// Used to give events a unique ID
// Events we are listening to
// Len is total number of entries after len
list EVT_CACHE;			// (str)scriptName, (int)evt, (arr)evt_listener_IDs
#define CACHESTRIDE 3
// Stores the event listeners
list EVT_LISTENERS;		// (int)id, (arr)targs, (int)max_targs, (float)proc_chance, (float)cooldown, (int)flags, (arr)wrapper
#define EVTSTRIDE 7


list PASSIVES;
// Nr elements before the attributes
#define PASSIVES_PRESTRIDE 4
// (str)name, (arr)evt_listener_ids, (int)length, (int)flags, (int)attributeID, (float)attributeVal
list ATTACHMENTS; 			// [(str)passive, (arr)attachments]
list CACHE_ATTACHMENTS;		// Contains names of attachments

#define COMPILATION_STRIDE 2
list compiled_passives;     // Compiled passives [id, val, id2, val2...]
// This should correlate to the FXCUpd$ index
list compiled_actives = [
	0,	// 00 Flags - Int
	1,	// 01 Mana regen - Multi | i2f
	1,	// 02 Damge done - Multi | i2f
	1,	// 03 Damage taken - Multi | i2f
	0,	// 04 Dodge - Add | i2f
	1,	// 05 Casttime - Multi | i2f
	1,	// 06 Cooldown - Multi | i2f
	1,	// 07 Mana cost - Multi | i2f
	0,	// 08 Crit - Add | i2f
	1,	// 09 Pain - Multi | i2f
	1,	// 10 Arousal - Multi | i2f
	0,	// 11 HP add
	1,	// 12 HP multiplier
	0,	// 13 Mana add - int
	1,	// 14 Mana - Multiplier
	0,	// 15 Arousal add - int
	1,	// 16 Arousal - Multiplier
	0,	// 17 Pain add - int
	1,	// 18 Pain - Multiplier
	1,	// 19 HP Regen - Multi
	1,	// 20 Pain regen - Multi
	1,	// 21 Arousal regen - Multi
	0,	// 22 SPell highlights
	1,	// 23 Healing Received
	1,	// 24 Movespeed (NPC)
	1,	// 25 Healing done
	-1, // 26 Team
	1	// 27 Befuddle
];      // Compiled actives defaults

/*
    Converts a name into a position
*/
integer findPassiveByName(string name){
    integer i;
    while(i<llGetListLength(PASSIVES)){
        if(llList2String(PASSIVES, i) == name)
            return i;
        i+=llList2Integer(PASSIVES, i+2)+PASSIVES_PRESTRIDE;
    }
    return -1;
}

// Macro this out
/*
outputDebug(string task){
	qd(task);
	qd("PASSIVES: "+mkarr(PASSIVES));
	qd("CACHE: "+mkarr(EVT_CACHE));
	qd("BINDS: "+mkarr(EVT_LISTENERS));
}
*/
#define outputDebug(task)

/*
    Removes a passive by name
*/
// Needs to remove procs and cache
integer removePassiveByName(string name){
    integer pos = findPassiveByName(name);
    if(~pos){
		// Remove event bindings
		list binds = llJson2List(l2s(PASSIVES, pos+1));
		
		list_shift_each(binds, id,
			integer n = (int)id;
			integer i;
			
			// Remove from storage
			// The ID will only occur once in this array
			for(i=0; i<count(EVT_LISTENERS); i+=EVTSTRIDE){
				if(l2i(EVT_LISTENERS, 0) == n){
					EVT_LISTENERS = subarrDel(EVT_LISTENERS, i, EVTSTRIDE);
				}
			}
			
			// Remove from index
			for(i=0; i<count(EVT_CACHE) && EVT_CACHE != []; i+=CACHESTRIDE){
				list p = llJson2List(l2s(EVT_CACHE, i+2));
				integer ps = llListFindList(p, [n]);
				if(~ps){
					p = llDeleteSubList(p, ps, ps);
					// There are still events bound to this
					if(p)
						EVT_CACHE = llListReplaceList(EVT_CACHE, [mkarr(p)], i+2, i+2);
					else{
						// There are no more events bound to this
						EVT_CACHE = subarrDel(EVT_CACHE, i, CACHESTRIDE);
						i-= CACHESTRIDE;
					}
				}
			}
			
		)
		
		// Remove attachments
		integer i;
		for(i=0; i<count(ATTACHMENTS) && ATTACHMENTS != []; i+= 2){
			if(l2s(ATTACHMENTS, i) == name){
				ATTACHMENTS = llDeleteSubList(ATTACHMENTS, i, i+1);
				i-= 2;
			}
		}
		
		
		
        integer ln = llList2Integer(PASSIVES, pos+2);
        PASSIVES = subarrDel(PASSIVES, pos, ln+PASSIVES_PRESTRIDE);
		
		outputDebug("REM");
		
		return TRUE;
    }
	
	return FALSE;
}

compilePassives(){
	// Values that should be added instead of multiplied
    list non_multi = FXCUpd$non_multi;
	
    list keys = [];         // Stores the attribute IDs
    list vals = [];         // Stores the attribute values
    integer i;
	
	@continueCompilePassives;
    while(i<llGetListLength(PASSIVES)){
        // Get the effects
		integer n = l2i(PASSIVES, i+2);
        list block = subarr(PASSIVES, i+PASSIVES_PRESTRIDE, n);
        i+=n+PASSIVES_PRESTRIDE;
        
		if(!n)
			jump continueCompilePassives;
		
		
        integer x;
        for(x = 0; x<llGetListLength(block); x+=2){
            integer id = llList2Integer(block, x);
            float val = llList2Float(block, x+1);
            
			integer add = (~llListFindList(non_multi, [id])); // Check if we should add or multiply
			
            integer pos = llListFindList(keys, [id]);
            // The key already exists, add!
            if(~pos){
				float n = llList2Float(vals, pos);
				if(add)n+= val;
				else{
					n*= (1+val);
				}
                vals = llListReplaceList(vals, [n], pos, pos);
			}
            else{
                keys += id;
				if(!add)val+=1;	// If something is a multiplier it should always start at 1
                vals += val;
            }
        }
    }
    
    // These need to match compilation stride
    compiled_passives = [];
    for(i=0; i<llGetListLength(keys); i++){
        list v = llList2List(vals, i, i);
        if(llList2Float(v,0) == (float)llList2Integer(v,0))v = [llList2Integer(v,0)];
        compiled_passives+= [llList2Integer(keys, i)]+v;
    }
    
	
    output();
}


output(){
	if(BFL&BFL_SENT){
		BFL = BFL|BFL_QUEUE_SEND; // Update once queue ends
		return;
	}
	BFL = BFL|BFL_SENT;
	multiTimer(["Q","",.5,FALSE]);
	
    // Output the same event as FXCEvt$update
    list output = compiled_actives;
   
    integer set_flags = llList2Integer(output, FXCUpd$FLAGS);
    integer unset_flags;
    
    
    // Fields that should be treated as ints for shortening
    list INT_FIELDS = [
        FXCUpd$HP_ADD,
        FXCUpd$MANA_ADD,
        FXCUpd$AROUSAL_ADD,
        FXCUpd$PAIN_ADD,
		FXCUpd$SPELL_HIGHLIGHTS,
		FXCUpd$TEAM
    ];
    list non_multi = FXCUpd$non_multi; // Things that should be ADDed
	
	
    integer i;
    for(i=0; i<llGetListLength(compiled_passives); i+=COMPILATION_STRIDE){
        integer type = llList2Integer(compiled_passives, i);
    
        // Cache the flags first so unset_flags can properly override
        if(type == FXCUpd$FLAGS)
            set_flags = set_flags|llList2Integer(compiled_passives,i+1);
        else if(type == FXCUpd$UNSET_FLAGS)
            unset_flags = unset_flags|llList2Integer(compiled_passives,i+1);
        
		else{
			float val = llList2Float(compiled_passives, i+1)*llList2Float(output,type);
			if(~llListFindList(non_multi, [type]))
				val = llList2Float(compiled_passives, i+1)+llList2Float(output,type);
            output = llListReplaceList(output, [val], type, type);
        }
    }
	
	// Shorten
	for(i=0; i<count(output); i++){
		float val = llList2Float(output, i);
		list v = [(int)val];
        if(llListFindList(INT_FIELDS, [i]) == -1){
			v = [f2i(val)];
		}
		output = llListReplaceList(output, v, i, i);
	}
    
	// Scan attachments
	list att = []; 	// Contains all names
	list add = [];	// New names
	for(i=0; i<count(ATTACHMENTS); i+= 2){
		list a = llJson2List(l2s(ATTACHMENTS, i+1));
		list_shift_each(a, val,
			if(llListFindList(att, [val]) == -1){
				att+= val;
				if(llListFindList(CACHE_ATTACHMENTS, [val]) == -1)
					add += val;
			}
		)
	}
	// Find attachments to remove
	list rem;
	for(i=0; i<count(CACHE_ATTACHMENTS); ++i){
		// Attachment no longer found
		if(llListFindList(att, llList2List(CACHE_ATTACHMENTS, i, i)) == -1){
			rem += l2s(CACHE_ATTACHMENTS, i);
		}
	}
	CACHE_ATTACHMENTS = att;
	if(add)
		Rape$addFXAttachments(add);
	if(rem)
		Rape$remFXAttachments(rem);
	
    set_flags = set_flags&~unset_flags;
	
    output = llListReplaceList(output, [set_flags], FXCUpd$FLAGS, FXCUpd$FLAGS);
	llMessageLinked(LINK_SET, TASK_FX, mkarr(output), "");
}

onEvt(string script, integer evt, list data){
    
    if(script == "got Bridge" && evt == BridgeEvt$userDataChanged){
        data = llJson2List(l2s(data, BSUD$WDATA));
		data = llJson2List(l2s(data, 2));
		Passives$set(LINK_THIS, "_WEAPON_", data, 0);				
		return;
    }
	
	// Remove passives that should be removed on cleanup
	else if(script == "got RootAux" && evt == RootAuxEvt$cleanup){
		integer i;
		@restartWipe;
		while(i<llGetListLength(PASSIVES)){
			// Get the effects
			string name = l2s(PASSIVES, i);
			integer n = l2i(PASSIVES, i+2);
			integer flags = l2i(PASSIVES, i+3);
			i+=n+PASSIVES_PRESTRIDE;
			
			if(flags&Passives$FLAG_REM_ON_CLEANUP){
				removePassiveByName(name);
				jump restartWipe;
			}
		}
		output();
		return;
	}
    
	// Procs here
	integer i;
	list ids;
	// Get the evt listeners for this event
	for(i=0; i<count(EVT_CACHE); i+=CACHESTRIDE){
		// Found the index
		if(llList2String(EVT_CACHE, i) == script && llList2Integer(EVT_CACHE, i+1) == evt){
			ids = llJson2List(l2s(EVT_CACHE, i+2));		// IDs we need to scan
			jump gotIDs;
		}
	}
	@gotIDs;
	
	// no events found
	if(ids == [])return;
	
	// Cycle events		
	integer x;
	for(x = 0; x<count(EVT_LISTENERS); x+= EVTSTRIDE){
		integer evtid = l2i(EVT_LISTENERS, x);
		// This event is in the index, one of the targs should match
		if(llListFindList(ids, [evtid]) == -1)
			jump evtBreak; // Go to next event
			
		list targs = llJson2List(l2s(EVT_LISTENERS, x+1));
		integer max_targs = l2i(EVT_LISTENERS, x+2);
		float proc_chance = l2f(EVT_LISTENERS, x+3);
		float cooldown = l2f(EVT_LISTENERS, x+4);
		integer flags = l2i(EVT_LISTENERS, x+5);
		// wrapper = l2s(EVT_LISTENERS, x+6);
		
		
		float proc = llFrand(1);
		//qd("Proc: "+(str)proc+" < "+(str)proc_chance);
		// Check prerequisites first
		if(flags&Passives$PF_ON_COOLDOWN || proc>proc_chance)
			jump evtBreak; // Go to next event
			
					
		// jump
		@targNext;
		
		//qd("Scanning");
		// Scan for all valid targets
		list_shift_each(targs, val,
			list t = llJson2List(val);						
			integer y;	// Iterator
			
			// This target should be checked against this event
			if(l2s(t, 1) == script && l2i(t, 2) == evt){
				// JSON array of parameters set in the proc
				list against = llJson2List(l2s(t,3));
			
				// Iterate over parameters and make sure they validate with the event params we received
				for(y = 0; y<llGetListLength(against); ++y){
					// Event data from package event
					list eva = explode("||", llList2String(against, y));
					// Event data from event
					string cur = llList2String(data, y);
		
					// Validate comparison here, currently a simple == check, could be expanded with num comparisons
					if(
						l2s(eva,0) != "" && 				// If the event condition at index is unset, it should always be accepted
						llListFindList(eva, [cur]) == -1	// But if it's not unset and not the same as the condition, then we fail
					){
						//qd("Failed because "+l2s(eva,0)+" not in "+mkarr(eva));
						jump targNext;						// Goes to the next target
					}
				}
			}

			// SUCCESS, send to this target!
				
			// Set cooldown if needed
			if(~flags&Passives$PF_ON_COOLDOWN && cooldown>0){
				EVT_LISTENERS = llListReplaceList(EVT_LISTENERS, [flags|Passives$PF_ON_COOLDOWN], x+5, x+5);
				flags = flags|Passives$PF_ON_COOLDOWN;
				multiTimer(["CD_"+(str)evtid, "", cooldown, FALSE]);
			}
					
			// We have validated that this event should be accepted, let's extract the wrapper
			string wrapper = llList2String(EVT_LISTENERS, x+6);
				
			// We can use <index> and <-index> tags to replace with data from the event
			for(y=0; y<llGetListLength(data); ++y){
				wrapper = implode((str)(-llList2Float(data, y)), explode("<-"+(str)y+">", wrapper));
				wrapper = implode(llList2String(data, y), explode("<"+(str)y+">", wrapper));
			}
					
			// Find the target and send
			integer targFlag = l2i(t, 0);
			float range = l2f(t, 4);
			
			//qd("targFlag: "+(str)targFlag);
			//qd("range: "+(string)range);
			
			if(targFlag == Passives$TARG_SELF)
				FX$run("", wrapper);
			else if(targFlag == Passives$TARG_AOE)
				FX$aoe(max_targs/10., llGetKey(), wrapper, TEAM_PC);
			else if(llVecDist(llGetPos(), prPos(l2s(data, targFlag)))< range || range <= 0) {
				FX$send(l2s(data, targFlag), llGetKey(), wrapper, TEAM_PC);
				//qd("Sent FX to "+llKey2Name(l2s(data, targFlag))+" ("+l2s(data, targFlag)+")");
			}
					
			// If we have sent to max targs, leave this event and go to the next
			if(max_targs > 0){
				--max_targs;
				if(max_targs)
					jump evtBreak;
			}
		)
		
		// Go to next event
		@evtBreak;
	}


}



// Add or remove a proc
addProc(string script, integer evt, integer id){
	
	integer i;
	for(i=0; i<count(EVT_CACHE) && EVT_CACHE != []; i+= CACHESTRIDE){
		
		if(l2s(EVT_CACHE, i) == script && l2i(EVT_CACHE, i+1) == evt){
			// IDs currently bound to this
			list t = llJson2List(l2s(EVT_CACHE, i+2));
			// Check if this ID exists
			integer pos = llListFindList(t, [id]);

			// Add
			if(pos == -1){
				t+= id;
				EVT_CACHE = llListReplaceList(EVT_CACHE, [mkarr(t)], i+2, i+2);
			}
			return;
		}
		
	}
	
	// We have looped through entirely. If we haven't yet found an exisiting event to add to, do so now
	EVT_CACHE += [script, evt, mkarr([id])];
	
}


timerEvent(string id, string data){
	// Send queue
	if(id == "Q"){
		BFL = BFL&~BFL_SENT;
		if(BFL&BFL_QUEUE_SEND){
			BFL = BFL&~BFL_QUEUE_SEND;
			output();
		}
	}
	
	else if(llGetSubString(id, 0,2) == "CD_"){
		integer n = (int)llGetSubString(id, 3, -1);
		// Take this one off CD
		integer i;
		for(i=0; i<llGetListLength(EVT_LISTENERS); i+=EVTSTRIDE){
			if(l2i(EVT_LISTENERS, i) == n){
				EVT_LISTENERS = llListReplaceList(EVT_LISTENERS, [l2i(EVT_LISTENERS, i+5)&~Passives$PF_ON_COOLDOWN], i+5, i+5);
				return;
			}
		}
	}
	
}


default
{
    timer()
    {
		multiTimer([]);
    }
    
	// Handle active effects
	#define LM_PRE \
	if(nr == TASK_PASSIVES_SET_ACTIVES){ \
		list set = llJson2List(s); \
        compiled_actives = [ \
			l2i(set, 0),			\
			i2f(l2f(set, 1)),		\
			i2f(l2f(set, 2)),		\
			i2f(l2f(set, 3)),		\
			i2f(l2f(set, 4)),		\
			i2f(l2f(set, 5)),		\
			i2f(l2f(set, 6)),		\
			i2f(l2f(set, 7)),		\
			i2f(l2f(set, 8)),		\
			i2f(l2f(set, 9)),		\
			i2f(l2f(set, 10)),		\
			\
			l2i(set, 11),			\
			l2f(set, 12),			\
			l2i(set, 13),			\
			l2f(set, 14),			\
			l2i(set, 15),			\
			l2f(set, 16),			\
			l2i(set, 17),			\
			l2f(set, 18),			\
			\
			l2f(set, 19),			\
			l2f(set, 20),			\
			l2f(set, 21),			\
			l2i(set, 22),			\
			i2f(l2f(set, 23)),		\
			l2f(set, 24),			\
			i2f(l2f(set, 25)),		\
			l2i(set, 26), 			\
			i2f(l2f(set,27))		\
		]; \
        output(); \
	}
	/*
		compiled_actives = [ \
			l2i(set, 0),			// Flags
			i2f(l2f(set, 1)),		// mana regen multi
			i2f(l2f(set, 2)),		// Damage done multi
			i2f(l2f(set, 3)),		// Damage taken multi
			i2f(l2f(set, 4)),		// Dodge add
			i2f(l2f(set, 5)),		// casttime multiplier
			i2f(l2f(set, 6)),		// Cooldown multiplier
			i2f(l2f(set, 7)),		// Manacost multiplier
			i2f(l2f(set, 8)),		// crit add
			i2f(l2f(set, 9)),		// Pain multiplier
			i2f(l2f(set, 10)),		// Arousal multiplier
			
			l2i(set, 11),			// HP add
			l2f(set, 12),			// HP Multi
			l2i(set, 13),			// Mana Add
			l2f(set, 14),			// Mana Multi
			l2i(set, 15),			// Arousal add
			l2f(set, 16),			// Arousal multi
			l2i(set, 17),			// Pain add
			l2f(set, 18),			// Pain multi
			
			l2f(set, 19),			// HP regen = 1
			l2f(set, 20),			// Pain regen = 1
			l2f(set, 21),			// Arousal regen = 1
			l2i(set, 22)			// Highlights
			l2f(set, 23)			// Healing received mod
			24						// Movespeed = 1
			25						// Healing done mod
			26						// Team = -1
			27						// Befuddle = 1
		]; \
	*/
	
    #include "xobj_core/_LM.lsl" 
    if(method$isCallback){
        return;
    }
    
    
    /*
        Adds a passive
    */
    if(METHOD == PassivesMethod$set){
        string name = method_arg(0);
		integer flags = l2i(PARAMS, 2);
		
        list effects = llJson2List(method_arg(1));
        if(effects == [])return Passives$rem(LINK_THIS, name);
        // Find if passive exists and remove it
        removePassiveByName(name);
        
		
        // Go through the index
        if((llGetListLength(effects)%2) == 1)return qd("Error: Passives have an uneven index: "+name);
        
		// IDs of effects added
		list added_effects;
		
		
		integer i;
		for(i=0; i<count(effects) && count(effects); i+=2){
			integer t = l2i(effects, i);
			if(t == FXCUpd$PROC){
			
				list data = llJson2List(l2s(effects, i+1));
				EVT_INDEX++;
				added_effects+= EVT_INDEX;
				// Add a proc
				list triggers = llJson2List(l2s(data, 0));
				list_shift_each(triggers, val,
					list d = llJson2List(val);
					addProc(l2s(d, 1), l2i(d,2), EVT_INDEX);
				)
				EVT_LISTENERS += [
					EVT_INDEX,
					l2s(data, 0),	// Triggers
					l2i(data, 1),	// Max targs
					l2f(data, 2),	// Proc chance
					l2f(data, 3),	// cooldown
					l2i(data, 4),	// flags,
					l2s(data, 5)	// wrapper
				];
				/*
				list EVT_CACHE;			// (str)scriptName, (int)evt, (arr)evt_listener_IDs
#define CACHESTRIDE 3
				
				*/
				
				effects = llDeleteSubList(effects, i, i+1);
				i-=2;
			}
			else if(t == FXCUpd$ATTACH){
				ATTACHMENTS += [name, l2s(effects, i+1)];
			}
		}
		
		PASSIVES += [name, mkarr(added_effects), llGetListLength(effects), flags]+effects;
        outputDebug("ADD");
		compilePassives();
    }
    
    
    /*
        Removes a passive
    */
    else if(METHOD == PassivesMethod$rem){
        string name = method_arg(0);
        if(removePassiveByName(name))
			compilePassives();
    }
    
    /*
        Returns a list of passive names
    */
    else if(METHOD == PassivesMethod$get){
        
        integer i;
        while(i<llGetListLength(PASSIVES)){
            CB_DATA += [llList2String(PASSIVES, i)];
            i+=llList2Integer(PASSIVES, i+2)+PASSIVES_PRESTRIDE;
        }
        
    }
    
    #define LM_BOTTOM  
    #include "xobj_core/_LM.lsl"  
}
