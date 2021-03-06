#define USE_EVENTS
#include "got/_core.lsl"

integer chan;
list bindings;			// (key)targ, (int)chan

onEvt(string script, integer evt, list data){
	if(bindings){
		
		// Pregenerate the message
		string msg = GotAPI$buildAction(GotAPI$actionEvt, ([
			script, evt, mkarr(data)
		]));
		
		integer i;
		for(i=0; i<count(bindings); i+= 2)
			llRegionSayTo(llList2Key(bindings, i), llList2Integer(bindings, i+1), msg);
	}
}

outputBindStatus(key id, integer bound){
	integer evt = GotAPIEvt$bound;
	if(!bound)
		evt = GotAPIEvt$unbound;
		
	string msg = GotAPI$buildAction(GotAPI$actionEvt, ([
		llGetScriptName(), evt
	]));
	llRegionSayTo(id, GotAPI$chan(llGetOwnerKey(id)), msg);
}


default
{
    state_entry()
    {
		chan = GotAPI$chan(llGetOwner());
		llListen(chan, "", "", "");
		llRegionSay(chan, GotAPI$buildAction(GotAPI$actionIni, []));
    }
	
	listen(integer chan, string name, key id, string message){
		key okey = llGetOwnerKey(id);
		if(okey != llGetOwner())return;
		if(llGetSubString(message, 0, 2) != "GA|")return;
		list data = llJson2List(llGetSubString(message, 3, -1));
		integer command = llList2Integer(data, 0);
		data = llDeleteSubList(data, 0, 0);
		
		
		
		if(command == GotAPI$cmdBind || command == GotAPI$cmdUnbind){
			key targ = id;
			if(llList2Key(data, 0))targ = llList2Key(data, 0);
			integer pos = llListFindList(bindings, [targ]);
			

			if(command == GotAPI$cmdBind && ~pos)return outputBindStatus(targ, TRUE);
			if(command == GotAPI$cmdUnbind && pos == -1)return outputBindStatus(targ, FALSE);
				
			// Bind
			if(command == GotAPI$cmdBind){
				bindings+= [targ, GotAPI$chan(llGetOwnerKey(targ))];
				outputBindStatus(targ, TRUE);
			}
			// Unbind
			else{
				bindings = llDeleteSubList(bindings, pos, pos+1);
				outputBindStatus(targ, FALSE);
			}
			
			
		}
		
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

	if(method$byOwner && METHOD == GotAPIMethod$list && !(method$isCallback)){
		
		llOwnerSay("Currently bound items: Item | Owner | Chan");
		integer i;
		for(i=0; i<llGetListLength(bindings); i+= 2){
			key item = llList2Key(bindings, i);
			llOwnerSay(llKey2Name(item) +" | "+ llKey2Name(llGetOwnerKey(item)) +" | "+ llList2String(bindings, i+1));
		}
		
	}
    // End link message code
    #define LM_BOTTOM  
    #include "xobj_core/_LM.lsl"  
}

