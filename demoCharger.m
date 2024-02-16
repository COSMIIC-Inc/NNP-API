% This file demonstrates a closed loop algorithm, where MATLAB controls the COSMIIC CHarger


%% Auto tune coil frequency based on current
% coil should NOT be coupled to PM
%try
nnp.setChargerLEDs(0, 0, 0);
chargerV = nnp.setChargerVoltage(5.0);
nnp.startCoil();

maxcurrent = 0;
optfreq = 0;

nnp.setChargerDisplay('Scanning Coil Freq');
for freq = 3480:1:3520
    nnp.setChargerDisplay([], [num2str(freq, '%4.0f') 'Hz']);
    nnp.setChargerCoilFreq(freq);
    pause(0.1)
    current = nnp.getChargerCurrent();
    if current > maxcurrent
        maxcurrent = current;
        optfreq = freq;
    end
end
nnp.stopCoil();
nnp.setChargerDisplay('Optimal Coil Freq: ',[num2str(optfreq, '%4.0f') 'Hz']);
pause(1)
nnp.setChargerCoilFreq(optfreq);

%%
timeout = 30;  %in seconds
tempPMinvalid = 0;
lastupdate = tic;
emptyCnt = 0;
dispCnt = 0;
maxI = [];
chargerMaxV = 7;
chargerMinV = 3;

% Temperature shutoffs in C
tempMaxCoilSkin = 49;
tempMaxCoilTop = 49;
tempMaxCharger = 49;
tempMaxPM = 40;
deltaTemp = 2; % buffer on temperatures to allow increase
deltaTempWarn = 1; % temperatures to force decrease
cnt = 0;

nnp.setChargerDisplay('   Position coil','   over implant');
nnp.startCoil();

while true
     if toc(lastupdate) > timeout
        nnp.stopCoil();
        nnp.setChargerDisplay('   Cannot find','    implant');
        nnp.setChargerLEDs(1, 0, 0);
        break;
     end

    %PM data
    serialPM = nnp.getSerial(7);
    strPM = 'PM#????';
    dataPM  = nnp.read(7, '3000', 13, 'uint8'); %VREC, PMTemp, Test, B1V, B2V, B3V, NClimit, B1I, B2I, B3I, cmdI
    if isempty(maxI)
        maxI = nnp.read(7, '3000', 11);
    end

    % these messages should always get through, but should we check if they don't
    tempCharger = nnp.getChargerTemp;
    tempCoilTop = 40; %nnp.getCoilTemp1;
    tempCoilSkin = nnp.getCoilTemp2;
    chargerI = nnp.getChargerCurrent;

    if tempCoilTop >= tempMaxCoilTop || tempCoilSkin >= tempMaxCoilSkin || tempCharger >= tempMaxCharger
        nnp.stopCoil();
        nnp.setChargerDisplay('   External coil','    too hot!');
        nnp.setChargerLEDs(1, 0, 0);
        break;
    end
   
    if isempty(dataPM)
        nnp.setChargerLEDs(2, 1, 2);
        continue;
    else
        if ~isempty(serialPM)
            strPM = sprintf('PM#%04d', serialPM);
        end

        data = double(typecast(dataPM(1:20), 'int16'));
        lastupdate = tic;
        
        tempPM = data(2)/10;
        if tempPM >= tempMaxPM 
            nnp.stopCoil();
            nnp.setChargerDisplay('   Implant ','    too hot!');
            nnp.setChargerLEDs(1, 0, 0);
            break
        end
        if tempPM == 10
            tempPMinvalid = tempPMinvalid + 1;
            if tempPMinvalid > 3
                nnp.stopCoil();
                nnp.setChargerDisplay('   Implant ','    temperature!');
                nnp.setChargerLEDs(1, 0, 0);
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
                nnp.setChargerLEDs(2, 1, 2);
            end
        else  %coil voltage is sufficient
            if chargerV > chargerMinV && vrec > 12 && ~isempty(maxI) && targ == maxI %coil voltage is excessive
                chargerV = nnp.setChargerVoltage(chargerV-0.1);    
            end
            nnp.setChargerLEDs(2, 0, 2);
        end

        %regardless if coil voltage is sufficient or not, reduce coil voltage if temperature is at warn level 
        if chargerV > chargerMinV && ...
           (tempCoilTop > tempMaxCoilTop-deltaTempWarn ||...
           tempCoilSkin > tempMaxCoilSkin-deltaTempWarn || ...
           tempCharger > tempMaxCharger-deltaTempWarn || ...
           tempPM > tempMaxPM-deltaTempWarn) 

                chargerV = nnp.setChargerVoltage(chargerV-0.1); 
                nnp.setChargerLEDs(2, 1, 2);
        end

                
        batV = data(4:6)/1000; %in V
        batI = data(8:10)/10; %in mA

        targ = dataPM(21);
        str1 = sprintf('%s %4.1fV  %4.1fC', strPM, vrec, tempPM);
        %nnp.setChargerDisplay(str1);
        cnt = cnt+1;
        if cnt>2
            dispCnt = dispCnt+1;
            if dispCnt>6
                dispCnt = 1;    
            end
            cnt = 0;
        

        switch dispCnt
            case 1
                str2 = sprintf('TARGET:      %5.1fmA', targ);
            case 2
                str2 = sprintf('BAT1: %5.3fV %5.1fmA', batV(1),batI(1));
            case 3
                str2 = sprintf('BAT2: %5.3fV %5.1fmA', batV(2), batI(2));
            case 4
                str2 = sprintf('BAT3: %5.3fV %5.1fmA', batV(3), batI(3));
            case 5
                str2 = sprintf('COIL: %4.1fC    %4.1fC', tempCoilSkin, tempCoilTop);
            case 6
                str2 = sprintf('COIL: %4.2fV    %4.2fA', chargerV, chargerI);
                
        end
        
        end
        nnp.setChargerDisplay(str1,str2);
        fprintf('\n%s %4.1fV  %4.1fC | TARGET: %5.1fmA | BAT1: %5.3fV %5.1fmA | BAT2: %5.3fV %5.1fmA | BAT3: %5.3fV %5.1fmA | COIL: %4.1fC %4.1fC %4.1fC %4.2fV %4.2fA', strPM, vrec, tempPM, targ, batV(1),batI(1),batV(2), batI(2), batV(3), batI(3), tempCoilSkin, tempCoilTop, tempCharger, chargerV, chargerI);
        pause(0.25)
        if targ > 0 
            nnp.setChargerLEDs(2, 2, 1);
        end
        pause(0.25)
        %if battery is not fully charged, blink green light.  Leave lit at full charge (avg current < 10% request)
        if mean(batV) < 4 || mean(batI) > 0.1*targ 
            nnp.setChargerLEDs(2, 2, 0);
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
 usecurrent = 1

