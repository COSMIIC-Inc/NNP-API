%Test file for exercising COSMIIC Charger
%Run the sections indivdually 
%% Set the Charging Frequency 
nnp.setChargerCoilFreq(3500); %freq in Hz
%% Set the Charging Voltage
nnp.setChargerVoltage(5); %Voltage in V
%% Start the Coil
nnp.startCoil();
%% Stop the Coil
nnp.stopCoil();
%% Read the Voltage into the DC/DC converter 
nnp.getChargerVoltage() %result in V
%% Read the Charging Current
nnp.getChargerCurrent() %result in A
%% Start the Audio Buzzer
nnp.startAudio();
%% Stop the Audio Buzzer
nnp.stopAudio();
%% Set the Coil TriColor LED
red = 255; green = 255; blue = 0;
nnp.setCoilLED(red, green, blue)
%% Turn off Coil LED
nnp.setCoilLED(0,0,0)
%% Power up Coil IMU Accelerometer at 26Hz
nnp.setCoilIMUMode(1)
%% Get the Accelerometer Data from Coil IMU
nnp.getCoilIMUData %result in g's
%% Power down Coil IMU Accelerometer
nnp.setCoilIMUMode(0)
%% Blink the Charger LEDs
nnp.setChargerLEDs(1, 0, 0);
pause(0.5)
nnp.setChargerLEDs(0, 1, 0);
pause(0.5)
nnp.setChargerLEDs(0, 0, 1);
%% Read Serial number from Power Module (test Radio)
nnp.getSerial(7) %returns PM serial number if radio settings are compatible and PM in range
%% Get the time/date from Charger
nnp.getChargerClock()
%% Set the time/date on Charger based on current computer time
nnp.setChargerClock()
%%
nnp.getChargerTemp
nnp.getCoilTemp1
nnp.getCoilTemp2
%% Auto tune coil frequency based on current
% coil should NOT be coupled to PM
nnp.setChargerVoltage(5.0);
nnp.startCoil();

maxcurrent = 0;
optfreq = 0;
nnp.setChargerDisplay('Scanning Coil Freq')
for freq = 3450:1:3550
    nnp.setChargerDisplay([], [num2str(freq, '%4.0f') 'Hz'])
    nnp.setChargerCoilFreq(freq);
    pause(0.1)
    current = nnp.getChargerCurrent();
    if current > maxcurrent
        maxcurrent = current;
        optfreq = freq;
    end
end
nnp.setChargerDisplay('Optimal Coil Freq: ',[num2str(optfreq, '%4.0f') 'Hz'])
nnp.setChargerCoilFreq(optfreq);
nnp.stopCoil();
%% Play a simple C-Major Scale
notes = [261, 293, 329, 349, 392, 440, 493, 523];
nnp.setChargerAudioFreq(notes(1));

for i=1:length(notes)
    nnp.setChargerAudioFreq(notes(i));
    if i==1
        nnp.startAudio();
    end
    pause(0.25)
end
nnp.stopAudio();