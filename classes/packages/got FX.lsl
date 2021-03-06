// p_* is package data
// NEW: (int)pid, (key)sender, (int)stacks, (int)timesnap, (float)p_dur, (int)p_flags, (str)p_name, (arr)p_fxobjs, (arr)p_evts, (arr)p_tags, (int)p_max_stacks
list PACKAGES;     // OLD: (int)pid, (key)id, (arr)package, (int)stacks, (int)timesnap
#define PSTRIDE 11
// Build slice data
#define pBuildSlice(pid, sender, stacks, timesnap, p_dur, p_flags, p_name, p_fxobjs, p_evts, p_tags, p_max_stacks) [pid, sender, stacks, timesnap, p_dur, p_flags, p_name, p_fxobjs, p_evts, p_tags, p_max_stacks]
// Returns a slice starting from index start
#define pSlice(start) llList2List(PACKAGES, start, start+PSTRIDE-1)
// Returns data from a slice
#define pID(slice) llList2Integer(slice, 0)
#define pSender(slice) llList2Key(slice, 1)
#define pStacks(slice) llList2Integer(slice, 2)
#define pTimesnap(slice) llList2Integer(slice, 3)
#define pDur(slice) llList2Float(slice, 4)
#define pFlags(slice) llList2Integer(slice, 5)
#define pName(slice) llList2String(slice, 6)
// Returns strings, not auto casted to arrays
#define pFxobjs(slice) llList2String(slice, 7)
#define pEvts(slice) llList2String(slice, 8)
#define pTags(slice) llList2String(slice, 9)

#define pMaxStacks(slice) llList2Integer(slice, 10)



list EVT_INDEX;     // [scriptname_evt, (int)numPids, pid, pid]...
// Takes an index of scriptname_evt (ex: 0) and uses the length int to get the PIDs
#define getEvtIdsByIndex(index) llList2List(EVT_INDEX, index+2, index+2+llList2Integer(EVT_INDEX, index+1))

list TAG_CACHE;     // [(int)tag1...]
list PLAYERS;		// Contains the players

integer PID;		// Maintains index

// FX stuff
float dodge_chance;
float dodge_add;
integer FX_FLAGS;
 
#define getRunPackage(slice) \
	[ \
		FXCPARSE$ACTION_RUN, \
		pID(slice), \
		pStacks(slice), \
		pFlags(slice), \
		pName(slice), \
		pFxobjs(slice), \
		pTimesnap(slice),\
		0 \
	]
 


