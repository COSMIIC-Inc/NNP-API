# NNP-API
NNPCORE includes the core functions of the NNP access point (e.g. nnp.transmitAP, nnp.transmit, nnp.read, nnp.write, nnp.nmt)
NNPHELPERS includes everything in NNPCORE + helper functions to do commonly performed tasks (e.g. nnp.networkON)
NNPCHARGER includes everything in NNPHELPERS + charger functionality for COSMIIC charger

normal usage:
nnp = NNPCHARGER; %choose COM port from drop down list, or specify COM port as argument nnp = NNPCHARGER('COM4')
%then use functions as in testCharger.m to operate the charger
e.g. 
nnp.startCoil; %starts coil with default parameters (5V, 3500 Hz) 

% values are specified and returned in real world values (e.g. Volts, Amps,DegreesC where conversions are done in NNPCHARGER)

type 
help nnp 
or 
help NNPCHARGER
to see available methods  

Charger refers to the CoilDrive Board and the capabilities of the main box (display, LEDs, buttons, audio, temperature, clock,...)
Coil refers to the coil iteself and the small board that sits in the coil (temperature, IMU,...)
