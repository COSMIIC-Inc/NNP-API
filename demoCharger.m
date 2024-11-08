% This file demonstrates a closed loop algorithm, where MATLAB controls the COSMIIC CHarger
%% Configure LEDs
% Set WL LED control to manual
nnp.transmitAP(hex2dec('3C'), 64+128)

% Turn off WL accelerometer
nnp.transmitAP(hex2dec('33'), 0)

%% Auto tune coil frequency based on current
% coil should NOT be coupled to PM
%try
CURRENT = [];
nnp.setChargerLEDs(0, 0, 0);
chargerV = nnp.setChargerVoltage(5.0);
nnp.startCoil();

maxcurrent = 0;
optfreq = 0;

nnp.setChargerDisplay(1,'Scanning Coil Freq');
for freq = 3400:10:3600
    nnp.setChargerDisplay(0,[], [num2str(freq, '%4.0f') 'Hz']);
    nnp.setChargerCoilFreq(freq);
    pause(1)
    currentsum = 0;
    n=1;
    for i = 1:n
        [~, current] = nnp.getCoilPower();
        currentsum = currentsum+current;
    end
    current = currentsum/n;
    if current > maxcurrent
        maxcurrent = current;
        optfreq = freq;
    end
    CURRENT = [CURRENT current];
end
nnp.stopCoil();
nnp.setChargerDisplay(1,'Optimal Coil Freq: ',[num2str(optfreq, '%4.0f') 'Hz']);
pause(1)
nnp.setChargerCoilFreq(optfreq);

%%
timeout = 30;  %in seconds
tempPMinvalid = 0;
lastupdate = tic;
emptyCnt = 0;
dispCnt = 2;
maxI = [];
str1 = [];
str2 = [];
str3 = [];
str4 = [];
chargerMaxV = 7;
chargerMinV = 3;

% Temperature shutoffs in C
tempMaxCoilSkin = 44;
tempMaxCoilTop = 44;
tempMaxCharger = 49;
tempMaxPM = 40;
deltaTemp = 2; % buffer on temperatures to allow increase
deltaTempWarn = 1; % temperatures to force decrease
cnt = 1;

nnp.setChargerDisplay(1, '   Position coil','   over implant');
nnp.startCoil();