// Searches packages and returns the index
list find(list names, list senders, list tags, list pids, integer flags){
    list out; integer i;

    for(i=0; i<llGetListLength(PACKAGES); i+=PSTRIDE){ // Cycle all packages
        
		integer add = TRUE; // If this should be added to output
		
		list slice = pSlice(i);
		
        string n = pName(slice);		// Name of package
        string u = pSender(slice);		// Package sender
		
		// See if we can find the name of this package in names
        if(l2s(names,0) != "" && llListFindList(names, [n])==-1){
			add = FALSE;
		}
		
		// See if we can find a package with these flags
		if(add && flags){
			if(!(pFlags(slice)&flags))
				add = FALSE;
		}
		
		// See if we can find a package sent by this person
        if(add && l2s(senders,0) != ""){
            if(llListFindList(senders, [u]) == -1){
				add = FALSE;
			}
        }
		
		// See if we can find a tag
        if(add && llList2Integer(pids,0)!=0){
            if(llListFindList(pids, [llList2Integer(PACKAGES, i)]) == -1)
				add = FALSE;
        }
		
		// See if it has any of these tags
		list t = llJson2List(pTags(slice));
        if(add && tags != [] && llList2Integer(tags,0) != 0){
            integer x; 
			integer found;
            for(x = 0; x<llGetListLength(tags) && !found; x++){
                if(~llListFindList(tags, llList2List(t, x, x)))
					found = TRUE;
            }
			if(!found)
				add = FALSE;
        }
		
		// in that case we add the index
        if(add)
			out+=i;
    }
    return out;
}
	
	
onEvt(string script, integer evt, list data){
	// TEAM should be defined in the PC and NPC implementation of this
	if(script == "got Status" && evt == StatusEvt$team){
		TEAM = llList2Integer(data, 0);
	}
		
		
// Ignore own events, intevents use "" as script
if(script != cls$name){
	// Find packages to open (should contain indexes from PACKAGES)
	list packages = [];
	key dispeller;
	
	// If internal event, run on a specific ID by data
	list no_id = [INTEVENT_SPELL_ADDED, INTEVENT_DODGE, INTEVENT_PACKAGE_RAN];			// Internal event that aren't bound to a specific ID
    if(script == "" && llListFindList(no_id, [evt]) == -1){
		
		if(evt == INTEVENT_DISPEL){
			dispeller = llList2String(data, 1);
		}
		
		packages = find([], [], [], [llList2Integer(data,0)], 0);	// Returns ID
		
	}
	// This was an external event
    else{
		// This works because the only strings in evt_index are the labels
        integer pos = llListFindList(EVT_INDEX, [script+"_"+(string)evt]);
        if(~pos){
            packages = find([],[],[],getEvtIdsByIndex(pos), 0);
        }
    }
    
	// Cycle through all packages that have this event, remember that the packages are just list of indexes from PACKAGES
    while(llGetListLength(packages)){
        list slice = pSlice(l2i(packages, 0));					// Get the package slice to work on
        packages = llDeleteSubList(packages, 0, 0);				// Iterate
		
        string sender = pSender(slice);
        if(sender == "s")sender = llGetOwner();
        
		// Read the events from the package
        list evts = llJson2List(pEvts(slice));


		// Create a jump, not pretty but fast
		@evtNext;
        while(llGetListLength(evts)){
		
            list evdata = llJson2List(llList2String(evts, 0)); 	// Event array from package
            evts = llDeleteSubList(evts, 0, 0);					// Iterate

			
			// Since each package might have multiple events, we have to find the events that match
            if(script+"_"+(string)evt == llList2String(evdata, 1)+"_"+llList2String(evdata,0)){ 
				
				// JSON array of parameters set in the package
				list against = llJson2List(llList2String(evdata, 5));
				
				// Iterate over parameters and make sure they validate with the event params we received
				integer i;
				for(i = 0; i<llGetListLength(against); ++i){
					
					// Event data from package event
					list eva = explode("||", llList2String(against, i));
										
					// Event data from event
					string cur = llList2String(data, i);
				
					// Validate comparison here, currently a simple == check, could be expanded with num comparisons
					if(
						l2s(eva,0) != "" && 	// If the event condition at index is unset, it should always be accepted
						llListFindList(eva, [cur]) == -1				// But if it's not unset and not the same as the condition, then we fail
					){
						//qd("Fail validating "+l2s(eva,0)+" against '"+cur+"'");
						jump evtNext;			// Jumps are fiddly but saves memory
					}
				}
				
				
				// We have validated that this event should be accepted, let's extract the wrapper
				string wrapper = llList2String(evdata, 4);
					
				// We can use <index> and <-index> tags to replace with data from the event
				for(i=0; i<llGetListLength(data); i++){
					wrapper = implode((str)(-llList2Float(data, i)), explode("<-"+(str)i+">", wrapper));
					wrapper = implode(llList2String(data, i), explode("<"+(str)i+">", wrapper));
				}
				
				// Target flags
				integer targ = llList2Integer(evdata, 2);
				integer maxtargs = llList2Integer(evdata, 3);
				if(maxtargs == 0)maxtargs = -1;
				
				// AOE cannot be limited by nr, maxtargs is instead used as a way to limit distance
				if(targ&TARG_AOE){
					float range = maxtargs;
					maxtargs = 1000;
					FX$aoe(range, llGetOwner(), wrapper, TEAM);
				}
				
				// Run on self
				if(targ&TARG_VICTIM || (targ&TARG_CASTER && sender == "s")){
					FX$run(sender, wrapper); maxtargs--;
				}
				// Run on dispeller (if dispel event)
				if(targ&TARG_DISPELLER && dispeller != "" && maxtargs != 0){
					if(dispeller == "s" || dispeller == "")FX$run(sender, wrapper);
					else FX$send(dispeller, sender, wrapper, TEAM);
					maxtargs--;
				}
				
				// Run on caster last
				if(targ&TARG_CASTER && maxtargs != 0){FX$send(sender, sender, wrapper, TEAM); maxtargs--;}
            }
        }
        
    }
}
	// Extended events
    #ifdef FXConf$useEvtListener
    evtListener(script, evt, data);
    #endif
}

