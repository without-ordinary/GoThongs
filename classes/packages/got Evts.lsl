#define USE_EVENTS
#include "got/_core.lsl"

integer BFL;
#define BFL_RECENT_CACHE 0x1

integer TEAM = TEAM_PC;

integer pointer;
list output_cache = [];		// score, key
list nearby_cache = [];		// key, key...
vector cache_pos;
rotation cache_rot;


#define descIsProper(desc) llGetSubString(desc, 0, 2) == "$M$" && (int)llGetSubString(desc, 3, 3) != TEAM

output(){
	if(output_cache == []){
		integer i;
		for(i=0; i<llGetListLength(nearby_cache); i++){
			vector pos = prPos(llList2Key(nearby_cache, i));
			
			float dist = llVecDist(pos, llGetPos());
			float angle = llRot2Angle(llRotBetween(llRot2Fwd(llGetRot()), llVecNorm(pos-llGetPos())))*RAD_TO_DEG;
			float score = dist+angle/8;
			output_cache += [score, llList2Key(nearby_cache, i)];
			
		}
		output_cache = llListSort(output_cache, 2, TRUE);
	}
	
	
	if(output_cache == [])return;
	
	
	
	integer i;
	for(i=0; i<llGetListLength(output_cache); i+=2){
		if(pointer>=llGetListLength(output_cache)/2)pointer = 0;
		
		key t = llList2Key(output_cache, pointer*2+1);
		vector pos = prPos(t);
		list ray = llCastRay(llGetPos(), pos+<0,0,.5>, [RC_REJECT_TYPES, RC_REJECT_PHYSICAL|RC_REJECT_AGENTS]);
		
		string desc = prDesc(t);
		if(llList2Integer(ray, -1) <1 && descIsProper(desc)){
			Status$monster_attemptTarget(t, true);
			return;
		}
		pointer++;
	}
}

onEvent(string script, integer evt, list data){
	if(script == "got Status" && evt == StatusEvt$team)
		team = l2i(data,0);
}

default
{
    state_entry(){
        llRegionSayTo(llGetOwner(), 1, "jasx.onattach GoThongs, 1");
        llRegionSayTo(llGetOwner(), 1, "jasx.onattach GoT, 1");
        memLim(1.5);
    }
    changed(integer change){
        if(change&CHANGED_REGION){
			resetAll();
		}
    }
    
    attach(key id){
        if(id == NULL_KEY){
			llOwnerSay("@detachall:JasX/onAttach/GoThongs=force");
			llOwnerSay("@detachall:JasX/onAttach/GoT=force");
			
            llRegionSayTo(llGetOwner(), 1, "jasx.onattach GoThongs, 0");
            llRegionSayTo(llGetOwner(), 1, "jasx.onattach GoT, 0");
        }
    }
	
	sensor(integer total){
		integer i;
		for(i=0; i<total; i++){
			string desc = prDesc(llDetectedKey(i));
			if(descIsProper(desc)){
				nearby_cache+=llDetectedKey(i);
			}
		}
		output();
	}
	
	
	timer(){
		BFL = BFL&~BFL_RECENT_CACHE;
		llSetTimerEvent(0);
	}
	
	// This is the standard linkmessages
    #include "xobj_core/_LM.lsl" 
    /*
        Included in all these calls:
        METHOD - (int)method  
        PARAMS - (var)parameters 
        SENDER_SCRIPT - (var)parameters
        CB - The callback you specified when you sent a task 
    */ 
    
    // Here's where you receive callbacks from running methods
    if(method$isCallback){
        return;
    }
    
    if(method$internal){
        if(METHOD == EvtsMethod$cycleEnemy){
			if(llVecDist(llGetPos(), cache_pos)>2 || llAngleBetween(llGetRot(), cache_rot)>PI/4 || ~BFL&BFL_RECENT_CACHE || nearby_cache == []){
				BFL = BFL|BFL_RECENT_CACHE;
				cache_pos = llGetPos();
				cache_rot = llGetRot();
				nearby_cache = [];
				output_cache = [];
				pointer = 0;
				llSensor("", "", SCRIPTED, 14, PI_BY_TWO);
			}
			else{
				pointer++;
				output();
			}
			llSetTimerEvent(4);
		}
    }

    // Public code can be put here

    // End link message code
    #define LM_BOTTOM  
    #include "xobj_core/_LM.lsl"  
    
}