while true
     if toc(lastupdate) > timeout
        nnp.stopCoil();
        nnp.setChargerDisplay(1, 'Error:  Cannot find','    implant');
        nnp.setCoilLED(255, 0, 0);
        nnp.setChargerLEDs(1, 0, 0); %turn on error  LED
        break;
     end

    %PM data
    serialPM = nnp.getSerial(7);
    %strPM = 'PM#????';
    strPM = '????';
    dataPM  = nnp.read(7, '3000', 13, 'uint8'); %VREC, PMTemp, Test, B1V, B2V, B3V, NClimit, B1I, B2I, B3I, cmdI
    if isempty(maxI)
        maxI = nnp.read(7, '3000', 11);
    end
    temperr = false;
    % these messages should always get through, but should we check if they don't
    for i=1:3
        tempCharger = nnp.getChargerTemp;
        if ~isempty(tempCharger)
            break;
        elseif i==3
            temperr = true;
        end
    end
    for i=1:3
        tempCoilTop = nnp.getCoilTemp1;
        if ~isempty(tempCoilTop)
            break;
        elseif i==3
            temperr = true;
        end
    end
    for i=1:3
        tempCoilSkin = nnp.getCoilTemp2;
        if ~isempty(tempCoilSkin)
            break;
        elseif i==3
            temperr = true;
        end
    end
    [chargerV, chargerI] = nnp.getCoilPower;

    if temperr
        nnp.stopCoil();
        nnp.setChargerDisplay(1,'Error:   External coil','    temperature error');
        nnp.setCoilLED(255, 0, 0);
        nnp.setChargerLEDs(1, 0, 0); %turn on error  LED
        break;
    end

    if tempCoilTop >= tempMaxCoilTop || tempCoilSkin >= tempMaxCoilSkin || tempCharger >= tempMaxCharger
        nnp.stopCoil();
        nnp.setChargerDisplay(1,'Error:   External coil','    too hot!');
        nnp.setCoilLED(255, 0, 0);
        nnp.setChargerLEDs(1, 0, 0); %turn on error  LED
        break;
    end
   
    if isempty(dataPM)
        nnp.setChargerLEDs(2, 1, 2); %turn on warning LED
        continue;
    else
        if ~isempty(serialPM)
            %strPM = sprintf('PM#%04d', serialPM);
            strPM = sprintf('#%04d', serialPM);
        end

        data = double(typecast(dataPM(1:20), 'int16'));
        lastupdate = tic;
        
        tempPM = data(2)/10;
        if tempPM >= tempMaxPM 
            nnp.stopCoil();
            nnp.setChargerDisplay(1, 'Error: Implant ','    too hot!');
            nnp.setCoilLED(255, 0, 0);
            nnp.setChargerLEDs(1,0,0);
            break
        end
        if tempPM == 10
            tempPMinvalid = tempPMinvalid + 1;
            if tempPMinvalid > 3
                nnp.stopCoil();
                nnp.setChargerDisplay(1, 'Error:  Implant ','   invalid response!');
                nnp.setChargerLEDs(1,0,0);
                nnp.setCoilLED(255, 0, 0);
                break;
            end
        else
            tempPMinvalid = 0;
        end

        vrec = data(1)/10;
        if vrec < data(7)/10 || (vrec < 12 && ~isempty(maxI) && targ < maxI) %coil voltage is insufficient
            if chargerV < chargerMaxV && tempPM < tempMaxPM-deltaTemp && ...
                tempCoilTop < tempMaxCoilTop-deltaTemp && ...
                tempCoilSkin < tempMaxCoilSkin-deltaTemp && ...
                tempCharger < tempMaxCharger-deltaTemp
                    chargerV = nnp.setChargerVoltage(chargerV+0.1);
                    % leaves warn level as it was in last cycle
            else
                nnp.setChargerLEDs(2, 1, 2); %turn on warning
                %nnp.setCoilLED(0, 255, 0);
            end
        else  %coil voltage is sufficient
            if chargerV > chargerMinV && vrec > 12 && ~isempty(maxI) && targ == maxI %coil voltage is excessive
                chargerV = nnp.setChargerVoltage(chargerV-0.1);    
            end
            nnp.setChargerLEDs(2,0,2);  %turn off warning
            %nnp.setCoilLED(0, 0, 0);
        end

        %regardless if coil voltage is sufficient or not, reduce coil voltage if temperature is at warn level 
        
        if chargerV > chargerMinV && (...
           (tempCoilTop > tempMaxCoilTop-deltaTempWarn)   ||...
           (tempCoilSkin > tempMaxCoilSkin-deltaTempWarn) || ...
           (tempCharger > tempMaxCharger-deltaTempWarn)   || ...
           (tempPM > tempMaxPM-deltaTempWarn) )

                chargerV = nnp.setChargerVoltage(chargerV-0.1); 
                nnp.setChargerLED(2, 1, 0);
                nnp.setCoilLED(0, 0, 255);
        end

                
        batV = data(4:6)/1000; %in V
        batI = data(8:10)/10; %in mA

        targ = dataPM(21);
        str1 = sprintf('PM:%4.1fC %4.1fV %3.0fmA',  tempPM,vrec, targ);
        %nnp.setChargerDisplay(str1);
        cnt = cnt+1;
        if cnt>2
            dispCnt = dispCnt+1;
            if dispCnt>2
                dispCnt = 1;    
            end
            cnt = 0;
        

        switch dispCnt
            case 1
                str2 = sprintf('COIL     SKIN:%3.1fC ', tempCoilSkin);
                str3 = sprintf(' %4.2fV    TOP:%3.1fC ', chargerV, tempCoilTop);
                str4 = sprintf(' %4.2fA    BOX:%3.1fC ', chargerI, tempCharger);
            case 2
                str2 = sprintf('BAT1: %5.3fV %5.1fmA', batV(1),batI(1));
                str3 = sprintf('BAT2: %5.3fV %5.1fmA', batV(2), batI(2));
                str4 = sprintf('BAT3: %5.3fV %5.1fmA', batV(3), batI(3));  
            case 3
                str2 = sprintf('V %4.2f %4.2f %4.2f', batV);
                str3 = sprintf('I %4.1f %4.1f %4.1f %3.0f', batI, targ);
                str4 = sprintf('%4.1f/%4.1fC %3.1fV %3.1fA', tempCoilSkin, tempCoilTop, chargerV, chargerI);
        end
        
        end
        nnp.setChargerDisplay(0,str1,str2,str3,str4);
        fprintf('\n%s %4.1fV  %4.1fC | TARGET: %5.1fmA | BAT1: %5.3fV %5.1fmA | BAT2: %5.3fV %5.1fmA | BAT3: %5.3fV %5.1fmA | COIL: %4.1fC %4.1fC %4.1fC %4.2fV %4.2fA', strPM, vrec, tempPM, targ, batV(1),batI(1),batV(2), batI(2), batV(3), batI(3), tempCoilSkin, tempCoilTop, tempCharger, chargerV, chargerI);
        pause(0.25)
        if targ > 0 
            nnp.setCoilLED(0, 255, 0);
            nnp.setChargerLEDs(2,2,1)
        end
        pause(0.25)
        %if battery is not fully charged, blink green light.  Leave lit at full charge (avg current < 10% request)
        if mean(batV) < 4 || mean(batI) > 0.1*targ 
            nnp.setCoilLED(0, 0, 0);
            nnp.setChargerLEDs(2,2,0)
        end
    end
    
