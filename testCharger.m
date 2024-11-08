%Test file for exercising COSMIIC Charger
%Run the sections indivdually 
%% Set WL LED control to manual
nnp.transmitAP(hex2dec('3C'), 1+2+4)
%% Set WL LED control to manual
nnp.transmitAP(hex2dec('3C'), 64+128)
%% Set WL LEDs
nnp.transmitAP(hex2dec('3F'), [0 0 0])

%% Turn off WL accelerometer
nnp.transmitAP(hex2dec('33'), 0)

%% Play tones (up to 16 tones)
notes = [130.81 146.83 164.81 174.61 196 220 246.94 ...
        261.63 293.66 329.63 349.23 392 440 493.88 ...
        523.25];

n = length(notes);
noteperiods = uint16(round(1./notes*1000000));
notelengths = uint16(ones(1, n)*100);
A = reshape([noteperiods; notelengths], 1, n*2);
B = typecast(swapbytes(A), 'uint8');
nnp.transmitAP(hex2dec('42'), [n B])

%% Set the Charging Frequency 
nnp.setChargerCoilFreq(3400)%freq in Hz
%% Set the Charging Voltage
nnp.setChargerVoltage(4); %Voltage in V
%% Start the Coil
nnp.startCoil();
%% Stop the Coil
nnp.stopCoil();
%% Read the Voltage into the DC/DC converter 
[voltage, current] =nnp.getChargerPower() %result in V
%% Read the Charging Current
[voltage, current] =nnp.getCoilPower() %result in A
%% Set the Coil TriColor LED
red = 255; green = 0; blue = 0;
nnp.setCoilLED(red, green, blue)
%% Turn off Coil LED
nnp.setCoilLED(0,0,0)
%% Power up Coil IMU Accelerometer at 26Hz
nnp.setCoilIMUMode(1)
%% Get the Accelerometer Data from Coil IMU
nnp.getCoilIMUData %result in g's
%% Power down Coil IMU Accelerometer
nnp.setCoilIMUMode(0)

%% Read Serial number from Power Module (test Radio)
nnp.getSerial(7) %returns PM serial number if radio settings are compatible and PM in range
%% Get the time/date from Charger
nnp.getChargerClock()
%% Set the time/date on Charger based on current computer time
nnp.setChargerClock(datetime(2000,1,1))
%% Set the time/date on Charger based on current computer time
nnp.setChargerClock()
%% Get Thermistor data
nnp.getChargerTemp
nnp.getCoilTemp1
nnp.getCoilTemp2
%%
[sw hw] = nnp.getCoilID
%%

nnp.setChargerDisplay(1)
%%
nnp.setChargerDisplay(1,'COSMIIC skldjfl;sdkl;fksdl;fkl;sdkf','A')
%% Auto tune coil frequency based on current
% coil should NOT be coupled to PM
nnp.setChargerVoltage(5.0);
nnp.startCoil();

maxcurrent = 0;
optfreq = 0;
nnp.setChargerDisplay(1,'Scanning Coil Freq')
for freq = 3450:1:3550
    nnp.setChargerDisplay(0,[], [num2str(freq, '%4.0f') 'Hz'],[],[])
    nnp.setChargerCoilFreq(freq);
    pause(0.1)
    [~,current] = nnp.getCoilPower();
    if current > maxcurrent
        maxcurrent = current;
        optfreq = freq;
    end
end
nnp.setChargerDisplay(1, 'Optimal Coil Freq: ',[num2str(optfreq, '%4.0f') 'Hz'])
nnp.setChargerCoilFreq(optfreq);
nnp.stopCoil();

%% Write Entries
for i=1:10
    msg = sprintf('hello COSMIIC world! log%04.0f\n', i);
    nnp.transmitAP(hex2dec('90'), [uint8(length(msg)) uint8(msg)])
    pause(0.1)
end
%% Dir SD
nnp.transmitAP(hex2dec('93'))
%% Init SD
nnp.transmitAP(hex2dec('92'))
%% Get Log Lenght
r = nnp.transmitAP(hex2dec('94'));
(typecast(uint8(r), 'uint32'))
%% Flush Log
r = nnp.transmitAP(hex2dec('95'))
%% Read full file
tic;
r = nnp.transmitAP(hex2dec('94'));
len = double((typecast(uint8(r), 'uint32')));
A = zeros(len,1);
address = 0;
N = 240;
while address < len
    numBytes = min(len-address, N);
    addrbytes = typecast(uint32(address), 'uint8');
    r = nnp.transmitAP(hex2dec('91'), [addrbytes numBytes]);
    if length(r)==numBytes
        A(address+1:address+numBytes) = r;
    else
        disp('invlid length')
    end
    address = address + numBytes;
end
toc;
%%
char(A')

%% 
nnp.transmitAP(hex2dec('a0'))