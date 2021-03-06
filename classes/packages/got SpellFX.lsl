
#define USE_EVENTS
#include "got/_core.lsl"

integer BFL;
#define BFL_QUEUE 0x1

list queue; // [name, targ, time]
purge(){
    integer i;
    for(i=0; i<llGetListLength(queue) && queue != []; i+=3){
        if(llGetTime()-llList2Integer(queue, i+2)>10){
            queue = llDeleteSubList(queue, i, i+2);
            i-=3;
        }
    }
}

default
{
    state_entry(){
        memLim(1.5);
    }
    
    #include "xobj_core/_LM.lsl" 
    /*
        METHOD - (int)method  
        PARAMS - (var)parameters 
        SENDER_SCRIPT - (var)parameters
        CB - The callback you specified when you sent a task 
    */ 
    
    if(method$isCallback){
        return;
    }
    
    if(method$internal){
        if(METHOD == SpellFXMethod$spawn){
            purge();
            string item = method_arg(0);
            key targ = method_arg(1);
            if(!isset(item) || !isset(targ))return;
            queue+=[item, targ, llGetTime()];
            llRezAtRoot(item, llGetPos()-<0,0,3>, ZERO_VECTOR, ZERO_ROTATION, 1);
        }
		else if(METHOD == SpellFXMethod$remInventory){
			list assets = llJson2List(method_arg(0));
			list_shift_each(assets, val,
				if(llGetInventoryType(val) == INVENTORY_OBJECT){
					llRemoveInventory(val);
				}
			)
		}
	}
    
    if(method$byOwner){
        if(METHOD == SpellFXMethod$getTarg){
            string n = llKey2Name(id);
            integer pos = llListFindList(llList2ListStrided(queue, 0, -1, 3), [n]);
            if(~pos){
                CB_DATA = [llList2String(queue, pos*3+1)];
                queue = llDeleteSubList(queue, pos, pos+2);
            }
            else CB_DATA = [0];
        }
        
        else if(METHOD == SpellFXMethod$sound){
            key sound = method_arg(0);
            if(sound){
                llStopSound();
                float vol = (float)method_arg(1);
                integer loop = (integer)method_arg(2);
                if(loop)llLoopSound(sound, vol);
                else llPlaySound(sound, vol);
            }
            else llStopSound();
        }
        else if(METHOD == SpellFXMethod$spawnInstant){
            list data = llJson2List(method_arg(0));
            string name = llList2String(data, 0);
            vector pos_offset = (vector)llList2String(data, 1);
            rotation rot_offset = (rotation)llList2String(data, 2);
			integer flags = llList2Integer(data, 3);
			integer startParam = l2i(data, 4);
			if(startParam == 0)
				startParam = 1;
			
            key targ = method_arg(1);
            
            boundsHeight(targ, b)
            if(llGetAgentSize(targ))b = 0;
            
			vector vrot = llRot2Euler(prRot(targ));
			if(~flags&SpellFXFlag$SPI_FULL_ROT)vrot = <0,0,vrot.z>;
			rotation rot = llEuler2Rot(vrot);
			
			vector to = prPos(targ)+<0,0,b/2>+pos_offset*rot;
			
            llRezAtRoot(name, to, ZERO_VECTOR, llEuler2Rot(vrot)*rot_offset, startParam);

        }
    }


    // End link message code
    #define LM_BOTTOM  
    #include "xobj_core/_LM.lsl"  
    
}