// Validates a package before it can be accepted
// Package is an actual package, not the abridged version stored in PACKAGES
integer preCheck(key sender, list package, integer team){
	
	// Quick scan if we're dead or not
	integer flags = l2i(package, PACKAGE_FLAGS);
	if(~flags&PF_ALLOW_WHEN_DEAD && isDead()){
		return FALSE;
	}
	
	// Conditions from the package
    list conds = llJson2List(l2s(package, PACKAGE_CONDS));
    
	// Min conditions that have to be met
	integer min = l2i(package, PACKAGE_MIN_CONDITIONS);
    // Require ALL if min is 0
	if(min == 0)min = count(conds);
	
	// Nr conditions met, this value has to be at least min to validate
    integer successes;
	
	// If we validated enough conditions. This is used because it can be inverted if the condition is negative
    integer add = TRUE;
	
	// Tracks how many conditions we have looped through, used to break the loop if the remaining conditions aren't enough to meet min
    integer parsed;
	
    // loop through all conditions
    list_shift_each(conds, cond, {
		
        list dta = llJson2List(cond);
		integer c = llList2Integer(dta,0); 	// Condition ID, rest of condl is vars 
        dta = llDeleteSubList(dta,0,0);		// Vars
		
		
        integer inverse = (c<0);				// Should return TRUE if validation fails, otherwise false
        c = llAbs(c);
        
        // Built in conditions
        if(c == fx$COND_HAS_PACKAGE_NAME || c == fx$COND_HAS_PACKAGE_TAG){
            integer found;
			
			// See if we have one of the package names stored in dta
            if(c == fx$COND_HAS_PACKAGE_NAME){
                integer i;
                for(i=0; i<llGetListLength(PACKAGES) && !found; i+=PSTRIDE){
                    if(~llListFindList(dta, [pName(pSlice(i))]))found = TRUE;
                }
            }
			// See if we have a tag stored in dta
			else{
                list_shift_each(dta, t, {
                    if(~llListFindList(TAG_CACHE, [(integer)t])){
                        found = TRUE;
                        dta = [];
                    }
                })
            }
			
            // Not found, so add should be false
            if(!found){
				add = FALSE;
			}     
        }
		else if(c == fx$COND_SAME_TEAM){
			inverse = l2i(dta,0);
			add = (TEAM == team);
		}
		// User defined conditions
        else{
			add = checkCondition(sender, c, dta, flags, team);
		}
		
		// If we're inverse, then flip add
        if(inverse)
			add = !add;
		
		// Store successes
        successes+=add;
		
		// We have reached the minimum
        if(successes>=min)return TRUE;
		
		// Increase nr parsed
        parsed++;
		
		// If there aren't enough conditions left to generate enough successes, just bail
        if(successes+(min-parsed)<min)
			return FALSE;
    })
	// Output if we hit enough successes
    return successes>=min;
}