mincurrent = 1.1;
chargerV = nnp.setChargerVoltage(5.0);
nnp.startCoil();
couplingtimer = tic;
nnp.setChargerAudioFreq(300);
while toc(couplingtimer) < 30
    if usecurrent
        iCharger = nnp.getChargerCurrent()
        t = (iCharger-mincurrent)*4;
    else
        vrec = double(nnp.read(7, '3000', 7, 'uint16'))/10;
        if ~isempty(vrec)
            t = -(vrec-maxvrec)/40
        end
    end
    
    nnp.startAudio();
    pause(0.1)
    if t > 0
        nnp.stopAudio();
        pause(t)
    end
end
nnp.stopAudio();
nnp.stopCoil();

%%
    nnp.setChargerAudioFreq(100);
    nnp.startAudio();
    %%  Note-based
   %half steps
notes  =[130.81 138.59 146.83 155.56 164.81 174.61 185  196 207.65 220 233.08 246.94 ...
        261.63  277.18 293.66 311.13 329.63 349.23 369.99 392 415.3 440 466.16 493.88 ...
        523.25 554.37 587.33 622.25 659.25 698.46 739.99 783.99 830.61 880 932.33 987.77 ...
        1046.5 1108.73 1174.66 1244.51 1318.51 1396.91 1479.98 1567.98 1661.22 1760 1864.66 1975.53 2093]

%whole steps C scale
notes = [130.81 146.83 164.81 174.61 196 220 246.94 ...
        261.63 293.66 329.63 349.23 392 440 493.88 ...
        523.25 587.33 659.25 698.46 783.99 880 987.77...
        1046.5 1174.66 1318.51 1396.91 1567.98 1760 1975.53 2093]

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

nnp.setChargerAudioFreq(minfreq);
nnp.startAudio();
couplingtimer = tic;
while toc(couplingtimer) < 30
    if usecurrent
        iCharger = nnp.getChargerCurrent()
        iNote = round(-(iCharger-maxcurrent)*D)
        iNote = min(max(iNote, 1), length(notes));
    
        nnp.setChargerAudioFreq(notes(iNote));
    else
        vrec = double(nnp.read(7, '3000', 7, 'uint16'))/10;
        if ~isempty(vrec)
            iNote = round((vrec-minvrec)*D)
            iNote = min(max(iNote, 1), length(notes));
            nnp.setChargerAudioFreq(notes(iNote));
        end
    end
    pause(0.1)
end
nnp.stopAudio();
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