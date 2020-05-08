/* air data sensor message declarations */
mtype= { airData };


#define MAX_THRUST   100
#define MIN_THRUST  -100
#define DLT_THRUST    20
#define HLF_THRUST    50

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

proctype AirDataTester( chan sensorBus) {
	int vVal;
	int hVal;
	
	printf( "Aircraft starting on runway.\n");
	
	/* full thrust */
	thrust= MAX_THRUST;
	
	do
	:: sensorBus?airData( vVal, hVal) ->
		atomic {
			if
			:: (hVal >= MAX_HEIGHT) -> thrust= HLF_THRUST; break
			:: else skip
			fi
		}
	od;
		
	do
	:: sensorBus?airData( vVal, hVal) ->
		atomic {
			if
			:: (hVal <= MIN_HEIGHT) -> thrust= MIN_THRUST; break
			:: else skip
			fi
		}
	od;
	
	do
	:: sensorBus?airData( vVal, hVal) ->
		atomic {
			if
			:: (vVal <= MIN_VELOCITY) -> thrust= 0;	break
			:: else skip
			fi
		}
	od;
	
	printf( "Aircraft stopped on runway.\n");
}

init {
	/*  the sensor bus modelled as a buffered channel */
	chan sensorBus= [1] of {mtype, int, int};
	
	atomic {
		/* instantiation of the sensor and tester process */
		run AirDataSensor( sensorBus);
		run AirDataTester( sensorBus);

		thrust= 0;	
		velocity= 0;
		height= 0;
	}	
}