timerEvent(string id, string data){
    integer pid = (integer)llGetSubString(id, 2, -1);
	
	// Package has timed out
    if(llGetSubString(id, 0, 1) == "F_"){
        FX$rem(TRUE, "", 0, "", pid, FALSE, 0, 0, 0);
    }
	// Package should tick
    else if(llGetSubString(id, 0, 1) == "T_"){
        integer i;
        for(i=0; i<llGetListLength(PACKAGES); i+=PSTRIDE){
            if(llList2Integer(PACKAGES, i) == pid){
				list slice = pSlice(i);
				string sender = pSender(slice);
				if(sender == "s")sender = llGetOwner();
				llMessageLinked(LINK_THIS, TASK_FXC_PARSE, llList2Json(JSON_ARRAY, getRunPackage(slice)), sender);
				onEvt("", INTEVENT_PACKAGE_RAN, [pName(slice)]);
                return;
            }
        }
    }
} 
default
{
    on_rez(integer start){
        llResetScript();
    }
	
	state_entry(){
		PLAYERS = [(str)llGetOwner()];
		if(llGetStartParameter())
			raiseEvent(evt$SCRIPT_INIT, "");
	}
    
    timer(){multiTimer([]);}
    
	
	#define LM_PRE \
	if(nr == TASK_FX){ \
		list data = llJson2List(s); \
		FX_FLAGS = l2i(data, FXCUpd$FLAGS); \
		dodge_chance = i2f(l2i(data, FXCUpd$DODGE)); \
	}
    
	#include "xobj_core/_LM.lsl"
        /*
            Included in all these calls:
            METHOD - (int)method
            PARAMS - (var)parameters
            SENDER_SCRIPT - (var)parameters
            CB - The callback you specified when you sent a task
        */
		
		// Prevent callbacks from being received
        if(method$isCallback)return;
	
		// This is the main input for adding an effect
        if(METHOD == FXMethod$run){
			
			string sender = method_arg(0);						// UUID of FX sender
			// Convert sender to "s" if self
			if(sender == (str)llGetOwner() || sender == "")sender = "s";
						
            list packages = llJson2List(method_arg(1));			// Open up the wrapper
			float range = llList2Float(PARAMS, 2);				// Max range for FX (if >0)
			integer team = llList2Integer(PARAMS, 3);			// Team defaults to NPC unless set
			// Internal commands are always same team
			if(method$internal)
				team = TEAM;
			
			integer flags = llList2Integer(packages, 0);		// Wrapper flags
			integer min_objs = llList2Integer(packages,1);		// Min packages to add
            integer max_objs = llList2Integer(packages,2);		// Max packages to add
			packages = llDeleteSubList(packages, 0, 2);			// Now packages contain a stride of 2: (int)stacks_to_add, (arr)package
			

			#ifdef IS_NPC
				// RC is only needed for NPCs since NPCs can direct effects to players
				integer RC = TRUE;
				if(flags&WF_REQUIRE_LOS && id != ""){
					list data = llGetObjectDetails(id, [OBJECT_POS, OBJECT_DESC]);
					vector pos = l2v(data, 0);
					if(llGetSubString(l2s(data, 1), 0, 2) == "$M$")
						pos+= <0,0,1>;
					if(llList2Integer(llCastRay(llGetPos()+<0,0,.5>, pos, [RC_REJECT_TYPES, RC_REJECT_PHYSICAL|RC_REJECT_AGENTS]), -1)> 0){
						RC = FALSE;
					}
				}
			#endif

			// Quick flag check on the wrapper
			if(
				(~flags&WF_ALLOW_WHEN_DEAD && STATUS&StatusFlag$dead) || 
				(~flags&WF_ALLOW_WHEN_QUICKRAPE && FX_FLAGS&fx$F_QUICKRAPE) || 
				(~flags&WF_ALLOW_WHEN_RAPED && STATUS&StatusFlag$raped) ||
				(range > 0 && llVecDist(llGetPos(), prPos(id))>range)
				#ifdef IS_NPC
				|| !RC
				#endif
			){
				CB_DATA = [FALSE];
			}	
			// If a user defined invul function is defined
			#ifdef IS_INVUL_CHECK
			else if(flags&WF_DETRIMENTAL && IS_INVUL_CHECK()){
				CB_DATA = [FALSE];
			}
			#endif
			// Check dodge
			else if(~flags&WF_NO_DODGE && flags&WF_DETRIMENTAL && sender != llGetOwner() && llFrand(1)<(dodge_chance+dodge_add)){
				// If not NPC we should animate when we dodge
				#ifndef IS_NPC
				AnimHandler$anim(mkarr((["got_dodge_active", "got_dodge_active_ub"])), TRUE, 0, 0);
				#endif
				llTriggerSound("2cd691be-46dc-ba05-9a08-ed4a8f48a976", .5);
				onEvt("", INTEVENT_DODGE, []);
				CB_DATA = [FALSE];
			}
			else{
				// The wrapper was accepted, so now we need to scan the packages
				
				list successful;	// [(int)nrStacks, (int)package_length]+packageData
				integer nSuc = 0;	// nr successful
				
				// Cycle through
				integer i;
				for(i=0; i<llGetListLength(packages); i+=2){
					list p = llJson2List(llList2String(packages, i+1));			// Convert package to list, since preCheck would have to do that anyways
					// Run user defined function on it
					if(preCheck(sender, p, team)){
						successful+=[llList2Integer(packages, i), count(p)]+p;
						nSuc++;
					}
					// If we have enough successful packages, stop
					if(nSuc>=max_objs && max_objs != 0){
						i = llGetListLength(packages);
					}
				}
				
				// We don't have enough successful packages
				if(nSuc<min_objs || !nSuc){
					CB_DATA = [FALSE];
				}
				else{
				
					// We have enough successful packages. Let's open them
					CB_DATA = [nSuc];		// Set a return value of nr accepted packages
					
					// If we received a detrimental effect, refresh combat
					#ifndef IS_NPC
					if(flags&WF_DETRIMENTAL){
						// Update combat since we received a detrimental effect
						Status$refreshCombat();
						if(_NPC_TARG == "" && llGetAgentSize(sender) == ZERO_VECTOR){
							// Attempt to target monster unless we already have a monster
							Status$monster_attemptTarget(sender, false);
						}
					}
					#endif
					
					
					
					// Data to send to the FXCompiler
					list send = [];
					
					@reloop;	// Jump is not graceful but LSL doesn't fucking have continue;
					while(successful){
						integer stacks = llList2Integer(successful, 0);
						// Min stacks is 1
						if(stacks==0)stacks = 1;
						
						list package = llList2List(successful, 2, 2+llList2Integer(successful,1)-1);
						successful = llDeleteSubList(successful, 0, 2+count(package)-1);
						
						
						
						
						float dur = llList2Float(package, PACKAGE_DUR);
						integer flags = llList2Integer(package, PACKAGE_FLAGS);
						string name = llList2String(package, PACKAGE_NAME);
						integer mstacks = llList2Integer(package, PACKAGE_MAX_STACKS); 
						if(mstacks == 0)mstacks = 1;
						integer ts = timeSnap();
						
						// Here we convert the package into a slice, we can later build upon this
						// The first value, PID needs to be updated if this package is a duration one later on

						list slice = pBuildSlice(
							0, 				// PID, needs to be updated if added as duration effect
							sender,
							stacks, 		// Nr stacks
							ts, 	// Generic timesnap of when it was added
							dur, 			// Duration of package
							flags, 			// Flags
							name, 			// Name
							llList2String(package, PACKAGE_FXOBJS), // FX objects
							llList2String(package, PACKAGE_EVTS), 	// Events
							llList2String(package, PACKAGE_TAGS), 	// Tags
							mstacks			// Max stacks
						);

						
						// Run and continue if duration is 0
						if(dur <= 0){
							send += getRunPackage(slice);
							onEvt("", INTEVENT_PACKAGE_RAN, [pName(slice)]);
							jump reloop;
						}
						
						// Ticking effect
						float tick = llList2Float(package, PACKAGE_TICK);
						
						// See if package exists already
						list s = [sender];
						// If full unique, it can add stacks regardless of sender
						if(flags&PF_FULL_UNIQUE)
							s = [];
						
						list exists = find([name], s, [], [], 0);
						if(exists){
							// It exists, schedule an add stack
							// Manage stacks
							FX$addStacks(LINK_THIS, stacks, "", 0, "", llList2Integer(PACKAGES, llList2Integer(exists,0)), TRUE, 0, 1, FALSE);
							
							// If trigger immediate, we still need to run it
							if(flags&PF_TRIGGER_IMMEDIATE){
								send += getRunPackage(slice);
								onEvt("", INTEVENT_PACKAGE_RAN, [pName(slice)]);
							}
							jump reloop;
						}

						// After this point we have to add, so increase the value of PID
						++PID;
						slice = llListReplaceList(slice, [PID], 0, 0);
						
						/*
						// Remove current if full unique
						if(flags&PF_FULL_UNIQUE){
							list find = find([name], [], [], [], 0);
							integer x;
							for(x=0; x<llGetListLength(find); x++){
								FX$rem(flags&PF_EVENT_ON_OVERWRITE, "", 0, "", llList2Integer(PACKAGES, llList2Integer(find, x)), TRUE, 0, 0, 0);
							}
						}
						*/
						
						// Update event-cache
						list evts = llJson2List(llList2String(package, PACKAGE_EVTS));
						while(llGetListLength(evts)){
							list evt = llJson2List(llList2String(evts,0));		// Event data array
							evts = llDeleteSubList(evts, 0, 0);
							
							// Events are renamed as (str)script_(int)event
							string find = l2s(evt, 1)+"_"+l2s(evt,0);
							
							// See if it exists already in the cache, this works because the label is the only string in that list
							integer pos = llListFindList(EVT_INDEX, [find]);
							
							// We already have an event of this type cached
							if(~pos){
								// Add this new effect PID to the index
								list pids = getEvtIdsByIndex(pos)+PID;
								// Update the index
								EVT_INDEX = llListReplaceList(EVT_INDEX, [count(pids)]+pids, pos+1, pos+1+llList2Integer(EVT_INDEX, pos+1)-1);
							}
							// Add to the index
							else{
								EVT_INDEX += [find, 1, PID];
							}
						} 
						
						
						// Add to PACKAGES
						PACKAGES += slice;
						// Add to tag cache
						TAG_CACHE+= llJson2List(llList2String(package, PACKAGE_TAGS));
						
						
						// Set Fade timer
						multiTimer(["F_"+(string)PID, "", dur, FALSE]);
						// Set tick if needed
						if(tick>0)
							multiTimer(["T_"+(string)PID, "", tick, TRUE]);
						
						// Send to fxCompiler
						integer actions = FXCPARSE$ACTION_ADD;
						if(flags&PF_TRIGGER_IMMEDIATE){
							actions = actions|FXCPARSE$ACTION_RUN;
							onEvt("", INTEVENT_PACKAGE_RAN, [pName(slice)]);
						}
						
						send+= [actions, pID(slice), pStacks(slice), pFlags(slice), pName(slice), pFxobjs(slice), pTimesnap(slice), f2i(pDur(slice))];
						onEvt("", INTEVENT_ONADD, [PID]);
						onEvt("", INTEVENT_SPELL_ADDED, [name]); 
					}
					
					
					// Send the packages to FXCompiler
					if(sender == "s")sender = llGetOwner();
					llMessageLinked(LINK_THIS, TASK_FXC_PARSE, llList2Json(JSON_ARRAY, send), sender);
				}
			}
        }
		
		// Remove an effect or add stacks
        if(METHOD == FXMethod$rem || METHOD == FXMethod$addStacks){
		
            integer rEvent = (integer)method_arg(0); 	// also num_stacks for addStacks
            string name = method_arg(1);				// Name of package
            integer tag = l2i(PARAMS, 2);				//
            string sender = method_arg(3);				//
            integer pid = l2i(PARAMS, 4);				//
			integer overwrite = l2i(PARAMS, 5); 		// If this is FALSE it's an overwrite and should not send the rem event
            integer flags = l2i(PARAMS, 6);				// 
			integer amount = l2i(PARAMS, 7);			// Max nr to remove
			if(amount<1)amount = -1;					// Set to -1 for all
			integer is_dispel = l2i(PARAMS, 8);			// Dispel event will be raised

			// Owner is always S
            if(sender == llGetOwner())
				sender = "s";
			
			// These are indexes of PACKAGES, sorted descending so they can be shifted without issue
			list find = llListSort(find([name], [sender], [tag], [pid], flags), 1, FALSE);	

			// Jump since we can't have continues
			@delContinue;
			while(find != [] && amount!=0){
			
				integer i = llList2Integer(find, 0);
				list slice = pSlice(i);
				
				find = llDeleteSubList(find, 0, 0);
				amount--;
				
				// UPDATE STACKS
				if(METHOD == FXMethod$addStacks){
				
					integer stacks = pStacks(slice);			// Current stacks
					stacks+= rEvent; 							// rEvent is num stacks to add or subtract in addStacks
					
					if(stacks<=0){								// No stacks left, schedule a remove
						FX$rem(TRUE, "", 0, "", llList2Integer(PACKAGES, i), overwrite, 0, -1, is_dispel);
						jump delContinue;						// Continue
					}
					
					// Update stacks
					// Edit the stacknr
					integer max = pMaxStacks(slice);
					if(stacks>max)stacks = max;
					// Update the index
					PACKAGES = llListReplaceList(PACKAGES, [stacks], i+2,i+2);
					
					// If adding stacks we need to reset the timer as well
					if(rEvent>=0){
						PACKAGES = llListReplaceList(PACKAGES, [timeSnap()], i+3, i+3);
						multiTimer(["F_"+(str)pID(slice), "", pDur(slice), FALSE]);
					}
					
					// Re-fetch slice with updated data
					slice = pSlice(i);
					// Send to FXCompiler
					llMessageLinked(LINK_THIS, TASK_FXC_PARSE, llList2Json(JSON_ARRAY, [
						FXCPARSE$ACTION_STACKS, 
						pID(slice), 
						pStacks(slice), 
						pFlags(slice), 
						pName(slice), 
						pFxobjs(slice), 
						pTimesnap(slice), 
						f2i(pDur(slice))
					]), "");
					
					onEvt("", INTEVENT_ONSTACKS, [pID(slice), stacks]);
					
				}
				
				// DELETE
				else{
				
					// Get the ID of the selected package
					integer pid_rem = pID(slice);
					
					// Raise dispel int-event
					if(is_dispel){
						integer f = pFlags(slice);
						
						// Undispelable
						if(f&PF_NO_DISPEL)
							jump delContinue;
						
						onEvt("", INTEVENT_DISPEL, [pid_rem, sender]);
					}
					
					// Raise remove int-event if not a remove
					if(rEvent && !overwrite)
						onEvt("", INTEVENT_ONREMOVE, [pid_rem]);
					
					// Tell FXCompiler
					llMessageLinked(LINK_THIS, TASK_FXC_PARSE, llList2Json(JSON_ARRAY, [
						FXCPARSE$ACTION_REM, 
						pID(slice), 
						pStacks(slice), 
						pFlags(slice), 
						pName(slice), 
						pFxobjs(slice), 
						pTimesnap(slice), 
						overwrite
					]), "");
					
					// Remove from evt cache
					list evts = llJson2List(pEvts(slice));
					list_shift_each(evts, val, 
						
						// Search for in events
						string find = jVal(val, [1])+"_"+jVal(val, [0]);
						
						// This works because the only string type in EVT_INDEX is the label
						integer pos = llListFindList(EVT_INDEX, [find]);
						
						// Found it
						if(~pos){
							// Get the PIDs
							list dta = getEvtIdsByIndex(pos);
							
							integer ppos = llListFindList(dta, [pid_rem]);
							if(~ppos){
								// Found this PID
								dta = llDeleteSubList(dta, ppos, ppos);
								
								if(dta == []){
									// Since deleting this PID emptied the array, we can safely assume there are only 3 elements
									EVT_INDEX = llDeleteSubList(EVT_INDEX, pos, pos+2);
								}else{
									// Update the index
									EVT_INDEX = llListReplaceList(EVT_INDEX, [count(dta)]+dta, pos+1, pos+1+llList2Integer(EVT_INDEX, pos+1)-1);
								}
							}
						}
					)
					
					// Remove from tag cache
					list tags = llJson2List(pTags(slice));
					list_shift_each(tags, t, {
						integer pos = llListFindList(TAG_CACHE, [(integer)t]);
						if(~pos)TAG_CACHE=llDeleteSubList(TAG_CACHE, pos, pos);
					})
					// Unset timers
					multiTimer(["F_"+(str)pid_rem]);
					multiTimer(["T_"+(str)pid_rem]);
					
					
					
					// Delete from packages
					PACKAGES = llDeleteSubList(PACKAGES, i, i+PSTRIDE-1);
				}
			}
        }
		
        if(METHOD == FXMethod$hasTags){
			list tags = [method_arg(0)];
			if(llJsonValueType(method_arg(0), []) == JSON_ARRAY)tags = llJson2List(method_arg(0));
			integer i; integer c = FALSE;
			for(i=0; i<llGetListLength(tags) && !c; i++){
				if(~llListFindList(TAG_CACHE, [llList2Integer(tags, i)]))c = TRUE;
			}
			CB_DATA = [c];
		}
        
    
    #define LM_BOTTOM  
    #include "xobj_core/_LM.lsl" 

}
