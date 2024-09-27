classdef NNPCORE < handle
    %NNPAPI Interface to the NNP via the AccessPoint
    % Updated: 20200521 JML
    % Updated: 20230614 GJRS - changed serial functions to serialport
    
    properties (Access = private)
        cancelRead = false;
        mutexAP = false;
    end
    
    properties (Access = public)
        port = [];     %Serial Port used by Access Point
        RSSI = 0;     %Received Signal Strength Indication for last received radio mesage
        LQI = 0;      %Link Quality Indication for last received radio mesage
        verbose = 0;   %0:no text, 1:warnings only, 2:all radio messages 
        timeout = 0.5; %timeout for response from serial port
        lastError = [];
        % Note: 
        % 1. A weak signal in the presence of noise may give low RSSI and high LQI.
        % 2. A weak signal in "total" absence of noise may give low RSSI and low LQI.
        % 3. Strong noise (usually coming from an interferer) may give high RSSI and high LQI.
        % 4. A strong signal without much noise may give high RSSI and low LQI.
        % 5. A very strong signal that causes the receiver to saturate may give high RSSI and high LQI.
    end
    
    methods
        function NNP = NNPCORE(port)                
        % NNPAPI - (constructor) Opens port for Access Point
        % if no port is provided, a selection menu lets user select port
        
            if nargin == 0
                %If you have instrument control toolbox you can use the
                %following lines instead of the system command below
                try
                    availablePorts = cellstr(serialportlist);
                catch
                    try
                        [status, result] = system('powershell [System.IO.Ports.SerialPort]::getportnames()');
                        if status == 0 
                            portsCell = textscan(result,'%s');
                            availablePorts = portsCell{1};
                        else
                            msgbox('Could not read available ports.  Only supports Windows','NNPAPI','error')
                        end
                    catch
                        msgbox('Could not read available ports for unknow reason','NNPAPI','error')
                    end
                end
                if isempty(availablePorts)
                    msgbox('No Serial Ports Found','NNPAPI','error')
                    return
                elseif length(availablePorts) == 1
                    port = availablePorts{1};
                    msgbox(['Connecting on: ' port],'NNPAPI','help')
                else
                    user = listdlg('ListString',availablePorts,'SelectionMode', 'single', ...
                        'OKstring', 'Open', 'PromptString', {'Select port for'; 'NNP Access Point'});
                    if isempty(user)
                        return
                    else
                        port = availablePorts{user};
                    end
                end
            end
           

            try
                NNP.port = serialport(port, 230400);
            catch
                msgbox(['Could not open port: ' port],'NNPAPI','error')
                NNP.port = [];
            end
            NNP.RSSI = [];
            NNP.LQI = [];
        end
               
      
        function flushInput(NNP) 
        % FLUSHINPUT - Clears any bytes available in the port buffer
            %disp(['Bytes available:' num2str(NNP.port.NumBytesAvailable)])    
            if NNP.port.NumBytesAvailable
                buf = NNP.tryread(NNP.port.NumBytesAvailable);
                if NNP.verbose > 0
                    fprintf('\nFlush Input clearing: ');
                    fprintf('%02X ', buf);
                    fprintf('\n')
                end
            end
        end
        
        function refresh(NNP)
        % REFRESH - close and reopen the serial port to correct USB issues
            try
                OGport = NNP.port.Port;
                NNP.port = [];
                NNP.port = serialport(OGport, 230400);
                NNP.mutexAP = false;
                NNP.lastError = [];
            catch
                msgbox(sprintf('Failed to refresh Access Point port'));
                NNP.lastError = 'Serial Port';
            end
        end
        
        function trywrite(NNP, data)
            NNP.flushInput();
            try
                if NNP.verbose == 2
                    fprintf('\nRequest: ')
                    fprintf('%02X ', data)
                    fprintf('\n')
                end
                write(NNP.port, data, 'uint8');
            catch
                userResp = questdlg([sprintf('Failed to write data on Access Point port (%s).', NNP.port.Port),...
                         sprintf('\n\nDo you want to refresh the port?'),...
                         sprintf('\n\nNote: You may need to unplug and replug the AccessPoint prior to hitting Yes to resolve some issues')],...
                         'Port Write Error'); 
                NNP.lastError = 'Serial Port';
                if isequal(userResp, 'Yes')
                    NNP.refresh;
                end
            end
        end
        
        function data = tryread(NNP, n)
            try
                data = uint8(read(NNP.port, n, 'uint8'));
            catch
                NNP.lastError = 'Could not read from serialport';
                if NNP.verbose > 0
                    disp('could not read from serial port')
                end
                data = [];
            end
        end
        
        %% 
        function response = transmitAP(NNP, cmd, payload)
            if nargin < 3
                payload = [];
            end

            response = uint8([]);
            
            if length(payload)>252
                NNP.lastError = 'Outgoing Payload too long';
                return
            end
            if NNP.mutexAP == true
                NNP.lastError = 'AP access denied';
                return
             end

            NNP.mutexAP = true;

            NNP.trywrite( uint8([255 cmd length(payload)+3 payload]));

            t = tic;
            while NNP.port.NumBytesAvailable < 3 && toc(t)< NNP.timeout
                %delay loop
                drawnow; %allow other callbacks to execute
            end
            if NNP.port.NumBytesAvailable 
                resp = NNP.tryread(NNP.port.NumBytesAvailable);
                if resp(1)==255 && length(resp)==resp(3) 
                    if resp(2) == 6
                        response = resp(4:end);
                        if NNP.verbose == 2
                            disp(['Response: ' num2str(resp,' %02X')]);
                        end
                    elseif resp(2) == 13 %0x0D
                        NNP.lastError = 'Radio Timeout';
                    elseif resp(2) == 11 %0x0B
                        NNP.lastError = 'Invalid packet length';
                    else
                        NNP.lastError = ['Unknown: ', num2str(resp(2),' %02X')];
                    end
                elseif NNP.verbose > 0
                    disp(['Bad Response from Access Point: ' num2str(resp', ' %02X')]);
                    NNP.lastError = 'Bad Response';
                end
            else
               if NNP.verbose > 0
                disp('No Response from Access Point');   
               end
               NNP.lastError = 'USB timeout';
            end

            NNP.mutexAP = false;
        end

        
        %% Access Point Radio Settings 
        function [ch, rssi] = getClearChannel(NNP, dwell)
        % GETCLEARCHANNEL - Reads clearest channel.  Dwell time in ms for
        % each channel (1-255).  ~1ms gap between channels.  Default dwell
        % = 10ms.  Use >= 10ms for MedRadio Compliance
            ch = []; %initialize output
            rssi = [];   
            if nargin<2
                dwell=10; 
            end
            if dwell <1
                dwell =1;
            end
            if dwell >255
                dwell =255;
            end
            if NNP.timeout<((dwell+1)*10)/1000
                disp(['NNP serial timeout is too short for specified dwell time.  Use ' num2str(((dwell+1)*10)/1000) 's or higher']);
            end
            
            payload = NNP.transmitAP(75, dwell);
            if length(payload) >= 2
                ch = double(payload(1));
                rssi  = double(typecast(uint8(payload(2)), 'int8'));
            end
        end

        function [settings] = getRadioSettings(NNP)
        % GETRADIOSETTINGS - Reads AccessPoint Radio Settings
            settings = []; %initialize output
            
            payload = double(NNP.transmitAP(73));
            if length(payload) >= 7
                settings.addrAP  = payload(1);
                settings.addrPM  = payload(2);
                settings.chan    = payload(3);
                settings.txPower = payload(4);
                settings.worInt  = payload(5);
                settings.rxTimeout = payload(6);
                settings.retries = payload(7);
            end
        end
        
        function [success, settings] = setRadio(NNP, varargin)
        % SETRADIO - Set radio settings using Value Pair inputs
        % [success, settings] = setRadio(name1,value1,name2,value2) 
        % e.g. setRadio('chan', 5) sets channel to 5 on AccessPoint 
        % 
        % Outputs: 
        %  success: true if radio settings were successfully set, false
        %           otherwise
        %  settings: returned Access Point radio settings structure
        %
        % Value Pair Values and Names
        % Address of AccessPoint: 1-254 
        %  {'addrAP', 'addressAP', 'addressap', 'addrap', 'AP', 'ap', 'accesspoint', 'AccessPoint'}
        % Address of PowerModule: 1-254
        %  {'addrPM', 'addressPM', 'addresspm', 'addrpm', 'PM', 'pm', 'PowerModule', 'powermodule', 'implant'}
        % Radio Channel: 0-9 
        %  {'chan', 'Chan', 'ch', 'Ch', 'channel', 'Channel'}
        % Transmit Power: 0-46 
        %  {'txPower', 'TXPower', 'txpower', 'power', 'Power'}
        % WOR wake interval: 0 or 14-255 (in ms) 
        %  {'worInt', 'worint', 'WorInt', 'wakeInterval', 'wakeinterval'}
        % Radio Timeout: 0-255 (in ms)
        %  {'rxTimeout', 'RXTimeOut', 'rxtimeout','rxTimeOut', 'timeout', 'Timeout'} 
        % Retry attempts: 0-5 
        %  {'retries', 'Retries'}
        % Save values to Flash: true, false 
        %  {'save', 'Save', 'flash', 'Flash'}
            if rem(nargin,2) ~= 1
                error('Radio settings must be listed in Pairs')
            end
            settingsIn = NNP.getRadioSettings();
            if isempty(settingsIn)
                success = 0; 
                settings = [];
                return;
            end
            save = false;
            
            for i = 1:2:nargin-2 
                switch varargin{i}   
                    case {'addrAP', 'addressAP', 'addressap', 'addrap', 'AP', 'ap', 'accesspoint', 'AccessPoint'} 
                        settingsIn.addrAP = varargin{i+1};
                    case {'addrPM', 'addressPM', 'addresspm', 'addrpm', 'PM', 'pm', 'PowerModule', 'powermodule', 'implant'}
                        settingsIn.addrPM = varargin{i+1};
                    case {'chan', 'Chan', 'ch', 'Ch', 'channel', 'Channel'}
                        settingsIn.chan = varargin{i+1};
                    case {'txPower', 'TXPower', 'txpower', 'power', 'Power'}
                        settingsIn.txPower = varargin{i+1};
                    case {'worInt', 'worint', 'WorInt', 'wakeInterval', 'wakeinterval'}
                        settingsIn.worInt = varargin{i+1};
                    case {'rxTimeout', 'RXTimeOut', 'rxtimeout','rxTimeOut', 'timeout', 'Timeout'}    
                        settingsIn.rxTimeout = varargin{i+1};
                    case {'retries', 'Retries'}
                        settingsIn.retries = varargin{i+1}; 
                    case {'save', 'Save', 'flash', 'Flash'}
                        save = varargin{i+1};
                    otherwise
                        error('Not a Radio setting');
                end
            end
            settings = NNP.setRadioSettings(settingsIn, save);
            success = isequal(settingsIn, settings);
        end 
                    

        function  settings = setRadioSettings(NNP,  settingsIn , save)
        % SETRADIOSETTINGS - Writes AccessPoint radio settings 
        % 
        % settings = setRadioSettings(settingsIn, save) 
        %   save = true: new settings are saved in AccessPoint Flash 
        %   save = false (default): new settings are changed in AccessPoint 
        %                   RAM and will be reset when AccessPoint is power cycled 
        % Settings Fields:
        %   addrAP: 1-254 
        %   addrPM: 1-254 
        %   chan: 0-9
        %   txPower: 0-46
        %   worInt: 0 or 14-255
        %   rxTimeout: 0-255
        %   retries: 0-5
        %
        % Output: 
        %  settings: returned Access Point radio settings structure
        

            settings = []; %initialize output

            %optional parameter to make settings temporary.  
            if nargin < 2
                error('not enough inputs')
            elseif nargin == 2
                save = false;
            end

            if save == true
                cmd = 72; 
            else 
                cmd = 74; %temporary
            end

            payloadTX = [settingsIn.addrAP...
                       settingsIn.addrPM ...
                       settingsIn.chan ...
                       settingsIn.txPower ...
                       settingsIn.worInt...
                       settingsIn.rxTimeout ...
                       settingsIn.retries];

            payload = double(NNP.transmitAP(cmd, payloadTX));
            if length(payload) >= 7
                settings.addrAP  = payload(1);
                settings.addrPM  = payload(2);
                settings.chan    = payload(3);
                settings.txPower = payload(4);
                settings.worInt  = payload(5);
                settings.rxTimeout = payload(6);
                settings.retries = payload(7);
            end
        end
        
        function [sw, hw] = getAPRev(NNP)
        % GETAPREV - Reads AccessPoint SW/HW Rev
        % [sw, hw] = GETAPREV(NNP)
            sw = []; %initialize output
            hw = [];
                       
            payload = double(NNP.transmitAP(32));
            if length(payload) >= 4
                sw  = payload(1) + payload(2)*256;
                hw  = payload(3) + payload(4)*256;
            end           
        end
        
        %% Transmit
        
        function [dataRX, errOut, errRX]= transmit(NNP, node, data, counter, protocol)
        % TRANSMIT - Sends message to PM following NNP Radio API and returns response
        % [dataRX, errOut]= transmit(NNP, node, data, counter, protocol)
        %
        % errOut:
        % 1: PM Internal or CAN error
        % 2: PM response is too short
        % 3: Radio Timeout
        % 4: Unknown response from AccessPoint
        % 5: USB Timeout
        % 6: PM response does not echo request
        % 7: Bad CRC

            errRX = [];
            errOut = 7;
            dataRX = [];
            rssioffset = 74;

            if length(data) + 7 >  62 %Maximum bytes on Access Point CHECK THIS! <<TODO
                error('data to write is too long');
            end

            %if netID = 0, then response is always 7 
            if node == 7  
                netID = 1;
            else
                netID = 1;
            end

            payload = NNP.transmitAP(71, [protocol, counter, netID, node, data]);
            if length(payload) >= 2 %minimum usb header (3) + radio addr, len, rssi, lqi
                 rssiraw = double(payload(end-1));
                 lqiraw = double(payload(end));
                 if rssiraw < 128
                     NNP.RSSI = rssiraw/2 - rssioffset;
                 else
                     NNP.RSSI = (rssiraw-256)/2 - rssioffset;
                 end
                 if lqiraw >= 128
                    NNP.LQI = lqiraw - 128;
                 else
                    NNP.LQI = lqiraw;
                     if NNP.verbose > 0
                        disp(['Bad CRC:' num2str(payload(1:end), ' %02X')]');
                     end
                     errOut = 7;
                     NNP.lastError = 'Bad CRC';
                     return;
                 end

                 if NNP.verbose == 2
                    disp(['RSSI: ', num2str(NNP.RSSI), 'dB | LQI: ', num2str(NNP.LQI)]);
                 end
            end

            if length(payload) >= 10 
                %PM flagged response as error message     
                if payload(4) > 127 
                   errRX = payload(9:end-2);
                   if NNP.verbose > 0
                       disp(['PM Internal/CAN error: ', num2str(payload(1:end-2),' %02X')]); 
                   end
                   errOut = 1;
                   NNP.lastError = 'PM Internal or CAN error';

                %PM response doesn't match request
                %JML TODO: not sure all message types echo these 7 elements!
                elseif payload(1)~= protocol || payload(2)~=counter || payload(3)~=netID || payload(4)~=node ||...
                    payload(5)~=data(1) || payload(6)~=data(2) || payload(7)~=data(3) %OD Index LB, HB, Subindex
                    if NNP.verbose > 0
                        disp(['PM response does not echo request: ' num2str(payload(1:end-2), ' %02X')])
                    end
                    errOut = 6;
                    NNP.lastError = 'PM response does not echo request';

                %Expected response!
                else 
                    dataRX = payload(8:end-2);
                    errOut = 0; 
                end
            elseif isempty(payload)
                errOut = 3;
                %NNP.lastError = 'Radio Timeout';  %NNP.lastError already set by transmitAP
            else
                if NNP.verbose > 0
                    disp(['Short message: ', num2str(payload(1:end-2), ' %02X')]);
                end
                errOut = 2;
                NNP.lastError = 'PM response is too short';
            end        
        end
        
        function [dataRX, errOut]= pmboot(NNP, cmd, varargin)
        % PMBOOT - Sends message to PM following NNP RadioBootloader API and returns response
        % [dataRX, errOut]= pmboot(NNP, cmd, data)
        %
        % errOut:
        % 1: PM Internal or CAN error
        % 2: PM response is too short
        % 3: Radio Timeout
        % 4: Unknown response from AccessPoint
        % 5: USB Timeout
        % 6: PM response does not echo request
        % 7: Bad CRC
        
            errOut = 7;
            dataRX = [];
            rssioffset = 74;

            if nargin<3
                data = [];
            else
                data = varargin{1};
            end
            
            if length(data) + 1 >  62 %Maximum bytes on Access Point CHECK THIS! <<TODO
                error('data to write is too long');
            end

            if ischar(cmd)
                cmd = hex2dec(cmd); 
            end
            
            payload = NNP.transmitAP(71, [cmd, data]);

            %if message is long enough to include RSSI/LQI/CRC, calculate it
            if length(payload) >= 2 %minimum usb header (3) +  rssi, lqi
                 rssiraw = double(payload(end-1));
                 lqiraw = double(payload(end));
                 if rssiraw < 128
                     NNP.RSSI = rssiraw/2 - rssioffset;
                 else
                     NNP.RSSI = (rssiraw-256)/2 - rssioffset;
                 end
                 if lqiraw >= 128
                    NNP.LQI = lqiraw - 128;
                 else
                    NNP.LQI = lqiraw;
                     if NNP.verbose > 0
                        disp(['Bad CRC:' num2str(payload(1:end), ' %02X')]);
                     end
                     errOut = 7;
                     NNP.lastError = 'Bad CRC';
                     return;
                 end

                 if NNP.verbose == 2
                    disp(['RSSI: ', num2str(NNP.RSSI), 'dB | LQI: ', num2str(NNP.LQI)]);
                 end
                 dataRX = payload(1:end-2);    
            else
                if NNP.verbose > 0
                    disp(['Short message: ', num2str(payload(1:end-2), ' %02X')]);
                end
                errOut = 2;
                NNP.lastError = 'PM response is too short';
            end
                            
        end

        
        %% SDO Read
        
        function dataOut = read(NNP, node, indexOD, subIndexOD, varargin) 
        % READ - Read data from Object Dictionary subindex or subindices 
        % (SDO read or block read)
        % dataOut = read(NNP, node, indexOD, subIndexOD)
        % dataOut = read(NNP, node, indexOD, subIndexOD, readType)
        % dataOut = read(NNP, node, indexOD, subIndexOD, numSubIndices)
        % dataOut = read(NNP, node, indexOD, subIndexOD, readType, numSubIndices)
        %
        % Inputs:
        % port:       serial port for access point
        % node:       7 for PM or 1-15 for RM
        % indexOD:    OD index specified as 4 character hex string, (e.g. '1F53')
        % subIndexOD: OD subindex specified as 1-2 charachter hex string, (e.g. 'A' or '0A') 
        %             or as decimal numerical value (e.g. 10) 
        % Optional Inputs:
        % nSubindices: 1-50 decimal value indicating number of subindicse to read.
        %             Note: it is expected that all subindices to be read have same
        %             (scalar) type.
        %              (default = 1)
        % readType:  'uint8', 'uint16', 'uint32', 'int8', 'int16', 'int32', or 'string'
        %             use 'uint8' for bytearrays
        %              (default = 'uint8')
        % Output:
        % dataOut:    Object Dictionary entry cast to the specified readType
        %
        %NOTE: assumes little-endian processor for byte conversions to uint16, uint32, etc.
        %use: <code> [str,maxsize,endian] = computer </code>  to check your system
            if nargin < 4
                error('needs at least 4 inputs')
            end

            %defaults
            readType = 'uint8';
            numSubIndices = 1;
            
            %if optional arguments are provided, determine whether readType, nSubIndices, or both 
            for i=1:length(varargin)
                 if ischar(varargin{i})
                    readType = varargin{i};
                 elseif isnumeric(varargin{i})
                    numSubIndices = varargin{i};
                 else
                     warning('Optional arguments ignored because they are not correct type');
                 end
            end

            data = zeros(1,4, 'uint8');    
            dataOut = [];

            if node == 0 
                error('Message cannot be broadcast')
            end
            % check for valid OD Index
            if ischar(indexOD)
                if length(indexOD) ~= 4
                    error('OD index must be specified as 4 letter (hex) string');
                else
                    try
                        data(1) = hex2dec(indexOD(3:4)); %low byte
                        data(2) = hex2dec(indexOD(1:2)); %high byte
                    catch
                        error('OD index string type: hex string character must be 0-9 or a-f, A-F');
                    end
                end
            else   
                error('index must be as a string');
            end
            % check for valid OD SubIndex
            if ischar(subIndexOD)
                if length(subIndexOD) > 2
                    error('OD subindex string type: must be specified as <=2 letter (hex) string');
                else
                    try 
                        data(3) = hex2dec(subIndexOD);
                    catch
                        error('OD subindex string type: hex string character must be 0-9 or a-f, A-F');
                    end
                end
            else
                if subIndexOD > 255 || subIndexOD < 0
                    error('OD subindex numerical type: subindex must be between 0 and 255');
                else
                    data(3) = subIndexOD;
                end
            end
            if numSubIndices > 1
                data(4) = numSubIndices; 
                [dataRX, err] = NNP.transmit(node, data, 0, hex2dec('30')); %SDO Block Read
            else
                [dataRX, err] = NNP.transmit(node, data, 0, hex2dec('24')); %SDO Read
            end
            if err == 0
                if strcmpi(readType, 'string')
                    dataOut = char(typecast(dataRX(2:end), 'uint8')); %first byte is length byte
                else
                    try
                        dataOut = typecast(dataRX(2:end), readType); %first byte is length byte
                    catch
                        dataOut = [];
                        warning(['data was available but could not be typecast into specified type:'...
                            sprintf('%02X ', dataRX(2:end))]);
                    end
                end
            end
        end
        
        %% SDO Write
        
        function dataOut = write(NNP, node, indexOD, subIndexOD, writeData, varargin) 
        % WRITE - Write data to Object Dictionary subindex or subindices 
        %(SDO write or block write)
        % dataOut = write(NNP, node, indexOD, subIndexOD, writeData)
        % dataOut = write(NNP, node, indexOD, subIndexOD, writeData, numSubIndices)
        % dataOut = write(NNP, node, indexOD, subIndexOD, writeData, writeType)
        % dataOut = write(NNP, node, indexOD, subIndexOD, writeData, writeType, numSubIndices)
        %
        % port:       serial port for access point
        % node:       7 for PM or 1-15 for RM
        % indexOD:    OD index specified as 4 character hex string, (e.g. '1F53')
        % subIndexOD: OD subindex specified as 1-2 charachter hex string, (e.g. 'A' or '0A') 
        %             or as decimal numerical value (e.g. 10) 
        % writeData:  array of values to be sent (will be converted to writeType,
        %             if not already)
        % Optional Inputs:
        % nSubindices: 1-50 decimal value indicating number of subindicse to read.
        %             Note: it is expected that all subindices to be read have same
        %             (scalar) type.
        %              (default = 1)
        % writeType:  'uint8', 'uint16', 'uint32', 'int8', 'int16', 'int32', or 'string'
        %             use 'uint8' for bytearrays
        %              (default = 'uint8')
        % Output:
        % dataOut:    Object Dictionary write response.  0 is correct response
        % 
        %
        %NOTE: assumes little-endian processor for byte conversions to uint16, uint32, etc.
        %use: <code> [str,maxsize,endian] = computer </code>  to check your system
        %

            if nargin < 5
               error('needs at least 5 inputs')
            end
            
            %defaults
            writeType = 'uint8';
            numSubIndices = 1; 
            
            %if optional arguments are provided, determine whether readType, nSubIndices, or both 
            for i=1:length(varargin)
                 if ischar(varargin{i})
                    writeType = varargin{i};
                 elseif isnumeric(varargin{i})
                    numSubIndices = varargin{i};
                 else
                     warning('Optional arguments ignored because they are not correct type');
                 end
            end
   


            data = zeros(1,4, 'uint8');    
            dataOut = [];

            if node == 0 
                error('Message cannot be broadcast')
            end
            % check for valid OD Index
            if ischar(indexOD)
                if length(indexOD) ~= 4
                    error('OD index must be specified as 4 letter (hex) string');
                else
                    try
                        data(1) = hex2dec(indexOD(3:4)); %low byte
                        data(2) = hex2dec(indexOD(1:2)); %high byte
                    catch
                        error('OD index string type: hex string character must be 0-9 or a-f, A-F');
                    end
                end
            else   
                error('index must be as a string');
            end
            % check for valid OD SubIndex
            if ischar(subIndexOD)
                if length(subIndexOD) > 2
                    error('OD subindex string type: must be specified as <=2 letter (hex) string');
                else
                    try
                        data(3) = hex2dec(subIndexOD);
                    catch
                        error('OD subindex string type: hex string character must be 0-9 or a-f, A-F');
                    end
                end
            else
                if subIndexOD > 255 || subIndexOD < 0
                    error('OD subindex numerical type: subindex must be between 0 and 255');
                else
                    data(3) = subIndexOD;
                end
            end
            
            if strcmpi(writeType, 'string')
                if numSubIndices > 1
                    error('string is not supported for SDO_BlockWrite');
                else
                    writeType = 'uint8'; %string will get casted to bytes
                end
            end
            writeData = cast(writeData, writeType); % make sure data is actually assigned as specified
            writeBytes = typecast(writeData, 'uint8');
            len = length(writeBytes);
            
            if numSubIndices > 1
                switch writeType
                    case {'uint8', 'int8'}
                        mul = 1;
                        data(4) = numSubIndices;
                    case {'uint16', 'int16'}
                        mul = 2;
                        data(4) = numSubIndices + 64; %set bit6
                    case {'uint32', 'int32'} 
                        mul = 4;
                        data(4) = numSubIndices + 128; %set bit 7
                    otherwise
                        error('unsupported type');
                end
                if len ~= numSubIndices*mul
                    error('number of data bytes does not match numSubIndices and writeType')
                end

                [dataRX, err] = transmit(NNP, node, [data writeBytes], 0, hex2dec('B0')); %SDO Block Write
            else
                data(4) = len;
                [dataRX, err] = transmit(NNP, node, [data writeBytes], 0, hex2dec('A4')); %SDO Write
            end
            if err == 0
                dataOut = dataRX(2:end);
            end
        end
        
        %% NMT 
        
        function dataOut = nmt( NNP, node, command, param1, param2 )
        % NMT - Send Network Management Command
        %  dataOut = NMT_Command( port, node, command, param1, param2 )
        %  dataOut = NMT_Command( port, node, command, param1 )
        %  dataOut = NMT_Command( port, node, command )
        % 
        % port:       serial port for access point
        % node:       8 for CT, 7 for PM or 1-15 for RM
        % command:    NMT command specified as 1-2 charachter hex string, (e.g. 'A' or '0A') 
        %             or as decimal numerical value (e.g. 10) 
        % param1:     decimal value
        % param2:     decimal value
        % dataOut:    command echoed (in decimal) if occured with no errors
        
            dataOut = []; 
            
            if nargin < 5
                param2 = [];
                if nargin < 4
                    param1 = [];
                    if nargin <3
                        error('needs at least 3 inputs')
                    end
                end
            end

            % check for valid NMT
            if ischar(command)
                if length(command) > 2
                    error('command string type: must be specified as <=2 letter (hex) string');
                else
                    try
                        command = hex2dec(command);
                    catch
                        error('NMT string type: hex string character must be 0-9 or a-f, A-F');
                    end
                end
            else
                if command > 255 || command < 0
                    error('command numerical type: subindex must be between 0 and 255');
                end
            end



            %check for valid param1 and/or param2
            if isempty(param1) && ~isempty(param2)
                error('param2 cannot be provided if param1 is empty');
            elseif ~isempty(param1) && (param1 > 255 || param1 < 0)
                error('param1 must be between 0 and 255 if not empty, []');
            elseif ~isempty(param2) && (param2 > 255 || param2 < 0)
                error('param1 must be between 0 and 255 if not empty, []');
            end

            if  isempty(param1) && isempty(param2) 
                data = zeros(1,5, 'uint8');
                data(4) = 1;
                data(5) = command;
            elseif  isempty(param2)
                data = zeros(1,6, 'uint8');
                data(4) = 2;
                data(5) = command;
                data(6) = param1;
            else
                data = zeros(1,7, 'uint8'); 
                data(4) = 3;
                data(5) = command;
                data(6) = param1;
                data(7) = param2;
            end
            [dataRX, err]= NNP.transmit( node, data, 0, hex2dec('34'));
            if err == 0
                dataOut = dataRX(2:end);
            end
        end  
        
        %% Wake On Radio
        
        function success = worOn(NNP, wakeInterval )
        % WORON - Sets PM to "Wake On Radio" mode and enables long preambles on Access Point
        %  using the specified wake interval (in ms).  
        %   Longer wake interval results in lower power consumption but 
        %   lower maximum bandwidth and higher latency.  
        %   Note: Turning on WOR has much larger effect then changing wake
        %   interval
        %   
        %   Default = 20ms
        %   Minimum = 14ms
        %   Maximum = 255ms
            
            if nargin < 2
                wakeInterval = 20;
                if nargin < 1
                    error('needs at least 1 input');
                end
            end
            
            %configure wake interval on Access Point
            settings = NNP.getRadioSettings();
            if isempty(settings) 
                success = false;
                warning('worOn: failed to read radio settings')
                return
            elseif settings.worInt ~= wakeInterval
                settings.worInt = wakeInterval;
                settingsOut = NNP.setRadioSettings(settings, false);
                if NNP.verbose > 0 && settingsOut.worInt ~= wakeInterval
                    warning(['wakeInterval set to:', num2str(settingsOut.worInt)])
                end
            end

            %turn WOR on PM with same wake interval
            resp = NNP.nmt(7, '8B', uint8(wakeInterval),0);
            if resp == hex2dec('8B')
                success = true;
            else
                success = false;
            end
        end

        function success = worOff( NNP )
        % WOROFF - turns off "Wake On Radio" on PM and turns off long preamble on Access Point
        %   Significantly increases PM power consumption but maximizes
        %   max radio bandwidth and minimizes latency

            if nargin < 1
                error('needs at least 1 input');
            end

            %turn WOR off on PM
            resp = NNP.nmt(7, '8C'); 

            if resp == hex2dec('8C')
                success = true;
            else
                success = false;
                warning('worOff: failed to confirm PM disabled WOR.  Leaving WOR enabled on AP')
                return;
            end
            %eliminate wake interval on Access Point
            settings = NNP.getRadioSettings();
            if isempty(settings) 
                success = false;
                warning('worOff: failed to read radio settings')
                return    
            elseif settings.worInt ~= 0
                settings.worInt = 0;
                settingsOut = NNP.setRadioSettings(settings, false);
                if NNP.verbose > 0 && settingsOut.worInt ~= 0
                    warning(['wakeInterval set to:', num2str(settingsOut.worInt)])
                    success = false;
                end
            end

        end
        
        %% Read File
        function cancelReadFile(obj, event, NNP)
        % CANCELREADFILE - not implemented
        % 
            disp('cancel')
            NNP.cancelRead = true;
        end
        
        function dataOut = readFile( NNP, file, address, len, print, fileOut)
        % READFILE - Read PM Log or OD Restore file
        % dataOut = READFILE( NNP, file, address, len) does not print to
        % command line or file
        % dataOut = READFILE( NNP, file, address, len, print) prints to
        % command line
        % dataOut = READFILE( NNP, file, address, len, print, fileOut)
        % file: 'log', 'Log', or 1 - Log file
        %       'param', 'odrestore', 'OD Restore', or 2 - OD Restore file
        % address: starting address within file (0 to start at beginning)
        % len: length to read, or 'all' to read entire file
        % print: format to print to file or command line:
        %        'ascii', 'ASCII', or 1 to print as ASCII
        %        'bin', 'binary', 'Bin', 'Binary', or 2 to print in binary
        %        format
        %        'hex', or 'Hex', or 3 to convert to Hex (as ASCII)
        %        0 - don't print to command line
        %fileOut: file to write to
        %
        %datOut contains all data read from file
        
        
        dataOut = [];

        if nargin < 6
            fileOut = [];
            fid = 1;
            disp('fileOut parameter not included, so printing to command line')
            if nargin < 5
                print = false;
                if nargin < 4
                    error('needs at least 4 inputs')
                end
            end
        end

        switch print
            case {true, 'ascii', 'ASCII', 1}
                print = 1;
            case {'bin', 'binary','Bin','Binary', 2}
                print = 2;
            case {'hex', 'Hex', 3}
                print = 3;    
            case {false, 0}  
                print = 0;
        end
        switch file
            case {'log', 'Log', 1}
                counter = hex2dec('D0') + 1; %log file init
                file = 'Log';
            case {'param', 'odrestore', 'OD Restore', 2}
                counter = hex2dec('D0') + 2; %OD restore file init
                file = 'OD Restore';
            otherwise
                error('Not a valid file ID')
        end
        %counter = hex2dec('D0') + hex2dec('0E'); %remaining file

        if ~isempty(fileOut)
            fid = fopen(fileOut, 'w+');  %open or create file for writing and discard existing contents 
        end

        if strcmp(len, 'all') 
            switch file
                case 'Log'
                    len = NNP.getLogCursor();
                case 'OD Restore'
                    len = 1024;
            end
            if isempty(len)
                error('len could not be determined')
            elseif len == 0
                disp('no data in log');
                return;
            end
        end
        
        

        %len = uint16(len);
        %lenBytes = typecast(len, 'uint8'); %Note: currently len cannot exceed 
        msgsize = 48; %msgsize should not exceed 48

        address = uint32(address);
        
        startaddress = address;
        if rem(len, msgsize)
            finaladdress = address+len-rem(len, msgsize);
        else
            finaladdress = address+len- msgsize;
        end
        h = waitbar(0, sprintf(' Start Address: 0x%06X\n Final Address: 0x%06X\nCurrent Address: 0x%06X', startaddress, finaladdress, address) ,...
            'Name', ['Reading ', file, ' file.']);%,'CreateCancelBtn', @cancelReadFile  );
        %a = get(h, 'CurrentAxes' );
        h.CurrentAxes.FontName = 'Monospaced';

        
        while len > 0
            %double(address-startaddress)/double(finaladdress-startaddress)
            waitbar(double(address-startaddress)/double(finaladdress-startaddress), h, ...
            sprintf(' Start Address: 0x%06X\n Final Address: 0x%06X\nCurrent Address: 0x%06X', startaddress, finaladdress, address));
            if len > msgsize
                n = uint16(msgsize);
            else
                n = uint16(len);
            end
            lenBytes = typecast(n, 'uint8');
            addressBytes = typecast(address, 'uint8');
            data = [0 0 0 6 addressBytes lenBytes];
            [dataRX, err] = NNP.transmit(7, data, counter, hex2dec('26'));
            if err == 0
                if length(dataRX) < 4
                    disp('response contains no data')
                    continue;
                end
                %remaining = dataRX(2:3)
                dataFile = dataRX(4:end)';
                dataOut = [dataOut; dataFile];
                switch print
                    case 1
                        %print as formatted text
                        fprintf(fid, '%s', char(dataFile));
                    case 2
                        %binary file, no formatting
                        fwrite(fid, dataFile);
                    case 3
                        %up to 16 bytes per line.  Note only woks if msgsize is integer multiple of 16
                        fprintf(fid, '%02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X\n', dataFile);
                end
            else
                %retry
                continue;
            end
            len = len - double(n);
            address = address + uint32(n);
            
            
            %pause(0.001)
        end

        %close(h);
        if ~isempty(fileOut)
            fclose(fid);
        end

        end
        
        function [ dataOut ] = readMemory( NNP, node, memSelect, address, len, print, fastMode, disableWOR, printAddress)
        %READMEM Summary of this function goes here
        %   dataOut = READMEM( NNP, node, memSelect, address, len)
        %     node: 7(PM) or RM node (no broadcast: 0)
        %     memSelect
        %      1, 'flash', 'Flash' 
        %      2, 'remoteflash', 'remote flash', Remote Flash' PM only)
        %      3, 'remoteram', 'remote ram', Remote RAM' (PM only)
        %      4,  'eeprom', 'EEPROM'  (RM only)
        %     address: address in decimal
        %     len: number of bytes to read
        % optional additional arguments
        %   dataOut = READMEM( NNP, node, memSelect, address, len, print, fastMode, disableWOR, printAddress)
        %     print: print to command line if true
        %         default is false
        %     fastMode:  if true, uses NMT_Read_Memory_Now (supported on PM 404 and later and to be supported in RMs in future)
        %         default is false
        %     disableWOR: if true, turns off Wake On Radio mode to further speed up radio requests.  
        %         defaults to true if fastmode is true, and false otherwise
        %     printAddress: if true, prints address along with data
        %         default is false
        % print: true: print to command line
        % Timing examples for reading 512 bytes from PM Flash using default WOR interval of 20ms:
        %   fastMode  disableWOR  Result(s)
        %    false      false      3.6
        %    false      true       2.4
        %    true       false      1.2
        %    false      true       0.5
        % 
        % For fastmode, recommend setting AP retries to 0
            dataOut = [];

            %handle cases where fewer arguments are passed
            if nargin < 9
                printAddress = false;
                if nargin < 8
                    disableWOR = false;
                    if nargin < 7
                        fastMode = false;
                        disableWOR = false;
                        if nargin < 6
                            print = false;
                            if nargin < 5
                                error('needs at least 5 inputs')
                            end
                        end
                    end
                end
            end

            if node == 0 
                error('Message cannot be broadcast')
            end
            switch memSelect
                case{'flash', 'Flash', 1}
                    memSelect = 1;
                case{'remoteflash', 'remote flash', 'Remote Flash', 2}
                    if node ~= 7
                        disp('No Remote Flash on RMs')
                    end
                    memSelect = 2;
                case{'remoteram', 'remote ram',  'Remote RAM', 3}
                    if node ~= 7
                        disp('No Remote RAM on RMs')
                    end
                    memSelect = 3;
                case{'eeprom', 'EEPROM', 4}
                    if node == 7
                        disp('No EEPROM on PM')
                    end
                    memSelect = 4;
                case{'ram', 'RAM','local ram','localram', 'Local Ram', 9}
                    if node ~= 7
                        disp('No RAM access on RMs yet')
                    end
                    memSelect = 9;
                otherwise
                    error('Bad memory selection')
            end

            if disableWOR
                radioSettings = NNP.getRadioSettings();
                if radioSettings.worInt > 0
                    NNP.worOff();
                end
                if radioSettings.retries > 0
                    NNP.setRadio('retries', 0);
                end
            end

            if fastMode
                result = NNP.write(node, '2020', 1, address, 'uint32');   %set address
                if ~isequal(result, 0)
                    disp('error on set address-please try again') %have retry here?
                    len = 0; %ignore rest, but turn WOR back on if disabled
                end
            else
                %trigger first read, further reads are triggered by address changing
                 result = NNP.write(node, '2020', 5, 1, 'uint8');         
                if ~isequal(result, 0)
                    disp('error on trigger read-please try again') %have retry here?
                    len = 0; %ignore rest, but turn WOR back on if disabled
                end
            end

            sendNMT = true; %only relevant for fastMode
            retryCount = 0;
            maxRetries = 3;
            prevLen = len;
            while len > 0  
                %fprintf('\nlen %d, prev %d\n', len, prevLen);
               
                if len == prevLen 
                    retryCount = retryCount + 1;
                    if retryCount > maxRetries
                        userResp = questdlg(['Main loop in readMemory has exceeded ' num2str(maxRetries) ' retries.  Do you want to continue trying?']);
                        if isequal(userResp, 'No') 
                            dataOut = [];
                            break;
                        else
                            retryCount = 0;
                            continue;
                        end
                    end
                else
                    retryCount = 0;
                end
                prevLen = len;
                
                if fastMode
                    retryNMT=0;
                    while sendNMT 
                        resp = NNP.nmt(node, 'E8', memSelect); %Force read with auto increment
                        if isequal(resp, hex2dec('E8'))
                            break;
                        else
                            addressRead = NNP.read(node, '2020', 1, 'uint32');   %get address
                            if isequal(addressRead, address + 32)
                                disp('NMT was not confirmed directly but address has incremented correctly')
                                break
                            else
                                NNP.write(node, '2020', 1, address, 'uint32');   %reset address 
                                disp('Retrying: send NMT_Read_Memory_Now')
                                retryNMT = retryNMT + 1;
                                if retryNMT > maxRetries
                                    userResp = questdlg(['Send NMT loop in readMemory has exceeded ' num2str(maxRetries) ' retries.  Do you want to continue trying?']);
                                    if isequal(userResp, 'No') 
                                        len = 0; %break outer loop gracefully
                                        dataOut = [];
                                        break;
                                    else
                                        retryNMT = 0;
                                        continue;
                                    end
                                end
                            end
                        end
                    end
                else
                    result = NNP.write(node, '2020', 1, address, 'uint32');   %set address
                    if ~isequal(result, 0)
                        disp('Retrying: error on set address')
                        continue;
                    end
                    result = NNP.write(node, '2020', 4, memSelect, 'uint8');  %select memory
                    if ~isequal(result, 0)
                        disp('Retrying: error on select memory')
                        continue;
                    end

                    %runcanserver task that reads memory only updates every 100ms
                    pause(0.1); 
                end

                dataRX = NNP.read(node, '2020', 2, 'uint8');
                if length(dataRX)<4
                    disp('Retrying: no address back') 
                    sendNMT = false;  
                    continue;
                end
                addressback = typecast(dataRX(end-3:end), 'uint32');
                if addressback ~=  address
                    sendNMT = false; 
                    %check for error only if addressback doesn't match
                    result = NNP.read(node, '2020', 7, 'uint8');              %check for errors
                    if ~isempty(result) && ~isequal(result, 0)
                        disp(['Retrying: error on memory read: ' num2str(result)]);
                        continue;
                    else
                        %No known error or couldn't read error
                        if fastMode
                            NNP.write(node, '2020', 1, address, 'uint32');   %reset address
                        end
                        fprintf('\nRetrying: address back (0x%08x) does not match 0x%08x\n', addressback, address);
                        continue;
                    end
                end
                mem = dataRX(1:end-4)';
                if length(mem) > len
                    mem = mem(1:len); %mem should always be 32 long, but we may only want part of it
                end
                if(print) %up to 32 bytes per line
                    if printAddress
                        fprintf('%08X : %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X\n', address, mem)
                    else
                        fprintf('%02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X\n', mem)
                    end
                end
                sendNMT = true; %allows address increment
                dataOut = [dataOut; mem];
                len = len - length(mem);
                address = address + length(mem);
            end
            if disableWOR 
                if radioSettings.worInt > 0
                    NNP.worOn(radioSettings.worInt);
                end
                if radioSettings.retries > 0
                    NNP.setRadio('retries', radioSettings.retries);
                end
            end
        end
        
        function [result] = loadScript(NNP, SP, data)
            %result = LOADSCRIPT(NNP, SP, data) loads data to location specified by SP
            %   SP is script pointer (i.e. script download location (1-25)

            T = 32; %up to 48, SE uses 32 (max bytes to transfer per radio packet)
            N = length(data);
            nPackets = floor(N/T) + double(rem(N,T)>0);
            result = [];

            counter = nPackets -1;
            address = 0;
            packetCnt = 1;
            attempt = 0;

            settings = NNP.getRadioSettings;
            if settings.rxTimeout<100
                NNP.setRadio('Timeout', 100)
            end

            h=waitbar(0, sprintf('Loading script to location #%d', SP));
            while packetCnt <= nPackets
                if ~isempty(h) 
                    if ~isvalid(h)  %if waitbar closed assume user wants to cancel
                        userResp = questdlg('Do you want to cancel loading script?');
                        if isequal(userResp, 'Yes')
                            return
                        else
                            h = waitbar(packetCnt/nPackets, sprintf('Loading script to location #%d', SP)); %if waitbar was closed, reopen it
                        end
                    end
                    waitbar(packetCnt/nPackets, h)
                end
                addrBytes = typecast(uint16(address), 'uint8');


                if packetCnt==nPackets % last packet
                    pktN = rem(N,T);
                    if pktN==0
                        pktN = T;
                    end
                    NNP.setRadio('Timeout', 251); %1s timeout for last packet
                else
                    pktN = T;
                end

                pktData = data(address+1:address+pktN);
                if size(pktData, 1)>1
                    pktData = pktData'; % change column vector to row vector
                end
                %counter = 0;
                message = [hex2dec('50'), hex2dec('1f'), SP, pktN+2, addrBytes, pktData];
                [result, err, errMsg]= NNP.transmit(7, message, counter, hex2dec('A4'));
                if err
                    if length(errMsg)==4
                        switch errMsg(1)
                            case 2 
                                str = 'Script Pointer invalid';
                            case 3
                                str = 'Script packet too short';
                            case 4 
                                str = 'Could not reset script control';
                            case 5
                                str = 'Script too big';
                            case 6 
                                str = 'Script Packet out of sequence';
                            case 7
                                str = 'Could not validate script ID';
                            case 8 
                                str = 'Could not set script pointer';
                            case 9
                                str = 'Could not load global variables.  Total across scripts may not exceed 400 bytes';
                            otherwise
                                str = sprintf('Loadscript error: %02X', errMsg(1));
                        end
                        msgbox(str);
                        NNP.setRadio('Timeout', settings.rxTimeout)
                        if ~isempty(h) && isvalid(h)
                            close(h);
                        end
                        return
                    end
                    %disp(NNP.lastError)
                end
                if ~isequal(result, [1 0])
                    attempt = attempt + 1;
                    if attempt > 3
                        if err
                            userResp = questdlg(sprintf('Error (%s) in loadScript at address 0x%02X. Keep trying?', NNP.lastError, address));
                        else
                            userResp = questdlg(sprintf('Unknown error in loadScript  at address 0x%02X. Keep trying?', NNP.lastError, address));
                        end
                        if isequal(userResp, 'Yes')
                            continue;
                        else
                            NNP.setRadio('Timeout', settings.rxTimeout)
                            if ~isempty(h) && isvalid(h)
                                close(h);
                            end
                            return
                        end
                    else
                        continue;
                    end
                end
                pause(0.1)
                attempt = 0;
                address = address + T; 
                packetCnt = packetCnt + 1;
                counter = counter-1;
            end
            if ~isempty(h) && isvalid(h)
                close(h)
            end
        end       
    end
end