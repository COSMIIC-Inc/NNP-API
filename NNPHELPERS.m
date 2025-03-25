classdef NNPHELPERS < NNPCORE
    %NNPHELPERS Adds commonly used helper methods to NNPCORE 
    %   Detailed explanation goes here

    methods
        function success = networkOn(NNP)
        % NETWORKON -turn ON network (must be in waiting mode)
        % success = NETWORKON(NNP)
            resp = NNP.nmt(7, '95'); 
            success = (resp == hex2dec('95'));
        end
        
        function success = networkOnBootloader(NNP)
        % NETWORKONBOOTLOADER - turn ON network, but don't start RM apps (must be in waiting mode)
        % success = NETWORKONBOOTLOADER(NNP)
            resp = NNP.nmt(7, 'A0'); 
            success = (resp == hex2dec('A0'));
        end
        
        function success = networkOff(NNP)
        % NETWORKOFF -turn OFF network (must be in waiting mode)
        % success = NETWORKOFF(NNP)
            resp = NNP.nmt(7, '96');
            success = (resp == hex2dec('96'));
        end
        
        function success = enterWaiting(NNP)
        % ENTERWAITING - Enter Waiting
        % success = ENTERWAITING(NNP)
            resp = NNP.nmt(0, '07'); 
            success = (resp == hex2dec('07'));
        end
        
        function success = enterPatient(NNP, pattern)
        % ENTERPATIENT - Enter Patient Mode
        % success = ENTERPATIENT(NNP) 
            if nargin > 1
                resp = NNP.nmt(0, '03', pattern); 
            else
                resp = NNP.nmt(0, '03');
            end
            success = (resp == hex2dec('03'));
        end
        
        function success = enterTestStim(NNP, mode)
        % ENTERTESTSTIM - Enter "Y Manual" Mode
        % success = ENTERTESTSTIM(NNP) 
        %     stim values are set in PG 3212.1-4 directly
        % success = ENTERTESTSTIM(NNP, mode)
        %     mode = 0: stim values are set in PG 3212.1-4 directly
        %     mode = 1: stim values are set in PM, PDOs must be mapped
        %     appropriately
        %     mode = 2: same as 1 but updates only occur if change has
        
            if nargin > 1
                resp = NNP.nmt(0, '05', mode); 
            else
                resp = NNP.nmt(0, '05');
            end
            success = (resp == hex2dec('05'));
        end
        
        function success = enterTestPatterns(NNP, pattern)
        % ENTERTESTPATTERNS - Enter "X Manual" Mode
        % success = ENTERTESTPATTERNS(NNP)
        %   follow up with activating specific patterns 
        % success = ENTERTESTPATTERNS(NNP, pattern) activates specified pattern
            if nargin > 1
                resp = NNP.nmt(0, '04', pattern);
            else
                resp = NNP.nmt(0, '04');
            end
            success = (resp == hex2dec('04'));
        end
        
        function success = enterTestRaw(NNP, node, ch) 
        % ENTERTESTRAW - Enter Raw MES Mode
        % success = ENTERTESTRAW(NNP, node, ch)
            resp = NNP.nmt(0, '0C', node+(ch-1)*16); 
            success = (resp == hex2dec('0C'));
        end
        
        function success = enterTestFeatures(NNP, mode)
        %ENTERTESTFEATURES - Enter "Produce X" Mode
        % success = ENTERTESTFEATURES(NNP)
        % success = ENTERTESTFEATURES(NNP, mode)
        %     mode = 0: stim values are set in PG 3212.1-4 directly
        %     mode = 1: stim values are set in PM, PDOs must be mapped
        %     appropriately
        %     mode = 2: same as 1 but updates only occur if change has
            if nargin > 1
                resp = NNP.nmt(0, '09', mode);
            else
                resp = NNP.nmt(0, '09'); 
            end
            success = (resp == hex2dec('09'));
        end
        
        function success = enterLowPower(NNP, node)
        % ENTERLOWPOWER - Enter low power.  For RM, requires Network power cycle to restore
        % success = ENTERLOWPOWER(NNP, node)
            resp = NNP.nmt(node, '9F'); 
            success = (resp == hex2dec('9F'));
        end
        
        function success = enterApp(NNP, node)
        % ENTERAPP - Wake from bootloader
        % success = ENTERAPP(NNP) wakes all
        % success = ENTERAPP(NNP, node) wakes selected node or all if node = 0
             if nargin > 1
                resp = NNP.nmt(7, '93', node);
             else
                 resp = NNP.nmt(7, '93', 0);
             end
            success = (resp == hex2dec('93'));
        end
        
        function success = powerOff(NNP)
        % POWEROFF -power off PM
            resp = NNP.nmt(7, '9E', 0);
            success = (resp == hex2dec('9E'));
        end
        
        function rev = getSwRev(NNP, node)    
        % GETSWREV Get Node's Software Revision #
        % rev = GETSWREV(NNP, node) 
           if nargin < 2
               node = 7;
           end
           rev = double(NNP.read(node, '1018', 3, 'uint32')); % rev
        end
        
        function sn = getSerial(NNP, node)  
        % GETSERIAL Get Node's  PCB Serial Number #
        % sn = GETSERIAL(NNP, node) 
           if nargin < 2
               node = 7;
           end
           sn = double(NNP.read(node, '1018', 4, 'uint32')); % pcb serial number
        end
        
        function type = getType(NNP, node)  
        % GETTYPE Get Node's  Type
        % type = GETTYPE(NNP, node) 
           if nargin < 2
               node = 7;
           end
           type = NNP.read(node, '1008', 0, 'string'); 
        end
        
        function success = setVNET(NNP, V) 
        % SETVNET Set PM Network Voltage (in Volts).  Range 4.7-9.6
        % success = SETVNET(NNP, V) 
            if V < 4.7 || V > 9.6
                error('Voltage out of range: must be between 4.7 and 9.6V')
            end
            resp = NNP.write(7, '3010', 0, uint8(V*10), 'uint8'); %VNET
            success = (resp == 0);
        end
        
        function vnet = getVNET(NNP) 
        % GETVNET Get PM Network Voltage (in Volts)
        % vnet = GETVNET(NNP)
            vnet = double(NNP.read(7, '3010', 0, 'uint8'))/10; %VNET
        end
        
        function temp = getTemp(NNP, node)
        % GETTEMP Get temperature for specified node(in deg C)
        % temp = GETTEMP(NNP, node) 
            resp = NNP.read(node, '2003', 1, 'uint16'); 
            if length(resp) == 1
                temp = double(resp)/10;
            else
                temp = [];
            end
        end
        
        function [accel, cnt, mag] = getAccel(NNP, node)
        % GETACCEL
        % accel = GETACCEL(NNP, node) returns accelerometer value (in g's) for specified node 
        % [accel, cnt, mag] = GETACCEL(NNP, node) also returns cnt and magnitude
           if nargin < 2
               node = 7;
           end
            temp = NNP.read(node, '2011', 1, 'uint8'); %
            if length(temp)==4
                if all(temp==255)
                    accel = [Inf Inf Inf];
                    cnt = Inf;
                    mag = Inf;
                else
                    accel = [0 0 0];
                    for i=1:3
                        accel(i) = (double((bitshift(temp(i), -2))) - 32)/16;
                    end
                    cnt = double(temp(4));
                    mag = norm(accel);
                end
            else
                accel = [];
                cnt = [];
                mag = [];
            end
        end
        
        function power = getPower(NNP)
        % power = GETPOWER(NNP)
        % read system power into/out of PM battery  
        % negative is discharging batteries, positive is charging
        % batteries.  This is a 5s average.  Due to other update
        % asynchronicities, the power may only reach steady state after
        % 12s following a transition
            bat = double(NNP.read(7, '3000', 13, 'uint8'));
            if length(bat)<20
                power = [];
            else
                batV = [bat( 7)+bat( 8)*256, bat( 9)+bat(10)*256, bat(11)+bat(12)*256]; %in mV
                batV(batV==65535) = 0;
                batI = uint16([bat(15)+bat(16)*256, bat(17)+bat(18)*256, bat(19)+bat(20)*256]);
                batI(batI==65535) = 0;
                batI = double(typecast(batI, 'int16'))/10; %in mA
                power = round(sum(batI.*batV)/1000); %in mW
            end
        end
        
        function success = setBPGains(NNP, node, ch1, ch2)
        % SETBPGAINS Sets gain wiper setting for both channels for specified node
        % success = SETBPGAINS(NNP, node, ch1, ch2)
            resp = NNP.nmt(node, 'D0', ch1, ch2);
            success = (resp == hex2dec('D0'));
        end
        
        function [ch1, ch2] = getBPGains(NNP, node)
        % GETBPGAINS Returns gain wiper setting for both channels
        % [ch1, ch2] = GETBPGAINS(NNP, node)
            ch1 = double(NNP.read(node, '3411', 1));
            ch2 = double(NNP.read(node, '3511', 1));
            if isempty(ch1)
                ch1 = nan;
            end
            if isempty(ch2)
                ch2 = nan;
            end
        end
        
        function stacks = checkPMStacks(NNP)
        % CHECKPMSTACKS Returns the stack usage for the 9 tasks running on PM (in %).
        % stacks = CHECKPMSTACKS(NNP)
        % 1. App
        % 2. CAN Server
        % 3. CAN Timer
        % 4. IO Scan
        % 5. Sleep
        % 6. Script
        % 7. Tick
        % 8. Idle
        % 9. Stats
            stacks = double(NNP.read(7, '3030', 1,9,'uint8'));
        end
        function success = saveOD(NNP, node)
        % success = SAVEOD(NNP, node)
        % Save Node's OD
            resp = NNP.nmt(node, '0A');
            success = (resp == hex2dec('0A'));
        end
        function success = resetPM(NNP)
        % RESETPM Turns off PM, require coil to restart
        % success = RESETPM(NNP)
            resp = NNP.nmt(7, '9E'); 
            success = (resp == hex2dec('9E'));
        end
        function success = setSync(NNP, T) 
        % SETSYNC Set PM sync interval (in ms)
        % success = SETSYNC(NNP, T) 
            resp = NNP.write(7, '1006', 0, uint32(T), 'uint32'); 
            success = (resp == 0);
        end
        function T = getSync(NNP) 
        % GETSYNC Get PM sync interval (in ms)
        % T = GETSYNC(NNP) 
            T = double(NNP.read(7, '1006', 0, 'uint32')); 
        end
        function success = flushLog(NNP)
        % FLUSHLOG Clear the PM Log space
        % success = FLUSHLOG(NNP)
            resp = NNP.nmt(7,'B8',1);
            success = (resp == hex2dec('B8'));
        end
        function success = initDirectory(NNP) %JML: do we need this?
        % INITDIRECTORY Initialize the PM Log directory
        % success = INITDIRECTORY(NNP)
            resp = NNP.nmt(7,'B9');
            success = (resp == hex2dec('B9'));
        end
        function A = getLogCursor(NNP)  
        % GETLOGCURSOR Get PM Log cursor position (remote flash address)
        % A = GETLOGCURSOR(NNP)  
            A = double(NNP.read(7,'a200', 3, 'uint32'));
        end
        function status = getNetworkStatus(NNP)
        % GETNETWORKSTATUS returns whteher netowrk is on (1) or off (0)
        % status = getNetworkStatus(NNP)
            status = double(NNP.read(7, '3004', 1));
        end
        
        function [year, month, day, dow, hour, min, sec] = getTime(NNP)
            % GETTIME Returns time from PM 
            year = [];
            month = [];
            day = [];
            dow = [];
            hour = [];
            min = [];
            sec = [];
            t = NNP.read(7,'2004',1,2, 'uint32');
            if length(t)==2
                year = double( bitshift(bitand(t(1), hex2dec('ffff0000')), -16) );
                month = double( bitshift(bitand(t(1), hex2dec('0000ff00')), -8) );
                day = double( bitand(t(1), hex2dec('000000ff')) );
                dow = double( bitshift(bitand(t(2), hex2dec('0f000000')), -24) );
                hour = double( bitshift(bitand(t(2), hex2dec('0001f0000')), -16) );
                min = double( bitshift(bitand(t(2), hex2dec('00003f00')), -8) );
                sec = double( bitand(t(2), hex2dec('0000003f')) );
            end
        end

        function success = setTime(NNP)
            % SETTIME sets time on PM based on current computer time
            resp = NNP.nmt(7, '97'); %stop clock
            if resp ~= hex2dec('97')
                success = false;
                return
            end

            dt = datetime;
            
            t=uint32([0 0]);
            t(1) = bitshift(uint32(year(dt)), 16) + ...
                   bitshift(uint32(month(dt)), 8) + ...
                   uint32(day(dt));
            t(2) = bitshift(uint32(weekday(dt)), 24) +...
                   bitshift(uint32(hour(dt)), 16) + ...
                   bitshift(uint32(minute(dt)), 8) + ...
                   uint32(second(dt));
            resp = NNP.write(7,'2004',1,t,2, 'uint32');
            if resp ~= 0
                success = false;
                return
            end

            resp = NNP.nmt(7, '88'); %set/start clock
            if resp ~= hex2dec('88')
                success = false;
                return
            end
            success = true;
        end

        function [modes, temp, vsys, net, rssi, lqi, group, lpm] = getStatus(NNP, nodes)
        % GETSTATUS Return node table and other PM status information 
        % modes = GETSTATUS(NNP) returns entire node table (15 nodes)
        % modes = GETSTATUS(NNP, nodes) returns mode for specified nodes
        % [modes, temp, vsys, net, rssi, lqi, group, lpm] = getStatus(NNP, nodes)
        % modes: list of modes for each node (string) 
        % temp: temperature (in degC)
        % vsys: system Voltage (Volts)
        % net: network status (1=on, 0=off)
        % rssi: PM radio RSSI (in dBm)
        % lqi: PM radio LQI
        % group: active function group
        % lpm: Low Power Mode Status
        
            resp = double(NNP.nmt(7,'10'));
            if nargin == 1
                nodes = 1:15;
            end
                
            if length(resp) == 29
                modes = cell(length(nodes),1); 
                k=1;
                for i=nodes
                    switch resp(i+1)
                        case 1,   mode = 'Waiting';
                        case 2,   mode = 'TestPatterns';
                        case 3,   mode = 'TestStim';                                          
                        case 4,   mode = 'Stopped';
                        case 5,   mode = 'Patient';
                        case 6,   mode = 'BootCheckReset';
                        case 7,   mode = 'Test Patient Mode';
                        case 8,   mode =  'Test Features';
                        case 9,   mode = 'Test Raw';
                        case 10,   mode = 'Charging';
                        case 15,   mode =  'Not Connected';
                        otherwise,  mode = 'Unknown';
                    end
                    modes{k} = mode;
                    k=k+1;
                end
                rssiraw = resp(21);
                lqiraw = resp(22);
                rssioffset = 74;
                   
                 if rssiraw < 128
                     rssi = rssiraw/2 - rssioffset;
                 else
                     rssi = (rssiraw-256)/2 - rssioffset;
                 end
                 if lqiraw >= 128
                    lqi = lqiraw - 128;
                 else
                    lqi = lqiraw; %bad CRC
                 end
                net = resp(23);
                vsys = (resp(24) + resp(25)*256)/10;
                group = resp(26);
                temp = (resp(27) + resp(28)*256)/10;
                lpm = resp(29);
            else
                 modes = [];
                 rssi = [];
                 lqi = [];
                 net = [];
                 vsys = [];
                 group = [];
                 temp = [];
                 lpm = [];               
            end
        end
    end

end