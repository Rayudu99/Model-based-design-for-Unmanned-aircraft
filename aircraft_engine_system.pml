/* the engine control system messages */
mtype= { engThrust};

#define MAX_THRUST   100
#define MIN_THRUST  -100
#define DLT_THRUST    20
#define HLF_THRUST    60

int  thrust;

proctype EngineControlComputer( chan engineBus) {
	int thrustVal;		/* the new thrust value for the engine */
	
	do
	:: engineBus?engThrust( thrustVal) ->
		atomic {
			do
			:: (thrust < thrustVal)  -> 
				thrust= thrust + DLT_THRUST; 
				printf( "New thrust %d\n", thrust)
			:: (thrust > thrustVal)  -> 
				thrust= thrust - DLT_THRUST;
				printf( "New thrust %d\n", thrust)
			:: (thrust == thrustVal) -> 
				printf( "New thrust %d\n", thrust); 
				break
			od
		}
	od
}

proctype EngineControlTester( chan engineBus) {
	int tVal;
	
	engineBus!engThrust( MAX_THRUST);
	engineBus!engThrust( HLF_THRUST);	
	engineBus!engThrust( MIN_THRUST);
}

init {
	chan engineBus= [1] of {mtype, int};
	
	atomic {
		run EngineControlComputer( engineBus);
		run EngineControlTester(   engineBus);
	
		thrust= 0;
	}	
}