end
% catch
%     nnp.setChargerDisplay('   MATLAB ','    ERROR!');
%     nnp.stopCoil();
% end

%%

usecurrent = 1;
if usecurrent
    maxcurrent = 1.32;  %uncoupled  (calibrate this if desired)
    mincurrent = 1;     %best coupling (calibrate this if desired)
else
     minvrec = 6;      %poor coupling (calibrate this if desired)
     maxvrec = 15;     %best coupling (calibrate this if desired)
    nnp.write(7, '3000', 11, 0, 'uint8'); %set charging rate to zero so VREC fluctuates based on coupling only
end

%% Beep rate 

nnp.setChargerCoilFreq(3500);
mincurrent = 1.1;
chargerV = nnp.setChargerVoltage(5.0);
nnp.startCoil();
couplingtimer = tic;

while toc(couplingtimer) < 30
    if usecurrent
        [~, iCharger] = nnp.getCoilPower();
        t = (iCharger-mincurrent)*4;
    else
        vrec = double(nnp.read(7, '3000', 7, 'uint16'))/10;
        if ~isempty(vrec)
            t = -(vrec-maxvrec)/40
        end
    end
    
    nnp.playTones(440,100);
    if t > 0
        pause(t)
    end
end
nnp.stopCoil();

%%
    nnp.setChargerAudioFreq(100);
    nnp.startAudio();
    %%  Note-based
%arpegio
notes = [130.81 164.81 196 ...
        261.63  329.63 392 ...
        523.25 659.25 783.99 ...
        1046.5 1318.5 1567.98 2093]

% Max coupling
chargerV = nnp.setChargerVoltage(5.0);
nnp.startCoil();
usecurrent = 1;
if usecurrent
    D = length(notes)/(maxcurrent-mincurrent);
else
    D = length(notes)/(maxvrec-minvrec);
end

couplingtimer = tic;
while toc(couplingtimer) < 30
    if usecurrent
        [~, iCharger] = nnp.getCoilPower()
        iNote = round(-(iCharger-maxcurrent)*D)
        iNote = min(max(iNote, 1), length(notes));
    
        nnp.playTones(notes(iNote),100);
    else
        vrec = double(nnp.read(7, '3000', 7, 'uint16'))/10;
        if ~isempty(vrec)
            iNote = round((vrec-minvrec)*D)
            iNote = min(max(iNote, 1), length(notes));
            nnp.playTones(notes(iNote),100);
        end
    end
    %pause(0.1)
end
nnp.stopCoil();

%%
% nnp.setChargerAudioFreq(notes(1));
% nnp.startAudio();
for i = 1:length(notes)
    nnp.setChargerAudioFreq(notes(i));
    nnp.startAudio();
    pause(0.2)
    nnp.stopAudio();
    pause(0.1)
end
nnp.stopAudio();