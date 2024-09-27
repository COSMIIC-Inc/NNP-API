classdef NNPCHARGER < NNPHELPERS
    %NNPCHARGER Adds charger functionality to NNPHELPERS
    %   

   properties (Access = public)
        %chargerFreqDivider = 8000000;  %MSP430 based
        chargerFreqDivider = 1000000;

   end

   methods
       function  out = convertADCtoCelsius(NNP, in)  
            %CONVERTADCTOTEMP converts ADC reading to temperature in Celsius
           x = [23798	23483	23163	22839	22511	22179	21844	21506	21164	20821	20475	20127	19778	19427	19076	18725	18373	18021	17670	17320	16971	16623	16278	15933	15592	15253	14915	14586	14256	13931	13609	13291	12977	12668	12363	12063	11764	11473	11190	10909	10634];
           v = [10	11	12	13	14	15	16	17	18	19	20	21	22	23	24	25	26	27	28	29	30	31	32	33	34	35	36	37	38	39	40	41	42	43	44	45	46	47	48	49	50];
           out = interp1(x,v,in);
       end

       function startCoil(NNP)
            NNP.startDCDC;
            NNP.startCD;
       end

       function stopCoil(NNP)
            NNP.stopCD;
            NNP.stopDCDC;
       end

       function startCD(NNP)
            NNP.transmitAP(84);
       end
       function stopCD(NNP)
            NNP.transmitAP(85);
       end
       function startDCDC(NNP)
            NNP.transmitAP(98);
       end
       function stopDCDC(NNP)
            NNP.transmitAP(99);
       end
       function startAudio(NNP)
            NNP.transmitAP(92);
       end
       function stopAudio(NNP)
            NNP.transmitAP(93);
       end


        function out = getChargerVoltage(NNP)
            %GETCHARGERVOLTAGE Read Coil Drive Battery Voltage
            %   Reads the Supply Voltage to the DC/DC converter ~12V on Power Supply or Battery Voltage
            out = [];
            payload = NNP.transmitAP(87);
            if length(payload) >= 2 
                out = double(typecast(uint8([payload(1), payload(2)]), 'uint16'))/4096*2.5*5;
            end
        end

        function out = getChargerCoilConnect(NNP)
            %GETCHARGERCOILCONNECT Read if coil is connected for older LAB2 without UART Coil
            out = [];
            payload = NNP.transmitAP(89);
            if length(payload) >= 1 
                out = double(payload(1));
            end
        end

        function out = getChargerCurrent(NNP)
            %GETCHARGERCURRENT Read Coil Drive Direct Current in Amps
            out = [];
            payload = NNP.transmitAP(86);
            if length(payload) >= 2 
                out = double(typecast(uint8([payload(1), payload(2)]), 'uint16'))/4096*2.5;
            end
        end

        function out = setChargerCoilFreq(NNP,  value)
            %SETCHARGERCOILFREQ Write Coil Drive Frequency in Hz
       
           periodTicks = round(NNP.chargerFreqDivider/value);
           periodTicks = min(periodTicks, 65535);
           periodTicks = max(periodTicks, 1);

           bytes = typecast(uint16(periodTicks), 'uint8');
           payload = NNP.transmitAP(82, bytes);
           if length(payload) >= 2 
               out = NNP.chargerFreqDivider/double(typecast(uint8([payload(1), payload(2)]), 'uint16'));
           end
        end

        function out = getChargerCoilFreq(NNP)
            %GETCHARGERCOILFREQ Read Coil Drive Frequency in Hz
            
            out = [];
            payload = NNP.transmitAP(83);
            if length(payload) >= 2 
                out = NNP.chargerFreqDivider/double(typecast(uint8([payload(1), payload(2)]), 'uint16'));
            end
        end



        function out = setChargerAudioFreq(NNP,  value)
        %SETCHARGERFREQ Write Coil Drive Frequency in Hz
       
           periodTicks = round(NNP.chargerFreqDivider/value);
           periodTicks = min(periodTicks, 65535);
           periodTicks = max(periodTicks, 1);

           bytes = typecast(uint16(periodTicks), 'uint8');
           payload = NNP.transmitAP(91, bytes);
           if length(payload) >= 2 
               out = NNP.chargerFreqDivider/double(typecast(uint8([payload(1), payload(2)]), 'uint16'));
           end
        end


        function out = getChargerAudioFreq(NNP)
            %GETCHARGERBAUDIOFREQ Read Coil Drive Audio Buzzer frequency in Hz
            %   controls audio buzzer frequency
            out = [];
            payload = NNP.transmitAP(90);
            if length(payload) >= 2 
                out = NNP.chargerFreqDivider/double(typecast(uint8([payload(1), payload(2)]), 'uint16'));
            end
        end

        function out = getChargerTemp(NNP)
            %GETCHARGERTEMP Read Coil Drive Thermistor Temperature in Celsius
            %  
            % unit16 is reverse endianness of other uint16??
            out = [];
            payload = NNP.transmitAP(88);
            if length(payload) >= 2 
                out = NNP.convertADCtoCelsius(double(typecast(uint8([payload(2), payload(1)]), 'uint16')));
            end
        end

        function [out, t] = getChargerClock(NNP)
            %GETCHARGERCLOCK Read Coil Drive Real-time Clock
            %   

            % str2double(dec2hex()) is used to convert from decimal back to BCD via dec2hex,   
            % which is a string. Use str2double to convert the string back to a number
            out = [];
            t = [];
            payload = NNP.transmitAP(112);
            if length(payload) >= 7 
                out.Sec = str2double(dec2hex(payload(1)));
                out.Min = str2double(dec2hex( payload(2)));
                out.Hour = str2double(dec2hex(payload(3)));
                out.Day = str2double(dec2hex(payload(4)));
                out.Date = str2double(dec2hex(payload(5)));
                out.Month = str2double(dec2hex(payload(6)));
                out.Year = str2double(dec2hex(payload(7)));

                t = datetime(out.Year+2000, out.Month, out.Date, out.Hour, out.Min, out.Sec);
            end
            
        end

        function setChargerClock(NNP)
            %SETCHARGERCLOCK Sets the charger clock based on current computer time
            %   
  
            % hex2dec(num2str()) is used to convert from BCD (string) to decimal (number)
            % to send data back to the RTC over the USB (serial)
            t = datetime;        %get current time
           
            % Calculate decimal vales to send back
            payloadTX = [hex2dec(num2str(round(second(t)))),...
                         hex2dec(num2str(minute(t))), ...
                         hex2dec(num2str(hour(t))), ...
                         hex2dec(num2str(weekday(t))), ...
                         hex2dec(num2str(day(t))), ...
                         hex2dec(num2str(month(t))), ...
                         hex2dec(num2str(year(t)-2000))];

            
            NNP.transmitAP(113, payloadTX);
        end


        function [sw, hw] = getCoilID(NNP)
            %GETCOILID Read Rev info for Coil MCU
            %   
            sw = [];
            hw = [];
            payload = NNP.transmitAP(128);
            if length(payload) >= 4 
                sw  = double(typecast(uint8([payload(1), payload(2)]), 'uint16'));
                hw = double(typecast(uint8([payload(3), payload(4)]), 'uint16'));
            end
        end

        
        %%UPDATE
       function out = getCoilTemp1(NNP)
            %GETCOILTEMP1 Read Coil Temperature 
            %   
            % unit16 is reverse endianness of other uint16??
            out = [];
            payload = NNP.transmitAP(120);
            if length(payload) >= 2 
                out =  NNP.convertADCtoCelsius(double(typecast(uint8([payload(2), payload(1)]), 'uint16')));
            end
       end

        %%UPDATE
        function out = getCoilTemp2(NNP)
            %GETCOILTEMP2 Read Coil Temperature 
            
            % unit16 is reverse endianness of other uint16??
            out = [];
            payload = NNP.transmitAP(121);
            if length(payload) >= 2 
                out = NNP.convertADCtoCelsius(double(typecast(uint8([payload(2), payload(1)]), 'uint16')));
            end
        end

        function out = setChargerDisplay(NNP,  str1, str2)
            %SETCHARGERDISPLAY set the charger display with strings 
            %        to only update line 1, do not include str2 or set it to []
            %        to only update line 2, set str1 = []
            if nargin<3
                str2 = [];
            end
            %convert strings to char arrays
            if isstring(str1)
                str1 = char(str1);
            end
            if isstring(str2)
                str2 = char(str2);
            end
            
            
            cmd = 109;
            if length(str1)>=20
                strOut = [str1(1:20) 0];  %null terminated
            elseif ~isempty(str1)
                strOut = [ones(1,20)*double(uint8(' ')) 0]; %spaces and null terminated
                strOut(1:length(str1))=str1; 
            else
                strOut = [];
                cmd = 111;
            end
            if length(str2)>=20
                strOut = [strOut str2(1:20) 0];
            elseif ~isempty(str2)
                str2_pad = [ones(1,20)*double(uint8(' ')) 0];
                str2_pad(1:length(str2))=str2;
                strOut = [strOut str2_pad]; 
            else
                if isempty(strOut)
                    return %no update
                else
                    cmd = 110;
                end
            end
  
            out = NNP.transmitAP(cmd, uint8(strOut)); %is there an output?
               
        end

        
        function out = setChargerVoltage(NNP,  value)
        %SETCHARGERVOLTAGE Sets the voltage output of the DC/DC converter
        %  this is the DC input voltage to the Coil Drive
        % currently limits max output to 10V, though DCDC converter allows 20V
        % the function returns the actual setting applied (in Volts)
        value = max(value, 0.8);
        value = min(value, 10);  %Maximum value is 20V, but for now limit to 10V max
        ISET = 3; %INTFB (setting results in 0.0564 default)
        setting = (round((value*(0.2256/(ISET+1))*1000-45)/0.5645));
        
            if(setting) > 65535
               error('DCDC setting cannot exceed 65535')%
           end

           bytes = typecast(uint16(setting), 'uint8');
           payload = NNP.transmitAP(100, bytes);
           settingout = double(typecast(payload, 'uint16'));
           out = (0.5645*settingout+45)*(ISET+1)/(0.2256*1000);
        end

        function setChargerLEDs(NNP,  red, yel, grn)
        %SETCHARGERLEDs Sets the LED values
        % 0:turns off LED, 1:turns on LED, otherwise LED remains same
            if nargin<3
                grn = [];
            end
            if nargin<2
                yel = [];
            end

            if ~isempty(red)
                if red == 1
                    NNP.transmitAP(101);
                elseif red == 0
                    NNP.transmitAP(102);
                end
            end

            if ~isempty(yel)
                if yel == 1
                    NNP.transmitAP(103);
                elseif yel == 0 
                    NNP.transmitAP(104);
                end
            end

            if ~isempty(grn)
                if grn == 1
                    NNP.transmitAP(105);
                elseif grn == 0 
                    NNP.transmitAP(106);
                end
            end
        end

        function setCoilLED(NNP, red, green, blue)
            %SETCOILLED sets tricolor LED
            %currently sets LED if value is above 127
            NNP.transmitAP(129, [red, green, blue]);
        end

        function setCoilIMUMode(NNP, mode)
        %SETCOILIMUMODE sets the mode for coil IMU
        % 0:powered down
        % 1:accelerometer only 26Hz
       
            switch mode
                case 0
                    NNP.transmitAP(122);
                case 1
                    NNP.transmitAP(123);
                otherwise
                    disp('mode not yet supported, 0=off, 1=Accel 26Hz');
            end

        end

       function out = getCoilIMUData(NNP) 
           %GETCOILIMUDATA returns data for selected IMU mode 
           % mode 1, returns accelerometer in g's as [x,y,z]
           out = [];
           payload = NNP.transmitAP(124);
           if length(payload)>=6
                x = double(typecast(uint8([payload(1), payload(2)]), 'int16'));
                y = double(typecast(uint8([payload(3), payload(4)]), 'int16'));
                z = double(typecast(uint8([payload(5), payload(6)]), 'int16'));
                out = [x y z]/(2^14); %JML note: this divider depends on Accelerometer register settings and could change
           end
        end

    end
end