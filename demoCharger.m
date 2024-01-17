% This file demonstrates a closed loop algorithm, where MATLAB controls the COSMIIC CHarger
% If VREC is insufficient but temperatures are 

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
    tempCoilTop = nnp.getCoilTemp1;
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
        if cnt>5
            dispCnt = dispCnt+1;
            if dispCnt>5
                dispCnt = 1;    
            end
            cnt = 0;
        
           
%         switch dispCnt
%             case 1
%                 str1 = sprintf('%s  VREC:%4.1fV', strPM, vrec);
%                 str2 = sprintf('         TEMP:%4.1fC', tempPM);
%             case 2
%                 str1 = sprintf('TARGET:      %5.1fmA', targ);
%                 str2 = sprintf('BAT1: %5.3fV %5.1fmA', batV(1),batI(1));
%             case 3
%                 str1 = sprintf('BAT2: %5.3fV %5.1fmA', batV(2), batI(2));
%                 str2 = sprintf('BAT3: %5.3fV %5.1fmA', batV(3), batI(3));
%             case 4
%                 str1 = sprintf('COIL: %4.1fC    %4.1fC', tempCoilSkin, tempCoilTop);
%                 str2 = sprintf(' %4.2fV  %4.2fA  %4.1fC', chargerV, chargerI, tempCharger);
%                 dispCnt = 0;

       

        switch dispCnt
            case 1
                str2 = sprintf('BAT1: %5.3fV %5.1fmA', batV(1),batI(1));
            case 2
                str2 = sprintf('BAT2: %5.3fV %5.1fmA', batV(2), batI(2));
            case 3
                str2 = sprintf('BAT3: %5.3fV %5.1fmA', batV(3), batI(3));
            case 4
                str2 = sprintf('COIL: %4.1fC    %4.1fC', tempCoilSkin, tempCoilTop);
            case 5
                str2 = sprintf('COIL: %4.2fV    %4.2fA', chargerV, chargerI);
                
        end
        
        end
        nnp.setChargerDisplay(str1,str2);
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
