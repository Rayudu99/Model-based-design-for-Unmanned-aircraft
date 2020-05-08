/* global message declarations */
mtype= { airData, engThrust };


/* state values identifying the various flight phases */
#define TAKEOFF     0
#define CLIMBING    1
#define DESCENDING  2
#define BREAKING    3
#define STOPPED     4

#define MAX_THRUST   100
#define MIN_THRUST  -100
#define DLT_THRUST    20
#define HLF_THRUST    60

#define MAX_VELOCITY 120
#define MIN_VELOCITY   0
#define DLT_VELOCITY  20

#define MAX_HEIGHT  6000
#define MIN_HEIGHT     0
#define DLT_HEIGHT   600

int  thrust;
int  velocity;
int  height;


inline incVelocity( value) {
	if
	:: (velocity <  MAX_VELOCITY) -> velocity= velocity + value
	:: (velocity >= MAX_VELOCITY) -> skip
	fi
}

inline decVelocity( value) {
	if
	:: (velocity >  MIN_VELOCITY) -> velocity= velocity - value;
	:: (velocity <= MIN_VELOCITY) -> skip
	fi
}

inline incHeight( value) {
	if
	:: (velocity <  MAX_VELOCITY) -> skip
	:: (velocity >= MAX_VELOCITY) ->
		if
		:: (height <  MAX_HEIGHT) -> height= height + value
		:: (height >= MAX_HEIGHT) -> skip
		fi
	fi
}

inline decHeight( value) {
	if 
	:: (height >  MIN_HEIGHT) -> height= height - value
	:: (height <= MIN_HEIGHT) -> skip
	fi
}

proctype AirDataSensor( chan sensorBus) {
	int val; 
	
	do		
	/* maximum thrust, accelerate and climb */
	:: (thrust == MAX_THRUST) ->
		atomic {
			incVelocity( DLT_VELOCITY);
			incHeight( DLT_HEIGHT);
			sensorBus!airData( velocity, height)
		}
			
			
	/* half thrust, constant velocity and sink */
	:: (thrust == HLF_THRUST) ->
		atomic {
			decHeight( DLT_HEIGHT);
			sensorBus!airData( velocity, height)

		}
		
	/* inverse thrust, decelerate */
	:: (thrust == MIN_THRUST) ->
		atomic {
			assert( height == MIN_HEIGHT);
			decVelocity( DLT_VELOCITY);
			sensorBus!airData( velocity, height)
		}
	od
}

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

proctype VehicleManagementComputer( chan sensorBus, engineBus) {
	int actVelocity;		/* the actual speed  */
	int actHeight;			/* the actual height */
	int state;				/* flight state variable */
	
	state= TAKEOFF;
	
	do
	:: 	if
		:: (state == TAKEOFF) ->
			printf( "[VMC] Take Off Mode\n");
			
			/* precondition */
			assert( height   == MIN_HEIGHT);
			assert( velocity == MIN_VELOCITY);

			/* give maximum thrust on engine and wait for take off */
			engineBus!engThrust( MAX_THRUST);
			do
			:: sensorBus?airData( actVelocity, actHeight) ->
				if 
				:: (actVelocity >= MAX_VELOCITY) -> break
				:: else -> skip
				fi

			od;		
			state= CLIMBING
			
		:: (state == CLIMBING) ->
			printf( "[VMC] Climbing Mode\n");
			
			/* precondition */
			assert( velocity == MAX_VELOCITY);

			/* wait for maximum altitude and then reduce thrust */
			do
			:: sensorBus?airData( actVelocity, actHeight) ->
				if 
				:: (actHeight >= MAX_HEIGHT) -> break
				:: else -> skip
				fi
			od;
			engineBus!engThrust( HLF_THRUST);
			state= DESCENDING
			
		:: (state == DESCENDING) ->
			printf( "[VMC] Descending Mode\n");
			
			/* precondition */
			assert( velocity == MAX_VELOCITY);

			/* wait for touch down and then inverse thrust */
			do
			:: sensorBus?airData( actVelocity, actHeight) ->
				if 
				:: (actHeight <= MIN_HEIGHT) -> break
				:: else -> skip
				fi
			od;
			engineBus!engThrust( MIN_THRUST);
			state= BREAKING
			
		:: (state == BREAKING) ->
			printf( "[VMC] Breaking Mode\n");
			
			/* precondition */
			assert( height == MIN_HEIGHT);
			
			/* wait for aircraft stop */
			do
			:: sensorBus?airData( actVelocity, actHeight) ->
				if 
				:: (actVelocity <= MIN_VELOCITY) -> break
				:: else -> skip
				fi
			od;
			engineBus!engThrust( 0);
			state= STOPPED
			
		:: (state == STOPPED) ->
			printf( "[VMC] Stopped Mode\n");
			
			/* precondition */
			assert( height == MIN_HEIGHT);
			assert( velocity == MIN_VELOCITY);
			
			/* terminate VMC system */
			break
					
		fi
	od
}

init {
	/* the two bus systems modelled as channels */
	chan sensorBus= [1] of {mtype, int, int};
	chan engineBus= [1] of {mtype, int};
	
	atomic {
		/* the avionics system */
		run AirDataSensor( sensorBus);
		run VehicleManagementComputer( sensorBus, engineBus);
		run EngineControlComputer( engineBus);
	
		/* intial state of the aircraft */
		thrust= 0;
		velocity= 0;
		height= 0;
	}	
}
