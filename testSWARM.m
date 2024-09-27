%% PDO Settings information
%          RPDO                           TPDO
%-------------------------------------------------------------------------------------
%mapping : OD subindices to put data      OD subindices to get data
%                                         IIIISSBB (IIII=index, SS=subindex, BB=size in bits)
%                                          Example: 1F530108, map 8 bits to/from 1F53.1
%
%id      : Source COB-ID                  COB-ID 
%
%type    : 0-240: synchronous -           0: acyclic synchronous -PDO sent when value changed AND SYNC received or on RTR
%              processed on next SYNC     1: cyclic synchronous - PDO sent when SYNC received or on RTR
%          255: asynchronous -            2-240: cyclic synchronous - PDO sent every X SYNCs or on RTR
%              processed immediately      252: synchronous RTR only - PDO sent when SYNC AND RTR received
%              when data arrives          253: asynchronous RTR only - PDO sent when RTR received
%                                         254-255: asynchronous - PDO sent when value changed 
%                                                  (can be limited by inhibit and event timer)
%
%                                         Note: we usually use 0 or 1 to
%                                         enable, and 253 to disable
%
%inhibit : not applicable (set to 0)      minimum time required between asynch PDOs (in 100us).  
%                                         Not applicable if type < 254
%
%compat  : script to run upon reception   not applicable (set to 0)
%          not applicable for RMs
%
%timer   : not applicable (set to 0)      Timer (in ms) between asynch PDOs if value changed.  Not applicable if
%                                         type < 254

%%
nodes = [1];

%% Set up PM RPDOs

%supports PG nodes 1-6, but configure all 8 PM RPDOs
RPDO=[];
RPDO.mapping = cell(8,1);
RPDO.mapping{1} = uint32(hex2dec({'1f530108','1f530208','1f530308','1f530408','1f530508','1f530608','1f530708','1f530808'})');
RPDO.mapping{2} = uint32(hex2dec({'1f530908','1f530a08','1f530b08','1f530c08','1f530d08','1f530e08','1f530f08','1f531008'})');
RPDO.mapping{3} = uint32(hex2dec({'1f531108','1f531208','1f531308','1f531408','1f531508','1f531608','1f531708','1f531808'})');
RPDO.mapping{4} = uint32(hex2dec({'1f531908','1f531a08','1f531b08','1f531c08','1f531d08','1f531e08','1f531f08','1f531008'})');
RPDO.mapping{5} = uint32(hex2dec({'1f532108','1f532208','1f532308','1f532408','1f532508','1f532608','1f532708','1f532808'})');
RPDO.mapping{6} = uint32(hex2dec({'1f532908','1f532a08','1f532b08','1f532c08','1f532d08','1f532e08','1f532f08','1f533008'})');
RPDO.mapping{7} = uint32(hex2dec({'00000000','00000000','00000000','00000000','00000000','00000000','00000000','00000000'})');
RPDO.mapping{8} = uint32(hex2dec({'00000000','00000000','00000000','00000000','00000000','00000000','00000000','00000000'})');

RPDO.id = uint32(hex2dec({'00000181','00000182','00000183','00000184','00000185','00000186','80000000','80000000'})');
RPDO.type = uint8(255); %process immediately when data received
% RPDO.type = uint8(0); %process on next SYNC
RPDO.inhibit = uint16(0); %not relevant for RPDO
RPDO.compat = uint8(0); %script pointer for script that runs when PDO is received
RPDO.timer = uint16(0); %not relevant for RPDO

%Write to OD
for i=1:8
    res = [];
    res = [res nnp.write(7, ['160' num2str(i-1)], 1, RPDO.mapping{i}, 'uint32', 8)];
    res = [res nnp.write(7, ['140' num2str(i-1)], 1, RPDO.id(i), 'uint32')];
    res = [res nnp.write(7, ['140' num2str(i-1)], 2, RPDO.type, 'uint8')];
    res = [res nnp.write(7, ['140' num2str(i-1)], 3, RPDO.inhibit, 'uint16')];
    res = [res nnp.write(7, ['140' num2str(i-1)], 4, RPDO.compat, 'uint8')];
    res = [res nnp.write(7, ['140' num2str(i-1)], 5, RPDO.timer, 'uint16')];
    if isequal(res, [0 0 0 0 0 0])
        fprintf('\n--PM RPDO #%1.0f written--\n', i) 
    else
        fprintf('\n--ERROR on write: PM RPDO #%1.0f--\n', i) 
    end
end
%Read back from OD
for i=1:8
    fprintf('\n--PM RPDO #%1.0f--\nMapping:\n', i) 
    fprintf('  %08X\n', nnp.read( 7, ['160' num2str(i-1)], 1, 8, 'uint32'))
    fprintf('Settings:\n  %08X %02X %04X %02X %04X\n', ...
                [nnp.read(7, ['140' num2str(i-1)], 1, 'uint32')
                 nnp.read(7, ['140' num2str(i-1)], 2, 'uint8')
                 nnp.read(7, ['140' num2str(i-1)], 3, 'uint16')
                 nnp.read(7, ['140' num2str(i-1)], 4, 'uint8')
                 nnp.read(7, ['140' num2str(i-1)], 5, 'uint16')])
end

%%
% end
%%
nnp.networkOff
%%
nnp.networkOn
%%
nnp.enterWaiting
%%
nnp.enterTestFeatures

%%
nnp.refresh
while 1
    resp = nnp.read(7,'1f53', 1, 6);
    if length(resp) == 6
        accel = double(typecast(resp, 'int16'))/16384;
        fprintf('\nX %6.3f   Y %6.3f   Z %6.3f   Mag  %6.3f', [accel norm(accel)])
    end
    pause(0.1)

end
%%
nnp.refresh
k=0;
while 1
    
    resp = nnp.read(7,'1f53', 1, 6);
    if length(resp) == 6
       if k==20
            fprintf('\n%3.0f ', resp(1));
            k=0;
       else
           fprintf('%3.0f ', resp(1))
       end
       k=k+1;
    end
    pause(0.00001)

end
%%
%NMT_Clear_CAN_Errors          0x98
nnp.networkOnBootloader();
pause(.01)

nnp.refresh
nnp.nmt(7, '98')
tic
while toc<1*60
    
    resp = double(nnp.read(7,'2500', 1, 10, 'uint16'));
    if length(resp) == 10
       
    fprintf('\nTotal %6.0f: B%6.0f S%6.0f F%6.0f O%6.0f RXE%6.0f TXE%6.0f BEI%6.0f RX%6.0f TX%6.0f', resp);
    k=0;

    end
    pause(0.01)

end
%%
tic
while toc<60
    nnp.lastError = [];
    resp = nnp.read(1, '2000', 1);
    if length(resp)== 4
        fprintf('\nSDO# %3.0f   RM# %3.0f  ERR %3.0f   %3.0f', resp)
    else
        if strcmp(nnp.lastError, 'PM Internal or CAN error')
            fprintf('\nCAN ERR')
        end
    end
    pause(0.1)
end